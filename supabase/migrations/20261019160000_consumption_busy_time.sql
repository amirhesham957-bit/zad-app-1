-- «هيخلص إمتى؟» (ZAD_PLAN ٣.٥، ٢٠٢٦-١٠-١٩): المعدل بيتحسب من الوقت اللي الصنف كان بيخلص فيه فعلاً،
-- والحارس بياخد التقريبي.
--
-- المقاس على الحي قبل الميجريشن دي: ١٦ صنف ليهم معدل، واحد بس rate_known، والحارس
-- (_agent_predicted_shortage_for_user) كان شرطه rate_known — فاشتغل صفر مرة من يوم ما اتعمل.
-- والمعدلات نفسها كانت مخففة: إجمالي النزول ÷ المدة من أول قراية لآخر قراية، والمدة دي فيها
-- أسابيع الصنف كان خلصان ومحدش اشتراه، أو العميل ماكانش فاتح التطبيق. حليب ٣ علب = ٠٫٠٣ في اليوم
-- (١٠٠ يوم)، توست ٠٫١٤، جبنة ٠٫٢٠.
--
-- الحساب الجديد: كل نزلة بتاخد الوقت من آخر مرة الكمية اتغيرت (اشترى أو نزلت) لحد النزلة — الوقت
-- اللي الكمية القديمة قعدت فيه لحد ما اتاكلت. والفترات اللي بتنتهي بشرا أو بنفس الكمية مابتتحسبش،
-- فوقت «خلص ولسه ماتشراش» بيطلع بره. نزلة قبلها أكتر من ٣٠ يوم من غير ولا قراية: العميل ماكانش
-- بيبص، ووقت الاستهلاك مجهول — بتتساب، ولو مافضلش غيرها الصنف مالوش معدل (الصف بيتمسح: مفيش صف =
-- مجهول، زي كل حتة بتقرا الجدول). نفس النتيجة على الحي: توست ٠٫٢٧، جبنة ٠٫٧٠، والحليب من غير معدل
-- بدل ١٠٠ يوم غلط.
--
-- اللي ماتغيرش: أقل من ١٢ ساعة استهلاك = مفيش تقدير (داتا التجربة ٦ ← ١ في ٣ دقايق،
-- 20260930000000)، و rate_known = ٣ نزلات على يومين مختلفين.
--
-- الحارس: شرط rate_known اتشال. النص بيقول «فاضل حوالي N يوم» أصلاً، والمهمة سؤال بموافقة
-- («أضيفهم لقايمة التسوق؟») — التقريبي الغلط تمنه سؤال، والمعروف بس كان تمنه إن الحارس مايشتغلش.

create or replace function public.zad_recompute_consumption(p_user uuid, p_item text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_total_drop double precision;
  v_busy_days double precision;
  v_drops int;
  v_distinct_days int;
  v_rate double precision;
  v_known boolean;
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

  if v_drops = 0 or v_total_drop <= 0 or v_busy_days < 0.5 then
    delete from public.zad_consumption where user_id = p_user and item_name = p_item;
    return jsonb_build_object('samples', v_drops, 'avg_daily_qty', null, 'rate_known', false);
  end if;

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
end $function$;

-- الحارس: جملة واحدة على النص الحي (زي 20261011250000)، وبيقف لو النص مش الشكل المتوقع.
do $migrate$
declare
  v_def text;
  v_pat text := 'and\s+coalesce\(c\.rate_known,\s*false\)';
  v_hits int;
begin
  select pg_get_functiondef('public._agent_predicted_shortage_for_user(uuid)'::regprocedure) into v_def;
  v_hits := regexp_count(v_def, v_pat);
  if v_hits <> 1 then
    raise exception 'busy time: _agent_predicted_shortage_for_user has % rate_known matches, expected 1', v_hits;
  end if;
  execute regexp_replace(v_def, v_pat, '');
end
$migrate$;

-- المعدلات اللي اتحسبت قبل كده تتحسب من جديد دلوقتي، مش لما الصنف ياخد قراية جديدة.
do $backfill$
declare r record;
begin
  for r in select distinct user_id, item_name from public.zad_consumption
           union
           select distinct user_id, item_name from public.zad_inventory_observations loop
    perform public.zad_recompute_consumption(r.user_id, r.item_name);
  end loop;
end
$backfill$;
