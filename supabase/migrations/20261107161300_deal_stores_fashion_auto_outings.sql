-- محلات الملابس والإلكترونيات والعربيات والخروجات في مصر والسعودية (طلب المالك ٧/١١، موسم الجمعة البيضاء:
-- «ملابس، طعام، معيشة، خروجات، اكسسوارات عربيات… طالما جوه حدود الحصة المجانية»).
--
-- نفس الدوران اليومي وقت الموسم (zad_deal_source_targets ⇐ البحث، يوتيوب، إنستجرام بحد Meta الأسبوعي). اتقاس قبلها
-- ٧/١١: ~٥٥ بحث و٣٠ نداء يوتيوب في اليوم؛ ١٦ محل زيادة (٨ لكل بلد) = ~١٦ بحث و~١٦ يوتيوب في اليوم — جوه حد يوتيوب
-- المجاني (١٠٠ بحث في اليوم) وفي حدود البحث. الأكل والمعيشة متغطيين أصلاً (٥٦ محل)، ونشرات الدانوب الرسمية (officialFlyers).
-- kind مابيتقريش في أي كود (الاستعلامات كلها بالاسم)، فالقيم الجديدة توسيع للقيد بس.

alter table public.zad_deal_seed_stores drop constraint if exists zad_deal_seed_stores_kind_check;
alter table public.zad_deal_seed_stores add constraint zad_deal_seed_stores_kind_check
  check (kind = any (array['grocery', 'delivery', 'marketplace', 'fashion', 'electronics', 'auto', 'outing']));

insert into public.zad_deal_seed_stores (country, store, currency, kind) values
  -- مصر
  ('EG', 'ديفاكتو', 'EGP', 'fashion'),
  ('EG', 'إل سي وايكيكي', 'EGP', 'fashion'),
  ('EG', 'سنتربوينت', 'EGP', 'fashion'),
  ('EG', 'ماكس فاشون', 'EGP', 'fashion'),
  ('EG', 'بي تك', 'EGP', 'electronics'),
  ('EG', '2B', 'EGP', 'electronics'),
  ('EG', 'فوكس سينما', 'EGP', 'outing'),
  ('EG', 'توتال إنرجيز', 'EGP', 'auto'),
  -- السعودية
  ('SA', 'سنتربوينت', 'SAR', 'fashion'),
  ('SA', 'ماكس فاشون', 'SAR', 'fashion'),
  ('SA', 'ريد تاغ', 'SAR', 'fashion'),
  ('SA', 'إكسترا', 'SAR', 'electronics'),
  ('SA', 'جرير', 'SAR', 'electronics'),
  ('SA', 'بترومين', 'SAR', 'auto'),
  ('SA', 'ساكو', 'SAR', 'auto'),
  ('SA', 'فوكس سينما', 'SAR', 'outing')
on conflict (country, store) do nothing;
