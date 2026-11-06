-- محلات المالك الناقصة (طلب ٦/١١): «وفّرها» (تطبيق عروض وكوبونات مصري) و«الصالات الاقتصادية» (صالات التخفيضات في
-- السعودية). نفس البحث الدوري بتاع باقي المحلات (deals-search-weekly / deals-instagram-weekly)، كل محل في سوقه بس
-- (ZAD_PLAN ٣.١٣). «ديل» مستني المالك يحدد أنهي تطبيق وأنهي بلد — محل في السوق الغلط بيعرض عروض بلد تاني.

insert into public.zad_deal_seed_stores (country, store, currency, kind) values
  ('EG', 'وفّرها', 'EGP', 'marketplace'),
  ('SA', 'الصالات الاقتصادية', 'SAR', 'grocery')
on conflict (country, store) do nothing;
