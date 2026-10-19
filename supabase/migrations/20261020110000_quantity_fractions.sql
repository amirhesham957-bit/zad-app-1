-- ZAD_PLAN ٣.٨ — الكميات بكسور (٢٠٢٦-١٠-٢٠، بلاغ المالك ١٩/١٠).
--
-- «نص كيلو رز» كان بيتسجّل ١ كيلو: zad_inventory.quantity كان integer (اتقرا من الحي ١٩/١٠)، وباب الشرا
-- بيقرّب الكمية لعدد صحيح وأقل حاجة ١ (20261019180000 وبعده). ملاحظات الاستهلاك
-- (zad_inventory_observations.qty) numeric من الأول، فالمعدّل كان بيتعلم من رقم متقرّب.
--
-- هنا: الكمية والحد بقوا numeric(12,3)، وباب الشرا بيحط الكمية زي ما هي (٣ أرقام عشرية) في المخزن. الصيدلية
-- لسه بالحبة (zad_pharmacy_restock بياخد integer).
--
-- التريجرين اللي على «update of quantity» (restock_link، companion_xp) بيمنعوا تغيير النوع («cannot alter
-- type of a column used in a trigger definition» — وقّف نشر #207 على الإنتاج ١٩/١٠). بيتشالوا ويرجعوا زي
-- ما هم بالظبط في نفس المعاملة.

drop trigger if exists trigger_restock_link_on_run_out on public.zad_inventory;
drop trigger if exists zad_companion_xp on public.zad_inventory;

alter table public.zad_inventory
  alter column quantity type numeric(12,3) using quantity::numeric,
  alter column low_stock_threshold type numeric(12,3) using low_stock_threshold::numeric;

create trigger trigger_restock_link_on_run_out
  after update of quantity on public.zad_inventory
  for each row execute function public._zad_restock_link_on_run_out();
create trigger zad_companion_xp after insert or update of quantity on public.zad_inventory
  for each row execute function public.zad_companion_on_home();

create or replace function private.zad_record_purchase_impl(p_user uuid, p_purchase jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_amount numeric;
  v_title text;
  v_category text;
  v_wallet text;
  v_source text;
  v_merchant text;
  v_store text;
  v_at timestamptz;
  v_merge uuid;
  v_lines jsonb;
  v_family uuid;
  v_prior jsonb;
  v_txn uuid;
  v_status text;
  v_twin record;
  v_line jsonb;
  v_i int := 0;
  v_name text;
  v_key text;
  v_words text;
  v_qty numeric;
  v_unit text;
  v_line_category text;
  v_price numeric;
  v_dest text;
  v_row record;
  v_shop uuid;
  v_rx jsonb;
  v_rep jsonb;
  v_prices_open boolean := true;
  v_lines_only boolean;
  v_added int := 0;
  v_topped int := 0;
  v_ticked int := 0;
  v_restocked int := 0;
  v_reported int := 0;
  v_skipped jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  if p_user is null or p_purchase is null or jsonb_typeof(p_purchase) <> 'object' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  begin
    v_id := (p_purchase ->> 'id')::uuid;
    v_amount := round((p_purchase ->> 'amount')::numeric, 2);
    v_at := coalesce((p_purchase ->> 'spent_at')::timestamptz, now());
    v_merge := nullif(p_purchase ->> 'merge_with', '')::uuid;
    -- No amount at all: the lines without an expense (Telegram's «المخزن بس» — the bank
    -- records the payment). An amount that is there must still be a real one.
    v_lines_only := coalesce(jsonb_typeof(p_purchase -> 'amount'), 'null') = 'null';
  exception when others then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end;

  v_title := left(nullif(btrim(coalesce(p_purchase ->> 'title', '')), ''), 80);
  v_category := left(nullif(btrim(coalesce(p_purchase ->> 'category', '')), ''), 40);
  v_wallet := case when p_purchase ->> 'wallet' in ('cash', 'bank') then p_purchase ->> 'wallet' else 'card' end;
  v_source := left(nullif(btrim(coalesce(p_purchase ->> 'source_type', '')), ''), 40);
  v_merchant := left(nullif(btrim(coalesce(p_purchase ->> 'merchant_name', '')), ''), 80);
  v_store := coalesce(v_merchant, left(nullif(btrim(coalesce(p_purchase ->> 'store', '')), ''), 80));
  v_lines := coalesce(p_purchase -> 'lines', '[]'::jsonb);

  if v_id is null or v_title is null or jsonb_typeof(v_lines) <> 'array' or jsonb_array_length(v_lines) > 100
     or (not v_lines_only and (v_amount is null or v_amount <= 0 or v_amount > 10000000))
     or (v_lines_only and (jsonb_array_length(v_lines) = 0 or v_merge is not null)) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  -- Two calls with one id (a retry racing the first) wait for each other here, and the
  -- second one finds the first one's answer below.
  perform pg_advisory_xact_lock(hashtextextended('zad_purchase:' || v_id::text, 0));

  select result into v_prior from public.zad_purchases where id = v_id and user_id = p_user;
  if found then
    return v_prior || jsonb_build_object('replayed', true);
  end if;
  if exists (select 1 from public.zad_purchases where id = v_id)
     or exists (select 1 from public.zad_transactions where id = v_id) then
    return jsonb_build_object('ok', false, 'reason', 'id_in_use');
  end if;

  -- 1. The money — none in lines-only mode.
  if v_lines_only then
    v_status := 'lines_only';
  elsif v_merge is not null then
    update public.zad_transactions
       set title = v_title,
           category = coalesce(v_category, category),
           merchant_name = coalesce(v_merchant, merchant_name)
     where id = v_merge and user_id = p_user and txn_kind = 'expense'
     returning id into v_txn;
    if v_txn is null then
      return jsonb_build_object('ok', false, 'reason', 'merge_target_not_found');
    end if;
    v_status := 'merged';
  else
    -- Same amount, same kind, within ten minutes of it: log_transaction's rule (index.ts,
    -- the 2026-08-15 triple salary). Nothing is written; the caller asks the customer, and
    -- their «لأ، دي عملية تانية» comes back as allow_duplicate.
    if coalesce((p_purchase ->> 'allow_duplicate')::boolean, false) is not true then
      select t.id, t.title, t.created_at into v_twin
        from public.zad_transactions t
       where t.user_id = p_user and t.txn_kind = 'expense'
         and abs(t.amount - v_amount) < 0.005
         and t.created_at between v_at - interval '10 minutes' and v_at + interval '10 minutes'
       order by abs(extract(epoch from t.created_at - v_at))
       limit 1;
      if found then
        return jsonb_build_object(
          'ok', false, 'status', 'duplicate_suspected',
          'twin', jsonb_build_object('id', v_twin.id, 'title', v_twin.title, 'created_at', v_twin.created_at));
      end if;
    end if;

    insert into public.zad_transactions
      (id, user_id, amount, title, category, is_expense, txn_kind, wallet, merchant_name, source_type, created_at)
    values
      (v_id, p_user, v_amount, v_title, v_category, true, 'expense', v_wallet, v_merchant, v_source, v_at)
    returning id into v_txn;
    v_status := 'recorded';
  end if;

  select m.family_id into v_family from public.family_members m where m.user_id = p_user limit 1;

  -- 2–4. The lines.
  for v_line in select value from jsonb_array_elements(v_lines) loop
    v_dest := coalesce(v_line ->> 'to', 'none');
    v_name := left(nullif(btrim(regexp_replace(coalesce(v_line ->> 'name', ''), '\s+', ' ', 'g')), ''), 80);
    begin
      -- The real amount, not a whole number: half a kilo of rice stays half a kilo (ZAD_PLAN
      -- ٣.٨, the owner 2026-10-19). Three decimals; a missing or non-positive one is one.
      v_qty := round(least(10000, coalesce(nullif(greatest((v_line ->> 'quantity')::numeric, 0), 0), 1)), 3);
      if v_qty <= 0 then v_qty := 0.001; end if;
    exception when others then
      v_qty := null;
    end;
    -- A price that cannot be read costs the line its price report, never the line.
    begin
      v_price := nullif((v_line ->> 'price')::numeric, 0);
    exception when others then
      v_price := null;
    end;
    v_unit := left(nullif(btrim(coalesce(v_line ->> 'unit', '')), ''), 20);
    v_line_category := left(nullif(btrim(coalesce(v_line ->> 'category', '')), ''), 40);

    if v_name is null or v_qty is null or v_dest not in ('pantry', 'pharmacy', 'none') then
      v_skipped := v_skipped || to_jsonb(v_i);
      v_i := v_i + 1;
      continue;
    end if;

    if v_dest = 'pantry' then
      v_name := coalesce(private.zad_product_canonical_for(p_user, v_name), v_name);
      v_key := public.zad_inventory_name_key(v_name);
      v_words := private.zad_name_words(v_key);

      -- The household's row for the same item (pantryMatch.ts pickPantryMatch): the
      -- customer's own first, then the family's; the exact name before the reordered
      -- words; a different unit, when both say one, is a different item.
      select i.id, i.user_id, i.item_name, i.quantity into v_row
        from public.zad_inventory i
       where (i.user_id = p_user or (v_family is not null and i.family_id = v_family))
         and (public.zad_inventory_name_key(i.item_name) = v_key
              or private.zad_name_words(public.zad_inventory_name_key(i.item_name)) = v_words)
         and (v_unit is null or nullif(btrim(coalesce(i.unit, '')), '') is null or btrim(i.unit) = v_unit)
       order by (i.user_id = p_user) desc,
                (public.zad_inventory_name_key(i.item_name) = v_key) desc,
                i.created_at desc nulls last
       limit 1
       for update;

      if found then
        update public.zad_inventory
           set quantity = greatest(coalesce(quantity, 0), 0) + v_qty,
               category = coalesce(category, v_line_category)
         where id = v_row.id;
        -- The learner reads rates per row owner (zad_consumption.user_id), so the
        -- reading goes under the owner even when another member bought it.
        insert into public.zad_inventory_observations (user_id, item_name, qty, source)
        values (v_row.user_id, v_row.item_name, greatest(coalesce(v_row.quantity, 0), 0) + v_qty, 'purchase');
        perform public.zad_recompute_consumption(v_row.user_id, private.zad_product_canonical_for(v_row.user_id, v_row.item_name));
        v_topped := v_topped + 1;
      else
        insert into public.zad_inventory (user_id, item_name, quantity, unit, category)
        values (p_user, v_name, v_qty, coalesce(v_unit, 'حبة'), v_line_category);
        insert into public.zad_inventory_observations (user_id, item_name, qty, source)
        values (p_user, v_name, v_qty, 'purchase');
        perform public.zad_recompute_consumption(p_user, private.zad_product_canonical_for(p_user, v_name));
        v_added := v_added + 1;
      end if;

      -- One open shopping-list line for it, the customer's own first.
      select s.id into v_shop
        from public.zad_shopping_list s
       where (s.user_id = p_user or (v_family is not null and s.family_id = v_family))
         and s.is_purchased = false
         and (public.zad_inventory_name_key(s.item_name) = v_key
              or private.zad_name_words(public.zad_inventory_name_key(s.item_name)) = v_words)
       order by (s.user_id = p_user) desc, s.created_at desc nulls last
       limit 1
       for update;
      if found then
        update public.zad_shopping_list set is_purchased = true where id = v_shop;
        v_ticked := v_ticked + 1;
      end if;

      -- Crowd prices: after the first refusal the rest would be refused for the same
      -- reason (too_many, invalid_currency), so stop asking.
      if v_prices_open and v_price is not null and v_price > 0 and v_store is not null then
        begin
          v_rep := private.zad_report_price_impl(
            p_user, md5(v_id::text || ':price:' || v_i)::uuid, v_name,
            round(v_price / v_qty, 2), null, null, v_store, v_line_category);
          if coalesce((v_rep ->> 'ok')::boolean, false) then
            v_reported := v_reported + 1;
          else
            v_prices_open := false;
          end if;
        exception when others then
          v_prices_open := false;
        end;
      end if;

    elsif v_dest = 'pharmacy' then
      v_rx := public.zad_pharmacy_restock(
        p_user,
        md5(v_id::text || ':rx:' || v_i)::uuid,
        coalesce(nullif(v_line ->> 'item_id', '')::uuid, md5(v_id::text || ':rxitem:' || v_i)::uuid),
        -- Pills are whole: the pharmacy counts units.
        greatest(1, round(v_qty))::int, v_name, v_unit, v_line_category);
      if coalesce((v_rx ->> 'ok')::boolean, false) then
        v_restocked := v_restocked + 1;
      else
        v_skipped := v_skipped || to_jsonb(v_i);
      end if;
    end if;

    v_i := v_i + 1;
  end loop;

  v_result := jsonb_build_object(
    'ok', true,
    'status', v_status,
    'purchase_id', v_id,
    'transaction_id', v_txn,
    'pantry', jsonb_build_object('added', v_added, 'topped_up', v_topped, 'ticked', v_ticked),
    'pharmacy', jsonb_build_object('restocked', v_restocked),
    'prices', jsonb_build_object('reported', v_reported),
    'skipped', v_skipped);

  insert into public.zad_purchases (id, user_id, transaction_id, source_type, lines, result)
  values (v_id, p_user, v_txn, v_source, v_lines, v_result);

  return v_result;
end;
$$;

revoke all on function private.zad_record_purchase_impl(uuid, jsonb) from public, anon, authenticated;
