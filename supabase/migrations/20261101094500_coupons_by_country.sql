-- zad_coupons: DCMnetwork offers and coupons by country, for the deals the app shows (ZAD_PLAN 4.5).
--
-- zad_deals is a price table, and nearly everything DCM has is store-wide: «6.3% back at Amazon UAE», a
-- code with no item and no price. Those were counted and dropped. The owner's decision on 2026-11-01 is a
-- place of their own, read by country.
--
-- Two sources, one row per (source, external_id, country_code):
--   • dcm_offer  — HasOffers Affiliate_Offer (84 approved offers on 2026-11-01): store, commission, target
--                  countries, categories, logo, and the tracked link once the offer's terms are accepted.
--   • dcm_coupon — the Codes Hub coupons API: a promo code with its countries (0 coupons on 2026-11-01).
-- An offer with no target country is stored once as 'GLOBAL'; get-user-deals falls back to those rows when
-- the customer's country has none.
--
-- Measured 2026-11-01: every offer refuses a tracking link until its terms are accepted in the DCM panel
-- («Must accept offer terms and conditions…»). Such a row keeps click_url null and is never shown: a link
-- without our tracking earns nothing.
--
-- Partner data, no customer data: any signed-in customer may read the active rows. Writes are the server's.

create table if not exists public.zad_coupons (
  id uuid primary key default gen_random_uuid(),
  source text not null check (source in ('dcm_offer', 'dcm_coupon')),
  external_id text not null check (char_length(external_id) between 1 and 80),
  country_code text not null check (country_code ~ '^([A-Z]{2}|GLOBAL)$'),
  store text not null check (char_length(store) between 1 and 80),
  title text not null default '' check (char_length(title) <= 200),
  code text check (code is null or char_length(code) between 1 and 60),
  category text check (category is null or char_length(category) <= 60),
  click_url text check (click_url is null or (click_url ~ '^https://' and char_length(click_url) <= 1000)),
  logo_url text check (logo_url is null or (logo_url ~ '^https://' and char_length(logo_url) <= 500)),
  payout_percent numeric check (payout_percent is null or payout_percent between 0 and 100),
  payout_flat numeric check (payout_flat is null or payout_flat >= 0),
  payout_currency text check (payout_currency is null or payout_currency ~ '^[A-Z]{3}$'),
  is_trending boolean not null default false,
  valid_until timestamptz,
  active boolean not null default true,
  synced_at timestamptz not null default now(),
  constraint zad_coupons_one_per_country unique (source, external_id, country_code)
);

-- What get-user-deals reads: one country (and GLOBAL), active and linked, trending first.
create index if not exists zad_coupons_country_live
  on public.zad_coupons (country_code, is_trending, payout_percent desc)
  where active and click_url is not null;
create index if not exists zad_coupons_trending
  on public.zad_coupons (country_code)
  where is_trending and active and click_url is not null;

alter table public.zad_coupons enable row level security;
revoke all on table public.zad_coupons from anon, authenticated;
grant select on table public.zad_coupons to authenticated;
grant all on table public.zad_coupons to service_role;

drop policy if exists zad_coupons_live on public.zad_coupons;
create policy zad_coupons_live on public.zad_coupons for select to authenticated
  using (active and click_url is not null and (valid_until is null or valid_until > now()));

comment on table public.zad_coupons is
  'DCMnetwork offers and promo codes by country (ZAD_PLAN 4.5). Partner data, no customer data. '
  'Written by sync-dcm-offers only; read through get-user-deals.';
