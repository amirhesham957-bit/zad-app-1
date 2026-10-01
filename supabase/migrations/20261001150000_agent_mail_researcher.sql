-- =====================================================
-- «الباحث» في فريق زاد (2026-10-01): مرة في الأسبوع بيدوّر على أسعار أهم سلع البيت في بلد
-- العميل (zad-brain/staff.ts runResearch) ويكتب في صندوق العقل باسمه. sender_check كان
-- بيقبل الستة القدام بس، فكتابته كانت هتترفض.
-- =====================================================

alter table public.zad_agent_messages drop constraint if exists zad_agent_messages_sender_check;
alter table public.zad_agent_messages add constraint zad_agent_messages_sender_check
  check (sender in ('finance', 'pantry', 'pharmacy', 'family', 'home', 'brain', 'research'));
