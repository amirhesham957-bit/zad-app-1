-- قناة المؤسس — الجزء التاني (طلب المالك ٧/١١ كمدير منتج): السوق والتنبؤ، والمشاكل، وفين الناس بتقف.
--
-- نفس شروط ٦/١١ (20261107101500): عدّ ناس وبيوت بس، عمر ما اسم ولا حساب ولا مشتريات شخص. الصنف والمحل بيظهروا
-- بس لو ٥ بيوت مختلفة على الأقل (عيلة = بيت واحد)، وحساب الفحص (a11ce000-…) برّه. تليجرام بيقبل ٤٠٩٦ حرف في
-- الرسالة، فالتقرير بقى ٣ رسايل: الناس والمنتج، السوق والتنبؤ، المشاكل.
--
-- المقاس ٧/١١ قبلها: صفر تذاكر دعم، ٧ لفات عقل فاشلة في الأسبوع (كلها تقريباً «every gemini model unavailable» —
-- الكوتة المجانية)، تصحيح واحد، ومشترك pro واحد من ٢٢. فـ«المشاكل الشائعة» بتتصنّف من إشارات الفشل الحقيقية
-- (العقل، البنك، التذاكر لما توصل) مش من التذاكر لوحدها.

-- البيت: عيلته لو في عيلة، وإلا هو.
create or replace function public.zad_home_of(p_user uuid)
returns text
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce((select fm.family_id::text from family_members fm where fm.user_id = p_user limit 1), p_user::text)
$$;
revoke all on function public.zad_home_of(uuid) from public, anon, authenticated;

-- ── فين الناس بتقف ────────────────────────────────────────────────────────────────────────────────────────────
-- آخر حاجة عملها كل واحد مافتحش التطبيق من ٧ أيام (وكان نشيط في الـ٣٠ يوم): لو أغلبهم آخر حاجة «شرح البداية»،
-- البداية هي اللي بتطفّش. والشاشات: عدد الناس اللي فتحوا كل قسم/تاب الأسبوع ده.
create or replace function public.zad_founder_dropoff(p_now timestamptz default now())
returns text
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  c_probe constant uuid := 'a11ce000-0000-4000-8000-00000000a11a';
  v_screens text;
  v_last text;
  v_gone int;
  v_d1 int; v_d7 int; v_new14 int;
begin
  select coalesce(string_agg(name || ' ' || n, '، ' order by n desc, name), 'مفيش')
    into v_screens
    from (select name, count(distinct user_id) as n from zad_product_events
           where user_id <> c_probe and at >= p_now - interval '7 days'
             and (name like 'tab.%' or name like 'section.%')
           group by name order by n desc, name limit 10) s;

  with last_seen as (
    select distinct on (user_id) user_id, name, at
      from zad_product_events
     where user_id <> c_probe and at >= p_now - interval '30 days'
     order by user_id, at desc
  ), gone as (select * from last_seen where at < p_now - interval '7 days')
  select (select count(*) from gone),
         coalesce((select string_agg(name || ' ' || n, '، ' order by n desc, name)
                     from (select name, count(*) as n from gone group by name order by n desc, name limit 6) g), '—')
    into v_gone, v_last;

  -- رجوع الجداد: اتسجلوا من ٢–١٤ يوم؛ رجعوا تاني يوم؟ رجعوا بعد أسبوع؟
  select count(*),
         count(*) filter (where exists (select 1 from zad_product_events e where e.user_id = u.id
                                         and e.at >= u.created_at + interval '1 day' and e.at < u.created_at + interval '2 days')),
         count(*) filter (where exists (select 1 from zad_product_events e where e.user_id = u.id
                                         and e.at >= u.created_at + interval '7 days'))
    into v_new14, v_d1, v_d7
    from zad_users u
   where u.id <> c_probe and u.created_at >= p_now - interval '14 days' and u.created_at < p_now - interval '2 days';

  return '🖥️ الشاشات (عدد الناس الأسبوع ده): ' || v_screens || '.' || E'\n\n' ||
         '🚪 فين بيقفوا: ' || v_gone || ' مافتحوش من أسبوع؛ آخر حاجة عملوها: ' || v_last || '.' || E'\n\n' ||
         '↩️ الجداد (آخر أسبوعين، ' || v_new14 || '): رجعوا تاني يوم ' || v_d1 || '، ولسه موجودين بعد أسبوع ' || v_d7 || '.';
end;
$$;
revoke all on function public.zad_founder_dropoff(timestamptz) from public, anon, authenticated;

-- ── السوق والتنبؤ ─────────────────────────────────────────────────────────────────────────────────────────────
create or replace function public.zad_founder_market(p_now timestamptz default now())
returns text
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  c_probe constant uuid := 'a11ce000-0000-4000-8000-00000000a11a';
  c_floor constant int := 5;
  v_top text; v_spike text; v_soon text; v_stores text;
  c_none constant text := 'لسه مفيش (أقل من ' || 5 || ' بيوت)';
