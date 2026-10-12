-- حارة المجاني وحارس العميل (خطة الدخل ٢٠٢٦-١٠-١١، «سيطرة الحشد»). zad-brain/freeLane.ts
-- هو اللي بيقرر؛ هنا العدّادات بس، ذرّية عشان نداءين في نفس اللحظة مايعدّوش نفس الخانة.
--
--   * zad_free_load: لفات المجاني في اليوم (UTC) على المشروع كله. بعد ZAD_FREE_DAILY_BUDGET
--     لفة، المجاني بيروح لجروك والمشتركين مابيتأثروش.
--   * zad_turn_gate: لكل عميل — لفة واحدة في نفس الوقت (قفل بيخلص لوحده بعد ٤٥ ث لو
--     الفنكشن وقعت قبل ما تفكه)، وحد في الدقيقة.
--
-- service_role بس (zad-brain). مفيش ولا policy للعميل.

create table if not exists public.zad_free_load (
  day date primary key,
  turns int not null default 0
);
alter table public.zad_free_load enable row level security;
revoke all on public.zad_free_load from anon, authenticated;

create table if not exists public.zad_turn_gate (
  user_id uuid primary key references auth.users(id) on delete cascade,
  busy_until timestamptz,
  window_start timestamptz not null default now(),
  window_count int not null default 0
);
alter table public.zad_turn_gate enable row level security;
revoke all on public.zad_turn_gate from anon, authenticated;

-- One more free turn today; returns today's count including it.
create or replace function public.zad_free_load_take()
returns int language sql security definer set search_path = public as $$
  insert into public.zad_free_load (day, turns) values ((now() at time zone 'utc')::date, 1)
  on conflict (day) do update set turns = public.zad_free_load.turns + 1
  returning turns
$$;

-- Starts a turn for p_user: refused while another of theirs is running ('busy'), or past
-- p_per_minute turns in the current minute ('too_fast'). A refused turn takes nothing.
create or replace function public.zad_turn_begin(p_user uuid, p_per_minute int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  g public.zad_turn_gate;
begin
  if p_user is null then return jsonb_build_object('ok', true); end if;
  insert into public.zad_turn_gate (user_id) values (p_user) on conflict (user_id) do nothing;
  select * into g from public.zad_turn_gate where user_id = p_user for update;
  if g.busy_until is not null and g.busy_until > now() then
    return jsonb_build_object('ok', false, 'reason', 'busy');
  end if;
  if g.window_start > now() - interval '1 minute' and g.window_count >= greatest(p_per_minute, 1) then
    return jsonb_build_object('ok', false, 'reason', 'too_fast');
  end if;
  update public.zad_turn_gate set
    busy_until = now() + interval '45 seconds',
    window_start = case when window_start > now() - interval '1 minute' then window_start else now() end,
    window_count = case when window_start > now() - interval '1 minute' then window_count + 1 else 1 end
  where user_id = p_user;
  return jsonb_build_object('ok', true);
end;
$$;

-- The turn ended (answered or failed): the next one may start.
create or replace function public.zad_turn_end(p_user uuid)
returns void language sql security definer set search_path = public as $$
  update public.zad_turn_gate set busy_until = null where user_id = p_user
$$;

revoke execute on function public.zad_free_load_take() from public, anon, authenticated;
revoke execute on function public.zad_turn_begin(uuid, int) from public, anon, authenticated;
revoke execute on function public.zad_turn_end(uuid) from public, anon, authenticated;
grant execute on function public.zad_free_load_take() to service_role;
grant execute on function public.zad_turn_begin(uuid, int) to service_role;
grant execute on function public.zad_turn_end(uuid) to service_role;
