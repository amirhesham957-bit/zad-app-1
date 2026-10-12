-- مكافأة الإعلان حسب البلد والصندوق (20261012050000) on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/ad_reward_scaffold.sql
--   psql < supabase/migrations/20261012050000_ad_reward_by_country.sql
--   psql < supabase/sql/tests/ad_reward_by_country_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1

insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000e1'), ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000f1')
on conflict do nothing;
insert into public.zad_users (id, country) values
  ('00000000-0000-0000-0000-0000000000e1', 'EG'), ('00000000-0000-0000-0000-0000000000a1', 'SA'),
  ('00000000-0000-0000-0000-0000000000f1', 'JO');
create table if not exists results (n int, ok boolean, note text);
create or replace function pg_temp.check(n int, ok boolean, note text default '') returns void language sql as $$
  insert into results values (n, coalesce(ok, false), note) $$;
create table if not exists g (who text, k int, v jsonb);
-- Grants as the service role (admob-ssv), the 60s gap stepped over by back-dating.
create or replace function pg_temp.watch(who text, uid uuid, k int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', false);
  update public.zad_ad_grants set granted_at = granted_at - interval '2 minutes' where user_id = uid;
  insert into g values (who, k, public.zad_ad_reward_grant(uid));
end $$;

do $$ begin for i in 1..3 loop
  perform pg_temp.watch('EG', '00000000-0000-0000-0000-0000000000e1', i);
  perform pg_temp.watch('SA', '00000000-0000-0000-0000-0000000000a1', i);
  perform pg_temp.watch('JO', '00000000-0000-0000-0000-0000000000f1', i);
end loop; end $$;

-- 1–3. Egypt: 2, 2, then 2 + a box of 2.
select pg_temp.check(1, (select array_agg((v->>'reward')::int order by k) from g where who = 'EG') = array[2, 2, 4]);
select pg_temp.check(2, (select bool_and((v->>'box_opened')::boolean = (k = 3)) from g where who = 'EG'));
select pg_temp.check(3, (select array_agg((v->>'box_progress')::int order by k) from g where who = 'EG') = array[1, 2, 0]);
-- 4. Saudi: 3, 3, 3 + 3.
select pg_temp.check(4, (select array_agg((v->>'reward')::int order by k) from g where who = 'SA') = array[3, 3, 6]);
-- 5. A country with no row of its own takes 'default': 2, 2, 2 + 3.
select pg_temp.check(5, (select array_agg((v->>'reward')::int order by k) from g where who = 'JO') = array[2, 2, 5]);
-- 6. The balance holds every grant: Egypt 8.
select pg_temp.check(6, (select chat_left from zad_entitlements where user_id = '00000000-0000-0000-0000-0000000000e1') = 8);
-- 7. The 60-second gap still holds.
select set_config('request.jwt.claims', '{"role":"service_role"}', false);
select pg_temp.check(7, zad_ad_reward_grant('00000000-0000-0000-0000-0000000000e1')->>'reason' = 'too_fast');
-- 8. The daily cap of 10 still holds.
do $$ begin for i in 4..10 loop perform pg_temp.watch('EG', '00000000-0000-0000-0000-0000000000e1', i); end loop; end $$;
select pg_temp.check(8, (select v->>'next_reward' from g where who = 'EG' and k = 10) is null);
update zad_ad_grants set granted_at = granted_at - interval '2 minutes';
select pg_temp.check(9, zad_ad_reward_grant('00000000-0000-0000-0000-0000000000e1')->>'reason' = 'daily_ad_cap');
-- 10. A rate changed in the table applies at once, no deploy.
update zad_ad_reward_rates set per_ad = 1 where country = 'SA';
select pg_temp.watch('SA', '00000000-0000-0000-0000-0000000000a1', 4);
select pg_temp.check(10, (select (v->>'reward')::int from g where who = 'SA' and k = 4) = 1);
-- 11. A signed-in customer cannot grant someone else.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', false);
select pg_temp.check(11, zad_ad_reward_grant('00000000-0000-0000-0000-0000000000e1')->>'reason' = 'forbidden');

-- 12. A child in a family is never granted an ad reward.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000c1') on conflict do nothing;
insert into family_groups (id) values ('00000000-0000-0000-0000-0000000000ff');
insert into family_members (family_id, user_id, role) values ('00000000-0000-0000-0000-0000000000ff', '00000000-0000-0000-0000-0000000000c1', 'child');
select set_config('request.jwt.claims', '{"role":"service_role"}', false);
select pg_temp.check(12, zad_ad_reward_grant('00000000-0000-0000-0000-0000000000c1')->>'reason' = 'kids_no_ads'
  and not exists (select 1 from zad_ad_grants where user_id = '00000000-0000-0000-0000-0000000000c1'));

\set QUIET 0
select n, ok, note from results order by n;
do $$ declare bad int; total int; begin
  select count(*) filter (where not ok), count(*) into bad, total from results;
  if bad > 0 then raise exception '% of % ad reward checks failed', bad, total; end if;
  raise notice 'all % ad reward checks passed', total;
end $$;
