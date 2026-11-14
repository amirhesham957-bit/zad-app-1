-- zad_set_tier(…, 'free') كانت بتنزّل الحساب للمجاني بأرقام الباقة الشهرية (zad_tiers.free):
-- scan_monthly = 0 و voice_monthly = -1 ⇐ صفر صور وصفر صوت، ودورة ٥ ساعات بدل zad_free_cycle().
-- اتقاس ١٤/١١ على حساب المالك (اتنزّل من pro لـfree عشان الإعلانات ترجع): ٢٠ رسالة، ٠ صور، ٠ صوت،
-- والتجديد بعد ٥ ساعات — وأي عميل جديد بياخد ٢٠/٢/٣ كل ساعتين.
--
-- التصليح: النزول للمجاني بيخلّي الدورة مستحقة دلوقتي ويسيب zad_entitlement_refresh يملاها —
-- هو الوحيد اللي بيعرف حصص المجاني (zad_free_quota) ودورته (zad_free_cycle). مكافآت الإعلانات
-- بتتصفّر لأن الباقة المدفوعة ماكانش فيها إعلانات أصلاً. الباقات المدفوعة مااتغيرش فيها حاجة.

create or replace function public.zad_set_tier(p_user uuid, p_tier text, p_expires timestamp with time zone DEFAULT NULL::timestamp with time zone)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  e public.zad_entitlements;
  t public.zad_tiers;
  t_old public.zad_tiers;
  v_fresh boolean;
begin
  select * into t from public.zad_tiers where tier = p_tier;
  if not found then return jsonb_build_object('ok', false, 'reason', 'unknown_tier'); end if;

  -- refresh بينزّل الباقة المنتهية للمجاني ويقفل الصف للترانزاكشن دي.
  e := public.zad_entitlement_refresh(p_user);
  select * into t_old from public.zad_tiers where tier = e.tier;

  if p_tier = 'free' then
    if e.tier = 'free' then
      return jsonb_build_object('ok', true, 'applied', false, 'tier', e.tier, 'cycle_reset_at', e.cycle_reset_at);
    end if;
    -- المجاني بيتملى من refresh بحصصه هو، مش من zad_tiers الشهرية.
    update public.zad_entitlements set
      tier = 'free',
      tier_expires_at = null,
      ad_attempts_left = 0,
      ad_voice_left = 0,
      ad_image_left = 0,
      cycle_reset_at = now(),
      updated_at = now()
    where user_id = p_user;
    e := public.zad_entitlement_refresh(p_user);
    return jsonb_build_object('ok', true, 'applied', true, 'refilled', true,
                              'tier', e.tier, 'cycle_reset_at', e.cycle_reset_at);
  elsif t.sort_order < coalesce(t_old.sort_order, 0) then
    -- اشتراك أقل والأعلى لسه شغال: الأعلى يفضل لحد ما ينتهي أو جوجل تسحبه.
    return jsonb_build_object('ok', true, 'applied', false, 'reason', 'higher_plan_active',
                              'tier', e.tier, 'cycle_reset_at', e.cycle_reset_at);
  elsif t.sort_order > coalesce(t_old.sort_order, 0) then
    v_fresh := true;
  else
    -- نفس الباقة: رصيد جديد بس لو جوجل مدّت الانتهاء (فترة جديدة اتدفعت).
    v_fresh := p_expires is not null
      and p_expires > coalesce(e.tier_expires_at, '-infinity'::timestamptz);
  end if;

  if v_fresh then
    update public.zad_entitlements set
      tier = p_tier,
      tier_expires_at = p_expires,
      brain_left = greatest(t.brain_monthly, 0),
      scan_left  = greatest(t.scan_monthly, 0),
      chat_left  = greatest(t.chat_monthly, 0),
      voice_left = greatest(t.voice_monthly, 0),
      cycle_reset_at = now() + interval '1 month',
      updated_at = now()
    where user_id = p_user returning * into e;
  else
    update public.zad_entitlements set
      tier_expires_at = coalesce(p_expires, tier_expires_at),
      updated_at = now()
    where user_id = p_user returning * into e;
  end if;

  return jsonb_build_object('ok', true, 'applied', true, 'refilled', v_fresh,
                            'tier', e.tier, 'cycle_reset_at', e.cycle_reset_at);
end;
$function$;

revoke execute on function public.zad_set_tier(uuid, text, timestamptz) from public, anon, authenticated;
grant execute on function public.zad_set_tier(uuid, text, timestamptz) to service_role;
