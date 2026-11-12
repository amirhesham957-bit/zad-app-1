-- zad_pantry_learning / zad_pantry_bet_answer / zad_pantry_bet_accuracy (ZAD_PLAN 10.1 slice 4).
\set ON_ERROR_STOP on
\set me   '''11111111-1111-1111-1111-111111111111'''
\set wife '''22222222-2222-2222-2222-222222222222'''
\set other '''33333333-3333-3333-3333-333333333333'''

insert into auth.users values (:me), (:wife), (:other);
insert into public.zad_users (id, country) values (:me, 'SA'), (:wife, 'SA'), (:other, 'EG');
insert into public.family_groups (id) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
insert into public.family_members (family_id, user_id) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', :me), ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', :wife);

insert into public.zad_inventory (id, user_id, family_id, item_name, quantity, restock_mode, created_at) values
  ('00000000-0000-0000-0000-000000000001', :me, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'حليب', 1, null, now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000000002', :me, null, 'رز', 10, null, now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000000003', :me, null, 'زعفران', 1, null, now() - interval '60 days'),
  ('00000000-0000-0000-0000-000000000004', :me, null, 'بخور', 1, 'occasional', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000000005', :other, null, 'سكر', 1, null, now());
-- The wife's rate for the shared milk: 1 a day ⇒ 1 day left. Rice: 1 a day, 10 days left.
insert into public.zad_consumption values
  (:wife, 'حليب', 1, 3, true, now()), (:me, 'رز', 1, 3, false, now()), (:other, 'سكر', 5, 3, true, now());
-- Saffron: one purchase 60 days ago, never dropped ⇒ stagnant.
insert into public.zad_inventory_observations (user_id, item_name, qty, observed_at, source) values
  (:me, 'زعفران', 1, now() - interval '60 days', 'purchase');

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :me)::text, false);

do $$
declare r record; n int;
begin
  select count(*) into n from public.zad_pantry_learning();
  if n <> 4 then raise exception 'expected 4 rows (own + family, not the stranger), got %', n; end if;

  select * into r from public.zad_pantry_learning() where item_name = 'حليب';
  if not r.ask or r.days_left <> 1 or r.confidence <> 'known' then
    raise exception 'milk should be asked with 1 day left on the wife''s known rate: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name = 'رز';
  if r.ask or r.stagnant or r.days_left <> 10 or r.confidence <> 'approximate' then raise exception 'rice: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name = 'زعفران';
  if not r.stagnant or r.ask then raise exception 'saffron should be stagnant, not asked: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name = 'بخور';
  if r.ask then raise exception 'occasional items are never asked'; end if;
end $$;

-- The client reads its own bets, and only reads them.
do $$
declare n int;
begin
  select count(*) into n from public.zad_pantry_bets;
  if n <> 1 then raise exception 'one bet for the milk, however often it is read; got %', n; end if;
  begin
    insert into public.zad_pantry_bets (user_id, item_id, item_name, asked_on, confidence)
    values (auth.uid(), gen_random_uuid(), 'x', current_date, 'known');
    raise exception 'a client insert must be refused';
  exception when insufficient_privilege then null; end;
end $$;

-- «لسه»: the bet is judged a miss, a reading at the same count is recorded, and the milk is not asked for 3 days.
do $$
declare a jsonb; r record;
begin
  a := public.zad_pantry_bet_answer('00000000-0000-0000-0000-000000000001', 'still_have');
  if not (a ->> 'ok')::boolean then raise exception 'answer refused: %', a; end if;
  select * into r from public.zad_pantry_learning() where item_name = 'حليب';
  if r.ask then raise exception 'milk must not be asked again after «لسه»'; end if;
  if (select answer from public.zad_pantry_bets where item_name = 'حليب') is distinct from 'still_have' then
    raise exception 'the bet was not judged'; end if;
end $$;

-- The next day «لسه» still holds; after three days the milk is asked again.
reset role;
update public.zad_pantry_bets set asked_on = asked_on - 1, asked_at = asked_at - interval '1 day',
       answered_at = answered_at - interval '1 day' where item_name = 'حليب';
set role authenticated;
do $$
begin
  if (select ask from public.zad_pantry_learning() where item_name = 'حليب') then
    raise exception 'milk must not be asked the day after «لسه»'; end if;
end $$;
reset role;
update public.zad_pantry_bets set asked_on = asked_on - 3, asked_at = asked_at - interval '3 days',
       answered_at = answered_at - interval '3 days' where item_name = 'حليب';
set role authenticated;
do $$
begin
  if not (select ask from public.zad_pantry_learning() where item_name = 'حليب') then
    raise exception 'milk must be asked again once «لسه» is three days old'; end if;
  if (select count(*) from public.zad_pantry_bets where item_name = 'حليب') <> 2 then
    raise exception 'the new question is a new bet'; end if;
end $$;

-- Somebody else's item is not found; a bad answer is refused.
do $$
begin
  if (public.zad_pantry_bet_answer('00000000-0000-0000-0000-000000000005', 'finished') ->> 'reason') is distinct from 'not_found' then
    raise exception 'another account''s item must not be answerable'; end if;
  if (public.zad_pantry_bet_answer('00000000-0000-0000-0000-000000000002', 'maybe') ->> 'reason') is distinct from 'bad_answer' then
    raise exception 'unknown answers must be refused'; end if;
end $$;

-- An answer with no open bet (card seen offline) is kept as «unasked», not counted as a bet.
do $$
begin
  perform public.zad_pantry_bet_answer('00000000-0000-0000-0000-000000000002', 'used_one');
  if (select confidence from public.zad_pantry_bets where item_name = 'رز') is distinct from 'unasked' then
    raise exception 'an unasked answer must say so'; end if;
end $$;

-- The accuracy is the server's, not a client's.
do $$
begin
  perform public.zad_pantry_bet_accuracy(7);
  raise exception 'a client must not read the accuracy';
exception when insufficient_privilege then null;
end $$;

reset role;
update public.zad_pantry_bets set asked_at = now() - interval '2 days';
do $$
declare a jsonb;
begin
  a := public.zad_pantry_bet_accuracy(7);
  if (a ->> 'miss')::int <> 1 or (a ->> 'asked')::int <> 3 or (a ->> 'ignored')::int <> 1 then raise exception 'accuracy: %', a; end if;
end $$;

select 'pantry_learning_test passed' as result;
