-- ٨.٥ step 2, part 2: after 20261113180000, pg_net lives in extensions, schema net is back with
-- its grants, and a caller written against net.http_post still enqueues a request.
-- Runs after pg_net_schema_scaffold.sql and the migration, on a postgres with pg_net.
\set ON_ERROR_STOP on
do $$
declare
  r text;
  rid bigint;
begin
  if (select extnamespace::regnamespace::text from pg_extension where extname = 'pg_net') <> 'extensions' then
    raise exception 'pg_net is not in schema extensions';
  end if;
  if exists (select 1 from pg_depend d join pg_extension e on e.oid = d.refobjid
             join pg_proc p on p.oid = d.objid and d.classid = 'pg_proc'::regclass
             where e.extname = 'pg_net' and p.pronamespace = 'public'::regnamespace) then
    raise exception 'a pg_net function is still in public';
  end if;
  foreach r in array array['postgres', 'anon', 'authenticated', 'service_role', 'supabase_functions_admin'] loop
    if not has_schema_privilege(r, 'net', 'usage') then
      raise exception 'role % lost usage on schema net', r;
    end if;
  end loop;
  rid := public.fire_one();
  if rid is null or not exists (select 1 from net.http_request_queue where id = rid) then
    raise exception 'the caller did not enqueue a request after the move';
  end if;
  raise notice 'pg_net_schema_test: 4 checks passed';
end $$;

-- The same caller, as the role a trigger fires under from the app.
set role authenticated;
select public.fire_one() is not null as fired_as_authenticated;
reset role;
