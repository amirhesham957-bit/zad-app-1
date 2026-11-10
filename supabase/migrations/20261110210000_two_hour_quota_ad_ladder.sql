-- الحصة المجانية كل ساعتين لكل نوع، وسلّم الإعلانات (قرار المالك ٢٠٢٦-١١-١٠).
--
-- قبل كده: رصيد واحد (chat_left) بيرجع ٥ كل ٥ ساعات، الرسالة بمحاولة والصورة بمحاولتين والتحليل بـ٣،
-- والصوت ٦ في اليوم، وكل ٣ إعلانات = محاولة واحدة (20261028010000).
--
-- دلوقتي للمجاني بس (الباقات المدفوعة زي ما هي بالحرف):
--   * كل ساعتين: ٢٠ رسالة (chat_left)، ٣ صوت (voice_left)، ٢ صورة (scan_left). كل نوع لوحده، فالصورة
--     مابقتش بتاكل من الرسايل. التحليل العميق لسه بـ٣ رسايل.
--   * الرصيد واحد للتطبيق والبوت: نفس الصف في zad_entitlements، والبوت بيصرف من نفس الدالة.
--   * سلّم الإعلانات (بعدد إعلانات اليوم UTC): الأول ٥ رسايل، التاني صوت + ٥ رسايل، التالت صوت + صورة
--     + ٥ رسايل، وكل إعلان بعد كده ٣ رسايل. الحمايات زي ما هي: ٦٠ ثانية بين إعلانين، ٩ في اليوم،
--     والأطفال مالهمش إعلانات.
--   * اللي اتكسب من إعلان ولسه ماتصرفش بيفضل بعد التجديد (زي 20261012100000)، لكل نوع لوحده.
--
-- الدوال بالحرف زي ما هي على المشروع (pg_get_functiondef، ٢٠٢٦-١١-١٠)، والتغيير في فرع المجاني بس.

alter table public.zad_entitlements add column if not exists ad_voice_left int not null default 0;
alter table public.zad_entitlements add column if not exists ad_image_left int not null default 0;

-- الأرقام في مكان واحد، والحالة والمعاينة والتجديد بيقروا منه.
create or replace function public.zad_free_quota(p_kind text)
returns int
language sql
immutable
set search_path to 'public'
as $$
  select case p_kind when 'chat' then 20 when 'voice' then 3 when 'scan' then 2 else 0 end
$$;

create or replace function public.zad_free_cycle()
returns interval
language sql
immutable
set search_path to 'public'
as $$ select interval '2 hours' $$;

-- سلّم الإعلانات: الإعلان رقم n في اليوم بيدّي إيه.
create or replace function public.zad_ad_ladder(p_n int)
returns jsonb
language sql
immutable
set search_path to 'public'
as $$
  select case
    when p_n = 1 then jsonb_build_object('chat', 5, 'voice', 0, 'scan', 0)
    when p_n = 2 then jsonb_build_object('chat', 5, 'voice', 1, 'scan', 0)
    when p_n = 3 then jsonb_build_object('chat', 5, 'voice', 1, 'scan', 1)
    else jsonb_build_object('chat', 3, 'voice', 0, 'scan', 0)
  end
$$;

-- الأرقام اللي الحالة بترجعها كـ attempts_per_cycle.
update public.zad_tiers set chat_monthly = 20 where tier = 'free';

