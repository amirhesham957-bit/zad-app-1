-- ── ٣ أسئلة صوتية في اليوم للمجاني (قرار المالك ٢٠٢٦-١٠-٢٨، ZAD_PLAN ٨ب.٢) ─────────────────────
--
-- قبل كده الصوت كان مجاني ومن غير حد للكل (قرار ٢٠٢٦-٠٩-١٤، voice_monthly = -1)، وكل نداء
-- voice_synthesize ووoice_agent كان بيعدّي على zad_entitlement_consume 'voice' — يعني حتى
-- قراية رد الشات بصوت كانت هتتحسب لو اتقفل الصوت، والرد الواحد بيتقطّع لـ٦–١٠ أجزاء.
--
-- القاعدة دلوقتي:
--   * المحاولة = سؤال صوتي واحد (voice_agent، التفريغ) ورد زاد عليه. zad-core-intelligence/meter.ts
--     مابقاش بيخصم على voice_synthesize — قراية ردود الشات بصوت مجانية للكل.
--   * المجاني: ٣ في اليوم (zad_tiers.voice_daily = 3)، اليوم بتوقيت UTC زي سقف الإعلانات.
--     مابيتراكموش، ومالهمش علاقة برصيد «محاولات» الشات ولا بالإعلانات.
--   * الباقات المدفوعة: voice_daily = -1 → زي ما هي، من غير حد (voice_monthly = -1).
--   * التصريح القديم بالإعلان (media_pass) مابقاش بيعدّي الصوت من الحد — بيفضل للمسح بس.
--   * سؤال رجع من غير كلام (Whisper ماسمعش حاجة) بيرجّع المحاولة (zad_entitlement_refund).

alter table public.zad_tiers
  add column if not exists voice_daily int not null default -1;
update public.zad_tiers set voice_daily = 3 where tier = 'free';

alter table public.zad_entitlements
  add column if not exists voice_day date,
  add column if not exists voice_day_count int not null default 0;

-- نفس الدالة الشغالة على المشروع (pg_get_functiondef، ٢٠٢٦-١٠-٢٨) بالحرف، والفرق الوحيد فرع
-- الصوت: بقى قبل التصريح، وفيه الحد اليومي.
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
  v_today date;
begin
  if p_kind not in ('brain', 'scan', 'chat', 'voice') then
    return jsonb_build_object('allowed', false, 'reason', 'unknown_kind');
  end if;

  e := public.zad_entitlement_refresh(p_user);
  select * into t from public.zad_tiers where tier = e.tier;

  -- الصوت: حد يومي للباقة اللي ليها حد (المجاني ٣)، والباقي برصيده الشهري (مفتوح = -1).
  if p_kind = 'voice' then
    if t.voice_daily >= 0 then
      v_today := (now() at time zone 'utc')::date;
      -- ذرّي زي خصم المحاولات: الشرط جوه نفس الـ update، فسؤالين في نفس اللحظة مايعدّوش الحد.
      update public.zad_entitlements set
        voice_day_count = case when voice_day = v_today then voice_day_count + 1 else 1 end,
        voice_day = v_today,
        updated_at = now()
       where user_id = p_user
         and (voice_day is distinct from v_today or voice_day_count < t.voice_daily)
      returning voice_day_count into left_now;
      if left_now is null then
        return jsonb_build_object('allowed', false, 'reason', 'voice_daily_cap', 'tier', e.tier,
                                  'voice_daily', t.voice_daily, 'voice_left', 0,
                                  'voice_resets_at', (v_today + 1)::timestamp at time zone 'utc');
      end if;
      return jsonb_build_object('allowed', true, 'reason', 'quota', 'tier', e.tier,
                                'voice_daily', t.voice_daily, 'voice_left', t.voice_daily - left_now);
    end if;
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

  -- بوابة الوسائط بالإعلان: مستخدم مجاني فتح البوابة بإعلان → المسح مسموح 24 ساعة.
  if p_kind = 'scan' and e.tier = 'free'
     and e.media_pass_expires_at is not null and e.media_pass_expires_at > now() then
    return jsonb_build_object('allowed', true, 'reason', 'media_pass', 'tier', e.tier,
                              'pass_expires_at', e.media_pass_expires_at);
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

-- الإرجاع: السؤال اللي رجع من غير كلام بيرجّع للعدّاد اليومي لو الباقة ليها حد يومي.
create or replace function public.zad_entitlement_refund(p_user uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_kind = 'voice' then
    if exists (select 1 from public.zad_entitlements e join public.zad_tiers t on t.tier = e.tier
                where e.user_id = p_user and t.voice_daily >= 0) then
      update public.zad_entitlements
         set voice_day_count = greatest(voice_day_count - 1, 0), updated_at = now()
       where user_id = p_user and voice_day = (now() at time zone 'utc')::date;
    else
      update public.zad_entitlements set voice_left = voice_left + 1, updated_at = now() where user_id = p_user;
    end if;
  elsif p_kind in ('chat', 'scan', 'brain') then
    update public.zad_entitlements
       set chat_left = chat_left + public.zad_attempt_cost(p_kind), updated_at = now()
     where user_id = p_user;
  end if;
end;
$$;

revoke execute on function public.zad_entitlement_consume(uuid, text, text) from public, anon, authenticated;
grant execute on function public.zad_entitlement_consume(uuid, text, text) to service_role;
revoke execute on function public.zad_entitlement_refund(uuid, text) from public, anon, authenticated;
grant execute on function public.zad_entitlement_refund(uuid, text) to service_role;
