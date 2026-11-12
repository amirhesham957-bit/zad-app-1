-- «بلّغ عن الرد» (migration 20261113040000, ZAD_PLAN 8.3), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261113040000_reply_reports.sql
--   psql < supabase/sql/tests/reply_reports_test.sql
--
-- Raises on the first failed check.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
create or replace function pg_temp.as_user(id text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', id, 'role', 'authenticated')::text, false) $$;

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1')
  on conflict do nothing;

create temp table s (k text primary key, v jsonb);
grant all on s to authenticated;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
set role authenticated;
insert into s values ('first', zad_report_reply('m1', '  رد مسيء  ', 'offensive'));
insert into s values ('again', zad_report_reply('m1', 'رد مسيء', 'wrong'));
insert into s values ('bad_reason', zad_report_reply('m2', 'نص', 'spam'));
insert into s values ('empty', zad_report_reply('m3', '   ', 'other'));
-- The table itself is closed to the customer: no read, no direct write.
do $$ begin
  perform 1 from public.zad_reply_reports;
  raise exception 'FAIL: the customer could read zad_reply_reports';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  insert into public.zad_reply_reports (user_id, message_id, reply_text, reason)
  values ('00000000-0000-0000-0000-0000000000b1', 'x', 'x', 'other');
  raise exception 'FAIL: the customer could write zad_reply_reports for someone else';
exception when insufficient_privilege then null;
end $$;
reset role;

select pg_temp.check((select v ->> 'ok' from s where k = 'first') = 'true', 'a report is accepted');
select pg_temp.check((select count(*) from zad_reply_reports) = 1, 'reporting the same reply again keeps one row');
select pg_temp.check((select reason from zad_reply_reports where message_id = 'm1') = 'wrong', 'the second report changes the reason');
select pg_temp.check((select reply_text from zad_reply_reports where message_id = 'm1') = 'رد مسيء', 'the text is trimmed');
select pg_temp.check((select user_id::text from zad_reply_reports where message_id = 'm1') = '00000000-0000-0000-0000-0000000000a1',
  'the reporter is auth.uid()');
select pg_temp.check((select v ->> 'reason' from s where k = 'bad_reason') = 'invalid', 'an unknown reason is refused');
select pg_temp.check((select v ->> 'reason' from s where k = 'empty') = 'invalid', 'an empty reply is refused');

-- Signed out: nothing is written.
select set_config('request.jwt.claims', '{"role": "anon"}', false);
select pg_temp.check((zad_report_reply('m9', 'نص', 'other') ->> 'reason') = 'signed_out', 'signed out is refused');

-- The daily ceiling.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
set role authenticated;
select zad_report_reply('n' || g, 'نص', 'other') from generate_series(1, 50) g;
insert into s values ('ceiling', zad_report_reply('n51', 'نص', 'other'));
reset role;
select pg_temp.check((select v ->> 'reason' from s where k = 'ceiling') = 'too_many', 'the 51st report in a day is refused');
select pg_temp.check((select count(*) from zad_reply_reports where user_id = '00000000-0000-0000-0000-0000000000b1') = 50,
  'fifty were kept');
