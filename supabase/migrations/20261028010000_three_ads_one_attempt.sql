-- ── كل ٣ إعلانات = محاولة واحدة (قرار المالك ٢٠٢٦-١٠-٢٨، ZAD_PLAN ٨ب.٢) ─────────────────────────
--
-- قبل كده: الإعلان الواحد بيدّي ٢–٣ محاولات حسب البلد (`per_ad`)، وكل تالت إعلان صندوق بزيادة ٢–٣
-- (`box_bonus`)، ولحد ١٠ إعلانات في اليوم — يعني لحد ٣٩ محاولة في اليوم من إعلانات في السعودية.
-- المالك عايز عائد الإعلانات يغطي تكلفة الموديلات وزيادة، فالقاعدة بقت: الإعلان لوحده صفر، وكل
-- تالت إعلان يفتح محاولة واحدة، ولحد ٩ إعلانات في اليوم = ٣ محاولات بالكتير.
--
-- الآلية نفسها ماتغيرتش (الصندوق كل ٣ موجود من ٢٠٢٦-١٠-١٢): الأرقام بس. `per_ad = 0` محتاج الشرط
-- يقبل صفر، والسقف اليومي في الدالتين (المنحة والمعاينة) لازم يتساوى عشان المعاينة ماتوعدش بإعلان
-- المنحة هترفضه. الدالتين بالحرف زي ما هما على المشروع (pg_get_functiondef، ٢٠٢٦-١٠-٢٨) والفرق
-- السقف بس.

alter table public.zad_ad_reward_rates drop constraint if exists zad_ad_reward_rates_per_ad_check;
alter table public.zad_ad_reward_rates
  add constraint zad_ad_reward_rates_per_ad_check check (per_ad between 0 and 10);

update public.zad_ad_reward_rates set per_ad = 0, box_bonus = 1;

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
  -- ٩/يوم (٣ محاولات) و٦٠ ثانية بين إعلانين: حماية من تصنيف AdMob للحركة غير الطبيعية.
  daily_cap constant int := 9;
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
  rate public.zad_ad_reward_rates;
  daily_cap constant int := 9;
  min_gap   constant interval := interval '60 seconds';
  box_every constant int := 3;
  wait_s int;
begin
  if uid is null then raise exception 'not signed in' using errcode = '42501'; end if;

  if exists (select 1 from public.family_members where user_id = uid and role = 'child') then
    return jsonb_build_object('available', false, 'reason', 'kids_no_ads');
  end if;

  select count(*) into today_count from public.zad_ad_grants
   where user_id = uid and granted_at >= (now() at time zone 'utc')::date;
  -- الفاصل بيتحسب من آخر منحة حتى لو كانت امبارح.
  select max(granted_at) into last_at from public.zad_ad_grants where user_id = uid;

  if today_count >= daily_cap then
    return jsonb_build_object('available', false, 'reason', 'daily_ad_cap',
                              'ads_today', today_count, 'daily_cap', daily_cap);
  end if;

  wait_s := case when last_at is null then 0
                 else greatest(ceil(extract(epoch from (last_at + min_gap - now())))::int, 0) end;
  rate := public.zad_ad_reward_rate(uid);

  return jsonb_build_object(
    'available', true,
    'reward', rate.per_ad,
    -- الإعلان الجاي بيفتح الصندوق؟ وبكام زيادة.
    'box_next', (today_count + 1) % box_every = 0,
    'box_bonus', rate.box_bonus,
    'box_progress', today_count % box_every,
    'ads_today', today_count,
    'daily_cap', daily_cap,
    'wait_seconds', wait_s
  );
end;
$function$;
