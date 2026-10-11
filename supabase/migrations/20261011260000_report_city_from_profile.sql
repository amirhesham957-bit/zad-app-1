-- البلاغ بمدينته (الموجة ٨، ٢٠٢٦-١٠-١١).
--
-- قرار المالك: «المدينة أو المنطقة مع البلاغ (من «ملفي»، مش لوكيشن)». بلاغات الفواتير (التطبيق وتليجرام)
-- كانت بتتبعت من غير مدينة، فـ«أرخص هنا» بتقارن كارفور القاهرة بكارفور جدة لو العملة واحدة، وفلتر المدينة في
-- zad_cheapest_prices مالوش لازمة.
--
-- دلوقتي private.zad_report_price_impl (20261011180000) — الجسم الواحد لكل الأبواب — لو البلاغ جاي من غير
-- مدينة بياخد مدينة العميل من zad_customer_profile.city (لو كاتبها). بلاغ فيه مدينة بيفضل زي ما هو. نفس
-- الحد (٦٠ حرف). تعديل على النص: الجملة مرة واحدة بالظبط، وإلا المايجريشن بتقف.

do $migrate$
declare
  v_def text;
  v_pat text;
  v_hits int;
begin
  select pg_get_functiondef('private.zad_report_price_impl(uuid, uuid, text, numeric, text, text, text, text)'::regprocedure) into v_def;
  v_pat := regexp_replace('-- A replay of a report already taken.', '([.*+?^${}()|\[\]\\])', '\\\1', 'g');
  v_pat := regexp_replace(v_pat, ' ', '\\s+', 'g');
  v_hits := regexp_count(v_def, v_pat);
  if v_hits <> 1 then
    raise exception 'report city: zad_report_price_impl has % anchors, expected 1', v_hits;
  end if;
  execute regexp_replace(v_def, v_pat,
    '-- No city given: the account''s own, from its profile (20261011260000).
  if v_location is null then
    select nullif(left(btrim(regexp_replace(coalesce(cp.city, ''''), ''\s+'', '' '', ''g'')), 60), '''')
      into v_location
      from public.zad_customer_profile cp where cp.user_id = v_uid;
  end if;

  -- A replay of a report already taken.');
end
$migrate$;
