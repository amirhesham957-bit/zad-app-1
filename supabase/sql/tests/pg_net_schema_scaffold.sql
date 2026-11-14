-- Scratch shape for pg_net_schema_test.sql: pg_net installed in public the way live had it
-- on 2026-11-13, the Supabase roles the grant names, and one security-definer caller shaped
-- like the six live ones. Needs a postgres with pg_net built and preloaded
-- (shared_preload_libraries = pg_net) — CI's postgres has neither, so this runs locally,
-- like vector_schema_test.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

do $$ begin
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin;
  create role supabase_functions_admin nologin;
exception when duplicate_object then null;
end $$;

create extension pg_net with schema public;

-- The callers resolve net.http_post at call time, by name; set search_path = public like live.
create table public.calls_made (request_id bigint);
create function public.fire_one() returns bigint
language plpgsql security definer set search_path = public as $$
declare rid bigint;
begin
  select net.http_post(
    url := 'http://127.0.0.1:9/zad', headers := '{}'::jsonb, body := '{}'::jsonb,
    timeout_milliseconds := 1000) into rid;
  insert into public.calls_made values (rid);
  return rid;
end $$;
grant execute on function public.fire_one() to authenticated;

-- Before the move the caller works.
select public.fire_one();
