-- ZAD_PLAN ١.١١ — what the customer does in the app, by name and time only (2026-10-19).
--
-- Every gate of the plan that speaks of coming back («the customer returns after a week», D1/D7,
-- which features are used at all) had no number: nothing recorded that the app was opened. This
-- table is that record. It holds a short event name and a time, never content: no amounts, no
-- text, no screen data. The app writes its own rows (RLS: insert as yourself, never read); the
-- server reads them through zad_product_retention, which service_role alone may call.

create table if not exists public.zad_product_events (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (name ~ '^[a-z][a-z0-9_.-]{1,47}$'),
  at timestamptz not null default now()
);

create index if not exists zad_product_events_user_at on public.zad_product_events (user_id, at desc);
create index if not exists zad_product_events_name_at on public.zad_product_events (name, at desc);

alter table public.zad_product_events enable row level security;

drop policy if exists "product events: insert own" on public.zad_product_events;
create policy "product events: insert own" on public.zad_product_events
  for insert to authenticated
  with check (user_id = auth.uid());

revoke all on public.zad_product_events from anon;
grant insert on public.zad_product_events to authenticated;

-- Retention for the plan's gates. Cohort = the day of a customer's first event; a customer
-- «returned on day N» if any event falls on that calendar day after the first (UTC).
create or replace function public.zad_product_retention(p_days integer default 60)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with first_seen as (
    select user_id, min(at)::date as d0
    from public.zad_product_events
    where at > now() - make_interval(days => p_days)
    group by user_id
  ),
  days as (
    select distinct e.user_id, e.at::date as d
    from public.zad_product_events e
    join first_seen f using (user_id)
  ),
  per_user as (
    select f.user_id, f.d0,
           exists (select 1 from days x where x.user_id = f.user_id and x.d = f.d0 + 1) as d1,
           exists (select 1 from days x where x.user_id = f.user_id and x.d between f.d0 + 7 and f.d0 + 13) as w1
    from first_seen f
  )
  select jsonb_build_object(
    'active_today', (select count(distinct user_id) from public.zad_product_events where at::date = current_date),
    'active_7d', (select count(distinct user_id) from public.zad_product_events where at > now() - interval '7 days'),
    'active_30d', (select count(distinct user_id) from public.zad_product_events where at > now() - interval '30 days'),
    'cohort_d1', (select count(*) from per_user where d0 <= current_date - 1),
    'returned_d1', (select count(*) from per_user where d0 <= current_date - 1 and d1),
    'cohort_week', (select count(*) from per_user where d0 <= current_date - 13),
    'returned_week2', (select count(*) from per_user where d0 <= current_date - 13 and w1),
    'top_events_7d', (
      select coalesce(jsonb_object_agg(name, n), '{}'::jsonb) from (
        select name, count(*) as n from public.zad_product_events
        where at > now() - interval '7 days' group by name order by n desc limit 20
      ) t
    )
  );
$$;

revoke all on function public.zad_product_retention(integer) from public, anon, authenticated;
grant execute on function public.zad_product_retention(integer) to service_role;

create or replace function public.zad_prune_product_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n integer;
begin
  delete from public.zad_product_events where at < now() - interval '400 days';
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke all on function public.zad_prune_product_events() from public, anon, authenticated;
grant execute on function public.zad_prune_product_events() to service_role;

select cron.unschedule('product-events-retention')
where exists (select 1 from cron.job where jobname = 'product-events-retention');

select cron.schedule('product-events-retention', '47 2 * * *', $$ select public.zad_prune_product_events(); $$);
