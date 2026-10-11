-- 20261011180000 — بلاغ السعر من السيرفر نفسه (الموجة ٥، ٢٠٢٦-١٠-١١).
--
-- صورة البون في تليجرام بقت بتملا المخزن وتشطب القايمة وتسجل المصروف باسم المحل
-- (f674a5e5، 9fc0b23c)، بس أسعارها ماكانتش بتوصل للجمهور: zad_report_price بتاخد العميل من
-- auth.uid()، والبوت شغال بصلاحية السيرفر من غير جلسة عميل. price_index على الحي = صفر صف.
--
-- الحل من غير ما القواعد تتكرر في مكانين:
--   private.zad_report_price_impl(p_uid, …) — نفس جسم zad_report_price حرفياً (20260921160000،
--     ومطابق للنص الحي اللي اتقرا ٢٠٢٦-١٠-١١) والفرق الوحيد إن العميل جاي في p_uid.
--   public.zad_report_price(…)       — للتطبيق: نفس التوقيع والصلاحيات، بتنادي الـimpl بـauth.uid().
--   public.zad_report_price_for(p_user, …) — للسيرفر بس (service_role): البوت بيبلّغ باسم صاحب البون.
-- نفس الحدود والتصحيح خلال ١٢ ساعة و٣٠ بلاغ في الساعة للعميل، أياً كان الباب.

create schema if not exists private;

create or replace function private.zad_report_price_impl(
  p_uid uuid,
  p_report uuid,
  p_item text,
  p_price numeric,
  p_currency text default null,
  p_location text default null,
  p_store text default null,
  p_category text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := p_uid;
  v_item text := btrim(regexp_replace(coalesce(p_item, ''), '\s+', ' ', 'g'));
  v_key text;
  v_location text := nullif(btrim(regexp_replace(coalesce(p_location, ''), '\s+', ' ', 'g')), '');
  v_store text := nullif(btrim(regexp_replace(coalesce(p_store, ''), '\s+', ' ', 'g')), '');
  v_category text := nullif(btrim(coalesce(p_category, '')), '');
  v_currency text;
  v_id bigint;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if p_report is null
     or char_length(v_item) < 2 or char_length(v_item) > 60
     or p_price is null or p_price <= 0 or p_price > 1000000
     or char_length(coalesce(v_location, '')) > 60
     or char_length(coalesce(v_store, '')) > 60
     or char_length(coalesce(v_category, '')) > 40 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  -- A replay of a report already taken.
  select id into v_id from public.price_index where client_report_id = p_report;
  if found then
    return jsonb_build_object('ok', true, 'duplicate', true, 'id', v_id);
  end if;

  -- The account's own currency; the phone's only when the account has none yet.
  select nullif(upper(btrim(coalesce(currency, ''))), '') into v_currency
  from public.zad_users where id = v_uid;
  v_currency := coalesce(v_currency, upper(btrim(coalesce(p_currency, ''))));
  if v_currency !~ '^[A-Z]{3}$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_currency');
  end if;

  v_key := lower(v_item);

  -- One voice per item per store per city per half day: a second report corrects the
  -- first. Two different reports of the same item arriving together would both miss
  -- the row the other is about to write, so the account and item are locked first.
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || '|' || v_key, 0));

  select id into v_id
  from public.price_index
  where user_id = v_uid
    and source = 'crowdsource'
    and currency = v_currency
    and lower(btrim(regexp_replace(item_name, '\s+', ' ', 'g'))) = v_key
    and coalesce(lower(store_name), '') = coalesce(lower(v_store), '')
    and coalesce(lower(location), '') = coalesce(lower(v_location), '')
    and "timestamp" > now() - interval '12 hours'
  order by "timestamp" desc
  limit 1;
  if found then
    update public.price_index
    set price = p_price, item_name = v_item, item_category = coalesce(v_category, item_category),
        "timestamp" = now()
    where id = v_id;
    return jsonb_build_object('ok', true, 'updated', true, 'id', v_id, 'currency', v_currency);
  end if;

  if (select count(*) from public.price_index
      where user_id = v_uid and source = 'crowdsource'
        and "timestamp" > now() - interval '1 hour') >= 30 then
    return jsonb_build_object('ok', false, 'reason', 'too_many');
  end if;

  insert into public.price_index
    (item_name, item_category, price, currency, user_id, location, store_name, source,
     client_report_id)
  values
    (v_item, v_category, p_price, v_currency, v_uid, v_location, v_store, 'crowdsource',
     p_report)
  on conflict (client_report_id) where client_report_id is not null do nothing
  returning id into v_id;

  if v_id is null then
    -- The same report arrived twice at once; the other one took it.
    select id into v_id from public.price_index where client_report_id = p_report;
    return jsonb_build_object('ok', true, 'duplicate', true, 'id', v_id);
  end if;

  return jsonb_build_object('ok', true, 'id', v_id, 'currency', v_currency);
end;
$$;

revoke all on function private.zad_report_price_impl(uuid, uuid, text, numeric, text, text, text, text)
  from public, anon, authenticated;

create or replace function public.zad_report_price(
  p_report uuid,
  p_item text,
  p_price numeric,
  p_currency text default null,
  p_location text default null,
  p_store text default null,
  p_category text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return private.zad_report_price_impl(auth.uid(), p_report, p_item, p_price, p_currency, p_location, p_store, p_category);
end;
$$;

create or replace function public.zad_report_price_for(
  p_user uuid,
  p_report uuid,
  p_item text,
  p_price numeric,
  p_currency text default null,
  p_location text default null,
  p_store text default null,
  p_category text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return private.zad_report_price_impl(p_user, p_report, p_item, p_price, p_currency, p_location, p_store, p_category);
end;
$$;

revoke all on function public.zad_report_price_for(uuid, uuid, text, numeric, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.zad_report_price_for(uuid, uuid, text, numeric, text, text, text, text)
  to service_role;
