-- ZAD_PLAN ٣.١٠: حاجات على فترات. بعد scratch_scaffold.sql، occasional_scaffold.sql،
-- و20261020120000_occasional_items.sql.

\set ON_ERROR_STOP on

insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000e1');
insert into zad_users (id, currency) values ('00000000-0000-4000-8000-0000000000e1', 'EGP');

-- رنجة: اتشرت ٣ مرات كل ~٧٠ يوم. لبن: كل ٣ أيام. فسيخ: مرة واحدة من ٩٠ يوم. تونة: مرة من ١٠ أيام.
insert into zad_inventory_observations (user_id, item_name, qty, source, observed_at) values
  ('00000000-0000-4000-8000-0000000000e1', 'رنجة', 1, 'purchase', now() - interval '140 days'),
  ('00000000-0000-4000-8000-0000000000e1', 'رنجة', 1, 'purchase', now() - interval '70 days'),
  ('00000000-0000-4000-8000-0000000000e1', 'رنجة', 1, 'purchase', now() - interval '2 days'),
  ('00000000-0000-4000-8000-0000000000e1', 'لبن', 2, 'purchase', now() - interval '9 days'),
  ('00000000-0000-4000-8000-0000000000e1', 'لبن', 2, 'purchase', now() - interval '6 days'),
  ('00000000-0000-4000-8000-0000000000e1', 'لبن', 2, 'purchase', now() - interval '3 days'),
  ('00000000-0000-4000-8000-0000000000e1', 'فسيخ', 1, 'purchase', now() - interval '90 days'),
  ('00000000-0000-4000-8000-0000000000e1', 'تونة', 1, 'purchase', now() - interval '10 days'),
  -- قراية مش شرا مابتتعدّش.
  ('00000000-0000-4000-8000-0000000000e1', 'لبن', 1, 'manual', now() - interval '100 days');

insert into zad_inventory (user_id, item_name, quantity, low_stock_threshold) values
  ('00000000-0000-4000-8000-0000000000e1', 'رنجة', 3, 1),
  ('00000000-0000-4000-8000-0000000000e1', 'لبن', 3, 1),
  ('00000000-0000-4000-8000-0000000000e1', 'فسيخ', 0, 1),
  ('00000000-0000-4000-8000-0000000000e1', 'تونة', 0, 1),
  ('00000000-0000-4000-8000-0000000000e1', 'سكر', 0, 1);

do $$
declare u uuid := '00000000-0000-4000-8000-0000000000e1';
begin
  assert zad_item_is_occasional(u, 'رنجة'), 'herring every ~70 days is occasional';
  assert not zad_item_is_occasional(u, 'لبن'), 'milk every 3 days is a staple';
  assert zad_item_is_occasional(u, 'فسيخ'), 'once, 90 days ago, never again: occasional';
  assert not zad_item_is_occasional(u, 'تونة'), 'once, 10 days ago: too early to tell — staple';
  assert not zad_item_is_occasional(u, 'سكر'), 'no history: staple, as before';
  assert zad_occasional_items(u) @> array['رنجة', 'فسيخ'] and not zad_occasional_items(u) && array['لبن', 'تونة', 'سكر'],
    'occasional set: ' || zad_occasional_items(u)::text;

  -- The customer's word wins either way.
  update zad_inventory set restock_mode = 'staple' where item_name = 'رنجة';
  update zad_inventory set restock_mode = 'occasional' where item_name = 'سكر';
  assert not zad_item_is_occasional(u, 'رنجة'), '«دي أساسية» beats the history';
  assert zad_item_is_occasional(u, 'سكر'), '«دي مش أساسية» beats no history';
  update zad_inventory set restock_mode = null where item_name in ('رنجة', 'سكر');
end $$;

-- «هيخلص إمتى؟» skips the herring but still sees the milk.
insert into zad_consumption (user_id, item_name, avg_daily_qty, rate_known) values
  ('00000000-0000-4000-8000-0000000000e1', 'رنجة', 1.5, true),
  ('00000000-0000-4000-8000-0000000000e1', 'لبن', 1.5, true);
do $$
declare d text;
begin
  perform _agent_predicted_shortage_for_user('00000000-0000-4000-8000-0000000000e1');
  select task_description into d from agent_tasks where kind = 'predicted_shortage';
  assert d is not null, 'no shortage task at all';
  assert position('لبن' in d) > 0, 'milk missing: ' || d;
  assert position('رنجة' in d) = 0, 'herring was predicted: ' || d;
end $$;

-- العميل مايقدرش يسأل عن حد تاني.
set role authenticated;
do $$ begin
  begin
    perform zad_item_is_occasional('00000000-0000-4000-8000-0000000000e1', 'رنجة');
    raise exception 'authenticated called it';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

select 'occasional_items_test: ok';
