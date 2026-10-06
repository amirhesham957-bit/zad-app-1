-- Campaign peaks and the month-long autumn season (migration
-- 20261006000500), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261004120000_app_campaigns.sql
--   psql < supabase/migrations/20261005100000_app_campaigns_event_name.sql
--   psql < supabase/migrations/20261006000500_app_campaigns_peak_and_autumn.sql
--   psql < supabase/sql/tests/app_campaigns_peak_test.sql
--
-- The re-run check reads the migration from /work: start the container with
-- the repository mounted there (docker run ... -v "$PWD":/work:ro ...).
-- Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

select pg_temp.check((select peak_md from app_campaigns where event_key = 'egypt_october_6') = '10-06', '6 October peaks on the 6th');
select pg_temp.check((select bool_and(peak_md = '10-31') from app_campaigns where event_key = 'halloween'), 'both Halloween copies peak on the 31st');
select pg_temp.check((select count(*) from app_campaigns where event_key = 'autumn') = 2, 'autumn in the default and the Gulf copy');
select pg_temp.check((select bool_and(from_md = '10-01' and to_md = '10-31' and priority < 0 and event_name is null and peak_md is null and target_country is null)
  from app_campaigns where event_key = 'autumn'), 'autumn: all October, everywhere, below every other campaign, no countdown');
select pg_temp.check((select count(*) from app_campaigns where peak_md is not null and peak_md not between from_md and to_md
  and from_md <= to_md) = 0, 'every peak sits inside its own window');

do $$ begin
  update app_campaigns set peak_md = '13-01' where event_key = 'halloween';
  raise exception 'FAIL: a month 13 peak was accepted';
exception when check_violation then raise notice 'ok: a bad peak is refused';
end $$;

-- A peak edited from the dashboard survives the migration running again.
update app_campaigns set peak_md = '10-30' where event_key = 'halloween' and dialect is null;
\i /work/supabase/migrations/20261006000500_app_campaigns_peak_and_autumn.sql
select pg_temp.check((select peak_md from app_campaigns where event_key = 'halloween' and dialect is null) = '10-30', 'an edited peak is kept on a re-run');
select pg_temp.check((select count(*) from app_campaigns where event_key = 'autumn') = 2, 'a re-run adds no second autumn');

set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', false);
select pg_temp.check((select count(*) from app_campaigns where event_key = 'autumn') = 2, 'a signed-in phone reads autumn');
reset role;
