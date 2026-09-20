-- إيقاف حلقة تليجرام، وتأمين تذكيرات الجرعات (٢٠٢٦-٠٩-١٩).
--
-- تلات بلاغات من العميل، وطلعوا تلات أعطال منفصلة بتتغذى على بعض:
--
--  1. «البوت بيقرا رسايل نفسه ويرد عليها باستمرار» — تليجرام بيضمن التسليم **مرة على
--     الأقل** مش مرة واحدة. الـwebhook بيستنى لفة الوكيل كلها (نداء موديل) قبل ما يرجّع
--     200، فتليجرام بيقراها timeout ويعيد تسليم نفس `update_id` — ولفة تانية تبدأ وترد.
--     `telegram_processed_updates` تحت هو الحجز الذرّي اللي بيخلي أول تسليم بس هو اللي
--     يتعالج. (فلتر الراسل-بوت نفسه في الكود: telegram.ts/isHumanUpdate.)
--
--  2. «بيولّد أدوية وهمية ومابيسجلش الجرعة» — التأكيد كان ماشي على فهم الموديل لكلمة
--     «أخدته». لفة الوكيل بتقع (نت/موديل/مهلة) وبترجع رد قرايا، فالعميل بيتشكر
--     والجرعة ماتسجلتش، والكرون يفضل يزن. الحل في الكود: زر `dz:` بيكتب في الداتابيز
--     الأول والشكر بعدين. الجزء بتاع الداتابيز هنا: `zad_dose_snoozes` + قراية الكرون منه.
--
--  3. «التنبيهات القديمة بتفضل تتبعت كل نص ساعة» — الطابور الحالي فيه لحظات معلّقة
--     لجرعات اتاخدت فعلاً أو عدّى عليها اليوم. التنضيف في آخر الملف.

-- ── ١. حجز تحديثات تليجرام ───────────────────────────────────────────────────
-- المفتاح الأساسي هو `update_id` نفسه: أول INSERT بيكسب، وأي إعادة تسليم بتاخد 23505
-- وبتترمي بـ200. مفيش RLS policy للعملاء عن قصد — ده جدول تشغيل بيتكتب بمفتاح الخدمة بس.
create table if not exists public.telegram_processed_updates (
  update_id bigint primary key,
  processed_at timestamptz not null default now()
);

create index if not exists telegram_processed_updates_processed_at_idx
  on public.telegram_processed_updates (processed_at);

alter table public.telegram_processed_updates enable row level security;

-- تليجرام بيعيد التسليم لمدة ٢٤ ساعة كحد أقصى، فأي صف أقدم من يومين مالوش لازمة.
create or replace function public.zad_prune_telegram_updates()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_deleted int;
begin
  delete from public.telegram_processed_updates where processed_at < now() - interval '2 days';
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$function$;

revoke all on function public.zad_prune_telegram_updates() from public, anon, authenticated;

-- ── ٢. تأجيل الجرعة («⏰ فكّرني بعد ١٥ دقيقة») ────────────────────────────────
-- الصف ده بيتكتب من زر تليجرام. بيعمل حاجتين في الكرون تحت: بيسكّت التذكير عن نفس
-- الجرعة طول مدة التأجيل، وبعد ما المدة تعدّي بيطلّع تذكير **واحد** جديد لو لسه ماتاخدتش.
create table if not exists public.zad_dose_snoozes (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null references public.zad_pharmacy_items(id) on delete cascade,
  scheduled_at timestamptz not null,
  snooze_until timestamptz not null,
  created_at timestamptz not null default now(),
  primary key (user_id, item_id, scheduled_at)
);

create index if not exists zad_dose_snoozes_until_idx
  on public.zad_dose_snoozes (snooze_until);

alter table public.zad_dose_snoozes enable row level security;

drop policy if exists "dose snoozes: owner reads" on public.zad_dose_snoozes;
create policy "dose snoozes: owner reads" on public.zad_dose_snoozes
  for select using (auth.uid() = user_id);

-- ── ٣. الكرون بيحترم التأجيل، ومابيكررش تذكير لجرعة اتاخدت ────────────────────
--
-- نفس 20260915002000 بالظبط زايد حاجتين:
--   أ. `not exists` على تأجيل لسه شغال ⇒ سكوت تام عن الجرعة دي لحد ما الوقت يعدّي.
--   ب. فرع `dose_due` جديد للتأجيل اللي خلص: تذكير واحد بس، وdedupe_key فيه وقت
--      التأجيل نفسه فمستحيل يتكرر.
create or replace function public.zad_enqueue_missed_doses()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int := 0;
  v_count int;
