-- Opened items (20261114220000): an opened item's life after opening caps its days left.
\set ON_ERROR_STOP on
\set me '''11111111-1111-1111-1111-111111111111'''
insert into auth.users values (:me);
insert into public.zad_users (id, country) values (:me, 'EG');
insert into public.zad_customer_profile (user_id, household_size) values (:me, 2);

insert into public.zad_inventory (id, user_id, item_name, quantity, unit, created_at, opened_at) values
  -- 3 litres of milk last 7.5 days for two, but the open one has been open 5 days of its 4.
  ('00000000-0000-0000-0000-000000000001', :me, 'حليب', 3, 'حبة', now(), now() - interval '5 days'),
  -- 400 g of cheese: 6.7 days by the rate, 6 left of its 7 after opening.
  ('00000000-0000-0000-0000-000000000002', :me, 'جبنة رومي 400 جرام', 1, 'قطعة', now(), now() - interval '1 day'),
  -- Opened rice has no short life: the rate rules.
  ('00000000-0000-0000-0000-000000000003', :me, 'أرز', 1, 'كيلو', now(), now() - interval '20 days'),
  -- Labneh: no rate at all, opened 2 days of its 5.
  ('00000000-0000-0000-0000-000000000004', :me, 'لبنة', 1, 'علبة', now(), now() - interval '2 days');

do $$
begin
  if (select opened_life_days from public.zad_inventory where item_name = 'حليب') <> 4 then raise exception 'milk lives 4 days open'; end if;
  if (select opened_life_days from public.zad_inventory where item_name = 'أرز') is not null then raise exception 'rice has no open life'; end if;
end $$;

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :me)::text, false);
do $$
declare r record;
begin
  select * into r from public.zad_pantry_learning() where item_name = 'حليب';
  if r.days_left <> 0 or r.confidence <> 'opened' or not r.ask then raise exception 'milk open past its life: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name like 'جبنة%';
  if r.days_left <> 6 or r.confidence <> 'opened' then raise exception 'cheese: 6 left after opening beats 6.7 by rate: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name = 'أرز';
  if r.days_left <> 7.1 or r.confidence <> 'prior' then raise exception 'opened rice follows its rate: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name = 'لبنة';
  if r.days_left <> 3 or r.confidence <> 'opened' then raise exception 'labneh, no rate, 3 left after opening: %', row_to_json(r); end if;
end $$;
reset role;

-- Finished: the opened mark goes with it; bought again it starts closed.
update public.zad_inventory set quantity = 0 where item_name = 'حليب';
update public.zad_inventory set quantity = 2 where item_name = 'حليب';
do $$
begin
  if (select opened_at from public.zad_inventory where item_name = 'حليب') is not null then raise exception 'an empty item is not open'; end if;
  if (select opened_life_days from public.zad_inventory where item_name = 'حليب') is not null then raise exception 'no life without opening'; end if;
end $$;

select 'pantry_opened_test passed' as result;
