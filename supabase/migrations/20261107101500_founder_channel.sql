-- قناة المؤسس (طلب المالك ٦–٧/١١): تقرير كل أحد الصبح + تنبيه فوري للحاجات الحرجة، لشات الأدمن السري بس
-- (`zad_notify_admin` ⇒ بوت تليجرام ⇒ ZAD_ADMIN_CHAT_ID، وبيرفض لو الشات ده شات عميل — 20261010130000).
--
-- شروط المالك اللي اتفقنا عليها ٦/١١: **أرقام وعدّ بس، عمر ما اسم ولا حساب ولا مشتريات شخص معيّن** — ده بيانات مالية
-- العميل دخّلها لنفسه، وعرضها على المالك بيكسر سياسة الخصوصية وسياسة بيانات جوجل بلاي وقوانين حماية البيانات في
-- السعودية ومصر. والطلب حسب المدينة بيظهر بس لما ٥ بيوت مختلفة على الأقل في نفس المدينة (عيلة = بيت واحد) — نفس
-- أرضية zad_area_trends (20260930010000). حساب فحص القبول/التقييم (a11ce000-…) برّه كل رقم.
--
-- اللي كان موجود من الفوري: صحة العقل، العقل ساكت، الماسح، اللفة اللي بتلف، ميزانية الذكاء (التكلفة). الجديد هنا:
-- قراية البنك اتقفلت عند حد (bank.off)، وليلة تقييم حمرا — كل نوع مرة واحدة في اليوم بالكتير.

-- ── أرقام التقرير ─────────────────────────────────────────────────────────────────────────────────────────────

create or replace function public.zad_founder_report(p_now timestamptz default now())
returns text
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  c_probe constant uuid := 'a11ce000-0000-4000-8000-00000000a11a';
  c_floor constant int := 5;
  v_since timestamptz := p_now - interval '7 days';
  v_prev timestamptz := p_now - interval '14 days';
  v_lines text[] := '{}';
  v_total int; v_new int; v_active int; v_active_prev int; v_kept int; v_countries text;
  v_seen int; v_done int; v_first int;
  v_usage text;
  v_flowing int; v_off int;
  r record;
  v_green int; v_nights int; v_last jsonb;
  v_demand text;
