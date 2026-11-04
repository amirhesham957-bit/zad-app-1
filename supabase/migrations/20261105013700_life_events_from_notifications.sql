-- أحداث الحياة من الإشعارات (ZAD_PLAN ٢.٨، طلب المالك ٤/١١).
--
-- البوابة كانت بتفهم الفلوس بس: رسالة «تم حجز موعدكم في معمل البرج يوم الأحد ١٠ص» أو «أبشر: تنتهي إقامة …
-- بعد ٣٠ يوم» أو «نتيجة التحليل جاهزة» أو «شحنتك وصلت» كانت بتترمى other_non_financial. دلوقتي البوابة بتطلّع
-- النوع والميعاد والمكان والإجراء والرابط، والحدث بيتسجل هنا وبيظهر للعميل سؤال «أسجّله وأفكرك؟». الميعاد
-- بيتعمل في zad_appointments بتأكيد العميل بس (life_event_decide في zad-brain)، والتذكير والمتابعة بعده
-- («النتيجة طلعت؟» في تحية الصبح) من آلية المواعيد الموجودة.
--
-- الخصوصية: مفيش رقم هوية/إقامة/لوحة ولا قيمة تحليل هنا — العنوان والمكان والإجراء بيتنضّفوا من أي رقم طويل
-- في السيرفر، والنتيجة الطبية نفسها عمرها ما بتتكتب (result_ready = «النتيجة جاهزة» بس). ومفيش كتابة في zad_memory.
-- الكتابة من السيرفر بس (service role)؛ العميل بيقرا صفوفه.

create table if not exists public.zad_life_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  ingest_event_id uuid references public.zad_notification_ingest_events(id) on delete set null,
  kind text not null check (kind in ('appointment', 'government', 'result_ready', 'shipment')),
  title text not null check (char_length(btrim(title)) between 2 and 120),
  event_at timestamptz,
  place text check (place is null or char_length(place) <= 120),
  action_hint text check (action_hint is null or char_length(action_hint) <= 160),
  link text check (link is null or (link ~ '^https://' and char_length(link) <= 300)),
  status text not null default 'proposed' check (status in ('proposed', 'confirmed', 'dismissed')),
  appointment_id uuid references public.zad_appointments(id) on delete set null,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);

create unique index if not exists zad_life_events_user_ingest_uidx
  on public.zad_life_events (user_id, ingest_event_id);
create index if not exists zad_life_events_user_created_idx
  on public.zad_life_events (user_id, created_at desc);

alter table public.zad_life_events enable row level security;

drop policy if exists "life events: owner reads" on public.zad_life_events;
create policy "life events: owner reads" on public.zad_life_events
  for select using (auth.uid() = user_id);

-- الميعاد اللي اتعمل من إشعار بيتعلّم بمصدره.
alter table public.zad_appointments drop constraint if exists zad_appointments_source_check;
alter table public.zad_appointments add constraint zad_appointments_source_check
  check (source in ('app', 'voice', 'chat', 'telegram', 'notification'));
