-- zad_deal_source_targets + zad_deal_search_log.source (migration 20261102201700, ZAD_PLAN 4.11), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/deals_scaffold.sql
--   psql < supabase/sql/tests/store_deals_search_scaffold.sql
--   psql < supabase/migrations/20261025234500_deals.sql
--   psql < supabase/migrations/20261026013500_store_deals_search.sql
--   psql < supabase/migrations/20261026171500_deal_seed_stores.sql
--   psql < supabase/migrations/20261102201700_deals_youtube.sql
--   psql < supabase/sql/tests/deals_youtube_test.sql
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
\set QUIET 0

select pg_temp.check((select count(*) from public.zad_deal_search_targets(50)) = (select count(*) from public.zad_deal_source_targets(50, 'search')),
  'zad_deal_search_targets is the search source');
select pg_temp.check(exists (select 1 from public.zad_deal_source_targets(50, 'youtube') where store = 'كيو'),
  'كيو is a YouTube target before anything was searched');

-- Searched on the web this week: the web waits, YouTube still gets its turn.
insert into public.zad_deal_search_log (country, store_key, hits, put)
values ('SA', public.zad_inventory_name_key('كيو'), 0, 0);
select pg_temp.check((select source from public.zad_deal_search_log limit 1) = 'search', 'an old log row is a web search');
select pg_temp.check(not exists (select 1 from public.zad_deal_search_targets(50) where store = 'كيو'),
  'a store searched on the web this week is not searched on the web again');
select pg_temp.check(exists (select 1 from public.zad_deal_source_targets(50, 'youtube') where store = 'كيو'),
  'the web search does not use up its YouTube turn');

-- Searched on YouTube this week: YouTube waits a week.
insert into public.zad_deal_search_log (country, store_key, hits, put, source)
values ('SA', public.zad_inventory_name_key('كيو'), 2, 1, 'youtube');
select pg_temp.check(not exists (select 1 from public.zad_deal_source_targets(50, 'youtube') where store = 'كيو'),
  'a store searched on YouTube this week waits a week');

do $$ begin
  insert into public.zad_deal_search_log (country, store_key, hits, put, source) values ('SA', 'x', 0, 0, 'tiktok');
  raise exception 'FAIL: an unknown source was logged';
exception when check_violation then raise notice 'ok: an unknown source is refused';
end $$;
