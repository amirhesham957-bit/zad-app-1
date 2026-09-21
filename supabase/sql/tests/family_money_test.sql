-- Family money through the server (migration 20260921150000), as four real
-- accounts on a scratch database — see scratch_scaffold.sql for how to run it.
-- P is a parent (admin), C and S are children, O is in another family. Every
-- check lands in `results`; the file raises if any failed.

\set ON_ERROR_STOP on

-- Scratch databases only: these files write rows. A real Supabase database has a
-- storage schema; refuse before touching anything.
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
-- P parent (admin), C child, S sibling (child), O outsider in another family.
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'),('00000000-0000-0000-0000-0000000000c1'),('00000000-0000-0000-0000-0000000000c2'),('00000000-0000-0000-0000-0000000000f1') on conflict do nothing;
create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', case p
    when 'P' then '00000000-0000-0000-0000-0000000000a1' when 'C' then '00000000-0000-0000-0000-0000000000c1'
    when 'S' then '00000000-0000-0000-0000-0000000000c2' when 'O' then '00000000-0000-0000-0000-0000000000f1' end,
    'role', 'authenticated')::text, false);
end $$;
create table if not exists results (n int, ok boolean, note text);
create or replace function pg_temp.check(n int, ok boolean, note text default '') returns void language sql as $$
  insert into results values (n, ok, note) $$;
grant all on results to authenticated;
create table if not exists ctx (k text primary key, v text);
grant all on ctx to authenticated;
create or replace function ctxv(k text) returns uuid language sql as $$ select v::uuid from ctx where ctx.k = $1 $$;
grant execute on function ctxv(text) to authenticated;

-- Setup through the real functions.
select pg_temp.who('P'); set role authenticated;
insert into ctx select 'fam', (zad_create_family('بابا')->>'family_id');
insert into ctx select 'code', (select invite_code from family_groups);
reset role; select pg_temp.who('C'); set role authenticated;
select zad_join_family((select v from ctx where k='code'), 'يوسف');
reset role; select pg_temp.who('S'); set role authenticated;
select zad_join_family((select v from ctx where k='code'), 'مريم');
reset role; select pg_temp.who('O'); set role authenticated;
insert into ctx select 'ofam', (zad_create_family('غريب')->>'family_id');
reset role;
insert into ctx select 'P', id from family_members where user_id='00000000-0000-0000-0000-0000000000a1';
insert into ctx select 'C', id from family_members where user_id='00000000-0000-0000-0000-0000000000c1';
insert into ctx select 'S', id from family_members where user_id='00000000-0000-0000-0000-0000000000c2';
insert into ctx select 'O', id from family_members where user_id='00000000-0000-0000-0000-0000000000f1';
select pg_temp.who('P'); set role authenticated;
update family_members set role = 'child' where id in (ctxv('C'), ctxv('S'));
reset role;

-- ── Balances
select pg_temp.who('C'); set role authenticated;
do $$ begin update family_members set balance = 1000 where id = ctxv('C'); perform pg_temp.check(1, false, 'child set own balance');
exception when insufficient_privilege then perform pg_temp.check(1, true); end $$;
reset role; select pg_temp.who('P'); set role authenticated;
do $$ begin update family_members set balance = 1000 where id = ctxv('C'); perform pg_temp.check(2, false, 'admin set balance directly');
exception when insufficient_privilege then perform pg_temp.check(2, true); end $$;
-- a parent can still rename and set limits
do $$ begin update family_members set alias = 'يويو', daily_limit = 50 where id = ctxv('C'); perform pg_temp.check(3, true);
exception when others then perform pg_temp.check(3, false, sqlerrm); end $$;

-- ── Chores
reset role; select pg_temp.who('C'); set role authenticated;
do $$ begin insert into family_chores (family_id, assigned_to, title, reward_amount) values (ctxv('fam'), ctxv('C'), 'x', 100);
  perform pg_temp.check(4, false, 'child set a reward');
exception when insufficient_privilege then perform pg_temp.check(4, true); end $$;
do $$ begin insert into family_chores (family_id, assigned_to, title) values (ctxv('fam'), ctxv('C'), 'ترتيب السرير'); perform pg_temp.check(5, true);
exception when others then perform pg_temp.check(5, false, sqlerrm); end $$;
reset role; select pg_temp.who('P'); set role authenticated;
with x as (insert into family_chores (family_id, assigned_to, title, reward_amount) values (ctxv('fam'), ctxv('C'), 'غسيل الأطباق', 50) returning id) insert into ctx select 'chore', id from x;
with x as (insert into family_chores (family_id, assigned_to, title, reward_amount) values (ctxv('fam'), ctxv('S'), 'سقي الزرع', 40) returning id) insert into ctx select 'schore', id from x;
do $$ begin insert into family_chores (family_id, assigned_to, title, reward_amount) values (ctxv('fam'), ctxv('O'), 'x', 5);
  perform pg_temp.check(6, false, 'assigned outside the family');
