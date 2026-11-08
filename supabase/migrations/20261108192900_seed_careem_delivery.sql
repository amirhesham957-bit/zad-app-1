-- عروض التطبيقات على تيك توك (طلب المالك ٨/١١): كريم كان ناقص من قايمة التوصيل. باقي التطبيقات موجودة.
insert into public.zad_deal_seed_stores (country, store, currency, kind) values
  ('SA', 'كريم', 'SAR', 'delivery'),
  ('AE', 'كريم', 'AED', 'delivery')
on conflict (country, store) do nothing;
