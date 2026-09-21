-- Crowd price reports go through the server, and nobody reads anybody else's.
--
-- What was open on price_index (read off the live project 2026-09-21; the table was
-- empty that day):
--
--   price_index_public_read             SELECT to public USING (true) — anyone, signed in
--                                       or not, could read every report with its user_id,
--                                       city, store and time: who was where, and when;
--   price_index_server_write            INSERT to public CHECK (user_id IS NULL) — anyone,
--                                       signed in or not, could insert any row without a
--                                       user: any source (a fake 'usda' reference price),
--                                       any currency, any price. Those rows feed
--                                       zad_cheapest_prices and the daily community post
--                                       on Telegram;
--   price_index_user_crowdsource_write  a signed-in user could insert as themselves, any
--                                       source, no bounds, as often as they liked — and
--                                       the leaderboard and the "reports" count are just
--                                       counts of rows.
--
-- After this migration:
--
--   * a client inserts, updates and deletes nothing directly. A report goes through
--     zad_report_price (security definer): signed in, source fixed to 'crowdsource',
--     the account's own currency, bounded fields;
--   * it is idempotent on an id the phone makes, so the outbox can replay it;
--   * the same person reporting the same item at the same store and city within 12 hours
--     corrects their report instead of adding a second one — one person is one voice
--     per item per store per half day, whatever the button count;
--   * 30 new reports an hour per account;
--   * a client reads only its own rows (Kotlin's achievements count them). The
--     aggregates — zad_cheapest_prices, and the new zad_price_leaderboard — are security
--     definer and return no user ids.
--
-- The service role (zad-brain, the Telegram bot, the reference-price jobs) bypasses RLS
-- and is unaffected.
--
-- Written for a hand-apply through execute_sql (no version stamped); every statement is
-- idempotent, so CI re-running this file changes nothing.

alter table public.price_index
  add column if not exists client_report_id uuid;

create unique index if not exists price_index_client_report_id
  on public.price_index (client_report_id) where client_report_id is not null;

-- ── Policies ─────────────────────────────────────────────────────────────────

drop policy if exists price_index_public_read on public.price_index;
drop policy if exists price_index_server_write on public.price_index;
drop policy if exists price_index_user_crowdsource_write on public.price_index;

drop policy if exists price_index_read_own on public.price_index;
create policy price_index_read_own on public.price_index
  for select to authenticated
  using (user_id = (select auth.uid()));

revoke insert, update, delete on public.price_index from anon, authenticated;

-- ── Reporting ────────────────────────────────────────────────────────────────

-- Expected refusals are answers, not exceptions, so the phone can tell a bad report
-- (drop it, say why) from a failed send (keep it, try again).
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
declare
  v_uid uuid := auth.uid();
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

-- ── Reading ──────────────────────────────────────────────────────────────────

-- Unchanged but for security definer: a client now reads only its own rows, and the
-- cheapest price has to see everyone's. It returns no user id.
create or replace function public.zad_cheapest_prices(
  p_currency text,
  p_location text default null,
  p_days int default 14,
  p_limit int default 20
)
returns table (
  item_name text,
  min_price double precision,
  avg_price double precision,
  reports int,
  cheapest_location text,
  cheapest_store text,
  last_reported timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with recent as (
    select lower(btrim(regexp_replace(p.item_name, '\s+', ' ', 'g'))) as item_key,
           btrim(p.item_name) as item_name, p.price, p.location, p.store_name, p."timestamp" as reported_at
    from public.price_index p
    where p.source = 'crowdsource'
      and p.currency = p_currency
      and p.price > 0
      and p."timestamp" > now() - make_interval(days => greatest(1, least(coalesce(p_days, 14), 60)))
      and (p_location is null or btrim(p_location) = '' or p.location ilike '%' || btrim(p_location) || '%')
  ),
  stats as (
    select item_key, min(price) as min_price, avg(price) as avg_price, count(*)::int as reports, max(reported_at) as last_reported
    from recent group by item_key
  ),
  cheapest as (
    select distinct on (item_key) item_key, item_name, location, store_name
    from recent order by item_key, price asc, reported_at desc
  )
  select c.item_name, s.min_price, round(s.avg_price::numeric, 2)::double precision, s.reports,
         c.location, c.store_name, s.last_reported
  from stats s join cheapest c using (item_key)
  order by s.reports desc, s.last_reported desc
  limit greatest(1, least(coalesce(p_limit, 20), 50));
$function$;

-- Who reports most, without saying who: a rank, a count, and whether it is the caller.
create or replace function public.zad_price_leaderboard(
  p_currency text default null,
  p_days int default 30
)
returns table (rank int, reports int, is_me boolean)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with counts as (
    select user_id, count(*)::int as reports, max("timestamp") as last_at
    from public.price_index
    where source = 'crowdsource'
      and user_id is not null
      and (p_currency is null or currency = p_currency)
      and "timestamp" > now() - make_interval(days => greatest(1, least(coalesce(p_days, 30), 90)))
    group by user_id
  )
  select (row_number() over (order by reports desc, last_at desc))::int, reports,
         user_id = auth.uid()
  from counts
  order by reports desc, last_at desc
  limit 10;
$function$;

-- ── Who may call what ────────────────────────────────────────────────────────

revoke all on function public.zad_report_price(uuid, text, numeric, text, text, text, text)
  from public, anon;
grant execute on function public.zad_report_price(uuid, text, numeric, text, text, text, text)
  to authenticated;

revoke all on function public.zad_cheapest_prices(text, text, int, int) from public, anon;
grant execute on function public.zad_cheapest_prices(text, text, int, int)
  to authenticated, service_role;

revoke all on function public.zad_price_leaderboard(text, int) from public, anon;
grant execute on function public.zad_price_leaderboard(text, int) to authenticated;
