-- ZAD_OR_PLAN م٢.٣. zad_inventory وzad_transactions بالشكل اللي فيه الكمية والمبلغ قبل المايجريشن،
-- ومعاهم صفوف قديمة مخالفة عشان نتأكد إن NOT VALID ماينفعش يفشل على الصفوف دي.

\set ON_ERROR_STOP on

create table public.zad_inventory (
  id uuid primary key default gen_random_uuid(), user_id uuid, item_name text,
  quantity numeric(12,3) default 1);

create table public.zad_transactions (
  id uuid primary key default gen_random_uuid(), user_id uuid,
  amount double precision not null, title text not null);

insert into public.zad_inventory (item_name, quantity) values
  ('legacy-rice', 2.5),
  ('legacy-broken-count', -1);

insert into public.zad_transactions (amount, title) values
  (0, 'legacy-free'),
  (-5, 'legacy-negative');
