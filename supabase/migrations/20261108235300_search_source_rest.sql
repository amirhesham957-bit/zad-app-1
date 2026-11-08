-- مصدر بحث رد 429/403 بيستريح ساعتين (sourcePool.ts). الكاتب والقارئ zad-core-intelligence، ومقفول للعميل.
-- ومعاها صيدليات مصر اللي المالك سماها، بنوع جديد pharmacy. رقم الإصدار مش على ساعة مدوّرة عن قصد.
create table if not exists public.zad_search_source_rest (
  source text primary key check (char_length(source) between 1 and 40),
  until timestamptz not null,
  reason text check (char_length(reason) <= 80)
);

alter table public.zad_search_source_rest enable row level security;
revoke all on public.zad_search_source_rest from anon, authenticated;
grant all on public.zad_search_source_rest to service_role;

alter table public.zad_deal_seed_stores drop constraint if exists zad_deal_seed_stores_kind_check;
alter table public.zad_deal_seed_stores add constraint zad_deal_seed_stores_kind_check
  check (kind = any (array['grocery', 'delivery', 'marketplace', 'fashion', 'electronics', 'auto', 'outing', 'restaurant', 'pharmacy']));

insert into public.zad_deal_seed_stores (country, store, currency, kind) values
  ('EG', 'شفاء', 'EGP', 'pharmacy'),
  ('EG', 'يداوي', 'EGP', 'pharmacy')
on conflict (country, store) do nothing;
