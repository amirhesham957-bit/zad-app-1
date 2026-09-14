-- لحظات صوت زاد (voice moments) — طابور واحد لكل موقف فيه مشاعر أو محتاج انتباه (٢٠٢٦-٠٩-١٤).
--
-- طلب المستخدم: الحاجات اللي فيها مشاعر ولفت انتباه تتقال بصوت زاد (نفس صوت المساعد جوه
-- التطبيق)، والباقي كتابي. وأول لحظة: "دوا ما اتخدش بعد تنبيهات كتابية يتبعت فويس".
--
-- ليه طابور مش نداء مباشر من التريجر:
-- - الكلام نفسه لازم يتكتب بلهجة العميل ولغته وبالإحساس المناسب — ده شغل موديل في zad-brain،
--   مش SQL. التريجرات بتسجّل "إيه اللي حصل" (moment + facts)، والعقل بيقرر "هتتقال إزاي".
-- - نفس الموقف ماينفعش يتقال مرتين: dedupe_key فريد لكل عميل.
-- - كل لحظة ليها أثر (sent/skipped/failed + delivery) — عكس أعطال "الصامت" اللي اتوثّقت
--   في SESSION_2026_09_12_silent_failures.md.
--
-- اللحظات اللي بتتسجّل هنا دلوقتي (الباقي بييجي مع المواعيد/الصباح/الأماكن):
-- - dose_nudge: عدّى ٣٠ دقيقة على ميعاد الجرعة ولسه ماتاخدتش → تذكير **مكتوب** على الموبايل.
-- - dose_missed: عدّت ساعة → **فويس** بعتاب (موبايل + تليجرام).
-- - dose_missed_again: جرعة تانية فاتت في نفس اليوم بعد فويس → فويس زعلانة.

create table if not exists public.zad_voice_moments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  moment text not null,
  facts jsonb not null default '{}'::jsonb,
  dedupe_key text not null,
  status text not null default 'pending'
    check (status in ('pending', 'sent', 'skipped', 'failed')),
  attempts int not null default 0,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  delivery jsonb,
  error text,
  unique (user_id, dedupe_key)
);

create index if not exists zad_voice_moments_pending_idx
  on public.zad_voice_moments (created_at)
  where status = 'pending';

alter table public.zad_voice_moments enable row level security;

-- العميل يشوف لحظاته بس (سجل جوه التطبيق لاحقًا). مفيش كتابة من العميل: الإدراج من دوال
-- security definer والتحديث من zad-brain بمفتاح الخدمة.
drop policy if exists "voice moments: owner reads" on public.zad_voice_moments;
create policy "voice moments: owner reads" on public.zad_voice_moments
  for select using (auth.uid() = user_id);

/**
 * جرعات فاتت → لحظات. `zad_dose_log` صف بيتعمل لما تنبيه الجرعة بيرن على الموبايل،
 * و`taken_at` بيتملى لما العميل يدوس "خدته". الشاشة بتسجّل كمان في `zad_pharmacy_doses`
 * بنفس `scheduled_at` القياسي (Task 17.2.2)، فالاتنين بيتفحصوا.
 *
 * النافذة ٣ ساعات بس: جرعات قديمة (٦ من ١٠ صفوف على الإنتاج يوم الميجريشن) ماتتبعتش
 * كلها مرة واحدة أول ما الكرون يشتغل.
 */
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
  -- dose_nudge: ٣٠–٦٠ دقيقة
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select d.user_id, 'dose_nudge',
         jsonb_build_object('item_name', d.item_name, 'scheduled_at', d.scheduled_at, 'dose_log_id', d.id),
         'dose_nudge:' || d.id
  from public.zad_dose_log d
  join auth.users a on a.id = d.user_id
  where d.taken_at is null
    and d.scheduled_at between now() - interval '60 minutes' and now() - interval '30 minutes'
    and not exists (
      select 1 from public.zad_pharmacy_doses p
      where p.user_id = d.user_id and p.item_id = d.pharmacy_item_id
        and p.scheduled_at = d.scheduled_at and p.status = 'taken'
    )
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;
  v_inserted := v_inserted + v_count;

  -- dose_missed / dose_missed_again: ١–٣ ساعات
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select d.user_id,
         case when exists (
           select 1 from public.zad_voice_moments m
           where m.user_id = d.user_id
             and m.moment in ('dose_missed', 'dose_missed_again')
             and m.created_at >= date_trunc('day', now())
         ) then 'dose_missed_again' else 'dose_missed' end,
         jsonb_build_object('item_name', d.item_name, 'scheduled_at', d.scheduled_at, 'dose_log_id', d.id),
         'dose_missed:' || d.id
  from public.zad_dose_log d
  join auth.users a on a.id = d.user_id
  where d.taken_at is null
    and d.scheduled_at between now() - interval '3 hours' and now() - interval '60 minutes'
    and not exists (
      select 1 from public.zad_pharmacy_doses p
      where p.user_id = d.user_id and p.item_id = d.pharmacy_item_id
        and p.scheduled_at = d.scheduled_at and p.status = 'taken'
    )
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;
  v_inserted := v_inserted + v_count;

  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_missed_doses() from public;
revoke all on function public.zad_enqueue_missed_doses() from anon;
revoke all on function public.zad_enqueue_missed_doses() from authenticated;

-- كل ٥ دقايق: سجّل الجرعات اللي فاتت، ونادي العقل **بس** لو فيه لحظات مستنية (نفس نمط
-- agent-tasks-processor — مفيش نداء edge function فاضي كل ٥ دقايق).
select cron.unschedule('voice-moments-processor')
where exists (select 1 from cron.job where jobname = 'voice-moments-processor');

select cron.schedule(
  'voice-moments-processor',
  '*/5 * * * *',
  $$
  select public.zad_enqueue_missed_doses();
  select net.http_post(
      url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
      ),
      body := '{"action":"process_voice_moments"}'::jsonb,
      timeout_milliseconds := 55000
    ) as request_id
  where exists (
    select 1 from public.zad_voice_moments
    where status = 'pending' and created_at > now() - interval '6 hours'
  );
  $$
);
