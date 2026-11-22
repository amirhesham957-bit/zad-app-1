-- ZAD_OR_PLAN م٣.٢: زرار «أسرع / أبطأ» على تقدير المخزن.
--
-- العميل بيحسب المعدل الجديد (الكمية ÷ الأيام المتبقية × ١.٣ أو ÷ ١.٣، زي TAP_FACTOR في _shared/or/rateCorrection.ts)
-- ويبعته نية inventory.rate_corrected {item_id, rate_per_day}. السيرفر بيخزنه على صف المخزن، وzad_pantry_learning
-- بيستخدمه بدل المعدل المتعلَّم لحد ما الصف يتمسح. الدوال التلاتة نسخ حرفية من اللي قبلهم + سطور م٣.٢ بس
-- (create or replace بيحافظ على الصلاحيات).

alter table public.zad_inventory add column if not exists rate_override_per_day numeric(12, 4)
  check (rate_override_per_day is null or rate_override_per_day > 0);

create or replace function public.zad_intent_inventory(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_row public.zad_inventory%rowtype;
  v_reason text;
  v_qty numeric;
  v_after numeric;
  v_row_id uuid;
  v_name text;
  v_expiry date;
  v_new_id uuid;
  v_member uuid;
  v_rate numeric;
begin
  if p_kind not in ('inventory.added', 'inventory.consumed', 'inventory.quantity_set', 'inventory.deleted',
                    'inventory.restock_mode_set', 'inventory.rate_corrected') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  -- الصنف: لازم للكل ماعدا الإضافة (اختياري فيها = تزويد).
  if p_kind <> 'inventory.added' or nullif(v_payload ->> 'item_id', '') is not null then
    v_row := public.zad_intent_household_item(p_uid, v_payload ->> 'item_id');
    if v_row.id is null then
      -- الإضافة بـitem_id مش موجود في البيت: id جديد من العميل (الـOutbox المحلي)، بشرطين: UUID صالح، ومش موجود
      -- خالص في zad_inventory (صف مستخدم تاني = item_not_found، من غير ما نقول إنه موجود).
      if p_kind = 'inventory.added' then
        begin
          v_new_id := (v_payload ->> 'item_id')::uuid;
        exception when others then
          v_new_id := null;
        end;
        if v_new_id is null or exists (select 1 from public.zad_inventory i where i.id = v_new_id) then
          return jsonb_build_object('ok', false, 'reason', 'item_not_found');
        end if;
      else
        return jsonb_build_object('ok', false, 'reason', 'item_not_found');
      end if;
    end if;
  end if;

  -- م٢.٦: الفرد اختياري (غايب = «أنا» بالتريجر)، ولو اتبعت لازم يبقى من بيت صاحب الطلب ومش مؤرشف.
  -- التزويد (الصنف موجود) بيتجاهل member_id: فرد قديم مايرفضش تزويد.
  if p_kind = 'inventory.added' and v_row.id is null
     and nullif(btrim(coalesce(v_payload ->> 'member_id', '')), '') is not null then
    v_member := public.zad_intent_member(p_uid, v_payload ->> 'member_id');
    if v_member is null then
      return jsonb_build_object('ok', false, 'reason', 'member_not_found');
    end if;
  end if;

  -- القيود.
  if p_kind = 'inventory.added' then
    v_name := btrim(coalesce(v_payload ->> 'item_name', ''));
    begin
      -- العمود numeric(12,3): 0.0004 كانت هتعدي «> 0» وتتخزن صفر.
      v_qty := round((v_payload ->> 'quantity')::numeric, 3);
    exception when others then
      v_qty := null;
    end;
    if length(v_name) < 2 or length(v_name) > 120 then
      v_reason := 'name_invalid';
    elsif v_qty is null or v_qty <= 0 then
      v_reason := 'qty_not_positive';
    elsif v_qty > 999 then
      v_reason := 'qty_too_large';
    elsif coalesce(v_payload ->> 'category', '') not in
          ('البقالة', 'الخضار', 'الفواكه', 'اللحوم', 'الألبان', 'المشروبات', 'العناية', 'أخرى') then
      v_reason := 'category_unknown';
    elsif nullif(v_payload ->> 'expiry_date', '') is not null then
      if (v_payload ->> 'expiry_date') !~ '^\d{4}-\d{2}-\d{2}$' then
        v_reason := 'expiry_bad_format';
      else
        begin
          v_expiry := (v_payload ->> 'expiry_date')::date;
        exception when others then
          v_reason := 'expiry_bad_format';
        end;
        if v_reason is null and v_expiry < p_occurred::date then
          v_reason := 'expiry_before_purchase';
        end if;
      end if;
    end if;
  elsif p_kind = 'inventory.consumed' then
    begin
      v_qty := round((v_payload ->> 'amount')::numeric, 3);
    exception when others then
      v_qty := null;
    end;
    if v_qty is null or v_qty < 0 or (v_qty = 0 and (v_payload -> 'opened') is distinct from 'true'::jsonb) then
      v_reason := 'amount_invalid';
    elsif v_qty > 1000 then
      v_reason := 'amount_too_large';
    end if;
  elsif p_kind = 'inventory.quantity_set' then
    begin
      v_qty := round((v_payload ->> 'quantity')::numeric, 3);
    exception when others then
      v_qty := null;
    end;
    if v_qty is null or v_qty < 0 then
      v_reason := 'qty_negative';
    elsif v_qty > greatest(coalesce(v_row.quantity, 0) * 20, 100) then
      v_reason := 'qty_too_large';
    end if;
  elsif p_kind = 'inventory.rate_corrected' then
    begin
      v_rate := round((v_payload ->> 'rate_per_day')::numeric, 4);
    exception when others then
      v_rate := null;
    end;
    if v_rate is null or v_rate <= 0 or v_rate > 100000 then
      v_reason := 'rate_invalid';
    end if;
  elsif p_kind = 'inventory.restock_mode_set' then
    if coalesce(v_payload ->> 'restock_mode', '') not in ('staple', 'occasional') then
      v_reason := 'restock_mode_unknown';
    end if;
  end if;
  if v_reason is not null then
    return jsonb_build_object('ok', false, 'reason', v_reason);
  end if;

  -- الكتابة.
  if p_kind = 'inventory.added' and v_row.id is not null then
    v_after := greatest(coalesce(v_row.quantity, 0), 0) + v_qty;
    update public.zad_inventory
       set quantity = v_after,
           category = coalesce(v_row.category, v_payload ->> 'category'),
           expiry_date = coalesce(nullif(v_payload ->> 'expiry_date', ''), v_row.expiry_date)
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.quantity, 'after', v_after);
  elsif p_kind = 'inventory.added' then
    insert into public.zad_inventory (id, user_id, member_id, item_name, quantity, unit, category, expiry_date)
    values (coalesce(v_new_id, gen_random_uuid()), p_uid, v_member, v_name, v_qty, coalesce(nullif(btrim(v_payload ->> 'unit'), ''), 'حبة'), v_payload ->> 'category',
            nullif(v_payload ->> 'expiry_date', ''))
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'after', v_qty);
  elsif p_kind = 'inventory.consumed' then
    v_after := greatest(coalesce(v_row.quantity, 0) - v_qty, 0);
    update public.zad_inventory
       set quantity = v_after,
           opened_at = case when (v_payload -> 'opened') = 'true'::jsonb then coalesce(opened_at, now()) else opened_at end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.quantity, 'after', v_after);
  elsif p_kind = 'inventory.quantity_set' then
    update public.zad_inventory set quantity = v_qty where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.quantity, 'after', v_qty);
  elsif p_kind = 'inventory.deleted' then
    -- الصف كامل في الحدث، وتريجر zad_trash بيحفظه للتراجع.
    delete from public.zad_inventory where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  elsif p_kind = 'inventory.rate_corrected' then
    update public.zad_inventory set rate_override_per_day = v_rate where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.rate_override_per_day, 'after', v_rate);
  else
    update public.zad_inventory set restock_mode = v_payload ->> 'restock_mode' where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.restock_mode,
                                                 'after', v_payload ->> 'restock_mode');
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

