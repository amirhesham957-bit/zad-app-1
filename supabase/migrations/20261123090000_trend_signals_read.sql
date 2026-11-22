-- م٦.٣: دالة قراية بس لإشارات الترند — بتغذّي _shared/or/trendSurge.ts.
-- المصدر: zad_events (kind = 'shopping.added'، الاسم من payload.item_name): كل إضافة لقايمة الشراء إشارة.
-- خصوصية: أرقام مجمّعة بس (عدد النهارده + عدد البيوت + المعتاد اليومي). مفيش user_id ولا member_id ولا id حدث ولا وقت دقيق،
-- وأي صنف أقل من ٥ بيوت النهارده مابيرجعش خالص. إشارات البيت الواحد في اليوم الواحد متقفولة بـ٣ عشان بيت واحد ماينفخش الرقم.
-- service_role بس. مابتكتبش حاجة.

create or replace function public.zad_trend_signals(
  p_as_of date default (now() at time zone 'utc')::date,
  p_baseline_days integer default 28
) returns table (
  item_key text,
  today_count integer,
  houses integer,
  baseline numeric
)
language sql stable security definer set search_path = public as $$
  with params as (
    select coalesce(p_as_of, (now() at time zone 'utc')::date) as d,
           least(greatest(coalesce(p_baseline_days, 28), 7), 90) as n
  ), sig as (
    select lower(btrim(e.payload ->> 'item_name')) as item,
           e.user_id as house,
           (e.occurred_at at time zone 'utc')::date as day,
           count(*) as c
      from public.zad_events e, params p
     where e.kind = 'shopping.added'
       and length(btrim(coalesce(e.payload ->> 'item_name', ''))) between 2 and 120
       and (e.occurred_at at time zone 'utc')::date between p.d - p.n and p.d
     group by 1, 2, 3
  ), today as (
    select item, sum(least(c, 3))::integer as cnt, count(distinct house)::integer as hs
      from sig, params p where day = p.d group by item
  ), base as (
    select item, sum(least(c, 3)) as total
      from sig, params p where day < p.d group by item
  )
  select t.item, t.cnt, t.hs, round(coalesce(b.total, 0) / p.n::numeric, 3)
    from today t
    join params p on true
    left join base b on b.item = t.item
   where t.hs >= 5
   order by t.cnt desc, t.item
   limit 200;
$$;
revoke all on function public.zad_trend_signals(date, integer) from public, anon, authenticated;
grant execute on function public.zad_trend_signals(date, integer) to service_role;
