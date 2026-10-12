-- رفيق زاد (20261012030000) as real accounts on a scratch database — how to run it
-- is at the top of companion_scaffold.sql. A logs, B is A's invited friend, C
-- tests the streak, F joins A's family. Every check lands in `results`; the file
-- raises if any failed.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
insert into auth.users (id) values
  ('00000000-0000-0000-0000-00000000000a'), ('00000000-0000-0000-0000-00000000000b'),
  ('00000000-0000-0000-0000-00000000000c'), ('00000000-0000-0000-0000-00000000000f')
on conflict do nothing;
insert into public.zad_users (id, country) values
  ('00000000-0000-0000-0000-00000000000a', 'EG'), ('00000000-0000-0000-0000-00000000000b', 'SA'),
  ('00000000-0000-0000-0000-00000000000c', 'EG'), ('00000000-0000-0000-0000-00000000000f', 'EG')
on conflict do nothing;
create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', case when p is null then '{}' else json_build_object('sub',
    '00000000-0000-0000-0000-00000000000' || lower(p), 'role', 'authenticated')::text end, false);
end $$;
create or replace function pg_temp.uid(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000000000' || lower(p))::uuid $$;
create table if not exists results (n int, ok boolean, note text);
grant all on results to authenticated;
create or replace function pg_temp.check(n int, ok boolean, note text default '') returns void language sql as $$
  insert into results values (n, coalesce(ok, false), note) $$;
create table if not exists s (k text primary key, v jsonb);
grant all on s to authenticated;

-- ── 1. A first status: born, zado and the morning owned, an invite code ──
select pg_temp.who('A'); set role authenticated;
insert into s select 'a1', zad_companion_status();
reset role;
select pg_temp.check(1, (v->>'level')::int = 1 and (v->>'stage')::int = 0 and (v->>'seeds')::int = 0
  and v->'owned' = '["morning","zado"]'::jsonb and v->>'persona' = 'zado'
  and v->>'invite_code' ~ '^ZAD-[0-9A-F]{4}-[0-9A-F]{4}$', v::text) from s where k = 'a1';

-- ── 2. Ten expenses: 80 XP of logging (capped), 25 for the streak day, level 2 ──
select pg_temp.who('A'); set role authenticated;
insert into zad_transactions (user_id, amount) select pg_temp.uid('A'), 50 from generate_series(1, 10);
reset role;
select pg_temp.check(2, xp = 105 and zad_companion_level(xp) = 2 and seeds = 50 and streak = 1,
  format('xp=%s seeds=%s streak=%s', xp, seeds, streak)) from zad_companion where user_id = pg_temp.uid('A');
select pg_temp.check(3, (select count(*) from zad_companion_ledger where user_id = pg_temp.uid('A') and source = 'log') = 10
  and (select sum(xp) from zad_companion_ledger where user_id = pg_temp.uid('A') and source = 'log') = 80);

-- ── 4. The same ref never pays twice ──
select pg_temp.check(4, zad_companion_award(pg_temp.uid('A'), 'log',
  (select ref from zad_companion_ledger where user_id = pg_temp.uid('A') and source = 'log' limit 1), 10) = 0);

-- ── 5. A receipt and the pantry: the day's three missions pay 30 seeds, once ──
select pg_temp.who('A'); set role authenticated;
insert into zad_transactions (user_id, amount, source_type) values (pg_temp.uid('A'), 120, 'receipt');
insert into zad_inventory (user_id, item_name) values (pg_temp.uid('A'), 'لبن') ;
update zad_inventory set quantity = 3 where user_id = pg_temp.uid('A');
update zad_inventory set quantity = 2 where user_id = pg_temp.uid('A');
insert into s select 'a5', zad_companion_status();
reset role;
select pg_temp.check(5, xp = 130 and seeds = 80, format('xp=%s seeds=%s', xp, seeds))
  from zad_companion where user_id = pg_temp.uid('A');
select pg_temp.check(6, v->'today' = '{"log": true, "scan": true, "pantry": true, "xp": 130}'::jsonb, v->>'today')
  from s where k = 'a5';
select pg_temp.check(7, (select count(*) from zad_companion_ledger where user_id = pg_temp.uid('A') and source = 'missions') = 1);

-- ── 8. A day-6 streak becomes 7 and pays the week's 100 seeds ──
select pg_temp.who('C'); set role authenticated;
select zad_companion_status();
reset role;
update zad_companion set streak = 6, streak_day = zad_companion_today(user_id) - 1 where user_id = pg_temp.uid('C');
select pg_temp.who('C'); set role authenticated;
insert into zad_transactions (user_id, amount) values (pg_temp.uid('C'), 10);
reset role;
select pg_temp.check(8, streak = 7 and best_streak = 7 and seeds = 100, format('streak=%s seeds=%s', streak, seeds))
  from zad_companion where user_id = pg_temp.uid('C');
-- A missed day starts over at 1.
update zad_companion set streak = 9, streak_day = zad_companion_today(user_id) - 3 where user_id = pg_temp.uid('C');
delete from zad_companion_ledger where user_id = pg_temp.uid('C') and source = 'streak';
select pg_temp.who('C'); set role authenticated;
insert into zad_transactions (user_id, amount) values (pg_temp.uid('C'), 10);
reset role;
select pg_temp.check(9, streak = 1 and best_streak = 7, format('streak=%s', streak)) from zad_companion where user_id = pg_temp.uid('C');

-- ── 10–15. Buying with seeds, wearing ──
select pg_temp.who('A'); set role authenticated;
insert into s select 'b1', zad_companion_buy('felfool');
reset role;
select pg_temp.check(10, v = '{"ok": false, "reason": "not_enough", "missing": 1920}'::jsonb, v::text) from s where k = 'b1';
update zad_companion set seeds = seeds + 5000 where user_id = pg_temp.uid('A');
select pg_temp.who('A'); set role authenticated;
insert into s select 'b2', zad_companion_buy('felfool');
insert into s select 'b3', zad_companion_buy('felfool');
insert into s select 'b4', zad_companion_buy('fanoos');
insert into s select 'b5', zad_companion_buy('fanoos', 'ramadan');
insert into s select 'b6', zad_companion_buy('zado');
insert into s select 'e1', zad_companion_equip('felfool');
insert into s select 'e2', zad_companion_equip('toota');
insert into s select 'e3', zad_companion_equip('night');
reset role;
select pg_temp.check(11, (select v->>'ok' from s where k = 'b2') = 'true'
  and (select v->>'reason' from s where k = 'b3') = 'owned'
  and (select v->>'reason' from s where k = 'b4') = 'out_of_season'
  and (select v->>'ok' from s where k = 'b5') = 'true'
  and (select v->>'reason' from s where k = 'b6') = 'not_for_seeds');
select pg_temp.check(12, seeds = 80 + 5000 - 2000 - 2500, format('seeds=%s', seeds)) from zad_companion where user_id = pg_temp.uid('A');
select pg_temp.check(13, persona = 'felfool' and (select v->>'reason' from s where k = 'e2') = 'not_owned'
  and (select v->>'reason' from s where k = 'e3') = 'not_owned') from zad_companion where user_id = pg_temp.uid('A');

-- ── 14. Nothing writable from the phone ──
select pg_temp.who('A'); set role authenticated;
do $$ begin update zad_companion set seeds = 99999; perform pg_temp.check(14, false, 'client set seeds');
exception when insufficient_privilege then perform pg_temp.check(14, true); end $$;
do $$ begin perform zad_companion_award(auth.uid(), 'log', 'x', 10); perform pg_temp.check(15, false, 'client awarded itself');
exception when insufficient_privilege then perform pg_temp.check(15, true); end $$;
do $$ begin perform zad_companion_grant_purchase(auth.uid(), 'zad_pet_seeds_6000', 'o1'); perform pg_temp.check(16, false, 'client bought free seeds');
exception when insufficient_privilege then perform pg_temp.check(16, true); end $$;
do $$ begin insert into zad_companion_owned values (auth.uid(), 'toota', 'free'); perform pg_temp.check(17, false, 'client took an item');
exception when insufficient_privilege then perform pg_temp.check(17, true); end $$;
reset role;

-- ── 18–22. A friend's code, proven only by a first expense ──
insert into s select 'code', to_jsonb(invite_code) from zad_companion where user_id = pg_temp.uid('A');
select pg_temp.who('B'); set role authenticated;
insert into s select 'i1', zad_companion_claim_invite('ZAD-0000-0000');
insert into s select 'i2', zad_companion_claim_invite(lower((select v->>0 from s where k = 'code')));
insert into s select 'i3', zad_companion_claim_invite((select v->>0 from s where k = 'code'));
reset role;
select pg_temp.check(18, (select v->>'reason' from s where k = 'i1') = 'wrong_code'
  and (select v->>'ok' from s where k = 'i2') = 'true' and (select v->>'reason' from s where k = 'i3') = 'already_claimed');
select pg_temp.check(19, confirmed_at is null) from zad_companion_referrals where invitee = pg_temp.uid('B');
select pg_temp.who('B'); set role authenticated;
insert into zad_transactions (user_id, amount) values (pg_temp.uid('B'), 30);
reset role;
select pg_temp.check(20, confirmed_at is not null) from zad_companion_referrals where invitee = pg_temp.uid('B');
select pg_temp.check(21, (select seeds from zad_companion where user_id = pg_temp.uid('A')) = 580 + 200
  and (select seeds from zad_companion where user_id = pg_temp.uid('B')) = 100);
select pg_temp.who('A'); set role authenticated;
insert into s select 'a22', zad_companion_status();
reset role;
select pg_temp.check(22, v->'owned' ? 'fella' and (v->>'invites')::int = 1, v->>'owned') from s where k = 'a22';
-- Your own code, and an old account, are refused.
update auth.users set created_at = now() - interval '30 days' where id = pg_temp.uid('C');
select pg_temp.who('C'); set role authenticated;
insert into s select 'i4', zad_companion_claim_invite((select v->>0 from s where k = 'code'));
reset role;
select pg_temp.check(23, (select v->>'reason' from s where k = 'i4') = 'too_late');

-- ── 24–27. Levels, the celebration, Plus, the age gate on evolution ──
update zad_companion set xp = zad_companion_level_floor(10) where user_id = pg_temp.uid('A');
select pg_temp.who('A'); set role authenticated;
insert into s select 'l1', zad_companion_status();
select zad_companion_ack();
insert into s select 'l2', zad_companion_status();
reset role;
select pg_temp.check(24, (v->>'level')::int = 10 and v->'owned' ? 'basbous' and v->'owned' ? 'garden'
  and (v->'celebrate'->>'to_level')::int = 10 and (v->>'level_xp')::int = 0 and (v->>'level_need')::int = 460, v::text)
  from s where k = 'l1';
select pg_temp.check(25, v->'celebrate' = 'null'::jsonb, v->>'celebrate') from s where k = 'l2';
insert into zad_entitlements (user_id, tier, tier_expires_at) values (pg_temp.uid('A'), 'plus', now() + interval '20 days');
update zad_companion set xp = zad_companion_level_floor(25) where user_id = pg_temp.uid('A');
select pg_temp.who('A'); set role authenticated;
insert into s select 'l3', zad_companion_status();
reset role;
select pg_temp.check(26, v->'owned' ? 'toota' and (v->>'stage')::int = 0, format('stage=%s', v->>'stage')) from s where k = 'l3';
update zad_companion set born_at = now() - interval '100 days' where user_id = pg_temp.uid('A');
select pg_temp.who('A'); set role authenticated;
insert into s select 'l4', zad_companion_status();
reset role;
select pg_temp.check(27, (v->>'stage')::int = 4 and v->'next_stage' = 'null'::jsonb
  and (v->'celebrate'->>'to_stage')::int = 4, v->>'celebrate') from s where k = 'l4';

-- ── 28. Back after three days: awake, «وحشتني», 10 seeds, once ──
update zad_companion set last_seen_at = now() - interval '3 days' where user_id = pg_temp.uid('A');
select pg_temp.who('A'); set role authenticated;
insert into s select 'w1', zad_companion_status();
insert into s select 'w2', zad_companion_status();
reset role;
select pg_temp.check(28, (select (v->>'welcome_back')::int from s where k = 'w1') = 10
  and (select (v->>'away_hours')::int from s where k = 'w1') >= 72
  and (select (v->>'welcome_back')::int from s where k = 'w2') = 0);

-- ── 29–30. Play purchases (service role): seeds once per order, a persona ──
select pg_temp.who(null);
select zad_companion_grant_purchase(pg_temp.uid('B'), 'zad_pet_seeds_2000', 'GPA.1');
select zad_companion_grant_purchase(pg_temp.uid('B'), 'zad_pet_seeds_2000', 'GPA.1');
select zad_companion_grant_purchase(pg_temp.uid('B'), 'zad_pet_mishmish', 'GPA.2');
select pg_temp.check(29, seeds = 2100, format('seeds=%s', seeds)) from zad_companion where user_id = pg_temp.uid('B');
select pg_temp.check(30, exists (select 1 from zad_companion_owned where user_id = pg_temp.uid('B') and item_id = 'mishmish' and source = 'purchase')
  and (zad_companion_grant_purchase(pg_temp.uid('B'), 'zad_pet_seeds_999', 'x')->>'reason') = 'unknown_pack');

-- ── 31. A family member joining: everyone already in the family earns 200 XP ──
insert into family_groups (id) values ('00000000-0000-0000-0000-0000000000ff');
insert into family_members (family_id, user_id) values ('00000000-0000-0000-0000-0000000000ff', pg_temp.uid('A'));
select xp as before from zad_companion where user_id = pg_temp.uid('A') \gset
insert into family_members (family_id, user_id) values ('00000000-0000-0000-0000-0000000000ff', pg_temp.uid('F'));
select pg_temp.check(31, xp = :before + 200, format('xp=%s', xp)) from zad_companion where user_id = pg_temp.uid('A');

-- ── 32. Mercy: a broken award never fails the expense ──
insert into zad_transactions (user_id, amount) values ('00000000-0000-0000-0000-0000000000ee', 5);
select pg_temp.check(32, exists (select 1 from zad_transactions where user_id = '00000000-0000-0000-0000-0000000000ee'));

-- ── 33. Signed out ──
do $$ begin perform zad_companion_status(); perform pg_temp.check(33, false, 'status signed out');
exception when insufficient_privilege then perform pg_temp.check(33, true); end $$;

\set QUIET 0
select n, ok, note from results order by n;
do $$ declare bad int; total int; begin
  select count(*) filter (where not ok), count(*) into bad, total from results;
  if bad > 0 then raise exception '% of % companion checks failed', bad, total; end if;
  raise notice 'all % companion checks passed', total;
end $$;