begin
  -- 👥 الناس
  select count(*), count(*) filter (where created_at >= v_since)
    into v_total, v_new
    from zad_users where id <> c_probe;
  select coalesce(string_agg(n || ' ' || coalesce(country, '؟'), '، ' order by n desc), '')
    into v_countries
    from (select country, count(*) as n from zad_users where id <> c_probe group by country) b;

  select count(distinct user_id) filter (where at >= v_since),
         count(distinct user_id) filter (where at >= v_prev and at < v_since)
    into v_active, v_active_prev
    from zad_product_events where user_id is not null and user_id <> c_probe and at >= v_prev;
  select count(*) into v_kept from (
    select user_id from zad_product_events
     where user_id <> c_probe and at >= v_prev and at < v_since
    intersect
    select user_id from zad_product_events
     where user_id <> c_probe and at >= v_since
  ) k;

  v_lines := v_lines || ('👥 الناس: ' || v_total || ' حساب (' || v_countries || ')، جديد الأسبوع ده ' || v_new ||
    '، نشيط ' || v_active || ' (الأسبوع اللي فات ' || v_active_prev || '، رجع منهم ' || v_kept || ').');

  -- 🧭 أول خطوات
  select count(distinct user_id) filter (where name = 'onboarding.steps_shown'),
         count(distinct user_id) filter (where name = 'onboarding.done'),
         count(distinct user_id) filter (where name = 'onboarding.first_expense')
    into v_seen, v_done, v_first
    from zad_product_events where user_id <> c_probe and at >= v_since;
  v_lines := v_lines || ('🧭 أول خطوات (الأسبوع ده): شافوا الشرح ' || v_seen || ' ← خلّصوه ' || v_done ||
    ' ← سجّلوا أول مصروف ' || v_first || '.');

  -- 📱 الاستخدام: أكتر ٨ حاجات، بعدد الناس مش عدد الضغطات.
  select coalesce(string_agg(name || ' ' || n, '، ' order by n desc, name), 'مفيش')
    into v_usage
    from (select name, count(distinct user_id) as n from zad_product_events
           where user_id <> c_probe and at >= v_since
             and name not like 'onboarding.%' and name not like 'bank.%'
           group by name order by n desc, name limit 8) u;
  v_lines := v_lines || ('📱 الاستخدام (عدد الناس): ' || v_usage || '.');

  -- 🏦 قناة البنك
  select count(distinct user_id) filter (where name = 'bank.flowing'),
         count(distinct user_id) filter (where name = 'bank.off')
    into v_flowing, v_off
    from zad_product_events where user_id <> c_probe and at >= v_since;
  v_lines := v_lines || ('🏦 قراية البنك: شغالة عند ' || v_flowing || '، اتقفلت مرة على الأقل عند ' || v_off || '.');

  -- 🧠 العقل (zad_health_daily)
  select coalesce(sum(brain_runs), 0) as runs, coalesce(sum(brain_runs_failed), 0) as failed,
         round(coalesce(sum(brain_cost_usd), 0)::numeric, 2) as cost,
         max(brain_p90_secs) as p90,
         coalesce(sum(guardian_delivered), 0) as delivered, coalesce(sum(guardian_replied), 0) as replied,
         coalesce(sum(guardian_acted), 0) as acted
    into r
    from zad_health_daily where user_id <> c_probe and day >= (v_since at time zone 'utc')::date;
  v_lines := v_lines || ('🧠 العقل: ' || r.runs || ' لفة، فشل ' || r.failed || '، التكلفة المسعّرة $' || r.cost ||
    coalesce('، أبطأ p90 ' || round(r.p90::numeric, 1) || ' ثانية', '') ||
    '. التنبيهات: وصل ' || r.delivered || '، اترد ' || r.replied || '، اتعمل بيه ' || r.acted || '.');

  -- ✅ التقييم الليلي (آخر ٧ ليالي)
  select count(*) filter (where (public.zad_eval_verdict(d.day) ->> 'green')::boolean), count(*)
    into v_green, v_nights
    from (select day from zad_eval_nights where day >= (v_since at time zone 'utc')::date) d;
  select public.zad_eval_verdict(max(day)) into v_last from zad_eval_nights;
  v_lines := v_lines || ('✅ التقييم: ' || v_green || ' ليلة خضرا من ' || v_nights ||
    coalesce('، آخر ليلة ' || (v_last ->> 'pct') || '٪ وفشل أمان ' || (v_last ->> 'safety_failed'), '') || '.');

  -- 🛒 الطلب حسب المدينة: صنف دخل قايمة شرا ٥ بيوت أو أكتر في نفس المدينة الأسبوع ده.
  with homes as (
    select s.item_name,
           lower(btrim(p.city)) as city_key, min(btrim(p.city)) over (partition by lower(btrim(p.city))) as city,
           coalesce(s.family_id::text, s.user_id::text) as home
      from zad_shopping_list s
      join zad_customer_profile p on p.user_id = s.user_id
     where s.created_at >= v_since and s.user_id <> c_probe and coalesce(btrim(p.city), '') <> ''
  ), items as (
    select city, lower(btrim(item_name)) as item, min(btrim(item_name)) as label, count(distinct home) as n
      from homes group by city, lower(btrim(item_name))
    having count(distinct home) >= c_floor
  ), ranked as (
    select city, label, n, row_number() over (partition by city order by n desc, label) as rk from items
  )
  select string_agg(city || ': ' || list, ' · ' order by city)
    into v_demand
    from (select city, string_agg(label || ' (' || n || ' بيت)', '، ' order by rk) as list
            from ranked where rk <= 5 group by city) c;
  v_lines := v_lines || ('🛒 الطلب حسب المدينة: ' || coalesce(v_demand,
    'لسه مفيش صنف دخل قايمة ' || c_floor || ' بيوت في نفس المدينة — الأرقام دي بتظهر لوحدها لما العدد يكبر') || '.');

  v_lines := v_lines || '🔒 كل الأرقام عدد ناس أو بيوت — مفيش أسامي ولا حسابات.'::text;
  return array_to_string(v_lines, E'\n\n');