begin
  -- الأكتر طلباً: صنف دخل قايمة شرا كام بيت في بلده الأسبوع ده.
  with w as (
    select u.country, lower(btrim(s.item_name)) as item, min(btrim(s.item_name)) as label,
           count(distinct public.zad_home_of(s.user_id)) filter (where s.created_at >= p_now - interval '7 days') as now_n,
           count(distinct public.zad_home_of(s.user_id)) filter (where s.created_at < p_now - interval '7 days') as prev_n
      from zad_shopping_list s join zad_users u on u.id = s.user_id
     where s.user_id <> c_probe and s.created_at >= p_now - interval '14 days' and coalesce(btrim(s.item_name), '') <> ''
     group by u.country, lower(btrim(s.item_name))
  )
  select (select string_agg(country || ': ' || list, ' · ' order by country)
            from (select country, string_agg(label || ' (' || now_n || ')', '، ' order by now_n desc, label) as list
                    from (select *, row_number() over (partition by country order by now_n desc, label) rk
                            from w where now_n >= c_floor) r where rk <= 6 group by country) a),
         (select string_agg(country || ': ' || list, ' · ' order by country)
            from (select country, string_agg(label || ' (' || prev_n || '←' || now_n || ')', '، ' order by now_n desc) as list
                    from w where now_n >= c_floor and now_n >= 2 * greatest(prev_n, 1) group by country) b)
    into v_top, v_spike;

  -- هيخلص الأسبوع الجاي: من دورة كل صنف (item_cycles، المرحلة ٣)، كام بيت في المدينة.
  with c as (
    select coalesce(nullif(btrim(p.city), ''), u.country) as area, lower(btrim(x ->> 'item')) as item,
           min(btrim(x ->> 'item')) as label, count(distinct public.zad_home_of(b.user_id)) as n
      from user_behavior_profile b
      join zad_users u on u.id = b.user_id
      left join zad_customer_profile p on p.user_id = b.user_id
      cross join lateral jsonb_array_elements(coalesce(b.item_cycles, '[]'::jsonb)) x
     where b.user_id <> c_probe and (x ->> 'due_in_days') ~ '^-?\d+$' and (x ->> 'due_in_days')::int between 0 and 7
     group by 1, 2
    having count(distinct public.zad_home_of(b.user_id)) >= c_floor
  )
  select string_agg(area || ': ' || list, ' · ' order by area)
    into v_soon
    from (select area, string_agg(label || ' (' || n || ' بيت)', '، ' order by n desc, label) as list
            from (select *, row_number() over (partition by area order by n desc, label) rk from c) r
           where rk <= 6 group by area) a;

  -- المحلات الصاعدة: كام بيت صرف فيها الأسبوع ده قصاد اللي قبله.
  with t as (
    select u.country, lower(btrim(t.merchant_name)) as store, min(btrim(t.merchant_name)) as label,
           count(distinct public.zad_home_of(t.user_id)) filter (where t.created_at >= p_now - interval '7 days') as now_n,
           count(distinct public.zad_home_of(t.user_id)) filter (where t.created_at < p_now - interval '7 days') as prev_n
      from zad_transactions t join zad_users u on u.id = t.user_id
     where t.user_id <> c_probe and t.created_at >= p_now - interval '14 days'
       and coalesce(t.is_expense, true) and coalesce(btrim(t.merchant_name), '') <> ''
       and t.merchant_name !~* '^(com|org|net)\.'
     group by u.country, lower(btrim(t.merchant_name))
  )
  select string_agg(country || ': ' || list, ' · ' order by country)
    into v_stores
    from (select country, string_agg(label || ' (' || prev_n || '←' || now_n || ' بيت)', '، ' order by now_n - prev_n desc) as list
            from t where now_n >= c_floor and now_n > prev_n group by country) a;

  return '🔥 الأكتر طلباً الأسبوع ده (بيوت حطّته في قايمة الشرا): ' || coalesce(v_top, c_none) || '.' || E'\n\n' ||
         '📈 قفزة مفاجئة (الأسبوع اللي فات ← ده): ' || coalesce(v_spike, c_none) || '.' || E'\n\n' ||
         '⏳ هيخلص عند الناس الأسبوع الجاي (من دورة كل صنف): ' || coalesce(v_soon, c_none) || '.' || E'\n\n' ||
         '🏪 محلات صاعدة: ' || coalesce(v_stores, c_none) || '.' || E'\n\n' ||
         '🔒 كل رقم عدد بيوت، ومن ٥ بيوت وطالع بس.';
end;
$$;
revoke all on function public.zad_founder_market(timestamptz) from public, anon, authenticated;

