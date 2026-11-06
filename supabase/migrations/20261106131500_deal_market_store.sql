-- «ديل» (Deal، dealcompany.sa) — هايبر ماركت سعودي من مجموعة الراجحي، تجزئة منخفضة التكلفة، أول فروعه الكبيرة في
-- الرياض يناير ٢٠٢٦ (المالك ٦/١١). الاسم «ديل ماركت» مش «ديل» بس: البحث بيبقى «عروض <الاسم> <المدينة> الأسبوع»
-- (liveDeals.storeDealsQuery)، و«عروض ديل الرياض» لوحدها بتجيب أي «ديل»/deal بالإنجليزي.

insert into public.zad_deal_seed_stores (country, store, currency, kind) values
  ('SA', 'ديل ماركت', 'SAR', 'grocery')
on conflict (country, store) do nothing;
