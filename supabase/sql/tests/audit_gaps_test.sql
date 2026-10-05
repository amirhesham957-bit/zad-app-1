-- The audit migration (20261005233809, docs/agent/ZAD_LIVING_BRAIN.md §11) — see audit_gaps_scaffold.sql for how to run it.
-- Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
\set QUIET 1
create temp table u as select '00000000-0000-0000-0000-0000000000a1'::uuid as id;
\set QUIET 0

-- 1. One name per category: the backfill folded the two vocabularies; the unknown stays, trimmed; null stays null.
select pg_temp.check((select count(*) from zad_transactions where category = 'البقالة') = 2, 'بقالة and البقالة are one');
select pg_temp.check((select category from zad_transactions where amount = 900) = 'الفواتير', 'فواتير became الفواتير');
select pg_temp.check((select category from zad_transactions where amount = 250) = 'الرعاية الصحية', 'صحة became الرعاية الصحية');
select pg_temp.check((select category from zad_transactions where amount = 300) = 'أخرى', 'عام became أخرى');
select pg_temp.check((select category from zad_transactions where amount = 1500) = 'شهر', 'a trailing space is trimmed, the word kept');
select pg_temp.check((select category from zad_transactions where amount = 40) = 'هدايا', 'an unknown category is not guessed');
select pg_temp.check((select category is null from zad_transactions where amount = 70), 'null is not invented into a category');

-- 2. Every later write goes through the same name, from any writer.
insert into zad_transactions (user_id, amount, category) values ((select id from u), 12, 'بقاله');
update zad_transactions set category = ' مطاعم ' where amount = 40;
select pg_temp.check((select category from zad_transactions where amount = 12) = 'البقالة', 'a new row is canonical');
select pg_temp.check((select category from zad_transactions where amount = 40) = 'المطاعم', 'an edited row is canonical');

-- 3. The weekly digest is weekly: one in the last 6 days holds the next.
insert into agent_tasks (user_id, kind, task_description, created_at) values ((select id from u), 'home_weekly_digest', 'old', now() - interval '2 days');
select public._agent_home_weekly_digest_for_user((select id from u));
select pg_temp.check((select count(*) from agent_tasks where kind = 'home_weekly_digest') = 1, 'no second digest within 6 days');
update agent_tasks set created_at = now() - interval '7 days' where kind = 'home_weekly_digest';
select public._agent_home_weekly_digest_for_user((select id from u));
select pg_temp.check((select count(*) from agent_tasks where kind = 'home_weekly_digest') = 2, 'a week later it comes');

-- 4. A renewal that passed last month is reminded this month; an unpaid one from yesterday still is.
insert into zad_subscriptions (user_id, title, amount, renewal_date) values
  ((select id from u), 'نتفليكس', 200, to_char(current_date - interval '1 month' + interval '2 days', 'YYYY-MM-DD')),
  ((select id from u), 'نت', 300, to_char(current_date - 1, 'YYYY-MM-DD')),
  ((select id from u), 'بعيد', 50, to_char(current_date + 20, 'YYYY-MM-DD'));
select public._agent_bill_reminder_for_user((select id from u));
select pg_temp.check((select task_description from agent_tasks where kind = 'bill_reminder') like '%نتفليكس%', 'last month''s date is this month''s reminder');
select pg_temp.check((select task_description from agent_tasks where kind = 'bill_reminder') like '%"نت"%', 'yesterday''s unpaid bill is still reminded');
select pg_temp.check((select task_description from agent_tasks where kind = 'bill_reminder') not like '%بعيد%', 'one 20 days out is not');
select pg_temp.check((select bool_and(e ->> 'due' >= to_char(current_date - 2, 'YYYY-MM-DD'))
  from agent_tasks, jsonb_array_elements(task_description::jsonb) e where kind = 'bill_reminder'), 'the dates said are the coming ones, not the old ones');

-- 5. The brain's observations see the coming renewal too.
select pg_temp.check((select jsonb_path_exists(public.zad_domain_observations((select id from u)), '$[*] ? (@.title == "نتفليكس")')),
  'observations know the subscription renews in two days');
