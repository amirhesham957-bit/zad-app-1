-- ── الرصيد المجاني بيتجدد كل ٥ ساعات (قرار المالك ٢٠٢٦-١٠-١١) ─────────────────────
--
-- 20260828010000 نزّل الدورة لـ٣ ساعات وكتب جنبها «لحد ما نغيّره لما نشهر». المالك قرر
-- في خطة الدخل: ٥ محاولات مجانية كل ٥ ساعات، ومش بتتراكم فوق الـ٥. ده بيرجّع العميل
-- للتطبيق ٢–٣ مرات في اليوم، وإعلان «شاهد وخد» هو اللي بيكمّل لما يخلص.
--
-- نفس الدالة الشغالة على المشروع (pg_get_functiondef، ٢٠٢٦-١٠-١١) بالحرف، والفرق
-- الوحيد هو الفترة. الباقات المدفوعة لسه شهرية زي ما هي.

create or replace function public.zad_entitlement_refresh(p_user uuid)
returns public.zad_entitlements
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  e public.zad_entitlements;
  t public.zad_tiers;
  v_cycle_interval constant interval := interval '5 hours';
  v_free_chat_refill constant int := 5;
begin
  insert into public.zad_entitlements (user_id) values (p_user)
  on conflict (user_id) do nothing;

  select * into e from public.zad_entitlements where user_id = p_user for update;

  -- A lapsed subscription becomes free immediately
  if e.tier <> 'free' and e.tier_expires_at is not null and e.tier_expires_at <= now() then
    e.tier := 'free';
    e.tier_expires_at := null;
    e.cycle_reset_at := now();
  end if;

  select * into t from public.zad_tiers where tier = e.tier;

  -- Refresh rolling quotas
  if e.cycle_reset_at <= now() then
    if e.tier = 'free' then
      e.chat_left := v_free_chat_refill;
      e.scan_left := greatest(e.scan_left, 1);
      e.cycle_reset_at := now() + v_cycle_interval;
    else
      e.brain_left := greatest(t.brain_monthly, 0);
      e.scan_left  := greatest(t.scan_monthly, 0);
      e.chat_left  := greatest(t.chat_monthly, 0);
      e.voice_left := greatest(t.voice_monthly, 0);
      e.cycle_reset_at := now() + interval '1 month';
    end if;
  end if;

  update public.zad_entitlements set
    tier = e.tier,
    tier_expires_at = e.tier_expires_at,
    brain_left = e.brain_left,
    scan_left = e.scan_left,
    chat_left = e.chat_left,
    voice_left = e.voice_left,
    cycle_reset_at = e.cycle_reset_at,
    updated_at = now()
  where user_id = p_user
  returning * into e;

  return e;
end;
$function$;

-- create or replace بيحتفظ بالصلاحيات، بس الدالة دي security definer وبتكتب، فنأكد
-- إن مفيش حد غير السيرفر يناديها مباشرة (زي ما 20260820030000 قفلها).
revoke all on function public.zad_entitlement_refresh(uuid) from public, anon, authenticated;