exception when insufficient_privilege then perform pg_temp.check(6, true); end $$;
reset role; select pg_temp.who('C'); set role authenticated;
do $$ begin update family_chores set reward_amount = 500 where id = ctxv('chore'); perform pg_temp.check(7, false, 'child raised reward');
exception when insufficient_privilege then perform pg_temp.check(7, true); end $$;
do $$ begin update family_chores set assigned_to = ctxv('C') where id = ctxv('schore'); perform pg_temp.check(8, false, 'child took sibling reward');
exception when insufficient_privilege then perform pg_temp.check(8, true); end $$;
do $$ begin update family_chores set is_completed = true where id = ctxv('chore'); perform pg_temp.check(9, false, 'completed directly');
exception when insufficient_privilege then perform pg_temp.check(9, true); end $$;
reset role; select pg_temp.who('S'); set role authenticated;
do $$ declare r jsonb := zad_complete_chore(ctxv('chore')); begin perform pg_temp.check(10, r->>'reason' = 'not_yours', r::text); end $$;
reset role; select pg_temp.who('O'); set role authenticated;
do $$ declare r jsonb := zad_complete_chore(ctxv('chore')); begin perform pg_temp.check(11, r->>'reason' = 'not_found', r::text); end $$;
reset role; select pg_temp.who('C'); set role authenticated;
do $$ declare r jsonb := zad_complete_chore(ctxv('chore')); begin perform pg_temp.check(12, (r->>'paid')::numeric = 50 and (r->>'balance')::numeric = 50, r::text); end $$;
do $$ declare r jsonb := zad_complete_chore(ctxv('chore')); begin perform pg_temp.check(13, (r->>'already')::bool and (select balance from family_members where id = ctxv('C')) = 50, r::text); end $$;
do $$ declare r jsonb := zad_reopen_chore(ctxv('chore')); begin perform pg_temp.check(14, r->>'reason' = 'not_an_admin', r::text); end $$;
do $$ begin perform pg_temp.check(15, exists (select 1 from app_notifications where user_id = auth.uid() and title like 'عمل رائع%')); end $$;
reset role; select pg_temp.who('P'); set role authenticated;
do $$ declare r jsonb := zad_reopen_chore(ctxv('chore')); begin perform pg_temp.check(16, (r->>'taken_back')::numeric = 50 and (select balance from family_members where id = ctxv('C')) = 0, r::text); end $$;
-- the parent raises the reward after the take-back; completing again pays the new figure once
update family_chores set reward_amount = 60 where id = ctxv('chore');
reset role; select pg_temp.who('C'); set role authenticated;
do $$ declare r jsonb := zad_complete_chore(ctxv('chore')); begin perform pg_temp.check(17, (select balance from family_members where id = ctxv('C')) = 60, r::text); end $$;

-- ── Challenges
do $$ begin insert into family_financial_challenges (family_id, title, target_amount, reward_amount, is_active) values (ctxv('fam'), 'x', 10, 100, true);
  perform pg_temp.check(18, false, 'child set a challenge reward');
exception when insufficient_privilege then perform pg_temp.check(18, true); end $$;
reset role; select pg_temp.who('P'); set role authenticated;
with x as (insert into family_financial_challenges (family_id, title, target_amount, reward_amount, is_active, end_date)
  values (ctxv('fam'), 'حوّش 100', 100, 30, true, now() + interval '7 days') returning id) insert into ctx select 'ch', id from x;
reset role; select pg_temp.who('C'); set role authenticated;
do $$ begin update family_financial_challenges set target_amount = 1 where id = ctxv('ch'); perform pg_temp.check(19, false, 'child lowered target');
exception when insufficient_privilege then perform pg_temp.check(19, true); end $$;
do $$ begin insert into financial_challenge_progress (challenge_id, user_id, current_amount, is_completed) values (ctxv('ch'), auth.uid(), 999, true);
  perform pg_temp.check(20, false, 'child wrote own progress');
exception when insufficient_privilege then perform pg_temp.check(20, true); end $$;
do $$ declare r jsonb := zad_contribute_to_challenge(ctxv('ch'), 60); begin perform pg_temp.check(21, not (r->>'completed')::bool and (r->>'paid')::numeric = 0, r::text); end $$;
do $$ declare r jsonb := zad_contribute_to_challenge(ctxv('ch'), 50); begin perform pg_temp.check(22, (r->>'completed')::bool and (r->>'paid')::numeric = 30 and (r->>'balance')::numeric = 90, r::text); end $$;
do $$ declare r jsonb := zad_contribute_to_challenge(ctxv('ch'), 10); begin perform pg_temp.check(23, (r->>'paid')::numeric = 0 and (select balance from family_members where id = ctxv('C')) = 90, r::text); end $$;
reset role; select pg_temp.who('S'); set role authenticated;
do $$ declare r jsonb := zad_contribute_to_challenge(ctxv('ch'), 500, ctxv('C')); begin perform pg_temp.check(24, r->>'reason' = 'not_yours', r::text); end $$;
reset role; select pg_temp.who('P'); set role authenticated;
do $$ declare r jsonb := zad_contribute_to_challenge(ctxv('ch'), 100, ctxv('S')); begin perform pg_temp.check(25, (r->>'paid')::numeric = 30 and (select balance from family_members where id = ctxv('S')) = 30, r::text); end $$;
update family_financial_challenges set is_active = false where id = ctxv('ch');
reset role; select pg_temp.who('C'); set role authenticated;
do $$ declare r jsonb := zad_contribute_to_challenge(ctxv('ch'), 10); begin perform pg_temp.check(26, r->>'reason' = 'closed', r::text); end $$;
do $$ declare r jsonb := zad_contribute_to_challenge(ctxv('ch'), -5); begin perform pg_temp.check(27, r->>'reason' = 'invalid_input', r::text); end $$;

