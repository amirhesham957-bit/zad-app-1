-- ZAD_PLAN 4.19: «العرض ده غلط» — the customer's own report on the morning deal, as a third button under it.
--
-- One report per morning greeting (the moment's taste_deal), kept with what was shown (store, item, price, source)
-- so the weekly accuracy measure can count it against that source. Two different homes reporting the same
-- zad_deals row take it down at once — one home is a signal, two is a wrong deal. The reporter never sees it again:
-- answer = 'wrong' keeps its key quiet for 30 days in askedDealKeys (tasteDeals.ts).
--
-- Written only by the bot through zad_deal_report_service (service role); customers read nothing here.

create table if not exists public.zad_deal_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  moment_id uuid not null,
  deal_id uuid references public.zad_deals (id) on delete set null,
  store text not null default '',
  item_name text not null,
  price numeric,
  source_kind text,
  source_url text,
  reported_at timestamptz not null default now(),
  unique (user_id, moment_id)
);
create index if not exists zad_deal_reports_deal on public.zad_deal_reports (deal_id) where deal_id is not null;
create index if not exists zad_deal_reports_at on public.zad_deal_reports (reported_at);

alter table public.zad_deal_reports enable row level security;
revoke all on table public.zad_deal_reports from anon, authenticated;

create or replace function public.zad_deal_report_service(p_user uuid, p_moment uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_deal jsonb;
  v_item text;
  v_store text;
  v_price numeric;
  v_url text;
  v_kind text;
  v_deal_id uuid;
  v_homes int := 0;
begin
  select m.facts -> 'taste_deal' into v_deal
    from public.zad_voice_moments m
   where m.id = p_moment and m.user_id = p_user and m.moment = 'morning_greeting';
  v_item := nullif(btrim(coalesce(v_deal ->> 'item', '')), '');
  if v_item is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_deal ? 'answer' then
    return jsonb_build_object('ok', true, 'already', true, 'answer', v_deal ->> 'answer', 'item', v_item);
  end if;

  v_store := btrim(coalesce(v_deal ->> 'store', ''));
  v_price := case when jsonb_typeof(v_deal -> 'price') = 'number' then (v_deal ->> 'price')::numeric end;
  v_kind := nullif(v_deal #>> '{source,kind}', '');
  v_url := nullif(v_deal #>> '{source,url}', '');

  update public.zad_voice_moments
     set facts = jsonb_set(facts, '{taste_deal,answer}', to_jsonb('wrong'::text))
   where id = p_moment;

  -- The stored row this deal came from: same shop, same item, same link (and price when known). A live-search deal
  -- (no stored source) matches nothing and is only counted.
  if v_kind is not null then
    select d.id into v_deal_id
      from public.zad_deals d
     where d.store_key = public.zad_inventory_name_key(v_store)
       and d.item_key = public.zad_inventory_name_key(v_item)
       and d.source_kind = v_kind
       and d.source_url is not distinct from v_url
       and (v_price is null or d.price = v_price)
     order by d.found_at desc
     limit 1;
  end if;

  insert into public.zad_deal_reports (user_id, moment_id, deal_id, store, item_name, price, source_kind, source_url)
  values (p_user, p_moment, v_deal_id, v_store, v_item, v_price, v_kind, v_url)
  on conflict (user_id, moment_id) do nothing;

  if v_deal_id is not null then
    select count(distinct r.user_id) into v_homes from public.zad_deal_reports r where r.deal_id = v_deal_id;
    if v_homes >= 2 then
      delete from public.zad_deals where id = v_deal_id;
    end if;
  end if;

  return jsonb_build_object('ok', true, 'answer', 'wrong', 'item', v_item, 'removed', v_homes >= 2);
end;
$function$;

revoke all on function public.zad_deal_report_service(uuid, uuid) from public, anon, authenticated;
grant execute on function public.zad_deal_report_service(uuid, uuid) to service_role;

-- The weekly measure (4.19): per source, morning deals shown and how many the customers called wrong.
create or replace function public.zad_deal_accuracy(p_days int default 7)
returns table (source_kind text, shown bigint, wrong bigint)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select coalesce(m.facts #>> '{taste_deal,source,kind}', 'live') as source_kind,
         count(*) as shown,
         count(*) filter (where m.facts #>> '{taste_deal,answer}' = 'wrong') as wrong
    from public.zad_voice_moments m
   where m.moment = 'morning_greeting'
     and m.facts ? 'taste_deal'
     and m.created_at > now() - make_interval(days => greatest(1, least(coalesce(p_days, 7), 90)))
   group by 1
   order by 2 desc;
$function$;

revoke all on function public.zad_deal_accuracy(int) from public, anon, authenticated;
grant execute on function public.zad_deal_accuracy(int) to service_role;