create or replace function public.zad_entitlement_refresh(p_user uuid)
returns public.zad_entitlements
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  e public.zad_entitlements;
  t public.zad_tiers;
  kept_chat int;
  kept_voice int;
  kept_image int;
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
    e.ad_voice_left := 0;
    e.ad_image_left := 0;
  end if;

  select * into t from public.zad_tiers where tier = e.tier;

  if e.cycle_reset_at <= now() then
    if e.tier = 'free' then
      -- Each kind refills on its own; what ads earned and is still unspent stays on top.
      kept_chat  := greatest(least(e.ad_attempts_left, e.chat_left), 0);
      kept_voice := greatest(least(e.ad_voice_left, e.voice_left), 0);
      kept_image := greatest(least(e.ad_image_left, e.scan_left), 0);
      e.chat_left  := public.zad_free_quota('chat') + kept_chat;
      e.voice_left := public.zad_free_quota('voice') + kept_voice;
      e.scan_left  := public.zad_free_quota('scan') + kept_image;
      e.ad_attempts_left := kept_chat;
      e.ad_voice_left := kept_voice;
      e.ad_image_left := kept_image;
      e.cycle_reset_at := now() + public.zad_free_cycle();
    else
      e.brain_left := greatest(t.brain_monthly, 0);
      e.scan_left  := greatest(t.scan_monthly, 0);
      e.chat_left  := greatest(t.chat_monthly, 0);
      e.voice_left := greatest(t.voice_monthly, 0);
      e.ad_attempts_left := 0;
      e.ad_voice_left := 0;
      e.ad_image_left := 0;
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
    ad_voice_left = e.ad_voice_left,
    ad_image_left = e.ad_image_left,
    cycle_reset_at = e.cycle_reset_at,
    updated_at = now()
  where user_id = p_user
  returning * into e;

  return e;
end;
$function$;

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

  -- المجاني: الصوت والصورة كل واحد من رصيده اللي بيتجدد كل ساعتين.
  if e.tier = 'free' and p_kind = 'voice' then
    update public.zad_entitlements set voice_left = voice_left - 1, updated_at = now()
     where user_id = p_user and voice_left > 0 returning voice_left into left_now;
    if left_now is null then
      return jsonb_build_object('allowed', false, 'reason', 'voice_cycle_cap', 'tier', e.tier,
                                'voice_left', 0, 'next_refill_at', e.cycle_reset_at);
    end if;
    return jsonb_build_object('allowed', true, 'reason', 'quota', 'tier', e.tier,
                              'voice_left', left_now, 'next_refill_at', e.cycle_reset_at);
  end if;

  -- تصريح الوسائط القديم بالإعلان (لو لسه فيه واحد شغال) بيفضل مجاني.
  if p_kind = 'scan' and e.tier = 'free'
     and e.media_pass_expires_at is not null and e.media_pass_expires_at > now() then
    return jsonb_build_object('allowed', true, 'reason', 'media_pass', 'tier', e.tier,
                              'pass_expires_at', e.media_pass_expires_at);
  end if;

  if e.tier = 'free' and p_kind = 'scan' then
    update public.zad_entitlements set scan_left = scan_left - 1, updated_at = now()
     where user_id = p_user and scan_left > 0 returning scan_left into left_now;
    if left_now is null then
      return jsonb_build_object('allowed', false, 'reason', 'image_cycle_cap', 'tier', e.tier,
                                'images_left', 0, 'next_refill_at', e.cycle_reset_at);
    end if;
    return jsonb_build_object('allowed', true, 'reason', 'quota', 'tier', e.tier,
                              'images_left', left_now, 'next_refill_at', e.cycle_reset_at);
  end if;

  -- الباقات المدفوعة: الصوت زي ما كان.
  if p_kind = 'voice' then
    if t.voice_daily >= 0 then
      v_today := (now() at time zone 'utc')::date;
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

  if p_kind = 'brain' and e.tier = 'free'
     and e.brain_session_expires_at is not null and e.brain_session_expires_at > now() then
    return jsonb_build_object('allowed', true, 'reason', 'ad_session', 'tier', e.tier,
                              'session_expires_at', e.brain_session_expires_at);
  end if;

  cost := public.zad_attempt_cost(p_kind);

  update public.zad_entitlements set chat_left = chat_left - cost, updated_at = now()
   where user_id = p_user and chat_left >= cost
  returning chat_left into left_now;
  if left_now is not null then
    return jsonb_build_object('allowed', true, 'reason', 'quota', 'tier', e.tier,
                              'left', left_now, 'cost', cost, 'cycle_reset_at', e.cycle_reset_at);
  end if;

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