-- ── Purchase requests
do $$ begin insert into chat_messages (family_id, sender_id, message, message_type, metadata) values (ctxv('fam'), ctxv('S')::text, 'x', 'PURCHASE_REQUEST', '{"amount":20,"status":"PENDING"}');
  perform pg_temp.check(28, false, 'request in sibling name');
exception when insufficient_privilege then perform pg_temp.check(28, true); end $$;
do $$ begin insert into chat_messages (family_id, sender_id, message, message_type, metadata) values (ctxv('fam'), ctxv('C')::text, 'x', 'PURCHASE_REQUEST', '{"amount":20,"status":"APPROVED"}');
  perform pg_temp.check(29, false, 'pre-approved request');
exception when invalid_parameter_value then perform pg_temp.check(29, true); end $$;
with x as (insert into chat_messages (family_id, sender_id, message, message_type, metadata)
  values (ctxv('fam'), ctxv('C')::text, 'عايز 20 للكانتين', 'PURCHASE_REQUEST', '{"amount":20, "status":"PENDING"}') returning id) insert into ctx select 'req', id from x;
with x as (insert into chat_messages (family_id, sender_id, message, message_type, metadata)
  values (ctxv('fam'), ctxv('C')::text, 'عايز 70 لعبة', 'PURCHASE_REQUEST', '{"amount":70, "status":"PENDING"}') returning id) insert into ctx select 'req2', id from x;
do $$ begin update chat_messages set metadata = '{"amount":20,"status":"APPROVED"}' where id = ctxv('req'); perform pg_temp.check(30, false, 'child approved own request');
exception when insufficient_privilege then perform pg_temp.check(30, true); end $$;
do $$ begin update chat_messages set is_pinned = true, reactions = '👍' where id = ctxv('req'); perform pg_temp.check(31, true);
exception when others then perform pg_temp.check(31, false, sqlerrm); end $$;
do $$ declare r jsonb := zad_decide_purchase_request(ctxv('req'), true); begin perform pg_temp.check(32, r->>'reason' = 'not_an_admin', r::text); end $$;
-- ordinary chat is untouched
do $$ begin insert into chat_messages (family_id, sender_id, message, message_type) values (ctxv('fam'), ctxv('C')::text, 'ازيكم', 'TEXT'); perform pg_temp.check(33, true);
exception when others then perform pg_temp.check(33, false, sqlerrm); end $$;
reset role; select pg_temp.who('P'); set role authenticated;
do $$ declare r jsonb := zad_decide_purchase_request(ctxv('req'), true); begin
  perform pg_temp.check(34, (r->>'debited')::numeric = 20 and (select balance from family_members where id = ctxv('C')) = 70
    and (select metadata::jsonb->>'status' from chat_messages where id = ctxv('req')) = 'APPROVED', r::text); end $$;
do $$ declare r jsonb := zad_decide_purchase_request(ctxv('req'), true); begin perform pg_temp.check(35, (r->>'already')::bool and (select balance from family_members where id = ctxv('C')) = 70, r::text); end $$;
do $$ declare r jsonb := zad_decide_purchase_request(ctxv('req2'), false); begin perform pg_temp.check(36, r->>'status' = 'REJECTED' and (select balance from family_members where id = ctxv('C')) = 70, r::text); end $$;

-- ── family_messages
insert into family_messages (family_id, sender_id, message) values (ctxv('fam'), auth.uid(), 'سر');
reset role; select pg_temp.who('O'); set role authenticated;
do $$ begin perform pg_temp.check(37, (select count(*) from family_messages) = 0); end $$;
do $$ begin insert into family_messages (family_id, message) values (ctxv('fam'), 'x'); perform pg_temp.check(38, false, 'outsider wrote into a family');
exception when insufficient_privilege then perform pg_temp.check(38, true); end $$;

-- ── the service role is trusted
reset role; select set_config('request.jwt.claims', '{"role":"service_role"}', false); set role service_role;
do $$ begin update family_members set balance = balance + 1 where id = ctxv('S'); perform pg_temp.check(39, true);
exception when others then perform pg_temp.check(39, false, sqlerrm); end $$;
reset role;

do $$
declare
  v_failed text;
begin
  select string_agg(n || ': ' || note, '; ' order by n) into v_failed from results where not ok;
  if v_failed is not null then
    raise exception 'family money checks failed — %', v_failed;
  end if;
  raise notice 'family money: % checks passed', (select count(*) from results);
end $$;
