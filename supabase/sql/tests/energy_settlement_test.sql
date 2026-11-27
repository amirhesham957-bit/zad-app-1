-- P0.3 تسوية الطاقة (20261127121500_energy_settlement). Scratch only.
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261127121500_energy_settlement.sql   (مرتين: لازم يعدّي من غير خطأ، idempotent)
--   psql < supabase/sql/tests/energy_settlement_test.sql
-- zad_entitlement_refund هنا بديل بسيط (scan_left + 1): اللي بيتختبر هو التسوية مش جدول الباقات.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create table public.zad_entitlements (user_id uuid primary key, scan_left int not null default 0, voice_left int not null default 0);
create or replace function public.zad_entitlement_refund(p_user uuid, p_kind text) returns void language plpgsql as $$
begin
  if current_setting('zad.fail_refund', true) = '1' then raise exception 'refund down'; end if;
  if p_kind = 'scan' then update public.zad_entitlements set scan_left = scan_left + 1 where user_id = p_user;
  else update public.zad_entitlements set voice_left = voice_left + 1 where user_id = p_user; end if;
end $$;


do $$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid(); d uuid := gen_random_uuid();
  la uuid; lb uuid; lc uuid; ld uuid; le uuid; n int;
begin
  insert into public.zad_entitlements (user_id, scan_left) values (a, 1), (b, 1), (c, 1), (d, 1);

  -- لا حد غير الخدمة يلمس الدفتر
  assert not has_function_privilege('authenticated', 'public.zad_energy_settle(interval)', 'execute'), 'customers settle';
  assert not has_function_privilege('anon', 'public.zad_energy_refund(uuid,text)', 'execute'), 'anon refunds';
  assert not has_table_privilege('authenticated', 'public.zad_energy_ledger', 'select'), 'customers read ledger';
  assert has_function_privilege('service_role', 'public.zad_energy_settle(interval)', 'execute'), 'service cannot settle';

  -- a: خصم من غير نتيجة، عمره ١١ دقيقة: الكرون يرجّعه
  la := public.zad_energy_open(a, 'scan');
  update public.zad_entitlements set scan_left = scan_left - 1 where user_id = a;
  update public.zad_energy_ledger set charged_at = now() - interval '11 minutes' where id = la;
  -- b: خصم عمره ٣ دقايق: الكرون مايلمسوش
  lb := public.zad_energy_open(b, 'scan');
  update public.zad_entitlements set scan_left = scan_left - 1 where user_id = b;
  update public.zad_energy_ledger set charged_at = now() - interval '3 minutes' where id = lb;
  -- c: الأكشن نجح وقفل done، عمره ٢٠ دقيقة: الكرون مايرجّعوش
  lc := public.zad_energy_open(c, 'scan');
  update public.zad_entitlements set scan_left = scan_left - 1 where user_id = c;
  assert public.zad_energy_done(lc), 'done refused';
  update public.zad_energy_ledger set charged_at = now() - interval '20 minutes' where id = lc;
  -- d: رجوع فاشل (الفنكشن حاول والرجوع وقع)، عمره ١٥ دقيقة: يفضل open والكرون يرجّعه
  ld := public.zad_energy_open(d, 'scan');
  update public.zad_entitlements set scan_left = scan_left - 1 where user_id = d;
  update public.zad_energy_ledger set charged_at = now() - interval '15 minutes' where id = ld;
  perform set_config('zad.fail_refund', '1', true);
  begin
    perform public.zad_energy_refund(ld, 'function');
    raise exception 'failed refund went through';
  exception when others then
    if sqlerrm = 'failed refund went through' then raise; end if;
  end;
  perform set_config('zad.fail_refund', '0', true);
  assert (select status from public.zad_energy_ledger where id = ld) = 'open', 'failed refund closed the row';
  assert (select scan_left from public.zad_entitlements where user_id = d) = 0, 'refund half-applied';

  n := public.zad_energy_settle();
  assert n = 2, format('settle refunded %s, want 2', n);
  assert (select scan_left from public.zad_entitlements where user_id = a) = 1, 'a not refunded';
  assert (select scan_left from public.zad_entitlements where user_id = d) = 1, 'failed refund not retried';
  assert (select scan_left from public.zad_entitlements where user_id = b) = 0, 'young charge refunded';
  assert (select scan_left from public.zad_entitlements where user_id = c) = 0, 'delivered result refunded';
  assert (select settled_by from public.zad_energy_ledger where id = la) = 'cron', 'settled_by';

  -- مرة تانية: مفيش رجوع تاني (لا مرتين)
  assert public.zad_energy_settle() = 0, 'second settle refunded again';
  assert not public.zad_energy_refund(la, 'function'), 'function refunded a cron-refunded row';
  assert not public.zad_energy_done(la), 'refunded row closed as done';
  assert (select scan_left from public.zad_entitlements where user_id = a) = 1, 'double refund';

  -- الفنكشن رجّع الأول، وبعدين الكرون بعد ١٠ دقايق: مرة واحدة بس
  le := public.zad_energy_open(a, 'scan');
  update public.zad_entitlements set scan_left = scan_left - 1 where user_id = a;
  assert public.zad_energy_refund(le, 'function'), 'function refund refused';
  update public.zad_energy_ledger set charged_at = now() - interval '30 minutes' where id = le;
  assert public.zad_energy_settle() = 0, 'cron refunded a function-refunded row';
  assert (select scan_left from public.zad_entitlements where user_id = a) = 1, 'function + cron refunded twice';
end $$;
\echo energy_settlement_test: all checks passed
