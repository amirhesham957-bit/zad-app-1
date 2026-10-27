-- الصرف لكل شخص في البيت (ZAD_PLAN ٥.٣، قرار المالك ٢٧/١٠).
--
-- الأدوية والمواعيد عندهم «لمين؟» من 20260929130000، والمعاملات لأ — فـ«صرفنا كام على يوسف الشهر ده؟» ماكانش
-- ليها جواب (ZAD_SUPER_AGENT نقطة ٨، ZAD_DREAM_PLAN ح٨). العمود نص حر زي الأدوية بالظبط، متوحّد في الكود بـ
-- normalizeForPerson («أمي» = «ماما»، و«أنا» = فاضي). فاضي = العميل نفسه أو البيت كله، مش «مجهول».
-- مفيش RLS جديد: الصف نفسه بسياسات zad_transactions اللي موجودة.

alter table public.zad_transactions
  add column if not exists for_person text;

alter table public.zad_transactions
  drop constraint if exists zad_transactions_for_person_len;
alter table public.zad_transactions
  add constraint zad_transactions_for_person_len
  check (for_person is null or char_length(btrim(for_person)) between 1 and 40);

create index if not exists zad_transactions_for_person
  on public.zad_transactions (user_id, created_at desc) where for_person is not null;

comment on column public.zad_transactions.for_person is
  'ZAD_PLAN 5.3 — who in the house this spending was for («ماما»، «يوسف»). Null = the customer or the whole house.';
