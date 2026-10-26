-- دفتر التوقعات (ZAD_PLAN ٥.٥): كل توقع زاد بيقوله بيتسجل، وبعد ميعاده بيتقفل بالرقم اللي حصل فعلاً.
--
-- البند: «هتصرف كام الأسبوع ده» بثقته الحقيقية، ولو الداتا قليلة يقول كده. الحسابات موجودة؛ الناقص إنها
-- تتقاس. أول نوع: صرف الأسبوع — `user_behavior_profile.avg_weekly_spending` (update-behavior-profile كل يوم
-- ٢٣:٠٠ UTC) هو نفس الرقم اللي تنبيه `spend_forecast` (20260912233000) وسياق الشات بيقولوه.
--
-- المقاس ٢٦/١٠ قبل الدفتر: حسابين عندهم ملف طازة. الأول متوقع ٢٬٠٨٢ في الأسبوع، واللي اتصرف فعلاً ٩٦٨ آخر ٧
-- أيام و١٥٢ اللي قبلهم — المتوسط = صرف ٩٠ يوم ÷ ١٢٫٩ أسبوع، فأسبوع فيه مصروف كبير بيرفعه شهور. التاني ١٣٦
-- وصفر حركة من أكتر من شهر. الدفتر بيحوّل ده لرقم بيتقال جنب التوقع بدل ما يتقال التوقع لوحده.
--
-- قرارات:
--   • توقع مفتوح واحد لكل عميل ونوع. الكرون اليومي بيقفل اللي ميعاده جه الأول، وبعده بيفتح الجديد.
--   • الفعلي = مصروفات zad_transactions (is_expense) في نفس الأسبوع، بنفس تعريف المتوسط.
--   • أسبوع من غير ولا حركة بيتقفل بـrecorded = 0 وبيتشال من الدقة: غالباً التسجيل كان واقف (٢.١: فجوات
--     لحد ٦ أيام في مستمع البنك)، مش إن البيت ماصرفش. صفر مسجّل ≠ صفر مصروف.
--   • الكتابة من السيرفر بس؛ العميل بيقرا صفوفه.

create table if not exists public.zad_forecasts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('weekly_spend')),
  made_at timestamptz not null,
  due_at timestamptz not null,
  predicted numeric not null check (predicted >= 0),
  basis jsonb not null default '{}'::jsonb,
  actual numeric check (actual is null or actual >= 0),
  recorded int check (recorded is null or recorded >= 0),
  settled_at timestamptz,
  constraint zad_forecasts_window check (due_at > made_at),
  constraint zad_forecasts_settled check ((settled_at is null) = (actual is null) and (actual is null) = (recorded is null))
);

create unique index if not exists zad_forecasts_one_open
  on public.zad_forecasts (user_id, kind) where settled_at is null;
create index if not exists zad_forecasts_user_kind on public.zad_forecasts (user_id, kind, made_at desc);

alter table public.zad_forecasts enable row level security;
revoke all on table public.zad_forecasts from anon, authenticated;
grant select on table public.zad_forecasts to authenticated;
grant all on table public.zad_forecasts to service_role;

drop policy if exists zad_forecasts_own on public.zad_forecasts;
create policy zad_forecasts_own on public.zad_forecasts for select to authenticated
  using (user_id = (select auth.uid()));

comment on table public.zad_forecasts is
  'ZAD_PLAN 5.5 — every forecast Zad states, settled against what happened. Written by zad_forecasts_tick() only.';

/** يقفل اللي ميعاده جه، ويفتح توقع الأسبوع لكل ملف طازة. بيرجع {settled, made}. */
create or replace function public.zad_forecasts_tick(p_now timestamptz default now())
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_settled int;
  v_made int;
begin
  with due as (
    select f.id,
           coalesce(sum(t.amount) filter (where t.id is not null), 0) as spent,
           count(t.id) as n
      from public.zad_forecasts f
      left join public.zad_transactions t
        on t.user_id = f.user_id and t.is_expense
       and t.created_at >= f.made_at and t.created_at < f.due_at
     where f.settled_at is null and f.due_at <= p_now and f.kind = 'weekly_spend'
     group by f.id
  )
  update public.zad_forecasts f
     set actual = round(due.spent::numeric, 2), recorded = due.n, settled_at = p_now
    from due where f.id = due.id;
  get diagnostics v_settled = row_count;

  -- نفس بوابة spend_forecast: ملف أقدم من ١٤ يوم أو متوسط صفر = مفيش أساس للتوقع.
  insert into public.zad_forecasts (user_id, kind, made_at, due_at, predicted, basis)
  select b.user_id, 'weekly_spend', p_now, p_now + interval '7 days', b.avg_weekly_spending,
         jsonb_build_object('source', 'user_behavior_profile.avg_weekly_spending', 'profile_at', b.last_updated_at)
    from public.user_behavior_profile b
   where b.avg_weekly_spending > 0
     and b.last_updated_at > p_now - interval '14 days'
     and exists (select 1 from auth.users u where u.id = b.user_id)
     and not exists (
       select 1 from public.zad_forecasts f
        where f.user_id = b.user_id and f.kind = 'weekly_spend' and f.settled_at is null
     );
  get diagnostics v_made = row_count;

  return jsonb_build_object('settled', v_settled, 'made', v_made);
end
$fn$;

revoke all on function public.zad_forecasts_tick(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_forecasts_tick(timestamptz) to service_role;

/**
 * دقة نوع توقع لعميل: الأسابيع المقفولة اللي فيها تسجيل، والوسيط للخطأ كنسبة من الفعلي، وكام أسبوع جه
 * في حدود ٢٥٪. أقل من ٣ أسابيع = {enough: false} — «الداتا لسه قليلة» بدل نسبة من أسبوع واحد.
 */
create or replace function public.zad_forecast_accuracy(p_user uuid, p_kind text default 'weekly_spend')
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
declare
  v jsonb;
begin
  if coalesce(auth.role(), '') <> 'service_role' and auth.uid() is distinct from p_user then
    return null;
  end if;
  select jsonb_build_object(
           'kind', p_kind,
           'weeks', count(*),
           'enough', count(*) >= 3,
           'median_error_pct', round((percentile_cont(0.5) within group (order by abs(actual - predicted) / actual) * 100)::numeric),
           'within_25pct', count(*) filter (where abs(actual - predicted) <= 0.25 * actual),
           'skipped_unrecorded', (select count(*) from public.zad_forecasts s
                                   where s.user_id = p_user and s.kind = p_kind and s.recorded = 0)
         )
    into v
    from public.zad_forecasts
   where user_id = p_user and kind = p_kind and settled_at is not null and recorded > 0 and actual > 0;
  return v;
end
$fn$;

revoke all on function public.zad_forecast_accuracy(uuid, text) from public, anon;
grant execute on function public.zad_forecast_accuracy(uuid, text) to authenticated, service_role;

do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  -- بعد update-behavior-profile (٢٣:٠٠) بربع ساعة، عشان التوقع الجديد يتفتح على المتوسط الجديد.
  perform cron.schedule('forecasts-daily', '17 23 * * *', $job$ select public.zad_forecasts_tick(); $job$);
end
$cron$;
