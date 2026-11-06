-- الملف السلوكي التراكمي — الشريحة ٤ (ZAD_PLAN المرحلة ٣، طلب المالك ٦/١١): محلات البيت، ومواعيد شراه، ودورة كل صنف.
--
-- update-behavior-profile بيحسبهم كل ليلة (habits.ts) بتوقيت سوق الحساب، والعقل بيقراهم، وصفحة «نمط استهلاكك»
-- بتعرضهم (RLS الموجودة: العميل بيقرا صفه بس). من غير موديل.
--
-- restock_cycle_days: تصحيح العميل لدورة صنف («الزيت عندي كل أسبوعين») — بيغلب أي حاجة متعلّمة
-- (`_shared/restockCycle.ts`). null = زاد يحكم.

alter table public.user_behavior_profile
  add column if not exists favorite_stores jsonb not null default '[]'::jsonb,
  add column if not exists shopping_rhythm jsonb not null default '{}'::jsonb,
  add column if not exists item_cycles jsonb not null default '[]'::jsonb,
  add column if not exists timezone text;

alter table public.zad_inventory
  add column if not exists restock_cycle_days integer
    check (restock_cycle_days is null or restock_cycle_days between 1 and 365);

comment on column public.zad_inventory.restock_cycle_days is
  'تصحيح العميل لدورة شرا الصنف بالأيام — بيغلب المتعلّم. null = زاد يحكم من نوع الصنف وتاريخ الشرا.';