-- ── المشاكل الشائعة ───────────────────────────────────────────────────────────────────────────────────────────
-- تصنيف ثابت (من غير موديل) لإشارات الفشل الحقيقية: أخطاء العقل، البنك، والتذاكر حسب موضوعها.
create or replace function public.zad_problem_kind(p_text text)
returns text
language sql
immutable
as $$
  select case
    when p_text ~* 'gemini model unavailable|quota|429|rate limit|ProviderUnavailable' then 'الذكاء مش متاح (الكوتة المجانية خلصت)'
    when p_text ~* 'timeout|timed out|aborted|deadline' then 'الرد اتأخر ووقف (timeout)'
    when p_text ~* '42703|42P01|column|relation .* does not exist' then 'غلطة في الداتابيز (عمود/جدول)'
    when p_text ~* 'tool_use_failed|tool' then 'أداة فشلت'
    when p_text ~* 'بنك|البنك|اشعار|إشعار|رسايل|رسالة|bank|notification|sms' then 'قراية البنك والإشعارات'
    when p_text ~* 'اشتراك|دفع|فلوس اتخصمت|باقة|subscription|payment|billing|refund' then 'الاشتراك والدفع'
    when p_text ~* 'دخول|باسورد|كلمة السر|حساب|login|password|otp|كود' then 'الدخول والحساب'
    when p_text ~* 'بطيء|تقيل|بيقفل|crash|يقفل|هنج|معلق' then 'البطء أو التطبيق بيقفل'
    when p_text ~* 'فاتورة|كاميرا|صورة|scan|receipt' then 'تصوير الفواتير'
    when p_text ~* 'تليجرام|البوت|telegram|bot' then 'بوت تليجرام'
    else 'تانية'
  end
$$;

create or replace function public.zad_founder_problems(p_now timestamptz default now())
returns text
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  c_probe constant uuid := 'a11ce000-0000-4000-8000-00000000a11a';
  v_brain text; v_brain_people int; v_tickets text; v_ticket_n int; v_bank_off int; v_bank_stalled int;
begin
  select coalesce(string_agg(kind || ' ' || n || ' مرة (' || people || ' شخص)', '، ' order by n desc), 'مفيش'),
         coalesce(sum(people), 0)
    into v_brain, v_brain_people
    from (select public.zad_problem_kind(coalesce(error, '')) as kind, count(*) as n, count(distinct user_id) as people
            from zad_brain_runs
           where status = 'failed' and user_id <> c_probe and started_at >= p_now - interval '7 days'
           group by 1) k;

  select coalesce(string_agg(kind || ' ' || n, '، ' order by n desc), '')
    into v_tickets
    from (select public.zad_problem_kind(coalesce(subject, '') || ' ' || coalesce(message, '')) as kind, count(*) as n
            from zad_support_tickets where created_at >= p_now - interval '7 days'
           group by 1) t;
  select coalesce(sum(n), 0) into v_ticket_n
    from (select count(*) as n from zad_support_tickets where created_at >= p_now - interval '7 days') x;

  select count(distinct user_id) filter (where name = 'bank.off'),
         count(distinct user_id) filter (where name = 'bank.stalled')
    into v_bank_off, v_bank_stalled
    from zad_product_events where user_id <> c_probe and at >= p_now - interval '7 days';

  return '🧯 أعطال العقل الأسبوع ده: ' || v_brain || '.' || E'\n\n' ||
         '🏦 البنك: قرايته اتقفلت عند ' || v_bank_off || '، ووقفت تستقبل عند ' || v_bank_stalled || '.' || E'\n\n' ||
         '🎫 تذاكر الدعم: ' || case when v_ticket_n = 0 then 'مفيش تذاكر الأسبوع ده'
                                   else v_ticket_n || ' — ' || v_tickets end || '.';
end;
$$;
revoke all on function public.zad_founder_problems(timestamptz) from public, anon, authenticated;

-- ── الإرسال: ٣ رسايل ──────────────────────────────────────────────────────────────────────────────────────────
-- تقرير الناس والمنتج = اللي كان + فين بيقفوا. كل رسالة مقصوصة عند ٣٩٠٠ حرف (حد تليجرام ٤٠٩٦ مع العنوان).
create or replace function public.zad_founder_weekly()
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  perform public.zad_notify_admin('📊 تقرير زاد الأسبوعي — الناس والمنتج',
    left(public.zad_founder_report() || E'\n\n' || public.zad_founder_dropoff(), 3900));
  perform public.zad_notify_admin('🛒 السوق والتنبؤ', left(public.zad_founder_market(), 3900));
  perform public.zad_notify_admin('🧯 المشاكل الشائعة', left(public.zad_founder_problems(), 3900));
end;
$$;
revoke all on function public.zad_founder_weekly() from public, anon, authenticated;
