-- P2.1: فرد واحد. zad_household_members هو الشخص؛ family_members مجرد ربط حساب.
-- يتضاف للفرد: بلد وعملة ولهجة ومين وليّه. كلها اختيارية (null = ورث من صاحب البيت).
-- ماتغيّرش: RLS القراية، ولا الـgrants على باقي الأعمدة، ولا أي دالة قديمة.

alter table public.zad_household_members add column if not exists country text;
alter table public.zad_household_members add column if not exists currency text;
alter table public.zad_household_members add column if not exists dialect text;
alter table public.zad_household_members add column if not exists guardian_member_id uuid;

-- وليّ الفرد لازم يكون من نفس البيت (نفس user_id)، ومايكونش هو نفسه. لو الوليّ اتمسح، العمود بس يفضى (مش user_id).
alter table public.zad_household_members drop constraint if exists zad_household_members_guardian_fk;
alter table public.zad_household_members add constraint zad_household_members_guardian_fk
  foreign key (guardian_member_id, user_id) references public.zad_household_members (id, user_id)
  on delete set null (guardian_member_id);
alter table public.zad_household_members drop constraint if exists zad_household_members_guardian_not_self;
alter table public.zad_household_members add constraint zad_household_members_guardian_not_self
  check (guardian_member_id is null or guardian_member_id <> id);
alter table public.zad_household_members drop constraint if exists zad_household_members_country_len;
alter table public.zad_household_members add constraint zad_household_members_country_len
  check (country is null or length(btrim(country)) between 1 and 8);
alter table public.zad_household_members drop constraint if exists zad_household_members_currency_len;
alter table public.zad_household_members add constraint zad_household_members_currency_len
  check (currency is null or length(btrim(currency)) between 1 and 8);
alter table public.zad_household_members drop constraint if exists zad_household_members_dialect_len;
alter table public.zad_household_members add constraint zad_household_members_dialect_len
  check (dialect is null or length(btrim(dialect)) between 1 and 32);

-- صاحب البيت بس يعدّل الأعمدة الجديدة دي. باقي الأعمدة (الاسم، النوع، الربط) لسه من الباب الوحيد.
drop policy if exists household_members_update_own_profile on public.zad_household_members;
create policy household_members_update_own_profile on public.zad_household_members
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
grant update (country, currency, dialect, guardian_member_id) on public.zad_household_members to authenticated;
