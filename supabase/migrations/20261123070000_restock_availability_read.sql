-- م٦.٢: دالة قراية بس لملاحظات التوافر (zad_restock_observations) — بتغذّي _shared/or/restockAvailability.ts.
-- خصوصية: مفيش معرّف صف ولا مصدر ولا أي حاجة عن مين اشترى أو أبلغ، العمر بالأيام بس، والموقع تقريبي للمحل (٢ رقم عشري).
-- service_role بس. مابتكتبش حاجة، والكتابة لسه من غير باب (مفيش كاتب).

create or replace function public.zad_restock_availability(
  p_country text,
  p_item_key text,
  p_max_age_days integer default 90
) returns table (
  store_key text,
  in_stock boolean,
  age_days numeric,
  area_lat numeric,
  area_lng numeric
)
language sql stable security definer set search_path = public as $$
  select o.store_key,
         o.in_stock,
         round((extract(epoch from (now() - o.observed_at)) / 86400)::numeric, 2) as age_days,
         o.area_lat,
         o.area_lng
    from public.zad_restock_observations o
   where o.country = upper(p_country)
     and o.item_key = p_item_key
     and o.observed_at >= now() - make_interval(days => least(greatest(coalesce(p_max_age_days, 90), 1), 90))
   order by o.store_key, o.observed_at desc
   limit 2000;
$$;
revoke all on function public.zad_restock_availability(text, text, integer) from public, anon, authenticated;
grant execute on function public.zad_restock_availability(text, text, integer) to service_role;
