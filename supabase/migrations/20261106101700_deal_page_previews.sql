-- صورة المعاينة بتاعة صفحة العرض (og:image) — طلب المالك ٦/١١: «اسحب الصورة تلقائياً من صفحة العرض».
--
-- عروض `search` كانت بتتعرض بمربع فاضي: الصورة الوحيدة كانت صورة يوتيوب، وصور كتالوج أمازون كلها Unsplash
-- (التطبيق بيرفضها). zad-brain (`_shared/pagePreview.ts`) بيقرا <meta og:image> من صفحة العرض مرة لكل رابط —
-- عروض كتير جاية من نفس الصفحة — ويكتبها هنا؛ checked_at بيتسجل حتى لو مالقاش صورة، فالصفحة ماتتقراش كل مرة.
-- صفحات أمازون وإنستجرام مابتتقراش (شروط Amazon Associates؛ إنستجرام صفحة دخول وروابط صوره بتنتهي).
-- الجدول للسيرفر بس: RLS شغال ومفيش policy، والعميل بيشوف الصورة من zad_my_deals() بس.

create table if not exists public.zad_page_previews (
  url text primary key check (url ~ '^https://' and length(url) <= 500),
  image text check (image is null or (image ~ '^https://' and length(image) <= 500)),
  checked_at timestamptz not null default now()
);

alter table public.zad_page_previews enable row level security;
revoke all on public.zad_page_previews from anon, authenticated;

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
                 z.source_url, z.valid_until, z.found_at, pv.image as preview_image,
                 case when z.price_before > z.price
                      then round((z.price_before - z.price) / z.price_before * 100) end as saving
            from public.zad_deals z
            left join public.zad_page_previews pv on pv.url = z.source_url
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
