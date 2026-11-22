-- م٦.٣: دالة قراية بس لقفزات اليوم (zad_trend_surges) — بتغذّي _shared/or/trendSurgeRead.ts.
-- الجدول عالمي (مفيش عمود بلد ولا أي هوية)، فالقراية كمان من غير بلد. حد ٥ بيوت متفحوص هنا تاني.
-- مفيش عمود «اشتري»: الهايب لوحده مش سبب ترشيح. service_role بس.
create or replace function public.zad_trend_surges_read(p_day date default null, p_limit integer default 10)
returns table (item_key text, houses integer, signal_count integer, baseline numeric, z numeric)
language sql stable security definer set search_path = public as $$
  select s.item_key, s.houses, s.signal_count, s.baseline, s.z
    from public.zad_trend_surges s
   where s.day = coalesce(p_day, (now() at time zone 'utc')::date)
     and s.houses >= 5
   order by s.z desc, s.item_key
   limit least(greatest(coalesce(p_limit, 10), 1), 50);
$$;
revoke all on function public.zad_trend_surges_read(date, integer) from public, anon, authenticated;
grant execute on function public.zad_trend_surges_read(date, integer) to service_role;
