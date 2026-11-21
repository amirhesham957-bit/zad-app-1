-- الباب الوحيد: مجال الالتزامات الثابتة (ZAD_OR_PLAN م٢.٥، ٢٢/١١). الأنواع:
--   obligation.added        {title, amount, kind, recurrence?, due_day?, provider?, total_installments?, auto_detected?, confirmed?}
--                           العنوان ٢–١٢٠، المبلغ > ٠ و≤ ١٠٠ مليون، النوع من قيد الجدول، التكرار monthly|quarterly|yearly|once،
--                           اليوم ١–٣١، مزوّد التقسيط تابي/تمارة/فاليو (وغيره بيتحول لفاضي)، عدد الأقساط بس مع المزوّد.
--   obligation.updated      {item_id, patch:{amount, due_day}}
--   obligation.deactivated  {item_id}   حذف ناعم: active=false والصف يفضل (التراجع بيرجّعه)، ونفس الطلب على صف مقفول = already_inactive.
-- الصف بيتدوّر عليه بـ id + user_id، ومش موجود/بتاع حد تاني = item_not_found.

create or replace function public.zad_intent_obligation(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_patch jsonb;
  v_row public.zad_obligations%rowtype;
  v_key text;
  v_title text;
  v_amount numeric;
  v_kind text;
  v_recurrence text;
  v_day int;
  v_provider text;
  v_total int;
  v_row_id uuid;
begin
  if p_kind not in ('obligation.added', 'obligation.updated', 'obligation.deactivated') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind in ('obligation.updated', 'obligation.deactivated') then
    begin
      select * into v_row from public.zad_obligations
       where id = (v_payload ->> 'item_id')::uuid and user_id = p_uid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
  end if;

  if p_kind = 'obligation.added' then
    v_title := btrim(coalesce(v_payload ->> 'title', ''));
    if length(v_title) not between 2 and 120 then
      return jsonb_build_object('ok', false, 'reason', 'obligation_title_invalid');
    end if;
    begin
      v_amount := round((v_payload ->> 'amount')::numeric, 2);
    exception when others then
      v_amount := null;
    end;
    if v_amount is null or v_amount <= 0 then
      return jsonb_build_object('ok', false, 'reason', 'amount_not_positive');
    elsif v_amount > 100000000 then
      return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
    end if;
    v_kind := v_payload ->> 'kind';
    if v_kind is null or v_kind not in ('rent', 'installment', 'debt', 'tuition', 'utility', 'other') then
      return jsonb_build_object('ok', false, 'reason', 'obligation_kind_invalid');
    end if;
    v_recurrence := coalesce(nullif(v_payload ->> 'recurrence', ''), 'monthly');
    if v_recurrence not in ('monthly', 'quarterly', 'yearly', 'once') then
      return jsonb_build_object('ok', false, 'reason', 'recurrence_invalid');
    end if;
    if nullif(v_payload ->> 'due_day', '') is not null then
      begin
        v_day := (v_payload ->> 'due_day')::int;
      exception when others then
        v_day := null;
      end;
      if v_day is null or v_day not between 1 and 31 then
        return jsonb_build_object('ok', false, 'reason', 'due_day_invalid');
      end if;
    end if;
    v_provider := nullif(btrim(coalesce(v_payload ->> 'provider', '')), '');
    if v_provider is not null and v_provider not in ('تابي', 'تمارة', 'فاليو') then
      v_provider := null;
    end if;
    -- عدد الأقساط له معنى مع مزوّد تقسيط بس، وهو اللي المتبقي منه بيبدأ.
    if v_provider is not null and nullif(v_payload ->> 'total_installments', '') is not null then
      begin
        v_total := round((v_payload ->> 'total_installments')::numeric)::int;
      exception when others then
        v_total := null;
      end;
      if v_total is null or v_total <= 0 or v_total > 600 then
        return jsonb_build_object('ok', false, 'reason', 'installments_invalid');
      end if;
    end if;
    insert into public.zad_obligations (user_id, title, amount, kind, recurrence, due_day, auto_detected, confirmed, active,
                                        provider, total_installments, remaining_installments)
    values (p_uid, v_title, v_amount, v_kind, v_recurrence, v_day,
            coalesce((v_payload ->> 'auto_detected')::boolean, false), coalesce((v_payload ->> 'confirmed')::boolean, true), true,
            v_provider, v_total, v_total)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null,
      'after', (select to_jsonb(o) from public.zad_obligations o where o.id = v_row_id));
  elsif p_kind = 'obligation.updated' then
    v_patch := v_payload -> 'patch';
    if v_patch is null or jsonb_typeof(v_patch) <> 'object' or v_patch = '{}'::jsonb then
      return jsonb_build_object('ok', false, 'reason', 'patch_empty');
    end if;
    for v_key in select jsonb_object_keys(v_patch) loop
      if v_key not in ('amount', 'due_day') then
        return jsonb_build_object('ok', false, 'reason', 'patch_field_unknown');
      end if;
    end loop;
    if v_patch ? 'amount' then
      begin
        v_amount := round((v_patch ->> 'amount')::numeric, 2);
      exception when others then
        v_amount := null;
      end;
      if v_amount is null or v_amount <= 0 then
        return jsonb_build_object('ok', false, 'reason', 'amount_not_positive');
      elsif v_amount > 100000000 then
        return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
      end if;
    end if;
    if v_patch ? 'due_day' then
      begin
        v_day := (v_patch ->> 'due_day')::int;
      exception when others then
        v_day := null;
      end;
      if v_day is null or v_day not between 1 and 31 then
        return jsonb_build_object('ok', false, 'reason', 'due_day_invalid');
      end if;
    end if;
    update public.zad_obligations
       set amount = case when v_patch ? 'amount' then v_amount else amount end,
           due_day = case when v_patch ? 'due_day' then v_day else due_day end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row),
      'after', (select to_jsonb(o) from public.zad_obligations o where o.id = v_row_id));
  else
    if not v_row.active then
      return jsonb_build_object('ok', false, 'reason', 'already_inactive');
    end if;
    update public.zad_obligations set active = false where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row),
      'after', (select to_jsonb(o) from public.zad_obligations o where o.id = v_row_id));
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_obligation(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
