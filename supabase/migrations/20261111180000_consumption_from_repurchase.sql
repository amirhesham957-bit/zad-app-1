-- زاد بيتعلم الاستهلاك من الشرا نفسه (المالك ١١/١١: «المفروض يتوقع أكلاتي واستهلاكي ويدير مخزوني بدقة»).
--
-- المقاس على حساب المالك ٤–١١/١١: ٣١ قراية في zad_inventory_observations — ١٣ شرا، ١٠ مسح، ٧ إيد، ورد
-- واحد على سؤال — ولا قراية واحدة الكمية فيها نزلت. zad_recompute_consumption مابيتعلمش غير من النزول،
-- فـzad_consumption فاضي، ومفيش توقع ولا «هيخلص إمتى» لأي صنف. النزول مابيجيش غير من العميل (يرد على
-- سؤال، أو يدوس −)، والشرا بيتسجل لوحده من الفواتير والبنك.
--
-- اللي اتغيّر: لما الصنف مالوش ولا نزلة، الشرا اللي بعد قراية قبله بيوم لـ٦٠ يوم بيدّي معدل تقريبي:
-- اللي اتشرا ÷ الأيام من القراية اللي قبله. البيت اللي بيشتري لبن كل ٣ أيام بيشرب تقريباً اللي بيشتريه.
-- بيتخزن rate_known = false دايماً (تقريبي): الصنف بيفضل «ينفع يتسأل عنه»، وسؤال «لسه عندك؟» هو اللي
-- بيصححه، وأول نزلة حقيقية بتلغيه وترجع للحساب القديم بالظبط.
-- الشرا = 'purchase' (الفاتورة والبنك) أو 'camera_ocr' (مسح فاتورة بالكاميرا). الزيادة بالإيد مش منهم: ممكن
-- تكون تصحيح عدّ.
-- أقل من يوم بين القرايتين مابيتحسبش: نفس الفاتورة بتتسجل مرتين أحياناً، والتخزين في نفس اليوم مش استهلاك.

create or replace function public.zad_recompute_consumption(p_user uuid, p_item text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total_drop double precision;
  v_busy_days double precision;
  v_drops int;
  v_distinct_days int;
  v_rate double precision;
  v_known boolean;
  v_bought double precision;
  v_cycle_days double precision;
  v_cycles int;
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'not_authorized';
  end if;

  with ordered as (
    select qty, observed_at, created_at, id,
           lag(qty) over w as prev_qty,
           lag(observed_at) over w as prev_at
      from public.zad_inventory_observations
     where user_id = p_user and item_name = p_item
    window w as (order by observed_at, created_at, id)
  ),
  marked as (
    select *,
           -- آخر مرة الكمية اتغيرت قبل الصف ده (أو أول قراية).
           max(case when prev_qty is null or qty <> prev_qty then observed_at end)
             over (order by observed_at, created_at, id
                   rows between unbounded preceding and 1 preceding) as changed_at
      from ordered
  ),
  drops as (
    select (prev_qty - qty) as amount, observed_at,
           extract(epoch from (observed_at - changed_at)) / 86400.0 as days
      from marked
     where prev_qty is not null and qty < prev_qty
       and observed_at - prev_at <= interval '30 days'
  )
  select coalesce(sum(amount), 0), coalesce(sum(days), 0), count(*), count(distinct observed_at::date)
    into v_total_drop, v_busy_days, v_drops, v_distinct_days
    from drops;

  if v_drops > 0 and v_total_drop > 0 and v_busy_days >= 0.5 then
    v_rate := v_total_drop / v_busy_days;
    v_known := v_drops >= 3 and v_distinct_days >= 2;

    insert into public.zad_consumption
      (user_id, item_name, avg_daily_qty, sample_count, rate_known, last_computed_at)
    values
      (p_user, p_item, v_rate, v_drops, v_known, now())
    on conflict (user_id, item_name) do update
      set avg_daily_qty    = excluded.avg_daily_qty,
          sample_count     = excluded.sample_count,
          rate_known       = excluded.rate_known,
          last_computed_at = excluded.last_computed_at;

    return jsonb_build_object('samples', v_drops, 'avg_daily_qty', v_rate, 'rate_known', v_known);
  end if;

  -- مفيش نزلة: الشرا المتكرر هو الدليل الوحيد.
  with ordered as (
    select qty, observed_at, source,
           lag(qty) over w as prev_qty,
           lag(observed_at) over w as prev_at
      from public.zad_inventory_observations
     where user_id = p_user and item_name = p_item
    window w as (order by observed_at, created_at, id)
  )
  select coalesce(sum(qty - prev_qty), 0),
         coalesce(sum(extract(epoch from (observed_at - prev_at)) / 86400.0), 0),
         count(*)
    into v_bought, v_cycle_days, v_cycles
    from ordered
   where source in ('purchase', 'camera_ocr') and prev_qty is not null and qty > prev_qty
     and observed_at - prev_at >= interval '1 day'
     and observed_at - prev_at <= interval '60 days';

  if v_cycles = 0 or v_bought <= 0 or v_cycle_days < 1 then
    delete from public.zad_consumption where user_id = p_user and item_name = p_item;
    return jsonb_build_object('samples', 0, 'avg_daily_qty', null, 'rate_known', false);
  end if;

  v_rate := v_bought / v_cycle_days;

  insert into public.zad_consumption
    (user_id, item_name, avg_daily_qty, sample_count, rate_known, last_computed_at)
  values
    (p_user, p_item, v_rate, v_cycles, false, now())
  on conflict (user_id, item_name) do update
    set avg_daily_qty    = excluded.avg_daily_qty,
        sample_count     = excluded.sample_count,
        rate_known       = excluded.rate_known,
        last_computed_at = excluded.last_computed_at;

  return jsonb_build_object('samples', v_cycles, 'avg_daily_qty', v_rate, 'rate_known', false, 'from', 'repurchase');
end $$;

revoke all on function public.zad_recompute_consumption(uuid, text) from public, anon;
grant execute on function public.zad_recompute_consumption(uuid, text) to authenticated, service_role;

-- الشرا اللي اتسجل قبل كده ياخد تقديره دلوقتي.
do $backfill$
declare r record;
begin
  for r in select distinct user_id, item_name from public.zad_inventory_observations loop
    perform public.zad_recompute_consumption(r.user_id, r.item_name);
  end loop;
end
$backfill$;
