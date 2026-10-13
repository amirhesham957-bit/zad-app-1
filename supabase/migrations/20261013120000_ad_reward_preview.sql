-- ── زرار «شاهد وخد» محتاج يعرف قبل الإعلان (حساب AdMob اتفتح ٢٠٢٦-١٠-١٣) ─────────────────────
--
-- المنحة بتيجي من admob-ssv بعد ما الإعلان يخلص، ورفضها (سقف اليوم، الفاصل، حساب طفل) بيوصل
-- لجوجل مش للعميل. من غير الدالة دي التطبيق كان هيعرض إعلان ٣٠ ثانية والمنحة تترفض في الآخر —
-- العميل اتفرج على الفاضي. دي قراءة بس: بتقول هل الإعلان الجاي هيتمنح، بكام، وإمتى.
--
-- الأرقام لازم تفضل زي zad_ad_reward_grant (٢٠٢٦١٠١٢٠٥٠٠٠٠): ١٠ في اليوم UTC، ٦٠ ثانية بين
-- إعلانين، الصندوق كل تالت إعلان. ad_reward_preview_test.sql بيقارن الاتنين.

create or replace function public.zad_ad_reward_preview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  today_count int;
  last_at timestamptz;
  rate public.zad_ad_reward_rates;
  daily_cap constant int := 10;
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
$$;

revoke execute on function public.zad_ad_reward_preview() from public, anon;
grant execute on function public.zad_ad_reward_preview() to authenticated;
