-- Ads revenue vs AI cost (ZAD_PLAN 10.3 g, 20261114210000).
\set ON_ERROR_STOP on
\set me   '''11111111-1111-1111-1111-111111111111'''
\set other '''33333333-3333-3333-3333-333333333333'''
insert into auth.users values (:me), (:other);

-- Two of my runs today on a priced model, one on an unpriced one.
insert into public.zad_brain_runs (user_id, started_at, finished_at, input_tokens, output_tokens, prompt_sizes) values
  (:me, now() - interval '1 hour', now() - interval '1 hour' + interval '3 seconds', 1000000, 0, '{"calls":{"models":["gemini-3.5-flash-lite"]}}'),
  (:me, now() - interval '2 hours', now() - interval '2 hours' + interval '3 seconds', 0, 1000000, '{"calls":{"models":["gemini-3.5-flash-lite"]}}'),
  (:me, now() - interval '3 hours', now() - interval '3 hours' + interval '3 seconds', 10, 10, '{"calls":{"models":["no-price"]}}');

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :me)::text, false);
do $$
begin
  if not public.zad_ad_paid('banner', 1500, 'usd', 'precise') then raise exception 'a banner impression is recorded'; end if;
  if not public.zad_ad_paid('rewarded', 20000, 'USD', 'estimated') then raise exception 'a rewarded impression is recorded'; end if;
  if public.zad_ad_paid('popup', 10, 'USD') then raise exception 'unknown format refused'; end if;
  if public.zad_ad_paid('banner', 2000000, 'USD') then raise exception 'over a dollar per impression refused'; end if;
  if public.zad_ad_paid('banner', 10, 'dollars') then raise exception 'bad currency refused'; end if;
  begin
    insert into public.zad_ad_paid_events (user_id, format, value_micros, currency) values (auth.uid(), 'banner', 999999, 'USD');
    raise exception 'a direct insert must be refused';
  exception when insufficient_privilege then null; end;
  begin
    perform * from public.zad_ads_vs_brain(7);
    raise exception 'the report is the server''s';
  exception when insufficient_privilege then null; end;
end $$;

-- 500 a day at most.
reset role;
insert into public.zad_ad_paid_events (user_id, format, value_micros, currency)
  select '33333333-3333-3333-3333-333333333333', 'banner', 1, 'USD' from generate_series(1, 500);
set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :other)::text, false);
do $$
begin
  if public.zad_ad_paid('banner', 1, 'USD') then raise exception 'the 501st impression of the day is refused'; end if;
end $$;
reset role;

do $$
declare r record;
begin
  select * into r from public.zad_ads_vs_brain(7) where user_id = '11111111-1111-1111-1111-111111111111';
  if r.impressions <> 2 or r.ad_usd <> 0.0215 then raise exception 'ads: 2 impressions, $0.0215: %', row_to_json(r); end if;
  -- 1M input at $0.30 + 1M output at $2.50.
  if r.brain_runs <> 3 or r.brain_usd <> 2.8 or r.brain_unpriced_runs <> 1 then raise exception 'brain: %', row_to_json(r); end if;
  select * into r from public.zad_ads_vs_brain(7) where user_id = '33333333-3333-3333-3333-333333333333';
  if r.impressions <> 500 or r.brain_runs <> 0 or r.brain_usd is not null then raise exception 'ads only, no runs: %', row_to_json(r); end if;
end $$;

-- Another currency stays as it is, never converted by a guess.
insert into public.zad_ad_paid_events (user_id, format, value_micros, currency) values (:me, 'native', 50000, 'EGP');
do $$
declare r record;
begin
  select * into r from public.zad_ads_vs_brain(7) where user_id = '11111111-1111-1111-1111-111111111111';
  if r.ad_usd is not null or (r.ad_by_currency ->> 'EGP')::numeric <> 0.05 then raise exception 'mixed currencies: %', row_to_json(r); end if;
end $$;

select 'ad_revenue_test passed' as result;
