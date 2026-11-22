-- م٦.٢: الكاتب الوحيد لـ zad_restock_observations. مجهول بقصد: مفيش user_id ولا family_id، فمش بيعدي من zad_commit_intent
-- (الباب بيسجّل صاحب الحدث في zad_events، وده بيكسر «ما يتقالش مين اشترى»). service_role بس (النشرات والشركاء والفواتير بعد ما تتجرّد من صاحبها).
-- الموقع بيتقرّب لرقمين عشريين، والملاحظة المتكررة لنفس (محل، صنف، حالة) في ساعة بتتجاهل.

create or replace function public.zad_restock_observe(
  p_country text,
  p_store_key text,
  p_item_key text,
  p_in_stock boolean,
  p_source_kind text,
  p_lat numeric default null,
  p_lng numeric default null,
  p_observed_at timestamptz default null
) returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_at timestamptz := least(coalesce(p_observed_at, now()), now());
begin
  if p_country is null or p_country !~ '^[A-Za-z]{2}$' then raise exception 'bad_country'; end if;
  if p_in_stock is null then raise exception 'bad_in_stock'; end if;
  if p_source_kind not in ('receipt', 'flyer', 'partner') then raise exception 'bad_source'; end if;
  if v_at < now() - interval '90 days' then return false; end if;
  if exists (
    select 1 from public.zad_restock_observations o
     where o.country = upper(p_country) and o.store_key = btrim(p_store_key) and o.item_key = btrim(p_item_key)
       and o.in_stock = p_in_stock and o.observed_at > v_at - interval '1 hour'
  ) then return false; end if;
  insert into public.zad_restock_observations (country, store_key, item_key, in_stock, source_kind, observed_at, area_lat, area_lng)
  values (upper(p_country), btrim(p_store_key), btrim(p_item_key), p_in_stock, p_source_kind, v_at,
          case when p_lat between -90 and 90 then round(p_lat, 2) end,
          case when p_lng between -180 and 180 then round(p_lng, 2) end);
  return true;
end;
$$;
revoke all on function public.zad_restock_observe(text, text, text, boolean, text, numeric, numeric, timestamptz) from public, anon, authenticated;
grant execute on function public.zad_restock_observe(text, text, text, boolean, text, numeric, numeric, timestamptz) to service_role;
