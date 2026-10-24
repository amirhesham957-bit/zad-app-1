-- حالة البيت (ZAD_PLAN ٣.١): صف واحد لكل بيت.
--
-- الفلوس (المتاح، الأيام الباقية، الخطر، الالتزام الجاي)، اللي هيخلص، الجرعات الجاية والدوا اللي قرّب يخلص،
-- المواعيد والتجديدات الجاية، المكان التقريبي (في بلده ولا مسافر — من غير إحداثيات)، الموسم، الظرف،
-- وآخر حاجة اتقالت للعميل. zad-brain بيحسبها من اللقطة نفسها (homeState.ts) — نفس الأرقام اللي العقل
-- بيقراها، مش معادلات موازية هنا في SQL.
--
-- «بيتحسب لما حاجة تتغير»:
--   • zad_home_state_touch — تريجر على جداول البيت بيعلّم الصف dirty_at = now() (والمخزن والقايمة
--     المشتركين بيعلّموا كل أفراد العيلة). عمره ما يوقف الكتابة الأصلية: أي خطأ = warning بس.
--   • zad_home_states_due — اللي dirty بعد آخر حساب، أو أقدم من ٦ ساعات (الجرعة الجاية بتتحرك مع الوقت)
--     لبيت اتغير فيه حاجة آخر ٣٠ يوم، أو بإصدار قديم.
--   • كرون home-state-refresh كل ٥ دقايق بينادي zad-brain بس لو فيه صف مستحق.
--   • وأي لقطة بتتبني (شات، تحليل يومي، مبادرة) بتحفظ الحالة كمان.
-- العميل بيقرا صفه بس (RLS)، ومحدش بيكتب غير السيرفر.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

create table if not exists public.zad_home_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  version int not null default 0,
  computed_at timestamptz,
  dirty_at timestamptz not null default now()
);

comment on table public.zad_home_state is
  'ZAD_PLAN 3.1 — one row per home: money, running out, doses, upcoming, place, season, circumstance, last said. Written by zad-brain (homeState.ts) from the snapshot; dirty_at set by zad_home_state_touch.';

alter table public.zad_home_state enable row level security;
drop policy if exists home_state_read_own on public.zad_home_state;
create policy home_state_read_own on public.zad_home_state for select using ((select auth.uid()) = user_id);
revoke all on public.zad_home_state from anon, authenticated;
grant select on public.zad_home_state to authenticated;
grant all on public.zad_home_state to service_role;

-- أعمدة zad_users اللي بتغيّر الحالة. الموقع (last_lat/last_lon) مش منهم — بيتحدث كتير ومش جوه الحالة.
create or replace function public.zad_home_state_touch()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_row jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  v_user uuid;
  v_family uuid;
  k text;
  v_changed boolean := false;
begin
  begin
    if tg_table_name = 'zad_users' then
      if tg_op = 'UPDATE' then
        foreach k in array array['monthly_limit', 'budget', 'cycle_start_day', 'cycle_anchor', 'currency', 'country',
                                 'travel_country', 'travel_since', 'balance_anchored_at'] loop
          if (to_jsonb(old) -> k) is distinct from (to_jsonb(new) -> k) then v_changed := true; end if;
        end loop;
        if not v_changed then return null; end if;
      end if;
      v_user := (v_row ->> 'id')::uuid;
    else
      v_user := nullif(v_row ->> 'user_id', '')::uuid;
      v_family := nullif(v_row ->> 'family_id', '')::uuid;
    end if;

    insert into public.zad_home_state (user_id, dirty_at)
    select x.u, now()
      from (
        select v_user as u
        union
        select fm.user_id from public.family_members fm where v_family is not null and fm.family_id = v_family
      ) x
     where x.u is not null and exists (select 1 from auth.users au where au.id = x.u)
    on conflict (user_id) do update set dirty_at = excluded.dirty_at;
  exception when others then
    raise warning 'zad_home_state_touch on %: %', tg_table_name, sqlerrm;
  end;
  return null;
end;
$$;

revoke all on function public.zad_home_state_touch() from public, anon, authenticated;

-- جداول البيت. اللي مش موجود (قاعدة سكراتش) بيتخطى.
do $$
declare
  t text;
begin
  foreach t in array array['zad_transactions', 'zad_inventory', 'zad_shopping_list', 'zad_consumption',
                           'zad_pharmacy_items', 'zad_pharmacy_doses', 'zad_appointments', 'zad_life_circumstances',
                           'zad_subscriptions', 'zad_obligations', 'zad_users'] loop
    if to_regclass('public.' || t) is null then
      continue;
    end if;
    execute format('drop trigger if exists zad_home_state_touch on public.%I', t);
    execute format('create trigger zad_home_state_touch after insert or update or delete on public.%I '
                   'for each row execute function public.zad_home_state_touch()', t);
  end loop;
end
$$;

-- [p_version] = HOME_STATE_VERSION في homeState.ts؛ null (الكرون) = من غير شرط الإصدار.
create or replace function public.zad_home_states_due(p_version int default null, p_limit int default 10)
returns table (user_id uuid)
language sql
stable
security definer
set search_path to 'public'
as $$
  select h.user_id
    from public.zad_home_state h
   where h.computed_at is null
      or h.dirty_at > h.computed_at
      or (p_version is not null and h.version is distinct from p_version)
      or (h.computed_at < now() - interval '6 hours' and h.dirty_at > now() - interval '30 days')
   order by h.dirty_at desc
   limit greatest(least(coalesce(p_limit, 10), 50), 1);
$$;

revoke all on function public.zad_home_states_due(int, int) from public, anon, authenticated;
grant execute on function public.zad_home_states_due(int, int) to service_role;

-- كل بيت عنده حساب بياخد صف من أول يوم، عشان الكرون يحسبه.
insert into public.zad_home_state (user_id) select id from auth.users on conflict (user_id) do nothing;

do $cron$
begin
  if to_regnamespace('cron') is null or to_regprocedure('public.zad_cron_secret(text)') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  if coalesce(length(public.zad_cron_secret('zad_agent_tasks_cron_secret')), 0) = 0 then
    raise warning 'zad_agent_tasks_cron_secret missing from vault — home-state-refresh not scheduled';
    return;
  end if;
  perform cron.schedule(
    'home-state-refresh',
    '*/5 * * * *',
    $job$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'X-Agent-Tasks-Cron-Secret', public.zad_cron_secret('zad_agent_tasks_cron_secret')
        ),
        body := '{"action":"refresh_home_state"}'::jsonb,
        timeout_milliseconds := 55000
      ) as request_id
    where exists (select 1 from public.zad_home_states_due(null, 1));
    $job$
  );
end
$cron$;
