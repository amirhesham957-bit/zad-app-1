-- P3.4: per-round model trace + a circuit breaker for the model engines, both in Postgres so
-- every edge instance sees the same state (the old breaker was per-isolate memory).
--
-- zad_round_trace: one row per model round (engine, when, how long, how it ended). Outcome starts
-- as accepted/error from the engine call itself; zad_round_mark later moves a round to
-- edited/reverted when the user changes or undoes what it did.
-- zad_engine_breaker: one row per engine key ("gemini:<model>", "groq:<model>").
-- Only the service role touches either table, and only through the functions below.
-- Idempotent.

create table if not exists public.zad_round_trace (
  id bigserial primary key,
  trace_id text,
  engine text not null check (length(engine) between 1 and 120),
  started_at timestamptz not null default now(),
  duration_ms integer not null default 0 check (duration_ms >= 0),
  outcome text not null check (outcome in ('accepted', 'edited', 'reverted', 'error')),
  error text,
  created_at timestamptz not null default now()
);
create index if not exists zad_round_trace_trace_idx on public.zad_round_trace (trace_id) where trace_id is not null;
create index if not exists zad_round_trace_started_idx on public.zad_round_trace (started_at);

create table if not exists public.zad_engine_breaker (
  engine text primary key check (length(engine) between 1 and 120),
  consecutive_failures integer not null default 0 check (consecutive_failures >= 0),
  opened_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.zad_round_trace enable row level security;
alter table public.zad_engine_breaker enable row level security;
revoke all on public.zad_round_trace from public, anon, authenticated;
revoke all on public.zad_engine_breaker from public, anon, authenticated;
revoke all on sequence public.zad_round_trace_id_seq from public, anon, authenticated;

-- Records one engine call: a trace row, and the breaker move (ok closes it, a failure counts;
-- p_threshold failures in a row opens it, and a failed half-open probe re-opens it).
-- Returns the breaker state after the call: closed | open.
create or replace function public.zad_engine_record_result(
  p_engine text,
  p_trace_id text,
  p_started_at timestamptz,
  p_duration_ms integer,
  p_ok boolean,
  p_error text default null,
  p_threshold integer default 3
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_opened timestamptz;
begin
  insert into public.zad_round_trace (trace_id, engine, started_at, duration_ms, outcome, error)
  values (p_trace_id, p_engine, coalesce(p_started_at, now()), greatest(coalesce(p_duration_ms, 0), 0),
          case when p_ok then 'accepted' else 'error' end, left(p_error, 300));

  -- Old rounds are of no use; trim now and then, not on every call.
  if random() < 0.01 then
    delete from public.zad_round_trace where started_at < now() - interval '30 days';
  end if;

  if p_ok then
    insert into public.zad_engine_breaker as b (engine, consecutive_failures, opened_at, updated_at)
    values (p_engine, 0, null, now())
    on conflict (engine) do update set consecutive_failures = 0, opened_at = null, updated_at = now();
    return 'closed';
  end if;

  insert into public.zad_engine_breaker as b (engine, consecutive_failures, opened_at, updated_at)
  values (p_engine, 1, case when 1 >= greatest(p_threshold, 1) then now() end, now())
  on conflict (engine) do update set
    consecutive_failures = b.consecutive_failures + 1,
    opened_at = case when b.consecutive_failures + 1 >= greatest(p_threshold, 1) then now() else b.opened_at end,
    updated_at = now()
  returning opened_at into v_opened;

  return case when v_opened is null then 'closed' else 'open' end;
end;
$$;

-- Answers the state of each open engine in one call: {"engine": "open|half_open"}; closed engines
-- are absent. open = inside the cooldown. After the cooldown the first caller gets half_open (one
-- probe) and the cooldown restarts, so the others still see open until that probe records its result.
create or replace function public.zad_engine_is_open(p_engines text[], p_cooldown_s integer default 300)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_out jsonb := '{}'::jsonb;
  r record;
begin
  for r in
    select b.engine, b.opened_at from public.zad_engine_breaker b
    where b.engine = any(p_engines) and b.opened_at is not null
    for update
  loop
    if r.opened_at + make_interval(secs => greatest(p_cooldown_s, 0)) > now() then
      v_out := v_out || jsonb_build_object(r.engine, 'open');
    else
      update public.zad_engine_breaker set opened_at = now(), updated_at = now() where engine = r.engine;
      v_out := v_out || jsonb_build_object(r.engine, 'half_open');
    end if;
  end loop;
  return v_out;
end;
$$;

-- The user edited or undid what the round did: move that trace's accepted rounds to p_outcome.
-- Returns how many rows changed.
create or replace function public.zad_round_mark(p_trace_id text, p_outcome text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n integer;
begin
  if p_outcome not in ('edited', 'reverted') or p_trace_id is null then
    return 0;
  end if;
  update public.zad_round_trace set outcome = p_outcome
  where trace_id = p_trace_id and outcome = 'accepted';
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke all on function public.zad_engine_record_result(text, text, timestamptz, integer, boolean, text, integer) from public, anon, authenticated;
revoke all on function public.zad_engine_is_open(text[], integer) from public, anon, authenticated;
revoke all on function public.zad_round_mark(text, text) from public, anon, authenticated;
grant execute on function public.zad_engine_record_result(text, text, timestamptz, integer, boolean, text, integer) to service_role;
grant execute on function public.zad_engine_is_open(text[], integer) to service_role;
grant execute on function public.zad_round_mark(text, text) to service_role;
