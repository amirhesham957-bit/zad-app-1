-- دقة كل التوقعات اللي في zad_forecasts بتتنشر للمالك كل أسبوع (ZAD_OR_PLAN م٣.٦).
--
-- القياس اللي اتعمل على الحي (٢١/١١): `pantry-accuracy-weekly` بيقيس رهانات المخزن بس، وماكانش بيبص على
-- zad_forecasts خالص. وفي الجدول: ١١ أسبوع صرف اتقفلوا، ١٠ منهم فيهم أقل من ٣ مصاريف متسجلة، والوسيط
-- للفعلي صفر. يعني «الخطأ ١٠٩٪» كان معناه إن الناس مابتسجّلش، مش إن التوقع وحش. ومن ٤٧ «هيخلص» اتقفلوا،
-- ٤١ (٨٧٪) نتيجتهم unknown.
--
-- عشان كده التقرير بيفصل بين حاجتين:
--   • أسبوع «دليل» = فيه ٣ مصاريف متسجلة أو أكتر، والفعلي أكبر من صفر. الخطأ (WAPE) والانحياز بيتحسبوا على دول بس.
--     الأسابيع التانية بتتعد «رفيعة» ومابتدخلش في الحساب.
--   • «هيخلص»: كام واحد اتحكم عليه فعلاً (out / still_had / restocked) من اللي اتقفلوا، والمجهول لوحده.
-- ده للمالك بس (zad_notify_admin). zad_forecast_accuracy اللي بيظهر للعميل مااتغيرش.
-- والمعادلات نفسها هي اللي في `_shared/or/forecastAccuracy.ts` (wape = Σ|فعلي − متوقع| ÷ Σفعلي، والانحياز موجب = توقع زيادة).

create or replace function public.zad_forecast_ledger_weekly(p_now timestamptz default now(), p_days int default 7)
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $fn$
  with s as (
    select * from public.zad_forecasts
     where settled_at is not null
       and settled_at > p_now - make_interval(days => p_days)
       and settled_at <= p_now
  ),
  ws as (select * from s where kind = 'weekly_spend'),
  ev as (select * from ws where recorded >= 3 and actual > 0),
  ro as (select * from s where kind = 'runs_out')
  select jsonb_build_object(
    'days', p_days,
    'weekly_spend', jsonb_build_object(
      'settled', (select count(*) from ws),
      'evidence', (select count(*) from ev),
      'thin', (select count(*) from ws where not (recorded >= 3 and actual > 0)),
      'wape', (select round(sum(abs(actual - predicted)) / nullif(sum(actual), 0), 3) from ev),
      'bias', (select round(sum(predicted - actual) / nullif(sum(actual), 0), 3) from ev)
    ),
    'runs_out', jsonb_build_object(
      'settled', (select count(*) from ro),
      'out', (select count(*) from ro where outcome = 'out'),
      'still_had', (select count(*) from ro where outcome = 'still_had'),
      'restocked', (select count(*) from ro where outcome = 'restocked'),
      'unknown', (select count(*) from ro where outcome = 'unknown'),
      'judged_pct', (select round(100.0 * count(*) filter (where outcome <> 'unknown') / nullif(count(*), 0)) from ro)
    )
  );
$fn$;

revoke all on function public.zad_forecast_ledger_weekly(timestamptz, int) from public, anon, authenticated;
grant execute on function public.zad_forecast_ledger_weekly(timestamptz, int) to service_role;

/** الرسالة الأسبوعية للمالك. فشلها مايكسرش الكرون. */
create or replace function public.zad_forecast_ledger_weekly_notify(p_now timestamptz default now())
returns text
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  a jsonb := public.zad_forecast_ledger_weekly(p_now, 7);
  w jsonb := a -> 'weekly_spend';
  r jsonb := a -> 'runs_out';
  v_body text;
begin
  v_body := format(
    'صرف الأسبوع: اتقفل %s توقع، منهم %s دليل (٣ مصاريف متسجلة أو أكتر) و%s رفيع. %s' || chr(10) ||
    'هيخلص: اتقفل %s، اتحكم على %s (خلص %s، لسه كان موجود %s، اتشرى %s، مجهول %s).',
    w ->> 'settled', w ->> 'evidence', w ->> 'thin',
    case when w ->> 'wape' is null then 'الخطأ مش محسوب: مفيش أسبوع دليل.'
         else format('الخطأ %s٪ والانحياز %s٪ (موجب = توقعنا أكتر).',
                     round((w ->> 'wape')::numeric * 100), round((w ->> 'bias')::numeric * 100)) end,
    r ->> 'settled',
    case when r ->> 'judged_pct' is null then 'ولا واحد' else (r ->> 'judged_pct') || '٪' end,
    r ->> 'out', r ->> 'still_had', r ->> 'restocked', r ->> 'unknown');
  perform public.zad_notify_admin('📈 دقة التوقعات', v_body);
  return v_body;
exception when others then
  return 'failed: ' || sqlerrm;
end;
$fn$;

revoke all on function public.zad_forecast_ledger_weekly_notify(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_forecast_ledger_weekly_notify(timestamptz) to service_role;

do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  -- الاتنين الصبح، بعد دقة المخزن (٩:٣٧) بعشر دقايق.
  perform cron.schedule('forecast-ledger-weekly', '47 9 * * 1', $job$ select public.zad_forecast_ledger_weekly_notify(); $job$);
end
$cron$;
