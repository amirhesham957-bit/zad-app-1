-- =====================================================
-- وضع السفر من الموقع (بلاغ المالك ٣/١١): حساب سوقه السعودية، الموبايل في الجيزة بإذن الموقع، و`travel_country`
-- فاضي — لأن السفر كان بيتعرف من بلد شبكة الموبايل بس (`zad_travel_report` من التطبيق)، والشبكة بترجع null على
-- الواي فاي أو من غير شريحة. الموقع نفسه (`last_lat/last_lon`، مقرّب لكيلو، بيكتبه التطبيق) ماكانش بيتقرا للسفر.
--
-- `zad_country_at(lat, lon)`: بلد النقطة من مستطيلات «جوه البلد بوضوح» لأسواق زاد الـ١٩ — مقصود إنها تسيب الحدود
-- برّه: نقطة على الحدود أو برّه أي مستطيل = null = مفيش تغيير. المستطيلات مابتتداخلش (السعودية بتقف عند ٥٠٫٣ شرق
-- قبل البحرين وقطر، ولبنان عند ٣٦٫١ قبل دمشق)، والترتيب احتياط بس. ده تقريب، مش خريطة: الغلط المسموح «ماعرفش»، مش
-- «بلد غلط» — مدن بعيدة عن الحدود اتجربت في travel_from_location_test.sql.
--
-- التريجر قبل تحديث النقطة: بلد تاني غير سوق الحساب ⇒ رحلة + لحظة `travel_arrived` مرة في اليوم (نفس اللي
-- `zad_travel_report` بيعمله)؛ نفس بلد السوق ⇒ الرحلة بتخلص. السوق والعملة مابيتغيروش — ده سياق بس.
-- =====================================================

create or replace function public.zad_country_at(p_lat double precision, p_lon double precision)
returns text
language sql
immutable
parallel safe
set search_path to 'public'
as $function$
  select b.country
    from (values
      -- (ترتيب, بلد, lat من, lat لحد, lon من, lon لحد)
      (1, 'BH', 25.78, 26.33, 50.38, 50.82),
      (2, 'QA', 24.55, 26.15, 50.75, 51.65),
      (3, 'KW', 28.55, 30.08, 46.60, 48.40),
      (4, 'LB', 33.10, 34.65, 35.15, 36.10),
      (5, 'PS', 31.22, 31.58, 34.22, 34.55),   -- غزة
      (6, 'PS', 31.50, 32.50, 35.08, 35.55),   -- الضفة
      (7, 'AE', 22.60, 26.05, 51.60, 56.35),
      (8, 'OM', 16.60, 24.00, 55.90, 59.90),
      (9, 'OM', 23.00, 24.60, 56.40, 58.90),
      (10, 'JO', 29.20, 32.30, 35.60, 39.00),
      (11, 'JO', 32.30, 32.55, 35.60, 36.30),
      (12, 'SY', 32.70, 33.70, 36.15, 41.00),  -- دمشق ودرعا
      (12, 'SY', 33.70, 36.60, 36.50, 41.00),
      (13, 'IQ', 30.00, 33.50, 41.50, 46.00),
      (14, 'IQ', 29.90, 31.50, 46.00, 47.90),
      (15, 'IQ', 33.50, 37.05, 41.50, 44.80),
      (16, 'TR', 36.90, 42.00, 26.00, 41.00),
      (17, 'TR', 36.90, 41.00, 41.00, 43.40),
      (18, 'EG', 22.00, 31.60, 25.00, 32.40),
      (19, 'EG', 24.00, 29.80, 32.40, 34.00),  -- ساحل البحر الأحمر
      (20, 'EG', 28.00, 31.25, 32.40, 34.20),  -- سينا
      (20, 'EG', 27.70, 29.00, 32.40, 34.50),  -- جنوب سينا (شرم ودهب)
      (21, 'SD', 10.50, 21.80, 24.00, 36.40),
      (22, 'SD', 18.00, 21.80, 36.40, 38.50),
      (23, 'LY', 23.50, 32.90, 11.60, 25.00),
      (24, 'TN', 30.50, 37.40, 8.40, 11.50),
      (25, 'DZ', 19.00, 37.10, -1.60, 8.00),
      (26, 'MA', 32.50, 35.95, -9.90, -1.80),
      (27, 'MA', 27.60, 32.50, -13.20, -5.00),
      (28, 'YE', 12.50, 16.30, 42.50, 52.00),
      (29, 'YE', 16.30, 17.20, 44.00, 52.00),
      (30, 'SA', 17.50, 28.30, 38.00, 50.30),
      (31, 'SA', 20.00, 28.90, 35.80, 38.00),  -- الحجاز وتبوك
      (32, 'SA', 16.40, 17.50, 42.00, 43.60)   -- جازان
    ) as b(ord, country, lat_min, lat_max, lon_min, lon_max)
   where p_lat is not null and p_lon is not null
     and p_lat between b.lat_min and b.lat_max
     and p_lon between b.lon_min and b.lon_max
   order by b.ord
   limit 1
$function$;

create or replace function public.zad_users_travel_from_location()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_here text := public.zad_country_at(new.last_lat, new.last_lon);
  v_home text := upper(nullif(btrim(coalesce(new.country, '')), ''));
begin
  if v_here is null or v_home is null then
    return new;
  end if;
  if v_here = v_home then
    if new.travel_country is not null then
      new.travel_country := null;
      new.travel_since := null;
    end if;
    return new;
  end if;
  if new.travel_country is distinct from v_here then
    new.travel_country := v_here;
    new.travel_since := now();
    insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
    values (new.id, 'travel_arrived',
            jsonb_build_object('country', v_here, 'home_country', v_home, 'from', 'location'),
            'travel:' || v_here || ':' || to_char(now(), 'YYYY-MM-DD'))
    on conflict (user_id, dedupe_key) do nothing;
  end if;
  return new;
end;
$function$;

revoke all on function public.zad_users_travel_from_location() from public, anon, authenticated;

drop trigger if exists zad_users_travel_from_location on public.zad_users;
create trigger zad_users_travel_from_location
  before update of last_lat, last_lon on public.zad_users
  for each row
  -- من غير WHEN: نفس النقطة المقرّبة بتتكتب تاني لما الموبايل يفضل في نفس الحتة، ولازم تتقرا برضه (الحساب ده
  -- كانت نقطته في الجيزة قبل التريجر). الدالة مابتكتبش غير لو الرحلة اتغيرت، واللحظة مرة في اليوم.
  execute function public.zad_users_travel_from_location();

-- النقط اللي اتكتبت آخر ٧ أيام قبل التريجر (منها حساب المالك الجديد في الجيزة): تتقري مرة دلوقتي. أقدم من كده
-- ممكن يكون رجع، فمش بنبدأ بيها رحلة.
update public.zad_users
   set last_lat = last_lat
 where last_lat is not null and last_lon is not null and country is not null
   and last_location_at > now() - interval '7 days';
