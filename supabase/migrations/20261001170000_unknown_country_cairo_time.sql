-- An account with no country keeps Egypt's time, not UTC (owner's decision, 2026-10-01).
--
-- Measured: an account linked to Telegram with no country got «صباح الخير» at 13:00 and
-- «تصبح على خير» at 02:00 Cairo time every day, because every civil-time job reads
-- zad_market_timezone(u.country) and an unknown country fell back to UTC. Egypt is the
-- app's first market; until the customer names a country, Cairo is the nearest guess
-- (Riyadh is the same hour in summer and one hour ahead in winter; UTC is three hours off).
create or replace function public.zad_market_timezone(p_country text)
 returns text
 language sql
 immutable
 set search_path to 'public'
as $function$
  select case upper(coalesce(p_country, ''))
    when 'SA' then 'Asia/Riyadh'      when 'EG' then 'Africa/Cairo'
    when 'AE' then 'Asia/Dubai'       when 'KW' then 'Asia/Kuwait'
    when 'QA' then 'Asia/Qatar'       when 'BH' then 'Asia/Bahrain'
    when 'OM' then 'Asia/Muscat'      when 'JO' then 'Asia/Amman'
    when 'LB' then 'Asia/Beirut'      when 'IQ' then 'Asia/Baghdad'
    when 'SY' then 'Asia/Damascus'    when 'YE' then 'Asia/Aden'
    when 'PS' then 'Asia/Gaza'        when 'LY' then 'Africa/Tripoli'
    when 'SD' then 'Africa/Khartoum'  when 'MA' then 'Africa/Casablanca'
    when 'TN' then 'Africa/Tunis'     when 'DZ' then 'Africa/Algiers'
    when 'TR' then 'Europe/Istanbul'
    else 'Africa/Cairo'
  end;
$function$;
