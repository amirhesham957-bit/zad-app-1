-- P0.3 تسوية الطاقة. zad-core-intelligence بيخصم محاولة (zad_entitlement_consume) قبل الأكشن،
-- وبيرجّعها لو الأكشن رجع فاضي. لو الفنكشن مات في النص (timeout، crash)، أو الرجوع نفسه فشل
-- (console.error وبس)، العميل كان بيخسر المحاولة ومفيش حاجة بترجعها.
--
-- دفتر: كل خصم فعلي (reason='quota') بيتسجّل 'open'، وبعد الأكشن بيتقفل:
--   done     الأكشن رجع نتيجة، الخصم صح.
--   refunded اتّرجع (من الفنكشن أو من الكرون). الانتقال open -> refunded ورجوع المحاولة في نفس
--            الترانزاكشن، فمايرجعش مرتين، ولو الرجوع فشل الصف يفضل open والكرون يعيد.
-- الكرون كل ٥ دقايق بيرجّع أي 'open' أقدم من ١٠ دقايق.

create table if not exists public.zad_energy_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  kind text not null check (kind in ('brain', 'scan', 'chat', 'voice')),
  status text not null default 'open' check (status in ('open', 'done', 'refunded')),
  charged_at timestamptz not null default now(),
  settled_at timestamptz,
  settled_by text check (settled_by in ('function', 'cron'))
);
create index if not exists zad_energy_ledger_open_idx on public.zad_energy_ledger (charged_at) where status = 'open';
alter table public.zad_energy_ledger enable row level security;
revoke all on table public.zad_energy_ledger from public, anon, authenticated;
grant all on table public.zad_energy_ledger to service_role;

create or replace function public.zad_energy_open(p_user uuid, p_kind text)
returns uuid
language sql
security definer
set search_path to 'public'
as $$
  insert into public.zad_energy_ledger (user_id, kind) values (p_user, p_kind) returning id;
$$;

create or replace function public.zad_energy_done(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare n int;
begin
  update public.zad_energy_ledger set status = 'done', settled_at = now(), settled_by = 'function'
   where id = p_id and status = 'open';
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

-- يرجّع المحاولة مرة واحدة بس: الصف لازم يكون 'open'. أي خطأ في الرجوع بيلغي التغيير كله.
create or replace function public.zad_energy_refund(p_id uuid, p_by text default 'function')
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare r public.zad_energy_ledger;
begin
  update public.zad_energy_ledger set status = 'refunded', settled_at = now(),
         settled_by = case when p_by = 'cron' then 'cron' else 'function' end
   where id = p_id and status = 'open'
  returning * into r;
  if r.id is null then return false; end if;
  perform public.zad_entitlement_refund(r.user_id, r.kind);
  return true;
end;
$$;

-- الكرون: كل خصم من غير نتيجة أكتر من p_older بيرجع. صف بيفشل مايوقفش الباقي.
create or replace function public.zad_energy_settle(p_older interval default interval '10 minutes')
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare r record; n int := 0;
begin
  for r in
    select id from public.zad_energy_ledger
     where status = 'open' and charged_at < now() - p_older
     order by charged_at limit 500
     for update skip locked
  loop
    begin
      if public.zad_energy_refund(r.id, 'cron') then n := n + 1; end if;
    exception when others then
      raise warning 'zad_energy_settle: % failed: %', r.id, sqlerrm;
    end;
  end loop;
  return n;
end;
$$;

revoke all on function public.zad_energy_open(uuid, text) from public, anon, authenticated;
revoke all on function public.zad_energy_done(uuid) from public, anon, authenticated;
revoke all on function public.zad_energy_refund(uuid, text) from public, anon, authenticated;
revoke all on function public.zad_energy_settle(interval) from public, anon, authenticated;
grant execute on function public.zad_energy_open(uuid, text) to service_role;
grant execute on function public.zad_energy_done(uuid) to service_role;
grant execute on function public.zad_energy_refund(uuid, text) to service_role;
grant execute on function public.zad_energy_settle(interval) to service_role;

do $$ begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule('energy-settle-5min') where exists (select 1 from cron.job where jobname = 'energy-settle-5min');
    perform cron.schedule('energy-settle-5min', '*/5 * * * *', 'select public.zad_energy_settle()');
  end if;
end $$;
