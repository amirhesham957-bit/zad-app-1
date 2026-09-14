-- «صباح الخير» الاحتياطية لعملاء تليجرام كمان (٢٠٢٦-٠٩-١٤).
--
-- بلاغ: «البوت مابيبعتليش فويس صباح الخير باسمي». تشخيص ما بعد النشر (zad_diag_cron_health):
-- كرون voice-moments-processor شغال من غير ولا فشل، بس `morning_candidates` = ١ من ٤ عملاء — الأهلية
-- كانت «سجّل دخول للتطبيق أو حدّث توكن FCM آخر ١٤ يوم». جلسة سوبابيز بتتجدد من غير ما last_sign_in_at
-- يتغير، وعميل بيكلم زاد من تليجرام أغلب الوقت مابيحدّثش توكن — فبيتشال من «صباح الخير» وهي أصلاً
-- بتتبعت له فويس على تليجرام. (والميزة نفسها اتنشرت النهارده ١١:٤١ UTC، بعد ١٠ الصبح بتوقيت القاهرة،
-- فأول تشغيل حقيقي بكرة.)
--
-- دلوقتي مؤهل كمان: أي عميل مربوط بتليجرام، أو كلّم زاد (zad_chat_turns) آخر ١٤ يوم.

create or replace function public.zad_enqueue_morning_fallback()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int;
begin
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select x.user_id, 'morning_greeting',
         jsonb_build_object('local_date', x.local_date, 'time_zone', x.tz, 'source', 'fallback_10am'),
         'morning:' || x.local_date
  from (
    select au.id as user_id,
           public.zad_market_timezone(u.country) as tz,
           to_char(now() at time zone public.zad_market_timezone(u.country), 'YYYY-MM-DD') as local_date,
           extract(hour from now() at time zone public.zad_market_timezone(u.country))::int as local_hour
    from auth.users au
    join public.zad_users u on u.id = au.id
    where au.last_sign_in_at > now() - interval '14 days'
       or exists (select 1 from public.zad_fcm_tokens t where t.user_id = au.id and t.updated_at > now() - interval '14 days')
       or exists (select 1 from public.telegram_bindings b where b.user_id = au.id and b.chat_id is not null)
       or exists (select 1 from public.zad_chat_turns c where c.user_id = au.id and c.created_at > now() - interval '14 days')
  ) x
  where x.local_hour = 10
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_morning_fallback() from public;
revoke all on function public.zad_enqueue_morning_fallback() from anon;
revoke all on function public.zad_enqueue_morning_fallback() from authenticated;
