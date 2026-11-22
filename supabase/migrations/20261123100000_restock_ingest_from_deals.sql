-- م٦.٢: أول مصدر فعلي لـ zad_restock_observations — عروض النشرات والشركاء والفواتير المجمّعة (zad_deals).
-- عرض سارٍ على صنف في محل = الصنف موجود هناك (in_stock=true). مفيش «خلصان» من العروض، فالمصدر ده بيدّي «موجود» بس.
-- مجهول: zad_deals مافيهاش صاحب (الفاتورة فيها homes ≥ ٣ مجمّعة). بيعدّي من zad_restock_observe فالتقريب والتكرار والـ٩٠ يوم مضبوطين.
-- كرون يومي ٤:١٧ UTC بيمسك اللي اتلقى في آخر يومين (تكرار الكرون بيتجاهل بحد الساعة).

create or replace function public.zad_restock_ingest_deals(p_days integer default 2) returns integer
language plpgsql security definer set search_path = public as $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select d.country, d.store_key, d.item_key, d.source_kind, d.lat, d.lng, d.found_at
      from public.zad_deals d
     where d.source_kind in ('receipt', 'flyer', 'partner')
       and d.expires_at > now()
       and d.found_at >= now() - make_interval(days => least(greatest(coalesce(p_days, 2), 1), 30))
       and char_length(d.store_key) between 2 and 60
       and char_length(d.item_key) between 2 and 60
     order by d.found_at
     limit 5000
  loop
    if public.zad_restock_observe(r.country, r.store_key, r.item_key, true, r.source_kind, r.lat::numeric, r.lng::numeric, r.found_at) then
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;
revoke all on function public.zad_restock_ingest_deals(integer) from public, anon, authenticated;
grant execute on function public.zad_restock_ingest_deals(integer) to service_role;

do $$ begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule('restock-ingest-deals') where exists (select 1 from cron.job where jobname = 'restock-ingest-deals');
    perform cron.schedule('restock-ingest-deals', '17 4 * * *', 'select public.zad_restock_ingest_deals()');
  end if;
end $$;
