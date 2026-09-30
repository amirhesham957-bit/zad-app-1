-- الفجوة ٧ (٢٠٢٦-٠٩-٢٩، قرار المالك): تقدير تقريبي للاستهلاك من أول دورة «اشتريت ← خلص».
--
-- قبل كده zad_recompute_consumption كانت عايزة نزلتين لنفس الصنف قبل ما تحسب أي
-- حاجة، والدورة العادية (اشترى ٢، خلصوا بعد ٥ أيام) بتدي نزلة واحدة — فالتعلّم
-- كان بياخد شهور. المقاس: آخر حساب ٢٠٢٦-٠٨-٢٩، صفّين بس في zad_consumption، رغم إن
-- أسئلة تليجرام «خلص / لسه موجود» سجّلت ٨ نزلات لـ٩ أصناف.
--
-- اللي اتغيّر:
--   * نزلة واحدة = معدل تقريبي: الكمية اللي نزلت ÷ الأيام من آخر ريستوك (قراية
--     طلعت فيها الكمية، أو أول قراية) لحد النزلة. أقل من ١٢ ساعة = مفيش تقدير:
--     الداتا الحقيقية فيها دورات أقصر من يوم (لبن ١ ← ٠ في ١٧.٦ ساعة، مياه في ٢١
--     ساعة)، وفيها داتا تجربة (٦ ← ١ في ٣ دقايق) لازم تترفض.
--   * نزلتين فأكتر: نفس الحساب القديم بالظبط (إجمالي النزول ÷ المدة كلها).
--   * rate_known ماتغيرش (٣ نزلات على يومين مختلفين). التقريبي بيتخزن
--     rate_known = false، فالصنف يفضل «ينفع يتسأل عنه» والعقل يأكده.
--   * zad_forward_ledger بيرجّع التقريبي في stockouts بـconfidence = 'approximate'
--     بدل ما يرميه في stock_unknown، والمعروف بـconfidence = 'known'.
--   * _inventory_needs_checkin بيعدّ التقريبي: سؤال «لسه موجود؟» تأكيد، والتقريبي
--     هو بالظبط الوقت اللي السؤال فيه بيفيد.

