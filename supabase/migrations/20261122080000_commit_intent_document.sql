-- الباب الوحيد: مجال المستندات (ZAD_OR_PLAN م٢.٥، ٢٢/١١). zad_commit_intent بينادي الدالة دي لكل نوع بادئته document.
--   document.saved    {kind, holder?, label?, expires_on}   صف واحد لكل (نوع، صاحب، اسم): الحفظ تاني بيعدّل التاريخ
--                                                            (before = الصف القديم، أو null لو جديد).
--   document.deleted  {item_id}                              حذف حقيقي، والصف كله في before.
-- القيود زي قيود الجدول الحي: النوع من قايمة، صاحب واسم متشذّبين وحد أقصى ٤٠، «other» لازم اسم، والتاريخ ٢٠٠٠–٢١٠٠.

create or replace function public.zad_intent_document(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_row public.zad_documents%rowtype;
  v_old public.zad_documents%rowtype;
  v_row_id uuid;
  v_kind text;
  v_holder text;
  v_label text;
  v_expires date;
begin
  if p_kind not in ('document.saved', 'document.deleted') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind = 'document.deleted' then
    begin
      select * into v_row from public.zad_documents
       where id = (v_payload ->> 'item_id')::uuid and user_id = p_uid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
    delete from public.zad_documents where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  else
    v_kind := v_payload ->> 'kind';
    v_holder := coalesce(v_payload ->> 'holder', '');
    v_label := coalesce(v_payload ->> 'label', '');
    if v_kind is null or v_kind not in ('passport', 'national_id', 'residence', 'driving_license', 'vehicle_license', 'other') then
      return jsonb_build_object('ok', false, 'reason', 'kind_invalid');
    elsif v_holder <> btrim(v_holder) or length(v_holder) > 40 then
      return jsonb_build_object('ok', false, 'reason', 'holder_invalid');
    elsif v_label <> btrim(v_label) or length(v_label) > 40 then
      return jsonb_build_object('ok', false, 'reason', 'label_invalid');
    elsif v_kind = 'other' and v_label = '' then
      return jsonb_build_object('ok', false, 'reason', 'label_required');
    end if;
    begin
      if coalesce(v_payload ->> 'expires_on', '') !~ '^\d{4}-\d{2}-\d{2}$' then
        raise exception 'shape';
      end if;
      v_expires := (v_payload ->> 'expires_on')::date;
      if to_char(v_expires, 'YYYY-MM-DD') <> v_payload ->> 'expires_on' then
        raise exception 'not a real day';
      end if;
    exception when others then
      return jsonb_build_object('ok', false, 'reason', 'day_invalid');
    end;
    if v_expires < date '2000-01-01' or v_expires > date '2100-12-31' then
      return jsonb_build_object('ok', false, 'reason', 'date_out_of_range');
    end if;
    select * into v_old from public.zad_documents
     where user_id = p_uid and kind = v_kind and holder = v_holder and label = v_label for update;
    insert into public.zad_documents (user_id, kind, holder, label, expires_on)
    values (p_uid, v_kind, v_holder, v_label, v_expires)
    on conflict (user_id, kind, holder, label) do update set expires_on = excluded.expires_on
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id,
      'before', case when v_old.id is null then null else to_jsonb(v_old) end,
      'after', (select to_jsonb(d) from public.zad_documents d where d.id = v_row_id));
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_document(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
