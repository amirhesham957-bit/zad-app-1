-- حصة Google CSE المتقسّمة (migration 20261113100000), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261113100000_cse_daily_share.sql
--   psql < supabase/sql/tests/cse_daily_share_test.sql
--
-- Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

delete from public.zad_cse_budget;

-- سقف كلي ١٠، العروض ٧: سبعة نداءات عروض بتعدّي والتامن لأ.
do $$ declare ok int := 0; begin
  for i in 1..9 loop if public.zad_cse_take('deals', 7, 10) then ok := ok + 1; end if; end loop;
  perform pg_temp.check(ok = 7, 'deals stop at their share (7 of 10)');
end $$;

-- الوصفات لسه ليها الباقي (٣)، وبعده مفيش ولا غرض ياخد.
select pg_temp.check(public.zad_cse_take('recipes', null, 10), 'recipes take after deals are capped');
select pg_temp.check(public.zad_cse_take('other', null, 10), 'chat takes from the rest');
select pg_temp.check(public.zad_cse_take('recipes', null, 10), 'recipes take the last one');
select pg_temp.check(not public.zad_cse_take('recipes', null, 10), 'nobody passes the total');
select pg_temp.check(not public.zad_cse_take('deals', 7, 10), 'deals still refused');

select pg_temp.check((select used from public.zad_cse_budget where purpose = 'all') = 10, 'all counts every call that passed');
select pg_temp.check((select used from public.zad_cse_budget where purpose = 'deals') = 7, 'deals counted alone');

-- اليوم بتوقيت المحيط الهادي (يوم جوجل)، مش UTC.
select pg_temp.check((select day from public.zad_cse_budget where purpose = 'all') = (now() at time zone 'America/Los_Angeles')::date,
  'the day is Google''s (Pacific)');

-- مدخلات غلط مابتعدّش.
select pg_temp.check(not public.zad_cse_take('all', null, 100), 'purpose all is not takeable');
select pg_temp.check(not public.zad_cse_take('deals', 7, 0), 'zero total cap refuses');

-- الصلاحيات: service_role بس.
select pg_temp.check(not has_function_privilege('anon', 'public.zad_cse_take(text,int,int)', 'execute'), 'anon cannot take');
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_cse_take(text,int,int)', 'execute'), 'authenticated cannot take');
select pg_temp.check(not has_table_privilege('authenticated', 'public.zad_cse_budget', 'select'), 'authenticated cannot read the table');
