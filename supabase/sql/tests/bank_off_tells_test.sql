-- zad_bank_off_tells (migration 20261107181900): the phone's bank.off / bank.stalled becomes one listener_gap_alert a
-- day, any other event does nothing, and a second one the same day neither duplicates nor breaks the event insert.
--   scratch_scaffold.sql, bank_off_tells_scaffold.sql, the migration, then this file.
\set ON_ERROR_STOP on

create function pg_temp.check(ok boolean, what text) returns void language plpgsql as $$
begin if not coalesce(ok, false) then raise exception 'FAILED: %', what; end if; raise notice 'ok: %', what; end $$;

insert into public.zad_product_events (user_id, name) values ('00000000-0000-0000-0000-0000000000a1', 'bank.flowing');
select pg_temp.check((select count(*) from public.agent_tasks) = 0, 'bank.flowing says nothing');

insert into public.zad_product_events (user_id, name) values ('00000000-0000-0000-0000-0000000000a1', 'bank.stalled');
select pg_temp.check((select count(*) from public.agent_tasks where kind = 'listener_gap_alert') = 1, 'bank.stalled queues one alert');
select pg_temp.check((select task_description like '%١٢ ساعة%' from public.agent_tasks limit 1), 'the stalled wording');

insert into public.zad_product_events (user_id, name) values ('00000000-0000-0000-0000-0000000000a1', 'bank.off');
select pg_temp.check((select count(*) from public.agent_tasks) = 1, 'a second one the same day is not queued');
select pg_temp.check((select count(*) from public.zad_product_events where name = 'bank.off') = 1, 'and the event itself is still recorded');

insert into public.zad_product_events (user_id, name) values ('00000000-0000-0000-0000-0000000000b2', 'bank.off');
select pg_temp.check((select task_description like '%اتشالت%' from public.agent_tasks where user_id = '00000000-0000-0000-0000-0000000000b2'), 'bank.off: the permission wording, for another customer');
select pg_temp.check(not exists (select 1 from public.agent_tasks where task_description ~ '\d{4}'), 'no account or card digits in the text');
