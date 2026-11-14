-- ZAD_PLAN ١٠.٣ (ز): دخل الإعلانات لكل عميل في اليوم قصاد تكلفة الذكاء لكل عميل في اليوم.
--
-- المصدر: AdMob بيبعت للتطبيق قيمة كل ظهور (onPaidEvent: القيمة بالمايكرو، والعملة، ودقتها). التطبيق بيبعتها
-- هنا بـzad_ad_paid. الرقم ده تقدير AdMob نفسه، مش الدفع النهائي — كفاية للمقارنة، مش للمحاسبة.
-- التكلفة: نفس zad_run_cost_usd (20261025050500) — «لو كانت على المدفوع»، بأغلى موديل في اللفة.
--
-- العميل بيكتب بس من الدالة: ظهوره هو، نوع من الخمسة، قيمة بسقف (دولار للظهور الواحد) و٥٠٠ ظهور في اليوم.
-- الرقم جاي من الموبايل، فهو مؤشر مش دليل — اللوحة بتقرا إجمالي AdMob نفسه للحسابات.

create table if not exists public.zad_ad_paid_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  at timestamptz not null default now(),
  format text not null check (format in ('banner', 'native', 'interstitial', 'rewarded', 'app_open')),
  value_micros bigint not null check (value_micros between 0 and 1000000),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  precision text not null default 'unknown' check (precision in ('unknown', 'estimated', 'publisher_provided', 'precise'))
);

create index if not exists zad_ad_paid_events_user_at on public.zad_ad_paid_events (user_id, at desc);

alter table public.zad_ad_paid_events enable row level security;
revoke all on table public.zad_ad_paid_events from anon, authenticated;
grant all on table public.zad_ad_paid_events to service_role;

comment on table public.zad_ad_paid_events is
  'ZAD_PLAN 10.3 (g) — AdMob onPaidEvent per impression, from the app through zad_ad_paid only. AdMob''s estimate, for ads-vs-AI-cost, not accounting.';

/** ظهور إعلان واحد ليه قيمة. بيرجّع false لو اترفض (من غير ما يرمي — الإعلان ظهر خلاص). */
create or replace function public.zad_ad_paid(p_format text, p_value_micros bigint, p_currency text, p_precision text default 'unknown')
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_currency text := upper(coalesce(p_currency, ''));
begin
  if v_me is null then
    raise exception 'not_authenticated';
  end if;
  if p_format not in ('banner', 'native', 'interstitial', 'rewarded', 'app_open')
     or p_value_micros is null or p_value_micros < 0 or p_value_micros > 1000000
     or v_currency !~ '^[A-Z]{3}$' then
    return false;
  end if;
  if (select count(*) from public.zad_ad_paid_events e
       where e.user_id = v_me and e.at > now() - interval '1 day') >= 500 then
    return false;
  end if;
  insert into public.zad_ad_paid_events (user_id, format, value_micros, currency, precision)
  values (v_me, p_format, p_value_micros, v_currency,
          case when p_precision in ('estimated', 'publisher_provided', 'precise') then p_precision else 'unknown' end);
  return true;
end;
$$;

revoke all on function public.zad_ad_paid(text, bigint, text, text) from public, anon;
grant execute on function public.zad_ad_paid(text, bigint, text, text) to authenticated;

/**
 * لكل عميل ويوم (UTC) في آخر [p_days] يوم: الظهورات ودخلها بعملة AdMob، وتكلفة الذكاء بالدولار. [ad_usd] بيتملى بس
 * لو كل دخل اليوم بالدولار — عملة تانية تفضل في [ad_by_currency] من غير تحويل متخمّن.
 */
create or replace function public.zad_ads_vs_brain(p_days int default 7)
returns table (
  user_id uuid,
  day date,
  impressions int,
  ad_by_currency jsonb,
  ad_usd numeric,
  brain_runs int,
  brain_usd numeric,
  brain_unpriced_runs int
)
language sql
stable
security definer
set search_path = public
as $$
  with span as (
    select ((now() at time zone 'utc')::date - greatest(1, least(coalesce(p_days, 7), 90))) as d0
  ),
  ads as (
    select e.user_id, (e.at at time zone 'utc')::date as day, e.currency,
           count(*)::int as n, sum(e.value_micros) as micros
      from public.zad_ad_paid_events e, span
     where e.at >= span.d0::timestamp at time zone 'utc'
     group by 1, 2, 3
  ),
  ad_day as (
    select a.user_id, a.day, sum(a.n)::int as impressions,
           jsonb_object_agg(a.currency, round(a.micros / 1e6, 4)) as by_currency,
           case when bool_and(a.currency = 'USD') then round(sum(a.micros) / 1e6, 4) end as usd
      from ads a group by 1, 2
  ),
  runs as (
    select br.user_id, (br.started_at at time zone 'utc')::date as day,
           public.zad_run_cost_usd(br.prompt_sizes -> 'calls' -> 'models', br.input_tokens, br.output_tokens, br.started_at) as usd
      from public.zad_brain_runs br, span
     where br.started_at >= span.d0::timestamp at time zone 'utc' and br.finished_at is not null
  ),
  brain_day as (
    select r.user_id, r.day, count(*)::int as n, round(sum(r.usd)::numeric, 6) as usd,
           count(*) filter (where r.usd is null)::int as unpriced
      from runs r group by 1, 2
  )
  select coalesce(a.user_id, b.user_id), coalesce(a.day, b.day),
         coalesce(a.impressions, 0), coalesce(a.by_currency, '{}'::jsonb), a.usd,
         coalesce(b.n, 0), b.usd, coalesce(b.unpriced, 0)
    from ad_day a
    full join brain_day b on b.user_id = a.user_id and b.day = a.day
   order by 2 desc, 1;
$$;

revoke all on function public.zad_ads_vs_brain(int) from public, anon, authenticated;
grant execute on function public.zad_ads_vs_brain(int) to service_role;
