-- مكافأة الإعلان حسب البلد، والصندوق كل تالت إعلان (خطة الدخل ٢٠٢٦-١٠-١١، القسمين ٣ و٦).
--
-- قبل كده: الإعلان الأول ٣ محاولات، التاني ٤، … لحد ١٠ للإعلان الواحد، ونفس الرقم في كل
-- البلاد. حسبة الخطة: الإعلان في مصر بيكسب حوالي ٠٫٠٠٢ دولار والمحاولة بتكلّف حوالي ٠٫٠٠٠٤،
-- فأكبر مكافأة مربحة هناك ~٣ — يعني من الإعلان الرابع كل إعلان كان بيخسّر، وأكتر عميل بيتفرج
-- هو أكتر عميل بيخسّر.
--
-- دلوقتي: المكافأة ثابتة لكل إعلان حسب بلد العميل (zad_ad_reward_rates)، وكل تالت إعلان في
-- اليوم بيفتح «الصندوق» بزيادة. ٣ إعلانات = ٣×المكافأة + الصندوق، من غير ما سقف اليوم (١٠)
-- ولا الفاصل (٦٠ ث) يتغيروا — دول حماية من AdMob نفسه.
--
-- الأرقام في جدول عشان تتظبط بعد أسبوعين بأرقام AdMob الحقيقية من غير نشر: update سطر.
-- 'default' لأي بلد مش مكتوب.

create table if not exists public.zad_ad_reward_rates (
  country text primary key check (country = 'default' or country ~ '^[A-Z]{2}$'),
  per_ad int not null check (per_ad between 1 and 10),
  box_bonus int not null check (box_bonus between 0 and 10)
);
alter table public.zad_ad_reward_rates enable row level security;
drop policy if exists zad_ad_reward_rates_read on public.zad_ad_reward_rates;
create policy zad_ad_reward_rates_read on public.zad_ad_reward_rates for select to authenticated using (true);
revoke insert, update, delete on public.zad_ad_reward_rates from anon, authenticated;

-- الخليج سعر الإعلان فيه أعلى؛ مصر والباقي +٢. الصندوق +٣ إلا مصر +٢.
insert into public.zad_ad_reward_rates (country, per_ad, box_bonus) values
  ('default', 2, 3),
  ('EG', 2, 2),
  ('SA', 3, 3), ('AE', 3, 3), ('KW', 3, 3), ('QA', 3, 3), ('BH', 3, 3), ('OM', 3, 3)
on conflict (country) do nothing;

create or replace function public.zad_ad_reward_rate(p_user uuid)
returns public.zad_ad_reward_rates language sql stable security definer set search_path = public as $$
  select r.* from public.zad_ad_reward_rates r
   where r.country in (coalesce((select upper(u.country) from public.zad_users u where u.id = p_user), 'default'), 'default')
   order by (r.country = 'default')
   limit 1
$$;

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

revoke execute on function public.zad_ad_reward_rate(uuid) from public, anon, authenticated;