begin
  create temporary table if not exists pg_temp.zad_due_doses (
    user_id uuid, item_id uuid, item_name text, scheduled_at timestamptz, tz text
  ) on commit drop;
  truncate pg_temp.zad_due_doses;

  insert into pg_temp.zad_due_doses
  select p.user_id, p.id, p.name, s.scheduled_at, s.tz
  from public.zad_pharmacy_items p
  join public.zad_users u on u.id = p.user_id
  cross join lateral (select public.zad_market_timezone(u.country) as tz) z
  cross join lateral unnest(string_to_array(p.dose_times, ',')) as t(raw)
  cross join lateral (values (0), (1)) as d(days_back)
  cross join lateral (
    select z.tz,
           (((now() at time zone z.tz)::date - d.days_back) + btrim(t.raw)::time) at time zone z.tz as scheduled_at
  ) s
  where coalesce(p.dose_times, '') <> ''
    and coalesce(p.has_invalid_dose_time, false) = false
    and (p.remaining_quantity is null or p.remaining_quantity > 0)
    and btrim(t.raw) ~ '^([01]?[0-9]|2[0-3]):[0-5][0-9]$'
    and s.scheduled_at between now() - interval '3 hours' and now()
    and s.scheduled_at > p.created_at
    and not exists (
      select 1 from public.zad_pharmacy_doses pd
      where pd.user_id = p.user_id and pd.item_id = p.id and pd.status = 'taken'
        and coalesce(pd.taken_at, pd.scheduled_at) >= s.scheduled_at - interval '3 hours'
    )
    and not exists (
      select 1 from public.zad_dose_log l
      where l.user_id = p.user_id and l.pharmacy_item_id = p.id
        and l.taken_at >= s.scheduled_at - interval '3 hours'
    )
    -- العميل داس «فكّرني بعدين» على الجرعة دي بالظبط — سكوت لحد ما الوقت يعدّي.
    and not exists (
      select 1 from public.zad_dose_snoozes sn
      where sn.user_id = p.user_id and sn.item_id = p.id
        and sn.scheduled_at = s.scheduled_at and sn.snooze_until > now()
    );

  -- dose_due (بصوتها، حنينة): أول ١٠ دقايق من الميعاد.
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select g.user_id, 'dose_due',
         jsonb_build_object('item_name', g.names, 'item_ids', g.ids, 'scheduled_at', g.scheduled_at, 'time_zone', g.tz),
         'dose_due:' || g.user_id || ':' || floor(extract(epoch from g.scheduled_at))::bigint
  from (
    select user_id, scheduled_at, tz, string_agg(item_name, ' و' order by item_name) as names, jsonb_agg(item_id) as ids
    from pg_temp.zad_due_doses
    where scheduled_at between now() - interval '10 minutes' and now()
    group by user_id, scheduled_at, tz
  ) g
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;
  v_inserted := v_inserted + v_count;

  -- تأجيل خلص ولسه الجرعة ماتاخدتش ⇒ تذكير واحد جديد. dedupe_key فيه وقت التأجيل
  -- نفسه، فكل ضغطة «أجّل» بتنتج تذكير واحد بالظبط مهما الكرون لفّ.
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select sn.user_id, 'dose_due',
         jsonb_build_object(
           'item_name', p.name, 'item_ids', jsonb_build_array(sn.item_id),
           'scheduled_at', sn.scheduled_at, 'time_zone', public.zad_market_timezone(u.country),
           'snoozed', true
         ),
         'dose_snooze:' || sn.user_id || ':' || sn.item_id || ':' || floor(extract(epoch from sn.snooze_until))::bigint
  from public.zad_dose_snoozes sn
  join public.zad_pharmacy_items p on p.id = sn.item_id and p.user_id = sn.user_id
  left join public.zad_users u on u.id = sn.user_id
  where sn.snooze_until between now() - interval '10 minutes' and now()
    and not exists (
      select 1 from public.zad_pharmacy_doses pd
      where pd.user_id = sn.user_id and pd.item_id = sn.item_id and pd.status = 'taken'
        and coalesce(pd.taken_at, pd.scheduled_at) >= sn.scheduled_at - interval '3 hours'
    )
    and not exists (
      select 1 from public.zad_dose_log l
      where l.user_id = sn.user_id and l.pharmacy_item_id = sn.item_id
        and l.taken_at >= sn.scheduled_at - interval '3 hours'
    )
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;
  v_inserted := v_inserted + v_count;

  -- dose_nudge (مكتوب بس): ٣٠–٦٠ دقيقة بعد الميعاد.
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select g.user_id, 'dose_nudge',
         jsonb_build_object('item_name', g.names, 'item_ids', g.ids, 'scheduled_at', g.scheduled_at, 'time_zone', g.tz),
         'dose_nudge:' || g.user_id || ':' || floor(extract(epoch from g.scheduled_at))::bigint
  from (
    select user_id, scheduled_at, tz, string_agg(item_name, ' و' order by item_name) as names, jsonb_agg(item_id) as ids
    from pg_temp.zad_due_doses
    where scheduled_at between now() - interval '60 minutes' and now() - interval '30 minutes'
    group by user_id, scheduled_at, tz
  ) g
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;
  v_inserted := v_inserted + v_count;

  -- dose_missed / dose_missed_again (بصوتها): ساعة لـ٣ ساعات، بحد ٣ في اليوم المحلي.
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select g.user_id,
         case when g.missed_today > 0 then 'dose_missed_again' else 'dose_missed' end,
         jsonb_build_object('item_name', g.names, 'item_ids', g.ids, 'scheduled_at', g.scheduled_at, 'time_zone', g.tz),
         'dose_missed:' || g.user_id || ':' || floor(extract(epoch from g.scheduled_at))::bigint
  from (
    select x.user_id, x.scheduled_at, x.tz, string_agg(x.item_name, ' و' order by x.item_name) as names, jsonb_agg(x.item_id) as ids,
           (select count(*) from public.zad_voice_moments m
             where m.user_id = x.user_id and m.moment in ('dose_missed', 'dose_missed_again')
               and m.created_at >= (date_trunc('day', now() at time zone x.tz) at time zone x.tz)) as missed_today
    from pg_temp.zad_due_doses x
    where x.scheduled_at between now() - interval '3 hours' and now() - interval '60 minutes'
    group by x.user_id, x.scheduled_at, x.tz
  ) g
  where g.missed_today < 3
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;
  v_inserted := v_inserted + v_count;

  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_missed_doses() from public, anon, authenticated;

