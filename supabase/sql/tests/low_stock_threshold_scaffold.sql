-- ZAD_PLAN ١٠.١ شريحة ٣: zad_inventory زي ما هو على الحي قبل المايجريشن (العمود default 2)،
-- وفيه صفوف قديمة عشان نشوف التحديث بيعمل إيه فيها.

\set ON_ERROR_STOP on

create table public.zad_inventory (
  id uuid primary key default gen_random_uuid(), user_id uuid, item_name text,
  quantity numeric default 1, unit text, low_stock_threshold numeric default 2);

insert into public.zad_inventory (item_name, quantity, unit) values
  ('legacy-one-box', 1, 'علبة'),
  ('legacy-eggs', 30, 'حبة'),
  ('legacy-rice', 5, 'كيلو'),
  ('legacy-empty', 0, 'قطعة');
insert into public.zad_inventory (item_name, quantity, unit, low_stock_threshold) values
  ('legacy-chosen', 1, 'كرتونة', 1);
