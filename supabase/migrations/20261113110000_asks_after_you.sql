-- «زاد يسأل عليك» لما تغيب (ZAD_PLAN ١٠.١٢، المالك وافق ١١/١١): رسالة صوتية على تليجرام وإشعار.
--
-- اتقاس ١٣/١١ على الحي: ٢١ عميل ليهم نشاط (فتح التطبيق `app_open` أو رسالة منهم في zad_chat_turns)؛ ٥ منهم
-- ساكتين ~١٢ يوم وكل واحد كان بيوصله ~٢٠ رسالة من زاد في الأسبوع، أغلبها نداء زادو (اتسكت بـ20261113090000)،
-- و٦ مابيفتحوش التطبيق بس لسه بيكلّموا زاد على تليجرام — فالغياب = مافيش فتح ولا رسالة، مش التطبيق بس.
--
-- لحظة الصوت `ignored_days` كانت موجودة (إحساسها، ومسكها في اليوم المزحوم والظرف) ومحدش بيعملها. هنا بتتعمل:
--   • الخطوة ١ بعد ٤ أيام سكوت، والخطوة ٢ بعد ١٤ يوم لو لسه ساكت — وبعدها خلاص لحد ما يرجع (مانزنّش على حد مشي).
--   • الساعة ٧ المسا بتوقيت سوقه، ولو ليه طريق يوصله (تليجرام أو FCM). أكتر من ٤٥ يوم = مش هيرجع بسؤال.
--   • الهدوء والسقف اليومي واليوم المزحوم والظروف من معالج اللحظات نفسه؛ والرجوع قبل الإرسال بيلغيها (isStillRelevant).
-- الحقايق أرقام بس (أيام الغياب، الخطوة، كام مصروف البنك سجّله وهو غايب) — من غير أي كلام من رسايله.

create or replace function public.zad_enqueue_ignored_days(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_inserted int;
begin
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select a.user_id, 'ignored_days',
         jsonb_build_object(
           'days_away', a.days_away,
           'step', a.step,
           'last_seen_at', a.last_at,
           'time_zone', a.zone,
           'expenses_recorded_while_away', (
             select count(*) from public.zad_transactions t
              where t.user_id = a.user_id and t.txn_kind = 'expense' and t.created_at > a.last_at)
         ),
         'ignored_days:' || to_char(a.last_at at time zone 'utc', 'YYYYMMDDHH24MISS') || ':' || a.step
    from (
      select s.*,
             case when s.asked = 0 and s.days_away >= 4 then 1
                  when s.asked = 1 and s.days_away >= 14 then 2 end as step
        from (
          select u.id as user_id, l.last_at, z.zone,
                 floor(extract(epoch from p_now - l.last_at) / 86400)::int as days_away,
                 -- الغياب ده اتسأل فيه كام مرة: المفتاح فيه آخر ظهور، فرجوعه بيبدأ غياب جديد من الصفر.
                 (select count(*) from public.zad_voice_moments m
                   where m.user_id = u.id and m.moment = 'ignored_days'
                     and m.dedupe_key like 'ignored_days:' || to_char(l.last_at at time zone 'utc', 'YYYYMMDDHH24MISS') || ':%') as asked
            from public.zad_users u
            cross join lateral (select public.zad_market_timezone(u.country) as zone) z
            cross join lateral (
              select greatest(
                (select max(e.at) from public.zad_product_events e where e.user_id = u.id and e.name = 'app_open'),
                (select max(c.created_at) from public.zad_chat_turns c where c.user_id = u.id and c.role = 'user')
              ) as last_at
            ) l
           where l.last_at is not null
             and l.last_at <= p_now - interval '4 days'
             and l.last_at > p_now - interval '45 days'
             and extract(hour from p_now at time zone z.zone) = 19
             and (exists (select 1 from public.telegram_bindings b where b.user_id = u.id)
                  or exists (select 1 from public.zad_fcm_tokens f where f.user_id = u.id))
        ) s
    ) a
   where a.step is not null
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end
$fn$;

revoke all on function public.zad_enqueue_ignored_days(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_enqueue_ignored_days(timestamptz) to service_role;

do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  -- كل ساعة عند الدقيقة ١٣: الدالة بتختار الساعة ٧ المسا لكل سوق، ومعالج اللحظات (كل ٥ دقايق) بيبعتها.
  perform cron.schedule('ignored-days-hourly', '13 * * * *', $job$ select public.zad_enqueue_ignored_days(); $job$);
end
$cron$;
