-- مكتب الدعم في شات الأدمن (طلب المالك ٧/١١): «أتحقق من مشكلة أي مستخدم وأجدد اشتراكه بالـID أو الإيميل».
--
-- ده الباب الوحيد اللي بيفتح حساب عميل **معيّن** للمالك، فشروطه أضيق من التقارير:
--   - الحالة التقنية بس: إمتى اتسجل، باقته وانتهاؤها، آخر مرة فتح التطبيق، قراية البنك شغالة ولا لأ، أعطال العقل
--     بنوعها، التذاكر (موضوع وحالة). **مفيش معاملات ولا مبالغ ولا محلات ولا مخزن ولا ذاكرة ولا رسايل شات.**
--   - كل بحث وكل تجديد بيتسجل في zad_support_access_log (مين، أنهي حساب، إيه، إمتى) — عشان الوصول يبقى له أثر.
--   - التجديد بيعدّي على zad_set_tier (الكاتب الوحيد للباقات) زي شرا جوجل بالظبط، ومحدود ١–٩٠ يوم.
--   - service_role بس؛ البوت بيناديهم من شات الأدمن (ZAD_ADMIN_CHAT_ID) وبيرفض أي شات تاني.

create table if not exists public.zad_support_access_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  admin_chat bigint not null,
  user_id uuid,
  action text not null check (action in ('lookup', 'extend')),
  query text,
  detail jsonb
);
alter table public.zad_support_access_log enable row level security;
revoke all on public.zad_support_access_log from anon, authenticated;

-- الحساب من ID أو إيميل (حساب الدخول، أو إيميل التواصل في تذكرة). null = مش موجود.
create or replace function public.zad_support_resolve(p_query text)
returns uuid
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $$
declare
  q text := lower(btrim(coalesce(p_query, '')));
  v uuid;
begin
  if q ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select id into v from public.zad_users where id = q::uuid;
    return v;
  end if;
  if q ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    select id into v from auth.users where lower(email) = q limit 1;
    if v is null then
      select user_id into v from public.zad_support_tickets
       where lower(contact_email) = q and user_id is not null order by created_at desc limit 1;
    end if;
    return v;
  end if;
  return null;
end;
$$;
revoke all on function public.zad_support_resolve(text) from public, anon, authenticated;

create or replace function public.zad_support_lookup(p_admin_chat bigint, p_query text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user uuid := public.zad_support_resolve(p_query);
  v jsonb;
begin
  insert into zad_support_access_log (admin_chat, user_id, action, query)
  values (p_admin_chat, v_user, 'lookup', left(btrim(coalesce(p_query, '')), 120));
  if v_user is null then
    return jsonb_build_object('found', false);
  end if;

  select jsonb_build_object(
    'found', true,
    'user_id', v_user,
    'created_at', u.created_at,
    'country', u.country,
    'tier', e.tier,
    'tier_expires_at', e.tier_expires_at,
    'chat_left', e.chat_left,
    'scan_left', e.scan_left,
    'last_open', (select max(at) from zad_product_events where user_id = v_user and name = 'app_open'),
    'last_event', (select max(at) from zad_product_events where user_id = v_user),
    'bank_last', (select name from zad_product_events where user_id = v_user and name like 'bank.%' order by at desc limit 1),
    'bank_last_at', (select max(at) from zad_product_events where user_id = v_user and name like 'bank.%'),
    'telegram', exists (select 1 from telegram_bindings where user_id = v_user and bound_at is not null),
    'brain_failed_7d', coalesce((
      select jsonb_object_agg(kind, n) from (
        select public.zad_problem_kind(coalesce(error, '')) as kind, count(*) as n
          from zad_brain_runs
         where user_id = v_user and status = 'failed' and started_at >= now() - interval '7 days'
         group by 1) k), '{}'::jsonb),
    'brain_runs_7d', (select count(*) from zad_brain_runs where user_id = v_user and started_at >= now() - interval '7 days'),
    'tickets', coalesce((
      select jsonb_agg(jsonb_build_object('at', created_at, 'subject', left(coalesce(subject, ''), 80), 'status', status)
                       order by created_at desc)
        from (select * from zad_support_tickets where user_id = v_user order by created_at desc limit 3) t), '[]'::jsonb)
  ) into v
  from zad_users u left join zad_entitlements e on e.user_id = u.id
  where u.id = v_user;
  return v;
end;
$$;
revoke all on function public.zad_support_lookup(bigint, text) from public, anon, authenticated;
grant execute on function public.zad_support_lookup(bigint, text) to service_role;

-- تجديد يدوي: من انتهاء الباقة الحالية لو لسه شغالة، وإلا من دلوقتي. الباقة = الحالية لو مدفوعة، وإلا pro.
create or replace function public.zad_support_extend(p_admin_chat bigint, p_user uuid, p_days int, p_tier text default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  e public.zad_entitlements;
  v_tier text;
  v_until timestamptz;
  v_res jsonb;
begin
  if p_days is null or p_days < 1 or p_days > 90 then
    return jsonb_build_object('ok', false, 'reason', 'days_1_to_90');
  end if;
  if not exists (select 1 from zad_users where id = p_user) then
    return jsonb_build_object('ok', false, 'reason', 'no_such_user');
  end if;
  select * into e from zad_entitlements where user_id = p_user;
  v_tier := coalesce(nullif(p_tier, ''), case when coalesce(e.tier, 'free') <> 'free' then e.tier else 'pro' end);
  if v_tier = 'free' or not exists (select 1 from zad_tiers where tier = v_tier) then
    return jsonb_build_object('ok', false, 'reason', 'unknown_tier');
  end if;
  v_until := greatest(now(), coalesce(case when e.tier = v_tier then e.tier_expires_at end, now()))
             + make_interval(days => p_days);
  v_res := public.zad_set_tier(p_user, v_tier, v_until);
  insert into zad_support_access_log (admin_chat, user_id, action, detail)
  values (p_admin_chat, p_user, 'extend',
          jsonb_build_object('days', p_days, 'tier', v_tier, 'until', v_until, 'result', v_res));
  return jsonb_build_object('ok', coalesce((v_res ->> 'ok')::boolean, false), 'tier', v_tier, 'until', v_until,
                            'applied', v_res -> 'applied', 'reason', v_res -> 'reason');
end;
$$;
revoke all on function public.zad_support_extend(bigint, uuid, int, text) from public, anon, authenticated;
grant execute on function public.zad_support_extend(bigint, uuid, int, text) to service_role;
