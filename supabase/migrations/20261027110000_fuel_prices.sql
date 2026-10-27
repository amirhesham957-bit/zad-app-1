-- ZAD_PLAN 4.10 — «المشوار ولا التوصيل»: سعر لتر البنزين لكل بلد، مرة في الشهر من البحث بمصدره.
-- عرض الصبح بيحسب منه تكلفة المشوار للمحل (رايح جاي)، ولو المشوار بياكل التوفير العرض مايتقالش.
-- الكاتب الوحيد zad-brain (fuel_price_run)؛ السعر عام فأي حساب داخل يقراه.

create table if not exists public.zad_fuel_prices (
  country text primary key check (country ~ '^[A-Z]{2}$'),
  grade text not null check (char_length(grade) between 2 and 40),
  price numeric(10, 2) not null check (price > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  source_url text not null check (source_url ~ '^https://' and char_length(source_url) <= 500),
  found_at timestamptz not null default now()
);

alter table public.zad_fuel_prices enable row level security;
revoke all on table public.zad_fuel_prices from anon, authenticated;
grant select on table public.zad_fuel_prices to authenticated;
grant all on table public.zad_fuel_prices to service_role;

drop policy if exists zad_fuel_prices_read on public.zad_fuel_prices;
create policy zad_fuel_prices_read on public.zad_fuel_prices for select to authenticated using (true);

comment on table public.zad_fuel_prices is
  'ZAD_PLAN 4.10 — this month''s per-litre fuel price per country, with the search result it came from. Written by zad-brain only.';

/** البلاد اللي فيها عملاء وسعرها مااتبحثش آخر ٢٥ يوم. */
create or replace function public.zad_fuel_price_targets()
returns table (country text)
language sql
stable
security definer
set search_path = public
as $$
  select distinct upper(u.country)
    from public.zad_users u
   where upper(coalesce(u.country, '')) in ('EG', 'SA', 'AE', 'KW', 'QA', 'BH', 'OM', 'JO')
     and not exists (
       select 1 from public.zad_fuel_prices f
        where f.country = upper(u.country) and f.found_at > now() - interval '25 days'
     )
   order by 1;
$$;

revoke all on function public.zad_fuel_price_targets() from public, anon, authenticated;
grant execute on function public.zad_fuel_price_targets() to service_role;

-- يوم ٢ في الشهر ٤:٢٣ UTC: مصر بتعلن أسعارها كل ربع سنة وأرامكو أول الشهر.
do $cron$
begin
  if to_regnamespace('cron') is null or to_regprocedure('public.zad_cron_secret(text)') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.schedule(
    'fuel-price-monthly',
    '23 4 2 * *',
    $job$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"fuel_price_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id;
    $job$
  );
end
$cron$;