end;
$$;

revoke all on function public.zad_founder_report(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_founder_report(timestamptz) to service_role;

-- ── الإرسال ──────────────────────────────────────────────────────────────────────────────────────────────────

create or replace function public.zad_founder_weekly()
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  perform public.zad_notify_admin('📊 تقرير زاد الأسبوعي', public.zad_founder_report());
end;
$$;

revoke all on function public.zad_founder_weekly() from public, anon, authenticated;

-- مرة لكل نوع في اليوم (UTC): التنبيه الفوري مايبقاش زن.
create table if not exists public.zad_founder_alerts (
  kind text not null,
  day date not null,
  sent_at timestamptz not null default now(),
  primary key (kind, day)
);
alter table public.zad_founder_alerts enable row level security;
revoke all on public.zad_founder_alerts from anon, authenticated;

create or replace function public.zad_founder_watch(p_now timestamptz default now())
returns int
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  c_probe constant uuid := 'a11ce000-0000-4000-8000-00000000a11a';
  v_day date := (p_now at time zone 'utc')::date;
  v_sent int := 0;
  v_off int;
  v_eval jsonb;
begin
  -- 🏦 قراية البنك اتقفلت عند حد آخر ساعتين.
  select count(distinct user_id) into v_off
    from zad_product_events
   where name = 'bank.off' and user_id <> c_probe and at >= p_now - interval '2 hours' and at <= p_now;
  if v_off > 0 then
    insert into zad_founder_alerts (kind, day) values ('bank_off', v_day) on conflict do nothing;
    if found then
      perform public.zad_notify_admin('🏦 قراية البنك اتقفلت',
        'قراية إشعارات البنك اتقفلت عند ' || v_off || ' حساب آخر ساعتين. التطبيق بيطلب منهم يرجّعوها؛ ' ||
        'لو العدد كبر، شوف تحديث أندرويد أو البطارية.');
      v_sent := v_sent + 1;
    end if;
  end if;

  -- ✅ ليلة التقييم خلصت وحمرا.
  v_eval := public.zad_eval_verdict(v_day);
  if (v_eval ->> 'finished')::boolean and not (v_eval ->> 'green')::boolean then
    insert into zad_founder_alerts (kind, day) values ('eval_red', v_day) on conflict do nothing;
    if found then
      perform public.zad_notify_admin('🔴 التقييم الليلي أحمر',
        (v_eval ->> 'passed') || ' من ' || (v_eval ->> 'ran') || ' (' || (v_eval ->> 'pct') || '٪)، فشل أمان ' ||
        (v_eval ->> 'safety_failed') || '. الحالات: ' || coalesce(v_eval -> 'failed_cases' #>> '{}', '—'));
      v_sent := v_sent + 1;
    end if;
  end if;
  return v_sent;
end;
$$;

revoke all on function public.zad_founder_watch(timestamptz) from public, anon, authenticated;

-- ── المواعيد ─────────────────────────────────────────────────────────────────────────────────────────────────
-- الأحد ٠٥:٠٥ UTC = ٧:٠٥ الصبح القاهرة / ٨:٠٥ الرياض. المراقبة كل ساعة عند :٣٧.

select cron.unschedule('founder-weekly') where exists (select 1 from cron.job where jobname = 'founder-weekly');
select cron.schedule('founder-weekly', '5 5 * * 0', $cron$ select public.zad_founder_weekly(); $cron$);

select cron.unschedule('founder-watch') where exists (select 1 from cron.job where jobname = 'founder-watch');
select cron.schedule('founder-watch', '37 * * * *', $cron$ select public.zad_founder_watch(); $cron$);
