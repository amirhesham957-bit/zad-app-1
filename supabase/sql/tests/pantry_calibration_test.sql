-- Per-home calibration of the household prior and the weekly accuracy message (20261114230000).
\set ON_ERROR_STOP on
\set me '''11111111-1111-1111-1111-111111111111'''
insert into auth.users values (:me);
insert into public.zad_users (id, country) values (:me, 'EG');
insert into public.zad_customer_profile (user_id, household_size) values (:me, 2);
insert into public.zad_inventory (id, user_id, item_name, quantity, unit, created_at) values
  ('00000000-0000-0000-0000-000000000001', :me, 'عيش', 10, 'رغيف', now()),
  ('00000000-0000-0000-0000-000000000002', :me, 'حليب', 1, 'حبة', now());
insert into public.zad_consumption values (:me, 'حليب', 1, 3, true, now());

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :me)::text, false);
do $$
begin
  -- 10 loaves at 5 a day = 2 days: asked on the prior. The milk is asked on its known rate.
  if (select days_left from public.zad_pantry_learning() where item_name = 'عيش') <> 2 then raise exception 'bread starts at 2 days'; end if;
  -- «لسه» on the prior's bet: the home eats bread slower than the guess.
  perform public.zad_pantry_bet_answer('00000000-0000-0000-0000-000000000001', 'still_have');
  -- «لسه» on the known rate's bet moves nothing.
  perform public.zad_pantry_bet_answer('00000000-0000-0000-0000-000000000002', 'still_have');
end $$;
reset role;

do $$
declare c record;
begin
  select * into c from public.zad_pantry_calibration where user_id = '11111111-1111-1111-1111-111111111111';
  if c.factor <> 0.85 or c.misses <> 1 or c.hits <> 0 then raise exception 'one prior miss: %', row_to_json(c); end if;
  -- 10 / (5 x 0.85) = 2.35.
  if (select days_left from private.zad_pantry_prior_days('11111111-1111-1111-1111-111111111111') where item_name = 'عيش') <> 2.4 then
    raise exception 'the bread lasts longer after the miss: %', (select days_left from private.zad_pantry_prior_days('11111111-1111-1111-1111-111111111111') where item_name = 'عيش'); end if;
end $$;

-- A «خلص» on a prior bet nudges it back up; the factor never leaves 0.3..3.
insert into public.zad_pantry_bets (user_id, item_id, item_name, asked_on, confidence)
  values (:me, '00000000-0000-0000-0000-000000000001', 'عيش', current_date - 1, 'prior');
update public.zad_pantry_bets set answer = 'finished', answered_at = now() where asked_on = current_date - 1;
update public.zad_pantry_calibration set factor = 0.31;
insert into public.zad_pantry_bets (user_id, item_id, item_name, asked_on, confidence)
  values (:me, '00000000-0000-0000-0000-000000000001', 'عيش', current_date - 2, 'prior');
update public.zad_pantry_bets set answer = 'still_have', answered_at = now() where asked_on = current_date - 2;
do $$
declare c record;
begin
  select * into c from public.zad_pantry_calibration;
  if c.factor <> 0.3 or c.hits <> 1 or c.misses <> 2 then raise exception 'floor and counts: %', row_to_json(c); end if;
end $$;

-- The weekly message: sent, and says the target.
update public.zad_pantry_bets set asked_at = now() - interval '2 days';
do $$
declare t text;
begin
  t := public.zad_pantry_accuracy_weekly();
  if t not like '%الهدف ٧٠٪%' then raise exception 'weekly text: %', t; end if;
  if (select count(*) from public.admin_messages) <> 1 then raise exception 'one admin message'; end if;
end $$;

select 'pantry_calibration_test passed' as result;
