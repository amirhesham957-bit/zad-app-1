-- save_trusted_technician (zad-brain, wave 3): the write the tool makes, on the live table shape
-- (migration 20261006014219). Scratch database only:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261006014219_trusted_technicians.sql
--   psql < supabase/sql/tests/technician_from_chat_test.sql
--
-- The tool upserts on (user_id, phone) as the owner. Rolls back.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

begin;
insert into auth.users values ('00000000-0000-0000-0000-0000000000c1') on conflict do nothing;
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-0000000000c1', 'role', 'authenticated')::text, true);
set local role authenticated;

-- What supabase-js sends for .upsert(row, { onConflict: "user_id,phone" }).
insert into public.zad_trusted_technicians (user_id, name, trade, phone, notes)
values ('00000000-0000-0000-0000-0000000000c1', 'عم محمد', 'plumber', '0100-123-4567', '')
on conflict (user_id, phone) do update set name = excluded.name, trade = excluded.trade, notes = excluded.notes;
-- The same number again from chat ⇒ the same row, corrected.
insert into public.zad_trusted_technicians (user_id, name, trade, phone, notes)
values ('00000000-0000-0000-0000-0000000000c1', 'محمد السباك', 'plumber', '0100-123-4567', 'شاطر في السخانات')
on conflict (user_id, phone) do update set name = excluded.name, trade = excluded.trade, notes = excluded.notes;

do $$
declare v_n int; v_name text; v_notes text;
begin
  select count(*), max(name), max(notes) into v_n, v_name, v_notes from public.zad_trusted_technicians;
  if v_n <> 1 or v_name <> 'محمد السباك' or v_notes <> 'شاطر في السخانات' then
    raise exception 'expected one corrected row, got % rows (% / %)', v_n, v_name, v_notes;
  end if;
  -- Arabic digits are converted before the write (latinDigits); the table itself refuses them.
  begin
    insert into public.zad_trusted_technicians (user_id, name, trade, phone)
    values ('00000000-0000-0000-0000-0000000000c1', 'حسن', 'electrician', '٠١٠٠١٢٣٤٥٦٧');
    raise exception 'Arabic digits were accepted by the table';
  exception when check_violation then null;
  end;
  raise notice 'technician_from_chat_test: all passed';
end $$;

rollback;
