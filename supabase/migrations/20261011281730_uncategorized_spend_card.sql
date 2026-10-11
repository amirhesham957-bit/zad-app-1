-- «اتسجّل مصروف تحت أخرى — كان على إيه؟» — فجوة ١ من الفحص الذاتي (٢٠٢٦-١٠-١١).
--
-- مقيس على الحي ٢٠٢٦-١٠-١١: ٢٣ من ٣٩ مصروف متسجّلين «أخرى» أو من غير تصنيف، و٣ من ١٣
-- في آخر ٣٠ يوم — التلاتة رسايل بنك (notification_listener). محدش كان بيسأل عنهم، فتقرير
-- المصاريف بيقول «أخرى» على أكبر بند عنده. الماسح الساعي بقى يكتب كارت سؤال واحد على الرئيسية
-- بيسمّي المصاريف دي، والعميل يرد («بنزين وسوبرماركت») فالرد بيروح للوكيل زي أي رسالة،
-- والوكيل يصنّفها بأداة set_transaction_category اللي موجودة أصلاً. صفر نداء موديل في الماسح.
--
-- القواعد:
--   • المصروف بيتسأل عنه مرة واحدة: بس اللي اتسجّل بعد آخر كارت من النوع ده (وفي آخر ٤٨ ساعة).
--   • كارت واحد مفتوح بس، ومش أكتر من كارت في اليوم (dedupe_key باليوم بتوقيت سوق العميل).
--   • سقف الانتباه: لو قدامه ٣ كروت مفتوحة بالفعل (نفس عدّ attention.ts openCards) مابنزودش.
--   • «مش مهم ليا» على الكارت = سكوت ٣٠ يوم عن النوع ده.
--   • مابيتكتبش في ساعات الهدوء: الكارت سؤال، وتريجر notify_telegram_on_insight بيبعت أي
--     سؤال جديد لتليجرام فورًا — من غير الحارس ده كان هيوصل الساعة ٣ الفجر.
--   • التاجر: merchant_name لو اسم حقيقي. قناة البنك بتكتب فيه اسم باكدج تطبيق الرسايل
--     (com.google.android.apps.messaging — مقيس على الحي)، فساعتها بنستخدم العنوان («BDC»).
--     النص من العميل/البنك: بيتشال منه «» والسطور ويتقص ٤٠ حرف، وبيتحط بين «» كبيانات.
--
-- الماسح نفسه بيتعدّل على نصه الحي، مش بيتكتب من نسخة قديمة (ZAD_LIVING_BRAIN.md §١١، ونفس
-- طريقة 20261010130000): قايمة المراحل اللي آخرها 'predicted_shortage' لازم تتلاقي مرة واحدة
-- بالظبط، وإلا الميجريشن بتقف. أي فشل جوه المرحلة بيطلع للماسح فبيتعد في failed بدل ما يتبلع.

-- ساعات الهدوء — نسخة SQL من zad-brain/shared.ts quietWindowOf + isQuietHourIn بالظبط
-- (نافذة نوم العميل لو جوه الحدود، وإلا ١١ بالليل لـ٧ الصبح). scanCards_test.ts بيقارن الاتنين
-- على كل ساعة نوم × ساعة صحيان × ساعة في اليوم، عشان مايفترقوش.
create or replace function public._zad_quiet_hour_at(p_bed time, p_wake time, p_local_hour int)
returns boolean
language sql
immutable
set search_path to 'public'
as $fn$
  select case when w.s > w.e then p_local_hour >= w.s or p_local_hour < w.e
              else p_local_hour >= w.s and p_local_hour < w.e end
  from (
    select case when v.ok then extract(hour from p_bed)::int else 23 end as s,
           case when v.ok then extract(hour from p_wake)::int
                               + case when extract(minute from p_wake) > 0 then 1 else 0 end
                else 7 end as e
    from (
      select p_bed is not null and p_wake is not null
             and (extract(hour from p_bed) >= 20 or extract(hour from p_bed) <= 3)
             and extract(hour from p_wake) between 4 and 12 as ok
    ) v
  ) w;
$fn$;

comment on function public._zad_quiet_hour_at(time, time, int) is
  'ساعة محلية جوه هدوء العميل؟ نسخة من quietWindowOf/isQuietHourIn في zad-brain/shared.ts — اختبار التطابق في scanCards_test.ts.';

revoke execute on function public._zad_quiet_hour_at(time, time, int) from public, anon, authenticated;
grant execute on function public._zad_quiet_hour_at(time, time, int) to service_role;

create or replace function public._agent_uncategorized_spend_for_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_tz text;
  v_currency text;
  v_bed time;
  v_wake time;
  v_since timestamptz;
  v_count int;
  v_list text;
  v_amounts text;
  v_title text;
  v_body text;
