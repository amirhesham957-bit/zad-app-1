-- The household priors (20261114200000): a starting rate per kind × the people in the home ÷ the pack,
-- used only with no learned rate and fewer than 3 purchase days.
\set ON_ERROR_STOP on
\set me   '''11111111-1111-1111-1111-111111111111'''
\set wife '''22222222-2222-2222-2222-222222222222'''
\set other '''33333333-3333-3333-3333-333333333333'''

insert into auth.users values (:me), (:wife), (:other);
insert into public.zad_users (id, country) values (:me, 'EG'), (:wife, 'EG'), (:other, 'EG');
insert into public.family_groups (id) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
insert into public.family_members (family_id, user_id) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', :me), ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', :wife),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '44444444-4444-4444-4444-444444444444');
insert into public.zad_customer_profile (user_id, household_size) values (:me, 2);

-- Who lives there: what the customer said, else the family in Zad, else 3.
do $$
begin
  if private.zad_household_people('11111111-1111-1111-1111-111111111111') <> 2 then raise exception 'me: the profile says 2, over 3 in the family'; end if;
  if private.zad_household_people('22222222-2222-2222-2222-222222222222') <> 3 then raise exception 'wife: three in the family'; end if;
  if private.zad_household_people('33333333-3333-3333-3333-333333333333') <> 3 then raise exception 'alone and silent: 3'; end if;
end $$;

-- The rate itself, for two people.
do $$
declare v numeric;
begin
  v := private.zad_pantry_prior_daily('عيش', 'رغيف', 2);
  if v <> 5 then raise exception 'bread: 2.5 loaves each = 5, got %', v; end if;
  v := private.zad_pantry_prior_daily('زجاجة مياه بسعة 1.5 لتر من ايلانو 6 قطع ليتر', 'قطعة', 2);
  if round(v, 2) <> 0.33 then raise exception 'a 6 x 1.5 l pack of water: 3 l a day / 9 l = 0.33, got %', v; end if;
  v := private.zad_pantry_prior_daily('جبنة رومي ٥٠٠ جم', 'قطعة', 2);
  if v <> 0.12 then raise exception 'arabic digits: 60 g / 500 g = 0.12, got %', v; end if;
  v := private.zad_pantry_prior_daily('أرز', 'كيلو', 2);
  if v <> 0.14 then raise exception 'rice by the kilo: 140 g = 0.14 kg, got %', v; end if;
  v := private.zad_pantry_prior_daily('فاين مناديل وجه من برستيج، 500 منديل، 3 طبقات', 'قطعة', 2);
  if v <> 0.032 then raise exception 'tissues: 16 / 500, got %', v; end if;
  v := private.zad_pantry_prior_daily('بيض', 'كرتونة', 2);
  if round(v, 4) <> 0.0667 then raise exception 'a tray of eggs is 30: 2 / 30, got %', v; end if;
  if private.zad_pantry_prior_daily('خيار', 'قطعة', 2) is not null then raise exception 'cucumbers have no prior'; end if;
  if private.zad_pantry_prior_daily('لبنة', 'علبة', 2) is not null then raise exception 'labneh is not milk'; end if;
end $$;

insert into public.zad_inventory (id, user_id, family_id, item_name, quantity, unit, created_at) values
  ('00000000-0000-0000-0000-000000000001', :me, null, 'عيش', 10, 'رغيف', now()),
  ('00000000-0000-0000-0000-000000000002', :me, null, 'زجاجة مياه بسعة 1.5 لتر من ايلانو 6 قطع ليتر', 1, 'قطعة', now()),
  ('00000000-0000-0000-0000-000000000003', :me, null, 'حليب جهينة', 3, 'حبة', now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000000004', :me, null, 'خيار', 2, 'قطعة', now()),
  ('00000000-0000-0000-0000-000000000005', :me, null, 'سكر', 1, 'قطعة', now() - interval '40 days'),
  ('00000000-0000-0000-0000-000000000006', :me, null, 'لبن', 1, 'حبة', now()),
  ('00000000-0000-0000-0000-000000000007', :me, null, 'شاي ريد ليبل 225 جرام', 1, 'قطعة', now()),
  ('00000000-0000-0000-0000-000000000008', :wife, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'مكرونة', 1, 'قطعة', now() - interval '30 days');
-- Sugar was bought on 3 different days: the home's own rhythm, not the prior.
insert into public.zad_inventory_observations (user_id, item_name, qty, observed_at, source) values
  (:me, 'سكر', 1, now() - interval '40 days', 'purchase'),
  (:me, 'سكر', 1, now() - interval '25 days', 'purchase'),
  (:me, 'سكر', 1, now() - interval '10 days', 'purchase'),
  -- The pasta was read again 27 days after it was added: the clock starts there.
  (:wife, 'مكرونة', 1, now() - interval '3 days', 'question_answer');
-- Laban has a learned rate: it wins.
insert into public.zad_consumption values (:me, 'لبن', 0.2, 2, false, now());

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :me)::text, false);

