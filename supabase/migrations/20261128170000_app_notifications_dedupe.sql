-- إشعار التطبيق البديل للحظة صوت ماوصلتش بأي قناة (voiceMoments.ts notifyInApp): صف واحد للحظة.
-- dedupe_key = مفتاح اللحظة؛ نفس (user_id, dedupe_key) مايتكتبش مرتين (insert ... on conflict do nothing).
-- العمود nullable: الصفوف القديمة وباقي الكتّاب مابيتأثروش (القيم الفاضية مش بتتعارض في unique index).
alter table public.app_notifications add column if not exists dedupe_key text;
create unique index if not exists app_notifications_user_dedupe_key
  on public.app_notifications (user_id, dedupe_key);
