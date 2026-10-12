-- ── رصيد واحد اسمه «محاولات» (خطة الدخل، اتوافق عليها ٢٠٢٦-١٠-١١) ─────────────────
--
-- قبل كده كان فيه أربع أرصدة (brain / scan / chat / voice) كل واحد بقاعدته، والعميل
-- مكانش يقدر يفهم هو فاضل له إيه. دلوقتي رقم واحد العميل بيشوفه، والسيرفر بيحسب سعر
-- كل طلب بالمحاولات:
--
--   تسجيل مصروف/دخل  ← مجاني (بيتقرر في zad-brain قبل ما يوصل هنا، «routine»)
--   شات عادي          ← ١
--   مسح فاتورة/صورة   ← ٢
--   تحليل عميق        ← ٣
--   صوت               ← مجاني (قرار المالك ٢٠٢٦-٠٩-١٤، voice_monthly = -1)
--
-- الرصيد نفسه هو العمود chat_left — هو أصلاً اللي بيتجدد ٥ كل ٥ ساعات للمجاني،
-- واللي منحة الإعلان بتزوّد عليه، واللي حارس W4 بيخصم منه. تغيير اسم العمود كان
-- هيكسر كل اللي بيقراه من غير مكسب.
--
-- الباقات بأرقام المالك: الأساسية ٣٠٠، بلس ١٠٠٠، العيلة ٢٥٠٠ في الشهر. «غير محدود»
-- اتشال: أي حد عملي كان هيبقى ادعاء مضلل، ومن غير حد التكلفة مفتوحة.

create or replace function public.zad_attempt_cost(p_kind text)
returns int
language sql
immutable
set search_path to 'public'
as $$
  select case p_kind when 'chat' then 1 when 'scan' then 2 when 'brain' then 3 else 0 end
$$;

update public.zad_tiers set chat_monthly = 5,    brain_monthly = 0, scan_monthly = 0 where tier = 'free';
update public.zad_tiers set chat_monthly = 300,  brain_monthly = 0, scan_monthly = 0 where tier = 'starter';
update public.zad_tiers set chat_monthly = 1000, brain_monthly = 0, scan_monthly = 0 where tier = 'plus';
update public.zad_tiers set chat_monthly = 2500, brain_monthly = 0, scan_monthly = 0 where tier = 'pro';

-- المشتركين الحاليين: باقة pro كانت chat = -1 (غير محدود)، فرصيدها المخزّن ٠. من غير
-- السطر ده كانوا هيتقفلوا لحد آخر الشهر. بياخدوا رصيد الشهر كامل دلوقتي.
update public.zad_entitlements e
   set chat_left = greatest(e.chat_left, t.chat_monthly), updated_at = now()
  from public.zad_tiers t
 where t.tier = e.tier and e.tier <> 'free';

create or replace function public.zad_entitlement_consume(p_user uuid, p_kind text, p_tz text default 'UTC')
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  e public.zad_entitlements;
  t public.zad_tiers;
  cost int;
  left_now int;
  free_ready boolean;
begin
  if p_kind not in ('brain', 'scan', 'chat', 'voice') then
    return jsonb_build_object('allowed', false, 'reason', 'unknown_kind');
  end if;

  e := public.zad_entitlement_refresh(p_user);
  select * into t from public.zad_tiers where tier = e.tier;

  -- بوابة الوسائط بالإعلان: مستخدم مجاني فتح البوابة بإعلان → voice/scan مسموحة 24 ساعة.
  if p_kind in ('voice', 'scan') and e.tier = 'free'
     and e.media_pass_expires_at is not null and e.media_pass_expires_at > now() then
    return jsonb_build_object('allowed', true, 'reason', 'media_pass', 'tier', e.tier,
                              'pass_expires_at', e.media_pass_expires_at);
  end if;

  -- الصوت لسه برصيده الخاص (مفتوح لكل الباقات من ٢٠٢٦-٠٩-١٤).
  if p_kind = 'voice' then
    if t.voice_monthly < 0 then
      return jsonb_build_object('allowed', true, 'reason', 'unlimited', 'tier', e.tier);
    end if;
    update public.zad_entitlements set voice_left = voice_left - 1, updated_at = now()
     where user_id = p_user and voice_left > 0 returning voice_left into left_now;
    if left_now is null then
      return jsonb_build_object('allowed', false, 'reason', 'quota_exhausted', 'tier', e.tier,
                                'cycle_reset_at', e.cycle_reset_at);
    end if;
    return jsonb_build_object('allowed', true, 'reason', 'quota', 'tier', e.tier, 'left', left_now);
  end if;

  -- جلسة العقل القديمة بالإعلان (اتصفّرت في 20260907050000) — لو لسه فيه واحدة شغالة تفضل.
  if p_kind = 'brain' and e.tier = 'free'
     and e.brain_session_expires_at is not null and e.brain_session_expires_at > now() then
    return jsonb_build_object('allowed', true, 'reason', 'ad_session', 'tier', e.tier,
                              'session_expires_at', e.brain_session_expires_at);
  end if;

  cost := public.zad_attempt_cost(p_kind);

  -- الخصم ذرّي: الشرط chat_left >= cost جوه نفس الـ update، فطلبين في نفس اللحظة
  -- مايقدروش يصرفوا نفس الرصيد.
  update public.zad_entitlements set chat_left = chat_left - cost, updated_at = now()
   where user_id = p_user and chat_left >= cost
  returning chat_left into left_now;
  if left_now is not null then
    return jsonb_build_object('allowed', true, 'reason', 'quota', 'tier', e.tier,
                              'left', left_now, 'cost', cost, 'cycle_reset_at', e.cycle_reset_at);
  end if;

  -- الاستشارة الأسبوعية المجانية فاضلة هدية للمجاني لما الرصيد مايكفيش تحليل.
  free_ready := e.tier = 'free' and (e.last_free_brain_at is null
    or e.last_free_brain_at < public.zad_week_start(now(), coalesce(p_tz, 'UTC')));
  if p_kind = 'brain' and free_ready then
    update public.zad_entitlements set last_free_brain_at = now(), updated_at = now()
     where user_id = p_user;
    return jsonb_build_object('allowed', true, 'reason', 'weekly_free', 'tier', e.tier);
  end if;

  return jsonb_build_object(
    'allowed', false,
    'reason', case when e.tier = 'free' then 'needs_ads_or_upgrade' else 'quota_exhausted' end,
    'tier', e.tier,
    'left', e.chat_left,
    'cost', cost,
    'cycle_reset_at', e.cycle_reset_at,
    'ad_watch_count', e.ad_watch_count,
    'next_weekly_free_at', case when e.tier = 'free' and not free_ready
      then public.zad_week_start(now(), coalesce(p_tz, 'UTC')) + interval '7 days' end
  );