do $$
declare r record;
begin
  select * into r from public.zad_pantry_learning() where item_name = 'عيش';
  if r.days_left <> 2 or r.confidence <> 'prior' or not r.ask then raise exception 'bread: 10 loaves / 5 a day = 2 days, asked: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name like 'زجاجة مياه%';
  if r.days_left <> 3 or r.confidence <> 'prior' or r.ask then raise exception 'water: 3 days, not yet: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name = 'حليب جهينة';
  if r.days_left <> 1.5 or not r.ask then raise exception 'milk: 7.5 days from 6 days ago = 1.5 left: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name like 'شاي%';
  if r.days_left <> 18.8 or r.ask then raise exception 'tea: 225 g / 12 g = 18.8: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name = 'مكرونة';
  if r.days_left <> 2 or r.confidence <> 'prior' then raise exception 'family pasta: 5 days (80 g of 400 a day) from the last reading 3 days ago = 2: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name = 'خيار';
  if r.days_left is not null or r.confidence is not null or r.ask then raise exception 'no prior, no guess: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name = 'سكر';
  if r.days_left is not null or r.ask then raise exception 'sugar follows its purchase rhythm: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_learning() where item_name = 'لبن';
  if r.days_left <> 5 or r.confidence <> 'approximate' then raise exception 'the learned rate wins: %', row_to_json(r); end if;
  if (select confidence from public.zad_pantry_bets where item_name = 'عيش') is distinct from 'prior' then
    raise exception 'the bread bet says it came from the prior'; end if;
  -- Three asked (milk 1.5, bread 2, pasta 2), the app shows two: two bets, the nearest.
  if (select count(*) from public.zad_pantry_bets) <> 2 then
    raise exception 'two bets a day, got %', (select count(*) from public.zad_pantry_bets); end if;
  if exists (select 1 from public.zad_pantry_bets where item_name = 'مكرونة') then raise exception 'pasta was not shown'; end if;
end $$;

-- The bot's door is the server's only.
do $$
begin
  perform * from public.zad_pantry_prior_days_for(auth.uid());
  raise exception 'a client must not call the bot''s function';
exception when insufficient_privilege then null;
end $$;

-- «لسه» on the bread holds it for the bot as well.
do $$
begin
  perform public.zad_pantry_bet_answer('00000000-0000-0000-0000-000000000001', 'still_have');
end $$;
reset role;

do $$
declare r record;
begin
  select * into r from public.zad_pantry_prior_days_for('11111111-1111-1111-1111-111111111111') where item_name = 'عيش';
  if not r.held then raise exception 'bread was answered «لسه»: held: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_prior_days_for('11111111-1111-1111-1111-111111111111') where item_name like 'شاي%';
  if r.held or r.days_left <> 18.8 then raise exception 'tea for the bot: %', row_to_json(r); end if;
  if exists (select 1 from public.zad_pantry_prior_days_for('11111111-1111-1111-1111-111111111111') where item_name in ('لبن', 'سكر', 'خيار')) then
    raise exception 'learned, habitual and unknown items are not the prior''s'; end if;
end $$;

-- A bot question is a bet: 'prior' with its days when the bot asked on the prior, 'cycle' otherwise.
insert into public.telegram_checkin_prompts (user_id, item_name, quantity_at_prompt) values
  (:me, 'شاي ريد ليبل 225 جرام', 1), (:me, 'خيار', 2);
do $$
declare r record;
begin
  select * into r from public.zad_pantry_bets where item_name like 'شاي%';
  if r.confidence <> 'prior' or r.predicted_days_left <> 18.8 or r.channel <> 'telegram' then raise exception 'tea bet: %', row_to_json(r); end if;
  select * into r from public.zad_pantry_bets where item_name = 'خيار';
  if r.confidence <> 'cycle' or r.predicted_days_left is not null then raise exception 'cucumber bet: %', row_to_json(r); end if;
end $$;

select 'pantry_priors_test passed' as result;
