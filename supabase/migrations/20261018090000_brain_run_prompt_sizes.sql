-- ميزان اللفة (ZAD_DREAM_PLAN.md ع١، promptBudget.ts): حجم كل جزء من برومبت لفة الشات بالحروف —
-- الأجزاء، أتقل مفاتيح الـSNAPSHOT، الأدوات، المحادثة. «رجيم السياق» بيقص على الأرقام دي.
alter table public.zad_brain_runs add column if not exists prompt_sizes jsonb;
