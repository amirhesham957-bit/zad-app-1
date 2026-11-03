-- توكن إنستجرام بيتجدد لوحده (ZAD_PLAN ٤.١٢، قرار ٤/١١: العروض أوتوماتيك ١٠٠٪ ومفيش خطوة يدوية بتوقف الإطلاق).
--
-- INSTAGRAM_ACCESS_TOKEN سر في سوبابيز، وتوكن فيسبوك طويل العمر بيخلص بعد ٦٠ يوم — ساعتها إنستجرام كان هيقف بهدوء لحد
-- ما حد يحط توكن جديد بإيده. هنا:
--   • zad_instagram_token() — أحدث توكن متجدد من الـVault (مشفّر)، أو null فالكود بيرجع للسر.
--   • zad_instagram_token_save(p_token, p_expires_at) — التجديد بيكتب التوكن الجديد في الـVault بنفس الاسم.
--   • كرون instagram-token-daily (كل يوم ٢:٥٣ UTC) ⇐ instagram_token_run في العقل ⇐ instagram_token_refresh في
--     core-intelligence: بيقرا تاريخ الانتهاء من Meta (debug_token)، ولو فاضل أقل من ٢٠ يوم ومفاتيح التطبيق موجودة
--     (META_APP_ID + META_APP_SECRET) بيبدّله بتوكن طويل جديد. توكن صفحة مالوش انتهاء = ولا حاجة.
-- السيرفر بس (service_role). plpgsql عشان قاعدة الاختبار من غير vault تعدّي. رقم الإصدار مش على ساعة مدوّرة عن قصد.

create or replace function public.zad_instagram_token()
returns text
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if to_regnamespace('vault') is null then
    return null;
  end if;
  return (select decrypted_secret from vault.decrypted_secrets where name = 'zad_instagram_token' limit 1);
end;
$$;

create or replace function public.zad_instagram_token_save(p_token text, p_expires_at timestamptz)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_id uuid;
  v_note text := 'Instagram Graph token, refreshed by instagram_token_refresh; expires ' || coalesce(p_expires_at::text, 'never');
begin
  if to_regnamespace('vault') is null or p_token is null or char_length(p_token) < 20 or char_length(p_token) > 1000 then
    return false;
  end if;
  select id into v_id from vault.secrets where name = 'zad_instagram_token' limit 1;
  if v_id is null then
    perform vault.create_secret(p_token, 'zad_instagram_token', v_note);
  else
    perform vault.update_secret(v_id, p_token, 'zad_instagram_token', v_note);
  end if;
  return true;
end;
$$;

revoke all on function public.zad_instagram_token() from public, anon, authenticated;
revoke all on function public.zad_instagram_token_save(text, timestamptz) from public, anon, authenticated;
grant execute on function public.zad_instagram_token() to service_role;
grant execute on function public.zad_instagram_token_save(text, timestamptz) to service_role;

do $cron$
begin
  if to_regnamespace('cron') is null or to_regprocedure('public.zad_cron_secret(text)') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.schedule(
    'instagram-token-daily',
    '53 2 * * *',
    $job$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"instagram_token_run"}'::jsonb,
        timeout_milliseconds := 60000
      ) as request_id;
    $job$
  );
end
$cron$;
