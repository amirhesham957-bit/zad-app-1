-- حكاية البيت الشهرية (ZAD_PLAN ٥.٢، الشريحة التالتة بعد 20261027001500 و20261027013000).
--
-- «فين راحت فلوسي؟» بيتقال كل جمعة (zad_enqueue_weekly_money_story، ٥ مرات لبيت واحد من ١٨/٩ لـ٢٣/١٠)، ومفيش
-- حاجة بتبص على الشهر كله. هنا: يوم ١ في الشهر الساعة ٦ المسا بتوقيت سوق الحساب، لحظة monthly_story بأرقام
-- الشهر اللي فات، محسوبة هنا وقت الإدخال (مش وقت الإرسال) عشان إعادة المحاولة تقول نفس الشهر.
--
-- الأرقام بنفس تعريف الأسبوعي (voiceMoments.weeklyMoneyFacts): txn_kind = 'expense' وcounts_toward_budget مش
-- false. الجديد:
--   • الشهر قصاد اللي قبله، وأغلى أسبوع وأرخص أسبوع (أسابيع الشهر بتوقيت السوق، من الاتنين).
--   • أكبر ٣ فئات. من غير أسامي تجار ولا عناوين حركات: الأسبوعي قال مرة «com.google.android.apps.messaging»
--     كأكبر مصروف (اسم باكدج، ٢/١٠)، والحكاية الشهرية مش هتكرره.
--   • «اتعلمت إن» اللي العميل قال عليها «صح» الشهر ده (zad_house_learnings).
-- أقل من ٥ مصروفات في الشهر = مفيش حكاية (مانختلقش).

create or replace function public.zad_monthly_story_facts(p_user uuid, p_month date)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
declare
  v_zone text;
  v_from timestamptz;
  v_to timestamptz;
  v_prev_from timestamptz;
  v_spent numeric;
  v_prev numeric;
  v_n int;
  v_days int;
  v_tops jsonb;
  v_weeks jsonb;
  v_learned jsonb;
  v_currency text;
begin
  select public.zad_market_timezone(u.country), u.currency into v_zone, v_currency from public.zad_users u where u.id = p_user;
  v_zone := coalesce(v_zone, 'Africa/Cairo');
  v_from := date_trunc('month', p_month)::timestamp at time zone v_zone;
  v_to := (date_trunc('month', p_month) + interval '1 month')::timestamp at time zone v_zone;
  v_prev_from := (date_trunc('month', p_month) - interval '1 month')::timestamp at time zone v_zone;

  select coalesce(sum(t.amount), 0), count(*), count(distinct (t.created_at at time zone v_zone)::date)
    into v_spent, v_n, v_days
    from public.zad_transactions t
   where t.user_id = p_user and t.txn_kind = 'expense' and t.counts_toward_budget is not false
     and t.created_at >= v_from and t.created_at < v_to;
  if v_n < 5 then
    return null;
  end if;

  select coalesce(sum(t.amount), 0) into v_prev
    from public.zad_transactions t
   where t.user_id = p_user and t.txn_kind = 'expense' and t.counts_toward_budget is not false
     and t.created_at >= v_prev_from and t.created_at < v_from;

  select coalesce(jsonb_agg(jsonb_build_object('name', c.cat, 'amount', round(c.total)) order by c.total desc), '[]'::jsonb)
    into v_tops
    from (
      select coalesce(nullif(trim(t.category), ''), 'غير مصنّف') as cat, sum(t.amount) as total
        from public.zad_transactions t
       where t.user_id = p_user and t.txn_kind = 'expense' and t.counts_toward_budget is not false
         and t.created_at >= v_from and t.created_at < v_to
       group by 1 order by 2 desc limit 3
    ) c;

  select jsonb_build_object(
           'count', count(*),
           'highest', (array_agg(jsonb_build_object('from', w.wk, 'spent', round(w.total)) order by w.total desc))[1],
           'lowest', (array_agg(jsonb_build_object('from', w.wk, 'spent', round(w.total)) order by w.total asc))[1]
         )
    into v_weeks
    from (
      select greatest(date_trunc('week', t.created_at at time zone v_zone)::date, date_trunc('month', p_month)::date) as wk,
             sum(t.amount) as total
        from public.zad_transactions t
       where t.user_id = p_user and t.txn_kind = 'expense' and t.counts_toward_budget is not false
         and t.created_at >= v_from and t.created_at < v_to
       group by 1
    ) w;

  select coalesce(jsonb_agg(l.note order by l.answered_at), '[]'::jsonb) into v_learned
    from public.zad_house_learnings l
   where l.user_id = p_user and l.answer = 'yes' and l.answered_at >= v_from and l.answered_at < v_to;

  return jsonb_build_object(
    'month', to_char(date_trunc('month', p_month), 'YYYY-MM'),
    'time_zone', v_zone,
    'currency', v_currency,
    'spent', round(v_spent),
    'last_month_spent', round(v_prev),
    'change_pct', case when v_prev > 0 then round(100 * (v_spent - v_prev) / v_prev) end,
    'txn_count', v_n,
    'days_with_spending', v_days,
    'top_categories', v_tops,
    'weeks', v_weeks,
    'learned', v_learned,
    'source', 'zad_transactions'
  );
end
$fn$;

revoke all on function public.zad_monthly_story_facts(uuid, date) from public, anon, authenticated;
grant execute on function public.zad_monthly_story_facts(uuid, date) to service_role;

/** يوم ١ الساعة ٦ المسا بتوقيت السوق: حكاية الشهر اللي فات، لنفس العملاء النشطين بتوع الحكاية الأسبوعية. */
create or replace function public.zad_enqueue_monthly_story(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_inserted int;
begin
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select x.user_id, 'monthly_story', f.facts, 'monthly_story:' || (f.facts ->> 'month')
    from (
      -- يوم ١ الساعة ٦ بس، قبل أي حساب: الدالة بتتنادى كل ساعة لكل العملاء.
      select au.id as user_id, (p_now at time zone public.zad_market_timezone(u.country))::date - 1 as last_day
        from auth.users au
        join public.zad_users u on u.id = au.id
       where (au.last_sign_in_at > p_now - interval '14 days'
              or exists (select 1 from public.zad_fcm_tokens t where t.user_id = au.id and t.updated_at > p_now - interval '14 days'))
         and extract(day from p_now at time zone public.zad_market_timezone(u.country)) = 1
         and extract(hour from p_now at time zone public.zad_market_timezone(u.country)) = 18
    ) x
    cross join lateral (select public.zad_monthly_story_facts(x.user_id, x.last_day) as facts) f
   where f.facts is not null
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end
$fn$;

revoke all on function public.zad_enqueue_monthly_story(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_enqueue_monthly_story(timestamptz) to service_role;

do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  -- كل ساعة عند الدقيقة ٣: الدالة نفسها بتختار يوم ١ الساعة ٦ المسا لكل سوق، ومعالج اللحظات (كل ٥ دقايق) بيبعتها.
  perform cron.schedule('monthly-story', '3 * * * *', $job$ select public.zad_enqueue_monthly_story(); $job$);
end
$cron$;
