-- ── محاولات الإعلان مابتتصفّرش مع تجديد الـ٥ ساعات (بلاغ المالك ٢٠٢٦-١٠-١٢) ─────────────────
--
-- العطل: zad_entitlement_refresh كانت بتعمل chat_left := 5 كل ما دورة المجاني تخلص. منحة
-- الإعلان بتزوّد على نفس العمود، فاللي اتفرج على ٣ إعلانات وماصرفش المكافأة كان بيرجع لـ٥
-- مع أول تجديد — المحاولات اللي كسبها بالإعلان بتختفي.
--
-- القاعدة الجديدة: الـ٥ المجانية بس هي اللي «مش بتتراكم» (قرار ٢٠٢٦-١٠-١١ لسه زي ما هو).
-- اللي اتكسب بالإعلان بيفضل لحد ما يتصرف:
--
--   chat_left بعد التجديد = 5 + اللي فاضل من الإعلانات
--
-- ad_attempts_left = أقصى جزء من chat_left ممكن يكون جاي من إعلانات. منحة الإعلان بتزوّده،
-- والتجديد بيقصّه على chat_left. الصرف مابيلمسوش: المحاولات المجانية بتتصرف الأول (هي اللي
-- بتنتهي)، فطول ما الصرف أقل من المجاني الجزء ده كامل، ولما يعدّيه chat_left نفسه بيبقى أقل
-- منه — least(ad_attempts_left, chat_left) هو اللي فاضل من الإعلانات بالظبط في الحالتين.
-- علشان كده zad_entitlement_consume وzad_entitlement_refund وأي حاجة تانية بتكتب في chat_left
-- مش محتاجة تتغير.
--
-- المدفوع مابيشوفش إعلانات: دورته الشهرية وانتهاء الاشتراك بيصفّروا الجزء ده عشان مايتحسبش
-- رصيد باقة قديمة كأنه من إعلانات لما العميل يرجع مجاني.

alter table public.zad_entitlements
  add column if not exists ad_attempts_left int not null default 0;

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
  v_ad_kept int;
begin
  insert into public.zad_entitlements (user_id) values (p_user)
  on conflict (user_id) do nothing;

  select * into e from public.zad_entitlements where user_id = p_user for update;

  -- A lapsed subscription becomes free immediately
  if e.tier <> 'free' and e.tier_expires_at is not null and e.tier_expires_at <= now() then
    e.tier := 'free';
    e.tier_expires_at := null;
    e.cycle_reset_at := now();
    e.ad_attempts_left := 0;
  end if;

  select * into t from public.zad_tiers where tier = e.tier;

  -- Refresh rolling quotas
  if e.cycle_reset_at <= now() then
    if e.tier = 'free' then
      -- The free 5 come back; what ads earned and is still unspent stays on top.
      v_ad_kept := greatest(least(e.ad_attempts_left, e.chat_left), 0);
      e.chat_left := v_free_chat_refill + v_ad_kept;
      e.ad_attempts_left := v_ad_kept;
      e.scan_left := greatest(e.scan_left, 1);
      e.cycle_reset_at := now() + v_cycle_interval;
    else
      e.brain_left := greatest(t.brain_monthly, 0);
      e.scan_left  := greatest(t.scan_monthly, 0);
      e.chat_left  := greatest(t.chat_monthly, 0);
      e.voice_left := greatest(t.voice_monthly, 0);
      e.ad_attempts_left := 0;
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
    ad_attempts_left = e.ad_attempts_left,
    cycle_reset_at = e.cycle_reset_at,
    updated_at = now()
  where user_id = p_user
  returning * into e;

  return e;
end;
$function$;

revoke all on function public.zad_entitlement_refresh(uuid) from public, anon, authenticated;

-- نفس الدالة الشغالة على المشروع (pg_get_functiondef، ٢٠٢٦-١٠-١٢) بالحرف، والفرق الوحيد
-- سطر ad_attempts_left في الـ update.
create or replace function public.zad_ad_reward_grant(p_user uuid default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  uid uuid;
  today_count int;
  reward int;
  new_left int;
  rate public.zad_ad_reward_rates;
  box boolean;
  -- ١٠/يوم و٦٠ ثانية بين إعلانين: حماية من تصنيف AdMob للحركة غير الطبيعية (زي ما كانوا).
  daily_cap constant int := 10;
  min_gap   constant interval := interval '60 seconds';
  box_every constant int := 3;
begin
  if auth.uid() is null and coalesce(auth.role(), '') <> 'service_role' then
    return jsonb_build_object('granted', false, 'reason', 'forbidden');
  end if;
  if auth.uid() is not null and p_user is not null and p_user <> auth.uid() then
    return jsonb_build_object('granted', false, 'reason', 'forbidden');
  end if;

  uid := coalesce(auth.uid(), p_user);
  if uid is null then
    return jsonb_build_object('granted', false, 'reason', 'no user');
  end if;

  -- وضع الأطفال: صفر إعلانات (سياسة العائلات في جوجل بلاي). حساب طفل في عيلة مايتمنحش
  -- مكافأة إعلان أبداً، حتى لو تطبيق قديم أو معدّل عرض إعلان.
  if exists (select 1 from public.family_members where user_id = uid and role = 'child') then
    return jsonb_build_object('granted', false, 'reason', 'kids_no_ads');
  end if;

  if exists (
    select 1 from public.zad_ad_grants
    where user_id = uid and granted_at > now() - min_gap
  ) then
    return jsonb_build_object('granted', false, 'reason', 'too_fast');
  end if;

  select count(*) into today_count from public.zad_ad_grants
  where user_id = uid and granted_at >= (now() at time zone 'utc')::date;

  if today_count >= daily_cap then
    return jsonb_build_object('granted', false, 'reason', 'daily_ad_cap',
                              'daily_cap', daily_cap, 'ads_today', today_count);
  end if;

  rate := public.zad_ad_reward_rate(uid);
  box := (today_count + 1) % box_every = 0;
  reward := rate.per_ad + case when box then rate.box_bonus else 0 end;

  perform public.zad_entitlement_refresh(uid);
  insert into public.zad_ad_grants (user_id) values (uid);

  update public.zad_entitlements set
    chat_left = chat_left + reward,
    ad_attempts_left = ad_attempts_left + reward,
    ad_watch_count = today_count + 1,
    brain_session_expires_at = null,
    updated_at = now()
  where user_id = uid
  returning chat_left into new_left;

  return jsonb_build_object(
    'granted', true,
    'reward', reward,
    'box_opened', box,
    'box_bonus', rate.box_bonus,
    -- كام إعلان اتشاف من الصندوق الجاي (٠–٢)، للشريط اللي فيه ٣ خانات.
    'box_progress', (today_count + 1) % box_every,
    'chat_left', new_left,
    'ads_today', today_count + 1,
    'daily_cap', daily_cap,
    -- اللي الزر بيعرضه للمشاهدة الجاية (من غير الصندوق). null = خلص السقف.
    'next_reward', case when today_count + 1 >= daily_cap then null else rate.per_ad end
  );
end;
$function$;

-- المنحة من admob-ssv بس (service_role)، زي ما 20261012090000 قفلها.
revoke execute on function public.zad_ad_reward_grant(uuid) from public, anon, authenticated;
grant execute on function public.zad_ad_reward_grant(uuid) to service_role;