create or replace function public.zad_recompute_consumption(p_user uuid, p_item text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_total_drop double precision;
  v_drops int;
  v_span_days double precision;
  v_distinct_days int;
  v_rate double precision;
  v_last_drop double precision;
  v_cycle_days double precision;
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'not_authorized';
  end if;

  with ordered as (
    select qty, observed_at,
           lag(qty) over (order by observed_at) as prev_qty
      from public.zad_inventory_observations
     where user_id = p_user and item_name = p_item
  ),
  drops as (
    select (prev_qty - qty) as amount, observed_at
      from ordered
     where prev_qty is not null and qty < prev_qty
  ),
  span as (
    select extract(epoch from (max(observed_at) - min(observed_at))) / 86400.0 as days
      from public.zad_inventory_observations
     where user_id = p_user and item_name = p_item
  )
  select coalesce(sum(d.amount), 0), count(*), count(distinct d.observed_at::date),
         (select days from span)
    into v_total_drop, v_drops, v_distinct_days, v_span_days
    from drops d;

  v_drops := coalesce(v_drops, 0);

  if v_drops = 0 or v_total_drop <= 0 then
    return jsonb_build_object('samples', v_drops, 'avg_daily_qty', null, 'rate_known', false);
  end if;

  if v_drops >= 2 and coalesce(v_span_days, 0) >= 1.0 then
    v_rate := v_total_drop / v_span_days;
  else
    -- دورة واحدة: آخر نزلة، من آخر ريستوك قبلها (أو أول قراية) لحد النزلة.
    with ordered as (
      select qty, observed_at,
             lag(qty) over (order by observed_at) as prev_qty
        from public.zad_inventory_observations
       where user_id = p_user and item_name = p_item
    ),
    last_drop as (
      select (prev_qty - qty) as amount, observed_at
        from ordered
       where prev_qty is not null and qty < prev_qty
       order by observed_at desc
       limit 1
    )
    select ld.amount,
           extract(epoch from (ld.observed_at - (
             select max(o.observed_at) from ordered o
              where o.observed_at < ld.observed_at
                and (o.prev_qty is null or o.qty > o.prev_qty)
           ))) / 86400.0
      into v_last_drop, v_cycle_days
      from last_drop ld;

    if v_cycle_days is null or v_cycle_days < 0.5 or coalesce(v_last_drop, 0) <= 0 then
      return jsonb_build_object('samples', v_drops, 'avg_daily_qty', null, 'rate_known', false);
    end if;
    v_rate := v_last_drop / v_cycle_days;
  end if;

  insert into public.zad_consumption
    (user_id, item_name, avg_daily_qty, sample_count, rate_known, last_computed_at)
  values
    (p_user, p_item, v_rate, v_drops, (v_drops >= 3 and v_distinct_days >= 2), now())
  on conflict (user_id, item_name) do update
    set avg_daily_qty    = excluded.avg_daily_qty,
        sample_count     = excluded.sample_count,
        rate_known       = excluded.rate_known,
        last_computed_at = excluded.last_computed_at;

  return jsonb_build_object(
    'samples', v_drops,
    'avg_daily_qty', v_rate,
    'rate_known', (v_drops >= 3 and v_distinct_days >= 2)
  );
end $function$;

-- سؤال «لسه موجود؟» بيتسأل بمعدل تقريبي كمان. p_rate_known فاضل في التوقيع عشان
-- المتصلين الحاليين (notify_telegram_on_low_stock) مايتغيروش.
create or replace function public._inventory_needs_checkin(p_quantity numeric, p_threshold numeric, p_avg_daily_qty numeric, p_rate_known boolean)
 returns boolean
 language sql
 immutable
 set search_path to 'public'
as $function$
    select p_quantity <= coalesce(p_threshold, 2)
        or (coalesce(p_avg_daily_qty, 0) > 0 and p_quantity / p_avg_daily_qty <= 2);
$function$;

create or replace function public.zad_forward_ledger(p_user uuid, p_days integer default 30, p_tz text default 'UTC'::text)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'public'
as $function$
with guard as (
  -- Same shape as the other SECURITY DEFINER readers: a signed-in caller may only ask
  -- about themselves; service_role (auth.uid() null) may ask about anyone.
  select case
    when auth.uid() is not null and auth.uid() <> p_user
      then null::uuid
    else p_user
  end as uid,
  greatest(1, least(coalesce(p_days, 30), 120)) as horizon
),
st as (
  select g.uid, g.horizon, public.zad_budget_state(g.uid, p_tz) as s
  from guard g where g.uid is not null
),
base as (
  select uid, horizon,
    (s->>'as_of')::date as as_of,
    coalesce((s->>'balance')::numeric, 0) as opening,
    -- velocity is spend-per-day so far this cycle. Negative or absent means we have no
    -- evidence of a burn rate, and projecting a negative burn would invent income.
    greatest(coalesce((s->>'velocity')::numeric, 0), 0) as burn,
    s->>'currency' as currency,
    (s->>'cycle_end')::date as cycle_end
  from st
),
days as (
  select b.*, gs::date as d, (gs::date - b.as_of) as idx
  from base b, generate_series(b.as_of + 1, b.as_of + b.horizon, interval '1 day') gs
),
ev as (
  select d.d, 'obligation'::text as kind, o.title, (-o.amount)::numeric as amount
  from days d
  join zad_obligations o on o.user_id = d.uid and o.active
  where public.zad_obligation_next_due(o.recurrence, o.due_day, o.due_date, d.d - 1) = d.d
  union all
  select d.d, 'subscription', s.title, (-s.amount)::numeric
  from days d
  join zad_subscriptions s on s.user_id = d.uid and s.is_active
  where public.zad_subscription_next_renewal(s.renewal_date, s.due_day, s.billing_cycle, d.d - 1) = d.d
),
per_day as (
  select d.d, d.idx, d.opening, d.burn,
    coalesce((select sum(amount) from ev where ev.d = d.d), 0) as day_events,
    coalesce(
      (select jsonb_agg(jsonb_build_object('kind', kind, 'title', title, 'amount', amount))
       from ev where ev.d = d.d),
      '[]'::jsonb
    ) as events
  from days d
),
running as (
  select d, idx, events,
    round(
      opening - burn * idx
      + sum(day_events) over (order by d rows between unbounded preceding and current row),
      2
    ) as balance
  from per_day
),
stock as (
  select i.item_name, c.avg_daily_qty,
    floor(i.quantity / nullif(c.avg_daily_qty, 0))::int as days_left,
    -- known = ٣ نزلات على يومين؛ approximate = من دورة أو اتنين، يتقال «تقريباً».
    case when c.rate_known then 'known' else 'approximate' end as confidence
  from zad_inventory i
  join zad_consumption c
    on c.user_id = i.user_id and c.item_name = i.item_name
   and c.avg_daily_qty > 0
  where i.user_id = (select uid from base) and i.quantity > 0
),
unknown_stock as (
  select i.item_name
  from zad_inventory i
  left join zad_consumption c
    on c.user_id = i.user_id and c.item_name = i.item_name and c.avg_daily_qty > 0
  where i.user_id = (select uid from base) and i.quantity > 0 and c.item_name is null
)
select case when (select count(*) from base) = 0 then null::jsonb else jsonb_build_object(
  'as_of', (select as_of from base),
  'currency', (select currency from base),
  'horizon_days', (select horizon from base),
  'opening_balance', (select opening from base),
  'daily_burn', (select burn from base),
  'cycle_end', (select cycle_end from base),
  -- The headline: the first day the projection crosses zero, or null if it never does.
  'first_negative', (
    select jsonb_build_object('date', d, 'balance', balance)
    from running where balance < 0 order by d limit 1
  ),
  'lowest', (
    select jsonb_build_object('date', d, 'balance', balance)
    from running order by balance asc, d asc limit 1
  ),
  -- Only days something actually happens. A 30-row array where 28 rows are "nothing
  -- happened" is noise in a prompt and noise on a screen.
  'event_days', (
    select coalesce(jsonb_agg(jsonb_build_object('date', d, 'balance', balance, 'events', events) order by d), '[]'::jsonb)
    from running where jsonb_array_length(events) > 0
  ),
  'stockouts', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'item_name', item_name, 'days_left', days_left,
      'date', (select as_of from base) + days_left,
      'avg_daily_qty', avg_daily_qty,
      'confidence', confidence
    ) order by days_left), '[]'::jsonb)
    from stock where days_left <= (select horizon from base)
  ),
  -- Named, not silently omitted: "I don't know how fast you get through this" is a real
  -- answer and the only honest one until zad_consumption has a cycle for the item.
  'stock_unknown', (
    select coalesce(jsonb_agg(item_name order by item_name), '[]'::jsonb) from unknown_stock
  )
) end;
$function$;

-- الداتا اللي اتسجلت قبل كده تاخد تقديرها دلوقتي، مش لما الصنف ياخد قراية جديدة.
do $backfill$
declare r record;
begin
  for r in select distinct user_id, item_name from public.zad_inventory_observations loop
    perform public.zad_recompute_consumption(r.user_id, r.item_name);
  end loop;
end
$backfill$;