begin
  select public.zad_market_timezone(u.country), u.currency, u.sleep_bed, u.sleep_wake
    into v_tz, v_currency, v_bed, v_wake
  from public.zad_users u where u.id = p_user;
  if v_tz is null then
    return;
  end if;

  if public._zad_quiet_hour_at(v_bed, v_wake, extract(hour from now() at time zone v_tz)::int) then
    return;
  end if;

  -- «مش مهم ليا» من آخر ٣٠ يوم، أو كارت لسه مفتوح.
  if exists (
    select 1 from public.zad_insights i
    where i.user_id = p_user and i.dedupe_key like 'uncategorized\_spend\_%'
      and ((i.status = 'dismissed' and i.dismiss_reason = 'not_relevant' and i.updated_at > now() - interval '30 days')
        or (i.status = 'pending' and (i.expires_at is null or i.expires_at > now())))
  ) then
    return;
  end if;

  -- سقف الانتباه — نفس شروط openCards في attention.ts (والسقف العادي ٣).
  if (
    select count(*) from public.zad_insights i
    where i.user_id = p_user and i.status = 'pending'
      and (i.expires_at is null or i.expires_at > now())
      and i.priority <> 'critical'
      and coalesce(i.surface, 'home_card') <> 'voice'
      and position(':' in coalesce(i.dedupe_key, '')) = 0
      and i.created_at > now() - interval '72 hours'
  ) >= 3 then
    return;
  end if;

  select greatest(now() - interval '48 hours', coalesce(max(i.created_at), '-infinity'::timestamptz))
    into v_since
  from public.zad_insights i
  where i.user_id = p_user and i.dedupe_key like 'uncategorized\_spend\_%';

  select count(*)::int,
         string_agg(case when x.rn <= 3 then
                      format('%s %s%s', x.amt, x.cur, case when x.label <> '' then format(' «%s»', x.label) else '' end)
                    end, '، ' order by x.rn),
         string_agg(case when x.rn <= 3 then x.amt end, ' و' order by x.rn)
    into v_count, v_list, v_amounts
  from (
    select trim_scale(round(t.amount::numeric, 2))::text as amt,
           coalesce(nullif(trim(t.currency), ''), v_currency, '') as cur,
           left(regexp_replace(
             case when coalesce(trim(t.merchant_name), '') = ''
                       or t.merchant_name ~ '^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$'
                  then coalesce(t.title, '')
                  else t.merchant_name end,
             '[«»\r\n]', '', 'g'), 40) as label,
           row_number() over (order by t.created_at desc) as rn
    from public.zad_transactions t
    where t.user_id = p_user
      and coalesce(t.is_expense, true)
      and t.txn_kind = 'expense'
      and t.amount > 0
      and coalesce(nullif(trim(t.category), ''), 'أخرى') in ('أخرى', 'اخرى', 'other', 'Other')
      and t.created_at > v_since
  ) x;

  if v_count = 0 then
    return;
  end if;

  v_title := 'مصاريف من غير تصنيف: ' || v_amounts || case when v_count > 3 then ' وغيرهم' else '' end;
  v_body := case
    when v_count = 1 then format('اتسجّل مصروف تحت «أخرى»: %s. كان على إيه؟ قولّي وأنا أصنّفه، عشان تقرير مصاريفك يبقى صح.', v_list)
    else format('اتسجّل %s تحت «أخرى» آخر يومين: %s%s. كانوا على إيه؟ قولّي وأنا أصنّفهم، عشان تقرير مصاريفك يبقى صح.',
                case when v_count = 2 then 'مصروفين' when v_count <= 10 then v_count || ' مصاريف' else v_count || ' مصروف' end,
                v_list, case when v_count > 3 then ' وغيرهم' else '' end)
  end;

  insert into public.zad_insights (user_id, kind, surface, priority, title, body, dedupe_key, about_item, expires_at)
  values (
    p_user, 'question', 'home_card', 'normal', v_title, v_body,
    'uncategorized_spend_' || to_char(now() at time zone v_tz, 'YYYY-MM-DD'),
    'المصاريف من غير تصنيف',
    now() + interval '72 hours'
  )
  on conflict (user_id, dedupe_key) do nothing;
end;
$fn$;

comment on function public._agent_uncategorized_spend_for_user(uuid) is
  'مصاريف «أخرى» جديدة من آخر ٤٨ ساعة: كارت سؤال واحد على الرئيسية يسمّيها، والرد بيروح للوكيل يصنّفها. كل مصروف بيتسأل عنه مرة.';

revoke execute on function public._agent_uncategorized_spend_for_user(uuid) from public, anon, authenticated;
grant execute on function public._agent_uncategorized_spend_for_user(uuid) to service_role;

do $migrate$
declare
  v_def text;
  v_pat constant text := '''predicted_shortage''\]';
  v_hits int;
begin
  select pg_get_functiondef('public.agent_proactive_scan()'::regprocedure) into v_def;
  v_hits := regexp_count(v_def, v_pat);
  if v_hits <> 1 then
    raise exception 'uncategorized_spend: agent_proactive_scan has % stage lists ending in predicted_shortage, expected 1', v_hits;
  end if;
  execute regexp_replace(v_def, v_pat, '''predicted_shortage'', ''uncategorized_spend'']');
end
$migrate$;
