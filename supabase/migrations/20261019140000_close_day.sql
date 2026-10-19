-- «اقفل يومك» (ZAD_PLAN ٣.٢، ZAD_DREAM_PLAN §٧ فكرة ١، قرار ٨: ٩:٣٠ بالليل بتوقيت السوق).
--
-- رسالة واحدة بالليل: «النهارده شفت ٣ حاجات: … فيه حاجة كاش؟» بأزرار [تمام كده] [صرفت كاش]
-- [في حاجة ناقصة]. بتتكتب بقالب (صفر موديل) في zad-brain/voiceMoments.ts، وبتتقال مكتوبة على
-- الموبايل وتليجرام. أي زرار = اليوم اتقفل: سطر في zad_day_closes ونقط للرفيق مرة في اليوم،
-- والقفلة بتحافظ على السلسلة زي التسجيل بالظبط (يوم من غير مصروف مايبقاش يوم ضايع).
--
-- الأزرار مابتكتبش فلوس: «صرفت كاش» و«في حاجة ناقصة» بيقفلوا اليوم وبيطلبوا من العميل يكتب
-- المصروف، وده بيعدّي على لفة الوكيل وتأكيدها زي أي مصروف.
--
-- الساعات الهادية والظروف (حالة البيت) بيتحكم فيهم المعالج (momentGate) مش هنا.

create table if not exists public.zad_day_closes (
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  outcome text not null check (outcome in ('all_good', 'cash', 'missing')),
  channel text not null check (channel in ('app', 'telegram')),
  xp int not null default 0,
  created_at timestamptz not null default now(),
  primary key (user_id, local_date)
);

alter table public.zad_day_closes enable row level security;

-- العميل يشوف قفلاته بس. الكتابة من الدوال تحت بس.
drop policy if exists "day closes: owner reads" on public.zad_day_closes;
create policy "day closes: owner reads" on public.zad_day_closes
  for select using ((select auth.uid()) = user_id);

-- ── نقط الرفيق: مصدر جديد بسقف، وبيحافظ على السلسلة ─────────────────────────

alter table public.zad_companion_ledger drop constraint if exists zad_companion_ledger_source_check;
alter table public.zad_companion_ledger add constraint zad_companion_ledger_source_check check (source in
  ('log', 'scan', 'pantry', 'streak', 'family', 'level', 'streak_milestone', 'missions',
   'invite', 'welcome', 'buy', 'purchase', 'challenge', 'close_day'));

-- نفس نمط 20261018140000: استبدال على التعريف الحي بدل نقل جسم الدالة بإيد، والاستبدال لازم
-- يحصل فعلاً وإلا الميجريشن تقع.
do $fix$
declare
  def text;
  fixed text;
begin
  select pg_get_functiondef('public.zad_companion_award(uuid, text, text, int)'::regprocedure) into def;
  if position('''close_day''' in def) > 0 then
    return; -- اتطبق قبل كده
  end if;
  fixed := replace(def, 'when ''streak'' then 25 else', 'when ''streak'' then 25 when ''close_day'' then 20 else');
  if fixed = def then
    raise exception 'zad_companion_award: the caps were not found';
  end if;
  def := fixed;
  fixed := replace(def, 'if p_source in (''log'', ''scan'') and v.streak_day', 'if p_source in (''log'', ''scan'', ''close_day'') and v.streak_day');
  if fixed = def then
    raise exception 'zad_companion_award: the streak condition was not found';
  end if;
  execute fixed;
end
$fix$;

-- ── القفلة نفسها ─────────────────────────────────────────────────────────────

/**
 * يقفل يوم العميل مرة واحدة. النهارده أو امبارح بس (ضغطة على رسالة امبارح بعد نص الليل
 * لسه تتحسب)، وأقدم من كده = stale. التانية لنفس اليوم بترجع already ومابتديش نقط.
 */
