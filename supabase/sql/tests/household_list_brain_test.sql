-- «هيخلص إمتى؟» and the Amazon matches see the household (20261011150000). Run after
-- household_list_brain_scaffold.sql and the migration; see the scaffold for the order.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- 1. dad already put milk on the household list: mom is not asked «أضيفه؟» about it
begin;
insert into zad_shopping_list (user_id, item_name) values ('00000000-0000-0000-0000-00000000f002', 'لبن');
select public._agent_predicted_shortage_for_user('00000000-0000-0000-0000-00000000f001');
do $$ begin
  assert not exists (select 1 from agent_tasks where kind = 'predicted_shortage'),
    'mom was asked about milk dad already listed: '
    || coalesce((select task_description from agent_tasks where kind = 'predicted_shortage' limit 1), '');
end $$;
rollback;

-- 2. nobody listed it: mom hears about it, and so does dad, though the milk is in mom's name
begin;
select public._agent_predicted_shortage_for_user('00000000-0000-0000-0000-00000000f001');
select public._agent_predicted_shortage_for_user('00000000-0000-0000-0000-00000000f002');
do $$ begin
  assert (select count(*) from agent_tasks where kind = 'predicted_shortage'
          and user_id = '00000000-0000-0000-0000-00000000f001' and task_description like '%«لبن»%') = 1,
    'mom was not told milk is running out';
  assert (select count(*) from agent_tasks where kind = 'predicted_shortage'
          and user_id = '00000000-0000-0000-0000-00000000f002' and task_description like '%«لبن»%') = 1,
    'dad was not told the household''s milk is running out';
end $$;
rollback;

-- 3. the neighbour's scan never sees the family's pantry
begin;
select public._agent_predicted_shortage_for_user('00000000-0000-0000-0000-00000000f003');
do $$ begin
  assert not exists (select 1 from agent_tasks where user_id = '00000000-0000-0000-0000-00000000f003'),
    'the neighbour was told about the family''s milk';
end $$;
rollback;

-- 4. Amazon: oil on dad's line is a need for mom's matches too; not for the neighbour
begin;
insert into zad_shopping_list (user_id, item_name) values ('00000000-0000-0000-0000-00000000f002', 'زيت');
do $$
declare v jsonb;
begin
  v := public.zad_affiliate_matches('00000000-0000-0000-0000-00000000f001');
  assert jsonb_array_length(v) = 1 and v -> 0 ->> 'matched_need' = 'زيت', 'mom''s matches: ' || v::text;
  v := public.zad_affiliate_matches('00000000-0000-0000-0000-00000000f003');
  assert jsonb_array_length(v) = 0, 'the neighbour''s matches: ' || v::text;
end $$;
rollback;

\echo household_list_brain_test: all checks passed
