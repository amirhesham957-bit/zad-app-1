-- The bot's «لسه عندك؟» is a bet in zad_pantry_bets (ZAD_PLAN 10.1 slice 4b).
\set ON_ERROR_STOP on
\set me '''11111111-1111-1111-1111-111111111111'''

insert into auth.users values (:me);
insert into public.zad_users (id, country) values (:me, 'SA');
insert into public.zad_inventory (id, user_id, item_name, quantity) values
  ('00000000-0000-0000-0000-000000000001', :me, 'حليب', 2),
  ('00000000-0000-0000-0000-000000000002', :me, 'رز', 4),
  ('00000000-0000-0000-0000-000000000003', :me, 'عسل', 1),
  ('00000000-0000-0000-0000-000000000004', :me, 'تمر', 3);
insert into public.zad_consumption values (:me, 'حليب', 1, 3, true, now());

-- The bot asks about milk (rate) and rice (cycle, no rate); a prompt for an item not in the pantry opens nothing.
insert into public.telegram_checkin_prompts (id, user_id, item_name, quantity_at_prompt) values
  ('aaaaaaaa-0000-0000-0000-000000000001', :me, 'حليب', 2),
  ('aaaaaaaa-0000-0000-0000-000000000002', :me, 'رز', 4),
  ('aaaaaaaa-0000-0000-0000-000000000003', :me, 'عسل', 1),
  ('aaaaaaaa-0000-0000-0000-000000000004', :me, 'تمر', 3),
  ('aaaaaaaa-0000-0000-0000-000000000009', :me, 'شاي', 1);

do $$
declare r record;
begin
  if (select count(*) from public.zad_pantry_bets) <> 4 then
    raise exception 'one bet per prompt for items in the pantry, got %', (select count(*) from public.zad_pantry_bets); end if;
  select * into r from public.zad_pantry_bets where item_name = 'حليب';
  if r.channel <> 'telegram' or r.predicted_days_left <> 2 or r.confidence <> 'known' then
    raise exception 'milk bet: %', row_to_json(r); end if;
  if (select confidence from public.zad_pantry_bets where item_name = 'رز') is distinct from 'cycle' then
    raise exception 'a bet asked by the purchase cycle says so'; end if;
end $$;

-- Answers: «خلص» = finished, «قليل» = low, «كتير» = still_have, «زي ما هو» (no fraction) = still_have.
update public.telegram_checkin_prompts set status = 'answered_no', answered_at = now(), answer_fraction = 0
 where id = 'aaaaaaaa-0000-0000-0000-000000000001';
update public.telegram_checkin_prompts set status = 'answered_yes', answered_at = now(), answer_fraction = 0.2
 where id = 'aaaaaaaa-0000-0000-0000-000000000002';
update public.telegram_checkin_prompts set status = 'answered_yes', answered_at = now(), answer_fraction = 0.75
 where id = 'aaaaaaaa-0000-0000-0000-000000000003';
update public.telegram_checkin_prompts set status = 'expired' where id = 'aaaaaaaa-0000-0000-0000-000000000004';

do $$
begin
  if (select answer from public.zad_pantry_bets where item_name = 'حليب') is distinct from 'finished' then raise exception 'milk'; end if;
  if (select answer from public.zad_pantry_bets where item_name = 'رز') is distinct from 'low' then raise exception '«قليل» is a hit (low)'; end if;
  if (select answer from public.zad_pantry_bets where item_name = 'عسل') is distinct from 'still_have' then raise exception 'honey'; end if;
  if (select answer from public.zad_pantry_bets where item_name = 'تمر') is not null then raise exception 'expired stays unanswered'; end if;
end $$;

-- The bot's «لسه» silences the home card too.
insert into public.zad_inventory (id, user_id, item_name, quantity) values ('00000000-0000-0000-0000-000000000005', :me, 'لبنة', 1);
insert into public.zad_consumption values (:me, 'لبنة', 1, 3, true, now());
insert into public.telegram_checkin_prompts (id, user_id, item_name, quantity_at_prompt, sent_at) values
  ('aaaaaaaa-0000-0000-0000-000000000005', :me, 'لبنة', 1, now() - interval '1 day');
update public.telegram_checkin_prompts set status = 'answered_yes', answered_at = now() - interval '1 day'
 where id = 'aaaaaaaa-0000-0000-0000-000000000005';
set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :me)::text, false);
do $$
begin
  if (select ask from public.zad_pantry_learning() where item_name = 'لبنة') then
    raise exception 'the bot''s «لسه» must keep the card quiet'; end if;
end $$;
reset role;

-- The card asked first today: the bot's prompt joins that bet instead of opening a second one.
insert into public.zad_inventory (id, user_id, item_name, quantity) values ('00000000-0000-0000-0000-000000000006', :me, 'خبز', 1);
insert into public.zad_consumption values (:me, 'خبز', 1, 3, true, now());
set role authenticated;
select count(*) from public.zad_pantry_learning();
reset role;
insert into public.telegram_checkin_prompts (id, user_id, item_name, quantity_at_prompt) values
  ('aaaaaaaa-0000-0000-0000-000000000006', :me, 'خبز', 1);
update public.telegram_checkin_prompts set status = 'answered_no', answered_at = now() where id = 'aaaaaaaa-0000-0000-0000-000000000006';
do $$
begin
  if (select count(*) from public.zad_pantry_bets where item_name = 'خبز') <> 1 then raise exception 'one bet a day'; end if;
  if (select answer from public.zad_pantry_bets where item_name = 'خبز') is distinct from 'finished' then
    raise exception 'the bot''s answer judges the card''s bet'; end if;
end $$;

-- Measurement counts «قليل» as a hit, per channel.
update public.zad_pantry_bets set asked_at = now() - interval '2 days';
do $$
declare a jsonb := public.zad_pantry_bet_accuracy(7);
begin
  if (a -> 'by_channel' -> 'telegram' ->> 'hit')::int < 2 or (a ->> 'miss')::int <> 2 then
    raise exception 'accuracy: %', a; end if;
end $$;

-- A client cannot write prompts (they would become bets through the trigger); it can still read its own.
set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :me)::text, false);
do $$
begin
  begin
    insert into public.telegram_checkin_prompts (user_id, item_name, quantity_at_prompt) values (auth.uid(), 'حليب', 1);
    raise exception 'a client insert must be refused';
  exception when insufficient_privilege then null; end;
  begin
    update public.telegram_checkin_prompts set status = 'answered_no' where user_id = auth.uid();
    raise exception 'a client update must be refused';
  exception when insufficient_privilege then null; end;
  if (select count(*) from public.telegram_checkin_prompts) = 0 then raise exception 'the owner still reads them'; end if;
end $$;
reset role;

select 'pantry_bot_bets_test passed' as result;
