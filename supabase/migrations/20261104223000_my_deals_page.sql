-- صفحة العروض في التطبيق (ZAD_PLAN ٤.٢٠/٤.٢٢، طلب المالك ٤/١١).
--
-- العروض كانت بتوصل العميل من تليجرام وتحية الصبح بس — مفيش صفحة في التطبيق بتقرا zad_deals، والدرج «العروض» كان
-- بيفتح المحلات القريبة. zad_my_deals() بيرجّع لصاحب الجلسة عروض بلده (البلد اللي هو مسافر فيه لو مسافر، نفس
-- dealCountry في zad-brain: travel_country آخر ٤٥ يوم) والأكواد (٤.٢٢)، من غير المصادر الموقوفة بالبلاغات (٤.١٩).
-- الجداول نفسها بتفضل السيرفر بس؛ ده باب قراية واحد، ومفيش فيه أي حاجة عن عملاء تانيين (zad_deals مافيهوش user_id).
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

create or replace function public.zad_my_deals()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_country text;
  v_paused text[];
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select case
           when upper(coalesce(u.travel_country, '')) ~ '^[A-Z]{2}$'
            and upper(u.travel_country) <> upper(coalesce(u.country, ''))
            and u.travel_since is not null
            and u.travel_since <= now()
            and u.travel_since > now() - interval '45 days'
           then upper(u.travel_country)
           else upper(nullif(btrim(u.country), ''))
         end
    into v_country
    from public.zad_users u
   where u.id = v_uid;

  if v_country is null or v_country !~ '^[A-Z]{2}$' then
    return jsonb_build_object('country', null, 'deals', '[]'::jsonb, 'codes', '[]'::jsonb);
  end if;

  select coalesce(array_agg(p.source_kind), '{}') into v_paused from public.zad_deal_paused_sources(14) p;

  return jsonb_build_object(
    'country', v_country,
    'deals', coalesce((
      select jsonb_agg(to_jsonb(d) order by d.saving desc nulls last, d.found_at desc)
        from (
          select z.store, z.city, z.item_name, z.price, z.price_before, z.currency, z.deal_kind, z.source_kind,
                 z.source_url, z.valid_until, z.found_at,
                 case when z.price_before > z.price
                      then round((z.price_before - z.price) / z.price_before * 100) end as saving
            from public.zad_deals z
           where z.country = v_country
             and z.expires_at > now()
             and not (z.source_kind = any (v_paused))
           order by z.found_at desc
           limit 120
        ) d
    ), '[]'::jsonb),
    'codes', coalesce((
      select jsonb_agg(to_jsonb(c) order by c.found_at desc)
        from (
          select k.store, k.code, k.discount_percent, k.discount_amount, k.currency, k.min_order, k.valid_until,
                 k.source_kind, k.source_url, k.found_at
            from public.zad_deal_codes k
           where k.country = v_country
             and k.expires_at > now()
           order by k.found_at desc
           limit 40
        ) c
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.zad_my_deals() from public, anon;
grant execute on function public.zad_my_deals() to authenticated;
