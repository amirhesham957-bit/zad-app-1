-- ZAD_PLAN ٣.١٠ ب: العمود المحسوب restock_occasional. بعد scratch_scaffold.sql، occasional_scaffold.sql،
-- 20261020120000_occasional_items.sql، و20261020130000_occasional_column.sql.

\set ON_ERROR_STOP on

insert into auth.users (id) values
  ('00000000-0000-4000-8000-0000000000f1'), ('00000000-0000-4000-8000-0000000000f2');

-- رنجة: كل ~٧٠ يوم عند f1 بس. لبن: كل ٣ أيام.
insert into zad_inventory_observations (user_id, item_name, qty, source, observed_at) values
  ('00000000-0000-4000-8000-0000000000f1', 'رنجة', 1, 'purchase', now() - interval '140 days'),
  ('00000000-0000-4000-8000-0000000000f1', 'رنجة', 1, 'purchase', now() - interval '70 days'),
  ('00000000-0000-4000-8000-0000000000f1', 'لبن', 1, 'purchase', now() - interval '6 days'),
  ('00000000-0000-4000-8000-0000000000f1', 'لبن', 1, 'purchase', now() - interval '3 days');

insert into zad_inventory (id, user_id, item_name, quantity) values
  ('00000000-0000-4000-8000-00000000f001', '00000000-0000-4000-8000-0000000000f1', 'رنجة', 0),
  ('00000000-0000-4000-8000-00000000f002', '00000000-0000-4000-8000-0000000000f1', 'لبن', 0);

-- As the owner, the way PostgREST calls it.
set role authenticated;
set request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"authenticated"}';
do $$ begin
  assert (select restock_occasional(i) from zad_inventory i where i.item_name = 'رنجة'), 'herring is occasional to its owner';
  assert not (select restock_occasional(i) from zad_inventory i where i.item_name = 'لبن'), 'milk is a staple';
end $$;

-- Someone else's history is not theirs: to f2 the same row has no history at all.
set request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000f2","role":"authenticated"}';
do $$ begin
  assert not (select restock_occasional(i) from zad_inventory i where i.item_name = 'رنجة'), 'f2 read f1''s history';
end $$;

-- No caller, no verdict.
set request.jwt.claims = '{}';
do $$ begin
  assert not (select restock_occasional(i) from zad_inventory i where i.item_name = 'رنجة'), 'anonymous call answered';
end $$;
reset role;

select 'occasional_column_test: ok';
