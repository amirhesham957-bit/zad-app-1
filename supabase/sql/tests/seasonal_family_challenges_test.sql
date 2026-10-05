-- Seasonal family challenges and their badges (migration 20261005110000), on
-- a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20260921130000_family_membership_through_the_server.sql
--   psql < supabase/migrations/20260921150000_family_money_through_the_server.sql
--   psql < supabase/migrations/20261005110000_seasonal_family_challenges.sql
--   psql < supabase/sql/tests/seasonal_family_challenges_test.sql
--
-- P is a parent (admin), C a child, O in another family.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'),('00000000-0000-0000-0000-0000000000c1'),('00000000-0000-0000-0000-0000000000f1') on conflict do nothing;
create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', case p
    when 'P' then '00000000-0000-0000-0000-0000000000a1' when 'C' then '00000000-0000-0000-0000-0000000000c1'
    when 'O' then '00000000-0000-0000-0000-0000000000f1' end, 'role', 'authenticated')::text, false);
end $$;
create table if not exists sres (n int, ok boolean, note text);
grant all on sres to authenticated;
create or replace function pg_temp.check(n int, ok boolean, note text default '') returns void language sql as $$
  insert into sres values (n, ok, note) $$;
create table if not exists sctx (k text primary key, v text);
grant all on sctx to authenticated;
create or replace function sctxv(k text) returns uuid language sql as $$ select v::uuid from sctx where sctx.k = $1 $$;
grant execute on function sctxv(text) to authenticated;

select pg_temp.who('P'); set role authenticated;
insert into sctx select 'fam', (zad_create_family('بابا')->>'family_id');
insert into sctx select 'code', (select invite_code from family_groups);
reset role; select pg_temp.who('C'); set role authenticated;
select zad_join_family((select v from sctx where k='code'), 'يوسف');
reset role; select pg_temp.who('O'); set role authenticated;
insert into sctx select 'ofam', (zad_create_family('غريب')->>'family_id');
reset role;
insert into sctx select 'C', id from family_members where user_id='00000000-0000-0000-0000-0000000000c1';
select pg_temp.who('P'); set role authenticated;
update family_members set role = 'child' where id = sctxv('C');
\set QUIET 0

-- 1. A parent starts a Ramadan challenge with its badge.
with x as (insert into family_financial_challenges (family_id, title, target_amount, reward_amount, is_active, end_date, season_key, badge)
  values (sctxv('fam'), 'تحدي رمضان 🌙', 100, 20, true, now() + interval '20 days', 'ramadan', '🌙') returning id)
insert into sctx select 'ch', id from x;
select pg_temp.check(1, (select badge = '🌙' and season_key = 'ramadan' from family_financial_challenges where id = sctxv('ch')));

-- 2. The shape is enforced.
do $$ begin insert into family_financial_challenges (family_id, title, season_key) values (sctxv('fam'), 'x', 'Ramadan!');
  perform pg_temp.check(2, false, 'stored a malformed season key');
exception when check_violation then perform pg_temp.check(2, true); end $$;

-- 3. A child cannot swap the badge on a running challenge.
reset role; select pg_temp.who('C'); set role authenticated;
do $$ begin update family_financial_challenges set badge = '👑' where id = sctxv('ch');
  perform pg_temp.check(3, false, 'child changed a badge');
exception when insufficient_privilege then perform pg_temp.check(3, true); end $$;
do $$ begin update family_financial_challenges set season_key = 'new_year' where id = sctxv('ch');
  perform pg_temp.check(4, false, 'child changed a season');
exception when insufficient_privilege then perform pg_temp.check(4, true); end $$;

-- 4. A child may start an unrewarded seasonal challenge of their own.
do $$ begin insert into family_financial_challenges (family_id, title, target_amount, season_key, badge)
  values (sctxv('fam'), 'تحدي التوفير', 10, 'ramadan', '🌙'); perform pg_temp.check(5, true);
exception when others then perform pg_temp.check(5, false, sqlerrm); end $$;

-- 5. No badge before the challenge is done; the badge once it is.
select pg_temp.check(6, not exists (select 1 from financial_challenge_progress p join family_financial_challenges c on c.id = p.challenge_id
  where p.user_id = auth.uid() and p.is_completed and c.badge is not null));
do $$ declare r jsonb := zad_contribute_to_challenge(sctxv('ch'), 100); begin perform pg_temp.check(7, (r->>'completed')::bool, r::text); end $$;
select pg_temp.check(8, (select c.badge from financial_challenge_progress p join family_financial_challenges c on c.id = p.challenge_id
  where p.user_id = auth.uid() and p.is_completed) = '🌙');

-- 6. The badge cannot be had without the work.
do $$ begin insert into financial_challenge_progress (challenge_id, user_id, current_amount, is_completed)
  values (sctxv('ch'), '00000000-0000-0000-0000-0000000000a1', 999, true);
  perform pg_temp.check(9, false, 'wrote a completion directly');
exception when insufficient_privilege then perform pg_temp.check(9, true); end $$;

-- 7. Another family sees neither the challenge nor the badge.
reset role; select pg_temp.who('O'); set role authenticated;
select pg_temp.check(10, not exists (select 1 from family_financial_challenges where id = sctxv('ch')));
select pg_temp.check(11, not exists (select 1 from financial_challenge_progress where challenge_id = sctxv('ch')));
reset role;

do $$ declare bad text; begin
  select string_agg(n || coalesce(' ' || nullif(note, ''), ''), '; ' order by n) into bad from sres where not ok;
  if bad is not null then raise exception 'FAIL: %', bad; end if;
  raise notice 'ok: % checks', (select count(*) from sres);
end $$;
