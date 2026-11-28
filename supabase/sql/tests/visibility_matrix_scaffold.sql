-- On top of scratch_scaffold.sql + view_rpcs_scaffold.sql: what the visibility matrix (20261128190000) reads that those two lack.
-- zad_inventory.family_id with the live family-scoped policy, agent_tasks (live shape, owner read), RLS on agent_goals and the
-- doses table, and zad_obligations (a second budget table, so the minor policy is checked on more than one).
-- Scratch only.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

alter table public.zad_inventory add column if not exists family_id uuid;
drop policy if exists own_rows on public.zad_inventory;
create policy zad_inventory_select on public.zad_inventory for select
  using ((family_id is null and auth.uid() = user_id) or (family_id is not null and family_id in (select public.get_my_family_ids())));

create table public.agent_tasks (id uuid primary key default gen_random_uuid(), user_id uuid not null, task_description text, status text not null default 'pending');
alter table public.agent_tasks enable row level security;
create policy user_reads_own_agent_tasks on public.agent_tasks for select using (auth.uid() = user_id);

drop policy if exists own_rows on public.agent_goals;
create policy user_crud_own_agent_goals on public.agent_goals for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

alter table public.zad_pharmacy_doses enable row level security;
create policy user_own_doses on public.zad_pharmacy_doses for all using ((select auth.uid()) = user_id);

create table public.zad_obligations (id uuid primary key default gen_random_uuid(), user_id uuid not null, amount numeric);
alter table public.zad_obligations enable row level security;
create policy own_rows on public.zad_obligations for select to authenticated using (user_id = (select auth.uid()));