-- ── ٤. التنضيف الفوري: وقف التنبيهات المتكررة الحالية ────────────────────────
--
-- ثلاث موجات، كل واحدة بتمسح فئة مختلفة، وكلها بتسيب أثر (`error`) مش بتحذف — سجل
-- التوصيل هو اللي بيثبت إن اللحظة ما اتبعتتش وليه.

-- أ. أي لحظة جرعة معلّقة والجرعة نفسها اتسجلت فعلاً بعد كده. دي اللي بتوصل للعميل
--    كـ«فاتتك جرعة المضاد» وهو خدها.
--
-- `@> to_jsonb(...)` بدل تفكيك المصفوفة وcast لـuuid: صفوف قديمة في الطابور فيها
-- `dose_log_id` من غير `item_ids` خالص، وأي cast عليها كان هيرمي الميجريشن كلها.
-- والنافذة متحسوبة من `created_at` بتاع اللحظة (عمود حقيقي) مش من نص جوه JSON.
update public.zad_voice_moments m
set status = 'skipped', error = 'cleanup 20260919: dose already taken'
where m.status in ('pending', 'sending')
  and m.moment like 'dose\_%'
  and jsonb_typeof(m.facts -> 'item_ids') = 'array'
  and exists (
    select 1 from public.zad_pharmacy_doses pd
    where pd.user_id = m.user_id
      and pd.status = 'taken'
      and m.facts -> 'item_ids' @> to_jsonb(pd.item_id::text)
      and pd.taken_at >= m.created_at - interval '3 hours'
  );

-- ب. أي لحظة قديمة عدّى عليها أكتر من ٦ ساعات. المعالج نفسه بيتجاهلها (MOMENT_MAX_AGE_MS)
--    بس بتفضل 'pending' للأبد وبتتقري في كل لفة كرون.
update public.zad_voice_moments
set status = 'skipped', error = 'cleanup 20260919: stale, older than the delivery window'
where status in ('pending', 'sending')
  and created_at < now() - interval '6 hours';

-- ج. صفوف محجوزة (`sending`) من معالج مات. من غير ده الصف بيفضل محجوز لحد ما
--    CLAIM_STALE_MS تعدّي في كل لفة.
update public.zad_voice_moments
set status = 'skipped', error = 'cleanup 20260919: abandoned claim'
where status = 'sending' and claimed_at < now() - interval '1 hour';

-- د. مواعيد فاتت من أكتر من يوم ولسه 'upcoming' — بتطلّع تذكير في كل لفة كرون لأن
--    نافذة `starts_at + 10 minutes` ماتقفلش الصف، بس المتكرر بيتنقل والمرة الواحدة لأ.
update public.zad_appointments
set status = 'done', updated_at = now()
where status = 'upcoming' and recurrence = 'once' and starts_at < now() - interval '1 day';

-- ── ٥. تنضيف دوري بدل ما يفضل يدوي ───────────────────────────────────────────
-- بيمشي مع كرون الخمس دقايق: الصفوف القديمة بتتقفل، وحجز تحديثات تليجرام بيتقلّم.
create or replace function public.zad_expire_stale_moments()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_expired int;
begin
  update public.zad_voice_moments
  set status = 'skipped', error = coalesce(error, 'expired: older than the delivery window')
  where status in ('pending', 'sending')
    and created_at < now() - interval '6 hours';
  get diagnostics v_expired = row_count;

  perform public.zad_prune_telegram_updates();
  delete from public.zad_dose_snoozes where snooze_until < now() - interval '1 day';
  return v_expired;
end;
$function$;

revoke all on function public.zad_expire_stale_moments() from public, anon, authenticated;

select cron.unschedule('zad-moments-housekeeping')
where exists (select 1 from cron.job where jobname = 'zad-moments-housekeeping');

select cron.schedule(
  'zad-moments-housekeeping',
  '17 * * * *',
  $$ select public.zad_expire_stale_moments(); $$
);
