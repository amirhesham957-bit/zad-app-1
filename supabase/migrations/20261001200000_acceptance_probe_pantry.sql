-- The acceptance probe account's pantry: water under three brands, one of them brand-first
-- («صافي مياه…»), so «عندي مية قد إيه؟» has one right answer: 6. Only this account.
delete from public.zad_inventory where user_id = 'a11ce000-0000-4000-8000-00000000a11a';
insert into public.zad_inventory (user_id, item_name, category, quantity, unit, low_stock_threshold)
values
  ('a11ce000-0000-4000-8000-00000000a11a', 'ماء إيلان', 'المشروبات', 2, 'زجاجة', 2),
  ('a11ce000-0000-4000-8000-00000000a11a', 'صافي مياه معدنية 1.5 لتر', 'البقالة', 3, 'زجاجة', 2),
  ('a11ce000-0000-4000-8000-00000000a11a', 'كرتونة ماية', 'المشروبات', 1, 'كرتونة', 1);
