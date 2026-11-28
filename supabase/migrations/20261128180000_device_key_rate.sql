-- Device send keys may now call the three place actions (store_arrival,
-- place_event, commute_summary) from the headless engine with no user JWT.
-- A leaked key must not be a free pipe into the model/push path, so zad-brain
-- counts place calls per key per hour and answers 429 past the limit.
--
-- Fixed hourly window, one row per (key, hour). The rows go with the key
-- (on delete cascade). Only the service role touches it, through the function.
-- Idempotent.

create table if not exists public.zad_device_key_rate (
  key_hash text not null references public.zad_device_send_keys (key_hash) on delete cascade,
  hour_start timestamptz not null,
  calls integer not null default 0 check (calls >= 0),
  primary key (key_hash, hour_start)
);

alter table public.zad_device_key_rate enable row level security;
revoke all on public.zad_device_key_rate from public, anon, authenticated;

-- Counts one call. Returns true when it is within p_limit for the current hour,
-- false when the key is over it (the call is still counted, so hammering stays blocked).
create or replace function public.zad_device_key_hit(p_key_hash text, p_limit integer default 60)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hour timestamptz := date_trunc('hour', now());
  v_calls integer;
begin
  insert into public.zad_device_key_rate as r (key_hash, hour_start, calls)
  values (p_key_hash, v_hour, 1)
  on conflict (key_hash, hour_start) do update set calls = r.calls + 1
  returning r.calls into v_calls;

  -- Old windows are of no use; keep the table tiny.
  delete from public.zad_device_key_rate
  where key_hash = p_key_hash and hour_start < v_hour - interval '2 hours';

  return v_calls <= p_limit;
end;
$$;

revoke all on function public.zad_device_key_hit(text, integer) from public, anon, authenticated;
grant execute on function public.zad_device_key_hit(text, integer) to service_role;
