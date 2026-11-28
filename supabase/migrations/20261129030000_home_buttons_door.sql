-- P1.6b (البيت): صيانة الأجهزة والمستندات من الزرار بتعدي من الباب.
--   * zad_intent_maintenance = نسخة 20261122070000 + purchase_date اختياري في maintenance.added (الزرار بيبعته).
--   * zad_commit_my_intent = نسخة 20261129020000 + maintenance.added/updated/deleted وdocument.saved/deleted.
-- مجال المستندات (zad_intent_document) مابيتغيّرش. «فنيين موثوقين» ماليهمش نوع في الباب، فبيفضلوا كتابة مباشرة.

create or replace function public.zad_intent_maintenance(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_patch jsonb;
  v_row public.zad_maintenance_items%rowtype;
  v_row_id uuid;
  v_before jsonb := '{}'::jsonb;
  v_key text;
  v_name text;
  v_category text;
  v_cost numeric;
  v_interval numeric;
  v_purchase text;
begin
  if p_kind not in ('maintenance.added', 'maintenance.updated', 'maintenance.deleted') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind in ('maintenance.updated', 'maintenance.deleted') then
    begin
      select * into v_row from public.zad_maintenance_items
       where id = (v_payload ->> 'item_id')::uuid and user_id = p_uid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
  end if;

  if p_kind = 'maintenance.added' then
    v_name := btrim(coalesce(v_payload ->> 'name', ''));
    v_category := coalesce(nullif(btrim(coalesce(v_payload ->> 'category', '')), ''), 'عام');
    if length(v_name) not between 2 and 120 then
      return jsonb_build_object('ok', false, 'reason', 'device_name_invalid');
    elsif length(v_category) > 60 then
      return jsonb_build_object('ok', false, 'reason', 'device_category_invalid');
    end if;
    v_purchase := nullif(v_payload ->> 'purchase_date', '');
    if v_purchase is not null and not public.zad_intent_maintenance_date(v_purchase) then
      return jsonb_build_object('ok', false, 'reason', 'day_invalid');
    end if;
    if nullif(v_payload ->> 'warranty_expiry_date', '') is not null
       and not public.zad_intent_maintenance_date(v_payload ->> 'warranty_expiry_date') then
      return jsonb_build_object('ok', false, 'reason', 'day_invalid');
    end if;
    begin
      v_interval := (v_payload ->> 'service_interval_days')::numeric;
      v_cost := coalesce((v_payload ->> 'estimated_cost')::numeric, 0);
    exception when others then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end;
    if v_interval is not null and (v_interval <= 0 or v_interval <> trunc(v_interval) or v_interval > 36500) then
      return jsonb_build_object('ok', false, 'reason', 'interval_invalid');
    elsif v_cost < 0 or v_cost > 1000000000 then
      return jsonb_build_object('ok', false, 'reason', 'cost_invalid');
    end if;
    insert into public.zad_maintenance_items (user_id, name, category, purchase_date, warranty_expiry_date, service_interval_days, estimated_cost)
    values (p_uid, v_name, v_category, v_purchase, nullif(v_payload ->> 'warranty_expiry_date', ''), v_interval::int, v_cost)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null,
      'after', (select to_jsonb(m) from public.zad_maintenance_items m where m.id = v_row_id));
  elsif p_kind = 'maintenance.updated' then
    v_patch := v_payload -> 'patch';
    if v_patch is null or jsonb_typeof(v_patch) <> 'object' or v_patch = '{}'::jsonb then
      return jsonb_build_object('ok', false, 'reason', 'patch_empty');
    end if;
    for v_key in select jsonb_object_keys(v_patch) loop
      if v_key not in ('last_service_date', 'warranty_expiry_date') then
        return jsonb_build_object('ok', false, 'reason', 'patch_field_unknown');
      end if;
      if jsonb_typeof(v_patch -> v_key) <> 'string' or not public.zad_intent_maintenance_date(v_patch ->> v_key) then
        return jsonb_build_object('ok', false, 'reason', 'day_invalid');
      end if;
      v_before := v_before || jsonb_build_object(v_key, to_jsonb(v_row) -> v_key);
    end loop;
    update public.zad_maintenance_items
       set last_service_date = case when v_patch ? 'last_service_date' then v_patch ->> 'last_service_date' else last_service_date end,
           warranty_expiry_date = case when v_patch ? 'warranty_expiry_date' then v_patch ->> 'warranty_expiry_date' else warranty_expiry_date end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_before,
      'after', (select to_jsonb(m) from public.zad_maintenance_items m where m.id = v_row_id));
  else
    delete from public.zad_maintenance_items where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_maintenance(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;

create or replace function public.zad_commit_my_intent(
  p_kind text,
  p_client_event_id text,
  p_payload jsonb,
  p_occurred_at timestamptz default null,
  p_trace_id text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $w$
declare
  v_uid uuid := auth.uid();
  v_intent jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  end if;
  if p_kind is null or p_kind not in ('inventory.added', 'inventory.consumed', 'inventory.quantity_set',
                                      'inventory.rate_corrected',
                                      'money.logged', 'money.updated', 'money.deleted', 'money.limit_set',
                                      'money.category_budget_set', 'settings.emergency_fund_set',
                                      'debt.added', 'debt.updated', 'debt.deleted',
                                      'obligation.added', 'obligation.updated', 'obligation.deleted',
                                      'subscription.added', 'subscription.updated', 'subscription.deleted',
                                      'settings.cycle_start_set', 'settings.market_set', 'settings.app_flag_set',
                                      'maintenance.added', 'maintenance.updated', 'maintenance.deleted',
                                      'document.saved', 'document.deleted') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;
  if p_occurred_at is not null and p_occurred_at > now() + interval '1 hour' then
    return jsonb_build_object('ok', false, 'reason', 'bad_shape');
  end if;

  v_intent := jsonb_build_object(
    'kind', p_kind,
    'client_event_id', p_client_event_id,
    'source', 'manual',
    'payload', p_payload);
  if p_occurred_at is not null then
    v_intent := v_intent || jsonb_build_object('occurred_at', p_occurred_at);
  end if;
  if nullif(btrim(coalesce(p_trace_id, '')), '') is not null then
    v_intent := v_intent || jsonb_build_object('trace_id', btrim(p_trace_id));
  end if;
  return public.zad_commit_intent(v_intent);
end;
$w$;

revoke all on function public.zad_commit_my_intent(text, text, jsonb, timestamptz, text) from public, anon;
grant execute on function public.zad_commit_my_intent(text, text, jsonb, timestamptz, text) to authenticated, service_role;