create or replace function public.zad_commit_my_intent(
  p_kind text,
  p_client_event_id text,
  p_payload jsonb,
  p_occurred_at timestamptz default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_intent jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  end if;
  if p_kind is null or p_kind not in ('inventory.added', 'inventory.consumed', 'inventory.quantity_set', 'inventory.rate_corrected') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;
  if p_occurred_at is not null and p_occurred_at > now() + interval '1 hour' then
    return jsonb_build_object('ok', false, 'reason', 'bad_shape');
  end if;

  -- مفيش user_id ولا member_id ولا confidence في النية: الباب بيجيب المستخدم من الـJWT والفرد «أنا».
  v_intent := jsonb_build_object(
    'kind', p_kind,
    'client_event_id', p_client_event_id,
    'source', 'manual',
    'payload', p_payload);
  if p_occurred_at is not null then
    v_intent := v_intent || jsonb_build_object('occurred_at', p_occurred_at);
  end if;
  return public.zad_commit_intent(v_intent);
end;
$fn$;

create or replace function public.zad_pantry_learning()
returns table (
  item_id uuid,
  item_name text,
  days_left numeric,
  confidence text,
  stagnant boolean,
  ask boolean
)
language plpgsql
volatile
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_me uuid := auth.uid();
  v_today date;
begin
  if v_me is null then
    raise exception 'not_authenticated';
  end if;

  select (now() at time zone coalesce(public.zad_market_timezone(u.country), 'Africa/Cairo'))::date
    into v_today
    from public.zad_users u where u.id = v_me;
  v_today := coalesce(v_today, (now() at time zone 'Africa/Cairo')::date);

  return query
  with home as (
    select v_me as uid
    union
    select m.user_id from public.family_members m
     where m.family_id in (select public.get_my_family_ids()) and m.user_id is not null
  ),
  inv as (
    select i.id, i.item_name, i.quantity, i.restock_mode, i.created_at, i.rate_override_per_day,
           private.zad_pantry_opened_left(i.opened_at, i.opened_life_days) as opened_left,
           private.zad_product_canonical_for(v_me, i.item_name) as canon
      from public.zad_inventory i
     where i.user_id = v_me
        or (i.family_id is not null and i.family_id in (select public.get_my_family_ids()))
     limit 400
  ),
  rate as (
    select inv.id,
           max(c.avg_daily_qty) filter (where c.avg_daily_qty > 0) as avg_daily_qty,
           bool_or(c.rate_known and c.avg_daily_qty > 0) as known
      from inv
      join public.zad_consumption c
        on c.user_id in (select uid from home) and c.item_name in (inv.canon, inv.item_name)
     group by inv.id
  ),
  prior as (
    select p.item_id, p.days_left from private.zad_pantry_prior_days(v_me) p
  ),
  obs as (
    select o.item_name, o.observed_at,
           o.qty < lag(o.qty) over (partition by o.user_id, o.item_name order by o.observed_at, o.created_at, o.id) as dropped
      from public.zad_inventory_observations o
     where o.user_id in (select uid from home)
  ),
  activity as (
    select inv.id, max(obs.observed_at) as last_at, coalesce(bool_or(obs.dropped), false) as used
      from inv join obs on obs.item_name in (inv.canon, inv.item_name)
     group by inv.id
  ),
  rated as (
    select inv.id, inv.item_name, inv.quantity, inv.restock_mode, inv.created_at, inv.opened_left,
           case when inv.rate_override_per_day > 0 then round((inv.quantity / inv.rate_override_per_day), 1)
                when r.avg_daily_qty > 0 then round((inv.quantity / r.avg_daily_qty::numeric), 1)
                else p.days_left end as by_rate,
           case when inv.rate_override_per_day > 0 then 'known'
                when r.avg_daily_qty > 0 then case when r.known then 'known' else 'approximate' end
                when p.days_left is not null then 'prior' end as rate_confidence,
           a.last_at, coalesce(a.used, false) as used
      from inv
      left join rate r on r.id = inv.id
      left join prior p on p.item_id = inv.id
      left join activity a on a.id = inv.id
  ),
  judged as (
    select r.*,
           case when r.opened_left is not null and (r.by_rate is null or r.opened_left < r.by_rate) then r.opened_left
                else r.by_rate end as days_left,
           case when r.opened_left is not null and (r.by_rate is null or r.opened_left < r.by_rate) then 'opened'
                else r.rate_confidence end as confidence
      from rated r
  ),
  out as (
    select j.id, j.item_name, j.days_left, j.confidence,
           (j.quantity > 0
             and coalesce(j.last_at, j.created_at, now()) < now() - interval '30 days'
             and not j.used) as stagnant,
           (j.quantity > 0
             and j.restock_mode is distinct from 'occasional'
             and j.days_left is not null and j.days_left <= 2
             and not exists (
               select 1 from public.zad_pantry_bets b
                where b.user_id in (select uid from home) and b.item_id = j.id
                  and ((b.answer = 'still_have' and b.answered_at > now() - interval '3 days')
                       or (b.asked_on = v_today and b.answer is not null))
             )) as ask
      from judged j
  ),
  -- رهان للي هيتسأل فعلاً بس: الموبايل بيعرض أقرب اتنين (20261114200000).
  bets as (
    insert into public.zad_pantry_bets (user_id, item_id, item_name, asked_on, predicted_days_left, confidence)
    select v_me, o.id, o.item_name, v_today, o.days_left, o.confidence
      from out o where o.ask
     order by o.days_left asc nulls last, o.item_name
     limit 2
    on conflict on constraint zad_pantry_bets_one_a_day do nothing
    returning 1
  )
  select o.id, o.item_name, o.days_left, o.confidence, o.stagnant, o.ask
    from out o
   order by o.ask desc, o.days_left asc nulls last, o.item_name;
end;
$$;
