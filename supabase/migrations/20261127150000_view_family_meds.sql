-- P1.3b: الولي (صاحب البيت) في zad_view_family يشوف أدوية الفرد وجرعاته الفايتة. باقي الدالة زي ما هي (20261127140000).
-- غير الولي: مفيش تغيير (medicines بس بموافقة، والطفل مايتشافش). مابتكتبش في أي جدول.

create or replace function public.zad_view_family(p_member_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_me uuid := auth.uid();
  m public.zad_household_members%rowtype;
  v_subject uuid;
  v_owner boolean;
  v_nums jsonb := '{}'::jsonb;
  v_sections text[] := '{}';
  v_n numeric; v_c int;
  v_actions jsonb := '[]'::jsonb;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  select * into m from public.zad_household_members where id = p_member_id and archived_at is null;
  if not found then return jsonb_build_object('ok', false, 'reason', 'member_not_found'); end if;
  v_owner := m.user_id = v_me;

  if not v_owner then
    if m.kind = 'child' then return jsonb_build_object('ok', false, 'reason', 'child_requires_guardian'); end if;
    v_subject := case when m.kind = 'self' then m.user_id else m.linked_user_id end;
    -- من غير حساب = مفيش حد يوافق غير صاحب البيت. نفس رد «مش موجود» عشان مانأكدش وجود فرد لغريب.
    if v_subject is null or v_subject = v_me then return jsonb_build_object('ok', false, 'reason', 'member_not_found'); end if;
    if not (public.zad_family_share_granted(v_me, v_subject, 'medicines')
         or public.zad_family_share_granted(v_me, v_subject, 'spending')
         or public.zad_family_share_granted(v_me, v_subject, 'tasks')) then
      return jsonb_build_object('ok', false, 'reason', 'consent_required');
    end if;
    if public.zad_family_share_granted(v_me, v_subject, 'medicines') then
      select count(*) into v_c from public.zad_pharmacy_items where user_id = v_subject and coalesce(remaining_quantity, 1) > 0;
      v_nums := v_nums || jsonb_build_object('medicines_active', public.zad_view_num(v_c, 'zad_pharmacy_items.remaining_quantity'));
      v_sections := array_append(v_sections, 'medicines');
    end if;
    if public.zad_family_share_granted(v_me, v_subject, 'spending') then
      select coalesce(sum(amount), 0) into v_n from public.zad_transactions
       where user_id = v_subject and txn_kind = 'expense' and created_at >= now() - interval '30 days';
      v_nums := v_nums || jsonb_build_object('spent_30d', public.zad_view_num(round(v_n, 2), 'zad_transactions.amount'));
      v_sections := array_append(v_sections, 'spending');
    end if;
    if public.zad_family_share_granted(v_me, v_subject, 'tasks') then
      select count(*) into v_c from public.zad_appointments
       where user_id = v_subject and status = 'upcoming' and starts_at >= now() and starts_at < now() + interval '7 days';
      v_nums := v_nums || jsonb_build_object('appointments_7d', public.zad_view_num(v_c, 'zad_appointments.starts_at'));
      v_sections := array_append(v_sections, 'tasks');
    end if;
  else
    -- صاحب البيت (ولي الأمر): بيانات الفرد نفسه من الصفوف اللي عليها member_id.
    select count(*) into v_c from public.agent_goals where user_id = v_me and member_id = m.id and status = 'active';
    v_nums := v_nums || jsonb_build_object('goals_active', public.zad_view_num(v_c, 'agent_goals.member_id'));
    select count(*), count(*) filter (where low_stock_threshold is not null and quantity <= low_stock_threshold)
      into v_c, v_n from public.zad_inventory where user_id = v_me and member_id = m.id;
    v_nums := v_nums || jsonb_build_object('inventory_items', public.zad_view_num(v_c, 'zad_inventory.member_id'),
                                           'low_stock', public.zad_view_num(v_n, 'zad_inventory.quantity<=low_stock_threshold'));
    -- P1.3b: الأدوية والجرعات الفايتة. zad_pharmacy_items مافيهوش member_id: family_member_id بيشاور على family_members
    -- (عضو بحساب، مش فرد البيت)، فالربط الوحيد المتاح هو for_person (الاسم الحر): «أنا» = for_person null،
    -- وغيره = نفس display_name (بعد trim وlower). مفيش عمود جديد. 'فايتة' = صف zad_pharmacy_doses.status = 'missed'
    -- (حكم النظام اللي بتكتبه zad_enqueue_missed_doses، مش 'skipped' اللي هو إجابة العميل) في آخر ٧ أيام.
    select count(*) into v_c from public.zad_pharmacy_items p
     where p.user_id = v_me and coalesce(p.remaining_quantity, 1) > 0
       and (case when m.kind = 'self' then p.for_person is null
                 else lower(btrim(p.for_person)) = lower(btrim(m.display_name)) end);
    v_nums := v_nums || jsonb_build_object('medicines_active', public.zad_view_num(v_c, 'zad_pharmacy_items.for_person'));
    select count(*) into v_c from public.zad_pharmacy_doses d
      join public.zad_pharmacy_items p on p.id = d.item_id and p.user_id = v_me
     where d.user_id = v_me and d.status = 'missed' and d.scheduled_at >= now() - interval '7 days'
       and (case when m.kind = 'self' then p.for_person is null
                 else lower(btrim(p.for_person)) = lower(btrim(m.display_name)) end);
    v_nums := v_nums || jsonb_build_object('missed_doses_7d', public.zad_view_num(v_c, 'zad_pharmacy_doses.status'));
    v_sections := array['goals', 'inventory', 'medicines'];
    v_actions := jsonb_build_array(jsonb_build_object('id', 'add_goal', 'label', 'ضيف هدف'));
  end if;

  return jsonb_build_object(
    'ok', true, 'view', 'family',
    'member', jsonb_build_object('id', m.id, 'name', m.display_name, 'kind', m.kind),
    'relation', case when v_owner then 'guardian' else 'consented' end,
    'sections', to_jsonb(v_sections),
    'numbers', v_nums,
    'available_actions', v_actions
  );
end $$;

grant execute on function public.zad_view_family(uuid) to authenticated;