create or replace function public.zad_entitlement_refund(p_user uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_tier text;
begin
  select tier into v_tier from public.zad_entitlements where user_id = p_user;
  if v_tier = 'free' and p_kind = 'voice' then
    update public.zad_entitlements set voice_left = voice_left + 1, updated_at = now() where user_id = p_user;
  elsif v_tier = 'free' and p_kind = 'scan' then
    update public.zad_entitlements set scan_left = scan_left + 1, updated_at = now() where user_id = p_user;
  elsif p_kind = 'voice' then
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
$function$;

create or replace function public.zad_entitlement_status(p_user uuid default null, p_tz text default 'UTC')
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
  is_free boolean;
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
  is_free := e.tier = 'free';

  free_ready := is_free
    and (e.last_free_brain_at is null
         or e.last_free_brain_at < public.zad_week_start(now(), coalesce(p_tz, 'UTC')));

  return jsonb_build_object(
    'tier', e.tier,
    'tier_expires_at', e.tier_expires_at,
    'ads_enabled', t.ads_enabled,
    'telegram_media', t.telegram_media = true
                      or (is_free and e.media_pass_expires_at is not null
                          and e.media_pass_expires_at > now()),
    'media_pass_expires_at', e.media_pass_expires_at,
    'attempts_left', e.chat_left,
    'attempts_per_cycle', t.chat_monthly,
    'next_refill_at', e.cycle_reset_at,
    'ad_attempts_left', greatest(least(e.ad_attempts_left, e.chat_left), 0),
    -- المجاني: الصوت والصور كل واحد برصيده كل ساعتين. المدفوع: null (من غير حد).
    'voice_free_left', case when is_free then e.voice_left end,
    'voice_per_cycle', case when is_free then public.zad_free_quota('voice') end,
    'ad_voice_left', case when is_free then greatest(least(e.ad_voice_left, e.voice_left), 0) end,
    'images_left', case when is_free then e.scan_left end,
    'images_per_cycle', case when is_free then public.zad_free_quota('scan') end,
    'ad_images_left', case when is_free then greatest(least(e.ad_image_left, e.scan_left), 0) end,
    'costs', jsonb_build_object('chat', 1, 'scan', case when is_free then 0 else 2 end, 'brain', 3, 'voice', 0),
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
    'brain_session_active', is_free and e.brain_session_expires_at is not null
                            and e.brain_session_expires_at > now(),
    'brain_available', e.chat_left >= public.zad_attempt_cost('brain') or free_ready
                       or (is_free and e.brain_session_expires_at is not null
                           and e.brain_session_expires_at > now())
  );
end;
$function$;

create or replace function public.zad_ad_reward_grant(p_user uuid default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  uid uuid;
  today_count int;
  step jsonb;
  next_step jsonb;
  e public.zad_entitlements;
  daily_cap constant int := 9;
  min_gap   constant interval := interval '60 seconds';
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

  step := public.zad_ad_ladder(today_count + 1);

  perform public.zad_entitlement_refresh(uid);
  insert into public.zad_ad_grants (user_id) values (uid);

  update public.zad_entitlements set
    chat_left = chat_left + (step->>'chat')::int,
    ad_attempts_left = ad_attempts_left + (step->>'chat')::int,
    voice_left = voice_left + (step->>'voice')::int,
    ad_voice_left = ad_voice_left + (step->>'voice')::int,
    scan_left = scan_left + (step->>'scan')::int,
    ad_image_left = ad_image_left + (step->>'scan')::int,
    ad_watch_count = today_count + 1,
    brain_session_expires_at = null,
    updated_at = now()
  where user_id = uid
  returning * into e;

  next_step := case when today_count + 1 >= daily_cap then null
                    else public.zad_ad_ladder(today_count + 2) end;

  return jsonb_build_object(
    'granted', true,
    'reward', (step->>'chat')::int,
    'reward_voice', (step->>'voice')::int,
    'reward_images', (step->>'scan')::int,
    'chat_left', e.chat_left,
    'voice_left', e.voice_left,
    'images_left', e.scan_left,
    'ads_today', today_count + 1,
    'daily_cap', daily_cap,
    'next', next_step,
    -- المفاتيح القديمة عشان تطبيق قديم مايقعش.
    'box_opened', false,
    'box_bonus', 0,
    'box_progress', 0,
    'next_reward', case when next_step is null then null else (next_step->>'chat')::int end
  );
end;
$function$;

create or replace function public.zad_ad_reward_preview()
returns jsonb
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  uid uuid := auth.uid();
  today_count int;
  last_at timestamptz;
  step jsonb;
  daily_cap constant int := 9;
  min_gap   constant interval := interval '60 seconds';
  wait_s int;
begin
  if uid is null then raise exception 'not signed in' using errcode = '42501'; end if;

  if exists (select 1 from public.family_members where user_id = uid and role = 'child') then
    return jsonb_build_object('available', false, 'reason', 'kids_no_ads');
  end if;

  select count(*) into today_count from public.zad_ad_grants
   where user_id = uid and granted_at >= (now() at time zone 'utc')::date;
  select max(granted_at) into last_at from public.zad_ad_grants where user_id = uid;

  if today_count >= daily_cap then
    return jsonb_build_object('available', false, 'reason', 'daily_ad_cap',
                              'ads_today', today_count, 'daily_cap', daily_cap);
  end if;

  wait_s := case when last_at is null then 0
                 else greatest(ceil(extract(epoch from (last_at + min_gap - now())))::int, 0) end;
  step := public.zad_ad_ladder(today_count + 1);

  return jsonb_build_object(
    'available', true,
    'reward', (step->>'chat')::int,
    'reward_voice', (step->>'voice')::int,
    'reward_images', (step->>'scan')::int,
    'step', today_count + 1,
    'box_next', false,
    'box_bonus', 0,
    'box_progress', 0,
    'ads_today', today_count,
    'daily_cap', daily_cap,
    'wait_seconds', wait_s
  );
end;
$function$;

revoke all on function public.zad_free_quota(text) from public, anon;
revoke all on function public.zad_free_cycle() from public, anon;
revoke all on function public.zad_ad_ladder(int) from public, anon;
grant execute on function public.zad_free_quota(text) to authenticated, service_role;
grant execute on function public.zad_free_cycle() to authenticated, service_role;
grant execute on function public.zad_ad_ladder(int) to authenticated, service_role;
revoke all on function public.zad_ad_reward_preview() from public, anon;
revoke all on function public.zad_entitlement_status(uuid, text) from public, anon;
revoke all on function public.zad_ad_reward_grant(uuid) from public, anon, authenticated;
grant execute on function public.zad_ad_reward_grant(uuid) to service_role;
grant execute on function public.zad_ad_reward_preview() to authenticated;
revoke all on function public.zad_entitlement_consume(uuid, text, text) from public, anon, authenticated;
grant execute on function public.zad_entitlement_consume(uuid, text, text) to service_role;
revoke all on function public.zad_entitlement_refund(uuid, text) from public, anon, authenticated;
grant execute on function public.zad_entitlement_refund(uuid, text) to service_role;
revoke all on function public.zad_entitlement_refresh(uuid) from public, anon, authenticated;
grant execute on function public.zad_entitlement_refresh(uuid) to service_role;
grant execute on function public.zad_entitlement_status(uuid, text) to authenticated, service_role;

-- المجاني بيبدأ الدورة الجديدة على أول طلب: رصيد كامل من كل نوع.
update public.zad_entitlements
   set cycle_reset_at = now(), ad_voice_left = 0, ad_image_left = 0
 where tier = 'free';
