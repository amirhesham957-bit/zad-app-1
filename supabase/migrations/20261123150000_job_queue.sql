-- م٥.٤: طابور مهام على pgmq ومُرسِل واحد، ومفاتيح وقف. مش متوصل لأي كرون لسه.
-- الطابوران: zad_jobs (عادي) و zad_jobs_critical (حرج، لوحده). كله service_role بس.
do $$ begin
  begin
    create extension if not exists pgmq;
  exception when others then
    raise notice 'pgmq extension unavailable: %', sqlerrm;
  end;
  if exists (select 1 from pg_extension where extname = 'pgmq') then
    if not exists (select 1 from pgmq.meta where queue_name = 'zad_jobs') then perform pgmq.create('zad_jobs'); end if;
    if not exists (select 1 from pgmq.meta where queue_name = 'zad_jobs_critical') then perform pgmq.create('zad_jobs_critical'); end if;
  end if;
end $$;

create table if not exists public.zad_kill_switches (
  key text primary key check (length(key) between 1 and 80),
  enabled boolean not null default true,
  reason text,
  updated_at timestamptz not null default now()
);
alter table public.zad_kill_switches enable row level security;
revoke all on public.zad_kill_switches from public, anon, authenticated;
grant select, insert, update on public.zad_kill_switches to service_role;

create or replace function public.zad_enqueue_job(p_queue text, p_payload jsonb, p_delay_s integer default 0)
returns bigint language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  if p_queue not in ('zad_jobs', 'zad_jobs_critical') then raise exception 'bad_queue'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then raise exception 'bad_payload'; end if;
  select msg_id into v_id from pgmq.send(p_queue, p_payload, greatest(coalesce(p_delay_s, 0), 0));
  return v_id;
end $$;

create or replace function public.zad_dequeue_jobs(p_queue text, p_vt_s integer default 60, p_qty integer default 10)
returns table (msg_id bigint, read_ct integer, enqueued_at timestamptz, payload jsonb)
language plpgsql security definer set search_path = public as $$
begin
  if p_queue not in ('zad_jobs', 'zad_jobs_critical') then raise exception 'bad_queue'; end if;
  return query select m.msg_id, m.read_ct, m.enqueued_at, m.message
    from pgmq.read(p_queue, greatest(coalesce(p_vt_s, 60), 1), least(greatest(coalesce(p_qty, 10), 1), 100)) m;
end $$;

create or replace function public.zad_ack_job(p_queue text, p_msg_id bigint)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if p_queue not in ('zad_jobs', 'zad_jobs_critical') then raise exception 'bad_queue'; end if;
  return pgmq.delete(p_queue, p_msg_id);
end $$;

create or replace function public.zad_set_kill_switch(p_key text, p_enabled boolean, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_key is null or btrim(p_key) = '' or length(p_key) > 80 then raise exception 'bad_key'; end if;
  if p_enabled is null then raise exception 'bad_enabled'; end if;
  insert into public.zad_kill_switches (key, enabled, reason, updated_at)
  values (btrim(p_key), p_enabled, left(p_reason, 300), now())
  on conflict (key) do update set enabled = excluded.enabled, reason = excluded.reason, updated_at = now();
end $$;

revoke all on function public.zad_enqueue_job(text, jsonb, integer) from public, anon, authenticated;
revoke all on function public.zad_dequeue_jobs(text, integer, integer) from public, anon, authenticated;
revoke all on function public.zad_ack_job(text, bigint) from public, anon, authenticated;
revoke all on function public.zad_set_kill_switch(text, boolean, text) from public, anon, authenticated;
grant execute on function public.zad_enqueue_job(text, jsonb, integer) to service_role;
grant execute on function public.zad_dequeue_jobs(text, integer, integer) to service_role;
grant execute on function public.zad_ack_job(text, bigint) to service_role;
grant execute on function public.zad_set_kill_switch(text, boolean, text) to service_role;