create or replace function public.zad_close_day_for(p_user uuid, p_date date, p_outcome text, p_channel text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_today date;
  v_inserted uuid;
  v_existing text;
  v_xp int;
begin
  if p_outcome is null or p_outcome not in ('all_good', 'cash', 'missing') then
    raise exception 'bad outcome' using errcode = '22023';
  end if;
  v_today := public.zad_companion_today(p_user);
  if p_date is null or p_date > v_today or p_date < v_today - 1 then
    return jsonb_build_object('ok', false, 'reason', 'stale');
  end if;
  insert into public.zad_day_closes (user_id, local_date, outcome, channel)
  values (p_user, p_date, p_outcome, p_channel)
  on conflict (user_id, local_date) do nothing
  returning user_id into v_inserted;
  if v_inserted is null then
    select outcome into v_existing from public.zad_day_closes where user_id = p_user and local_date = p_date;
    return jsonb_build_object('ok', true, 'already', true, 'outcome', v_existing, 'xp', 0);
  end if;
  v_xp := public.zad_companion_award(p_user, 'close_day', p_date::text, 20);
  update public.zad_day_closes set xp = v_xp where user_id = p_user and local_date = p_date;
  return jsonb_build_object('ok', true, 'already', false, 'outcome', p_outcome, 'xp', v_xp);
end;
$function$;

revoke all on function public.zad_close_day_for(uuid, date, text, text) from public, anon, authenticated;

/** من التطبيق: يوم العميل النهارده بتوقيت سوقه. */
create or replace function public.zad_close_day(p_outcome text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'not signed in' using errcode = '42501'; end if;
  return public.zad_close_day_for(v_user, public.zad_companion_today(v_user), p_outcome, 'app');
end;
$function$;

revoke all on function public.zad_close_day(text) from public, anon;
grant execute on function public.zad_close_day(text) to authenticated;

/**
 * من زرار تليجرام: اليوم بييجي من اللحظة نفسها (facts.local_date)، مش من الشات. اللحظة
 * لازم تكون close_day وبتاعة نفس العميل اللي البوت حلّه من الشات.
 */
create or replace function public.zad_close_day_service(p_user uuid, p_moment uuid, p_outcome text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_date date;
begin
  select (m.facts->>'local_date')::date into v_date
    from public.zad_voice_moments m
   where m.id = p_moment and m.user_id = p_user and m.moment = 'close_day';
  if v_date is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  return public.zad_close_day_for(p_user, v_date, p_outcome, 'telegram');
end;
$function$;

revoke all on function public.zad_close_day_service(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.zad_close_day_service(uuid, uuid, text) to service_role;

-- ── اللحظة ───────────────────────────────────────────────────────────────────

/**
 * من ٩:٣٠ لـ١٠ بالليل بتوقيت سوق العميل (الكرون كل ٥ دقايق، والـdedupe بيخلّيها مرة). نفس
 * «نشط» بتاع تصبح على خير، ومن غير الأولاد، ومن غير اللي قفل يومه من التطبيق قبلها.
 * المصاريف اللي زاد شافها النهارده بتتحسب هنا: العدد، وآخر ٣ بأسمائهم ومبالغهم.
 */
create or replace function public.zad_enqueue_close_day()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int;
begin
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select x.user_id, 'close_day',
         jsonb_build_object(
           'local_date', x.local_date, 'time_zone', x.tz, 'currency', x.currency,
           'seen_count', (
             select count(*) from public.zad_transactions t
              where t.user_id = x.user_id and t.txn_kind = 'expense'
                and (t.created_at at time zone x.tz)::date = x.local_date::date),
           'seen', coalesce((
             select jsonb_agg(jsonb_build_object('name', s.name, 'amount', s.amount) order by s.created_at desc)
               from (
                 select coalesce(nullif(t.merchant_name, ''), nullif(t.title, ''), t.category) as name,
                        t.amount, t.created_at
                   from public.zad_transactions t
                  where t.user_id = x.user_id and t.txn_kind = 'expense'
                    and (t.created_at at time zone x.tz)::date = x.local_date::date
                  order by t.created_at desc
                  limit 3
               ) s), '[]'::jsonb)
         ),
         'close_day:' || x.local_date
  from (
    select au.id as user_id,
           u.currency,
           public.zad_market_timezone(u.country) as tz,
           to_char(now() at time zone public.zad_market_timezone(u.country), 'YYYY-MM-DD') as local_date,
           extract(hour from now() at time zone public.zad_market_timezone(u.country))::int as local_hour,
           extract(minute from now() at time zone public.zad_market_timezone(u.country))::int as local_minute
    from auth.users au
    join public.zad_users u on u.id = au.id
    where au.last_sign_in_at > now() - interval '14 days'
       or exists (select 1 from public.zad_fcm_tokens t where t.user_id = au.id and t.updated_at > now() - interval '14 days')
       or exists (select 1 from public.telegram_bindings b where b.user_id = au.id and b.chat_id is not null)
       or exists (select 1 from public.zad_chat_turns c where c.user_id = au.id and c.role = 'user' and c.created_at > now() - interval '14 days')
  ) x
  where x.local_hour = 21 and x.local_minute >= 30
    and not exists (select 1 from public.family_members fm where fm.user_id = x.user_id and fm.role = 'child')
    and not exists (select 1 from public.zad_day_closes d where d.user_id = x.user_id and d.local_date = x.local_date::date)
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_close_day() from public, anon, authenticated;

-- أمر 20261018180000 زي ما هو بالظبط + سطر القفلة. (مش الأقدم: ده بيرجّع نداءات الجرعات
-- والمواعيد اللي عملت deadlock مع reminders-minutely.)
select cron.schedule(
  'voice-moments-processor',
  '*/5 * * * *',
  $job$
  select public.zad_enqueue_morning_fallback();
  select public.zad_enqueue_good_night();
  select public.zad_enqueue_close_day();
  select public.zad_enqueue_newcomer_question();
  select public.zad_enqueue_weekly_money_story();
  select public.zad_evaluate_savings_challenges();
  select net.http_post(
      url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
      ),
      body := '{"action":"process_voice_moments"}'::jsonb,
      timeout_milliseconds := 55000
    ) as request_id
  where exists (
    select 1 from public.zad_voice_moments
    where status = 'pending' and created_at > now() - interval '6 hours'
  );
  $job$
);
