-- م٦.٣: إشارات الترند المجمّعة (صنف + بلد + يوم) من إضافات قايمة الشراء في دفتر الأحداث (zad_events، kind = 'shopping.added').
-- خصوصية: الدالة ما بترجعش user_id ولا family_id ولا member_id، وبترجع بس الصفوف اللي وراها ٥ بيوت مختلفة أو أكتر
-- (البيت = العيلة لو في عيلة، وإلا الحساب نفسه). الحد في الـSQL نفسه، مش في العميل. السيرفر بس: service_role.
create or replace function public.zad_trend_signals(p_days int default 29)
returns table (country text, item_key text, day date, signal_count int, houses int)
language sql
stable
security definer
set search_path = public
as $$
  with raw as (
    select upper(btrim(u.country)) as country,
           lower(btrim(regexp_replace(e.payload ->> 'item_name', '\s+', ' ', 'g'))) as item_key,
           (e.occurred_at at time zone 'UTC')::date as day,
           coalesce((select m.family_id::text from public.family_members m where m.user_id = e.user_id limit 1),
                    e.user_id::text) as home
      from public.zad_events e
      join public.zad_users u on u.id = e.user_id
     where e.kind = 'shopping.added'
       and e.occurred_at >= now() - make_interval(days => least(greatest(p_days, 1), 90))
       and u.country ~ '^[A-Za-z]{2}$'
  )
  select r.country, r.item_key, r.day, count(*)::int, count(distinct r.home)::int
    from raw r
   where char_length(r.item_key) between 2 and 60
   group by r.country, r.item_key, r.day
  having count(distinct r.home) >= 5
$$;
revoke all on function public.zad_trend_signals(int) from public, anon, authenticated;
grant execute on function public.zad_trend_signals(int) to service_role;