end;
$function$;

create or replace function public.zad_entitlement_status(p_user uuid default null::uuid, p_tz text default 'UTC'::text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  uid uuid;
  e public.zad_entitlements;
  t public.zad_tiers;
  free_ready boolean;
begin
  if auth.uid() is null and coalesce(auth.role(), '') <> 'service_role' then
    return jsonb_build_object('error', 'forbidden');
  end if;
  if auth.uid() is not null and p_user is not null and p_user <> auth.uid() then
    return jsonb_build_object('error', 'forbidden');
  end if;

  uid := coalesce(p_user, auth.uid());
  if uid is null then return jsonb_build_object('error', 'no user'); end if;

  e := public.zad_entitlement_refresh(uid);
  select * into t from public.zad_tiers where tier = e.tier;

  free_ready := e.tier = 'free'
    and (e.last_free_brain_at is null
         or e.last_free_brain_at < public.zad_week_start(now(), coalesce(p_tz, 'UTC')));

  return jsonb_build_object(
    'tier', e.tier,
    'tier_expires_at', e.tier_expires_at,
    'ads_enabled', t.ads_enabled,
    'telegram_media', t.telegram_media = true
                      or (e.tier = 'free' and e.media_pass_expires_at is not null
                          and e.media_pass_expires_at > now()),
    'media_pass_expires_at', e.media_pass_expires_at,
    -- الرصيد الواحد، وكام بيتجدد، وإمتى.
    'attempts_left', e.chat_left,
    'attempts_per_cycle', t.chat_monthly,
    'next_refill_at', e.cycle_reset_at,
    'costs', jsonb_build_object('chat', 1, 'scan', 2, 'brain', 3, 'voice', 0),
    -- المفاتيح القديمة لسه بترجع عشان أي كود بيقراها مايقعش.
    'brain_left', e.brain_left,
    'scan_left', e.scan_left,
    'chat_left', e.chat_left,
    'voice_left', case when t.voice_monthly < 0 then -1 else e.voice_left end,
    'cycle_reset_at', e.cycle_reset_at,
    'weekly_free_ready', free_ready,
    'next_weekly_free_at', case when free_ready then null
      else public.zad_week_start(now(), coalesce(p_tz, 'UTC')) + interval '7 days' end,
    'ad_watch_count', e.ad_watch_count,
    'brain_session_expires_at', e.brain_session_expires_at,
    'brain_session_active', e.tier = 'free' and e.brain_session_expires_at is not null
                            and e.brain_session_expires_at > now(),
    'brain_available', e.chat_left >= public.zad_attempt_cost('brain') or free_ready
                       or (e.tier = 'free' and e.brain_session_expires_at is not null
                           and e.brain_session_expires_at > now())
  );
end;
$function$;

revoke all on function public.zad_entitlement_consume(uuid, text, text) from public, anon, authenticated;
revoke all on function public.zad_attempt_cost(text) from public, anon;
grant execute on function public.zad_attempt_cost(text) to authenticated, service_role;
revoke all on function public.zad_entitlement_status(uuid, text) from public, anon;
grant execute on function public.zad_entitlement_status(uuid, text) to authenticated, service_role;
