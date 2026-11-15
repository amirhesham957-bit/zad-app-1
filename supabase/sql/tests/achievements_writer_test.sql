-- zad_grant_achievement + triggers (20261116010000). Chain as game_reward_test.sql, minus 20261116020000.
\set ON_ERROR_STOP on

insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000b1'), ('00000000-0000-4000-8000-0000000000b2');

-- The old open insert policy is gone and no client can write.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}', false);
do $$ begin
  begin insert into user_achievements (user_id, achievement_id, points_earned)
    values ('00000000-0000-4000-8000-0000000000b1', 'first_receipt', 999); raise exception 'client insert allowed';
  exception when insufficient_privilege then null; end;
  begin perform zad_grant_achievement('00000000-0000-4000-8000-0000000000b1', 'first_receipt'); raise exception 'client granted';
  exception when insufficient_privilege then null; end;
end $$;
set role anon;
do $$ begin
  begin perform zad_grant_achievement('00000000-0000-4000-8000-0000000000b1', 'first_receipt'); raise exception 'anon granted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Server side: catalogue only, idempotent.
do $$ begin
  if not zad_grant_achievement('00000000-0000-4000-8000-0000000000b1', 'saved_1000') then raise exception 'first grant false'; end if;
  if zad_grant_achievement('00000000-0000-4000-8000-0000000000b1', 'saved_1000') then raise exception 'second grant true'; end if;
  if zad_grant_achievement('00000000-0000-4000-8000-0000000000b1', 'made_up') then raise exception 'unknown id granted'; end if;
  if (select count(*) from user_achievements where user_id = '00000000-0000-4000-8000-0000000000b1') <> 1 then raise exception 'rows <> 1'; end if;
end $$;
delete from user_achievements;

-- Triggers: a plain transaction -> first_transaction only; a receipt -> both; a second one adds nothing.
insert into zad_transactions (user_id, amount, source_type) values ('00000000-0000-4000-8000-0000000000b1', 10, 'manual');
do $$ begin
  if (select array_agg(achievement_id order by achievement_id) from user_achievements where user_id = '00000000-0000-4000-8000-0000000000b1')
     is distinct from array['first_transaction'] then raise exception 'manual txn -> %', (select array_agg(achievement_id) from user_achievements); end if;
end $$;
insert into zad_transactions (user_id, amount, source_type) values ('00000000-0000-4000-8000-0000000000b1', 20, 'receipt');
insert into zad_transactions (user_id, amount, source_type) values ('00000000-0000-4000-8000-0000000000b1', 30, 'receipt');
do $$ begin
  if (select count(*) from user_achievements where user_id = '00000000-0000-4000-8000-0000000000b1') <> 2
     or not exists (select 1 from user_achievements where achievement_id = 'first_receipt') then raise exception 'receipt txn -> wrong rows'; end if;
  if exists (select 1 from user_achievements where user_id = '00000000-0000-4000-8000-0000000000b2') then raise exception 'leaked to b2'; end if;
end $$;

-- 7-day streak: 6 nothing, 7 yes.
select zad_companion_ensure('00000000-0000-4000-8000-0000000000b2');
update zad_companion set streak = 6 where user_id = '00000000-0000-4000-8000-0000000000b2';
do $$ begin if exists (select 1 from user_achievements where achievement_id = 'streak_7') then raise exception 'streak 6 granted'; end if; end $$;
update zad_companion set streak = 7 where user_id = '00000000-0000-4000-8000-0000000000b2';
do $$ begin if not exists (select 1 from user_achievements where achievement_id = 'streak_7' and user_id = '00000000-0000-4000-8000-0000000000b2') then raise exception 'streak 7 missing'; end if; end $$;

-- Tasbih: 98 nothing; 99 yes (personal tree -> its owner); a family tree -> the one clicking, not the whole family.
insert into family_tasbiha (family_id, user_id, total_clicks) values (null, '00000000-0000-4000-8000-0000000000b2', 98);
do $$ begin if exists (select 1 from user_achievements where achievement_id = 'tasbih_tree') then raise exception '98 granted'; end if; end $$;
update family_tasbiha set total_clicks = 99;
do $$ begin if (select count(*) from user_achievements where achievement_id = 'tasbih_tree' and user_id = '00000000-0000-4000-8000-0000000000b2') <> 1 then raise exception '99 missing'; end if; end $$;

-- 1000 saved.
insert into agent_goals (user_id, title, current_value) values ('00000000-0000-4000-8000-0000000000b1', 'g', 999);
do $$ begin if exists (select 1 from user_achievements where achievement_id = 'saved_1000' and user_id = '00000000-0000-4000-8000-0000000000b1') then raise exception '999 granted'; end if; end $$;
update agent_goals set current_value = 1000;
do $$ begin if not exists (select 1 from user_achievements where achievement_id = 'saved_1000' and user_id = '00000000-0000-4000-8000-0000000000b1') then raise exception '1000 missing'; end if; end $$;

-- Own-read only.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b2","role":"authenticated"}', false);
do $$ begin
  if exists (select 1 from user_achievements where user_id <> '00000000-0000-4000-8000-0000000000b2') then raise exception 'read another user'; end if;
  if not exists (select 1 from user_achievements) then raise exception 'cannot read own'; end if;
end $$;
reset role;
select 'achievements_writer_test OK' as result;
