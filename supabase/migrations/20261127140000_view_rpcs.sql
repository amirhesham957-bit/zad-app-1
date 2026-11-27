-- P1.3: دوال العرض. شاشة التطبيق بتقرا من هنا بدل ما تحسب، فالرقم اللي على الشاشة هو رقم البوت لنفس العميل.
-- كل رقم = {value, source} (المصدر اسم الجدول.العمود أو الدالة اللي طلّعته). وكل دالة بترجع available_actions (معرّفات + عنوان عربي).
-- مابتكتبش في أي جدول. zad_view_home/money/house من غير security definer: RLS بتشتغل، والمستخدم دايماً auth.uid() (مفيش معامل user).
-- zad_view_family security definer لأنها بتعدّي على حساب تاني بعد فحص الموافقة بإيدها:
--   - صاحب البيت (zad_household_members.user_id = المستدعي) = ولي الأمر، بيشوف أي فرد عنده، الطفل كمان.
--   - غيره: الطفل مايتشافش أبداً. البالغ/الكبير/«أنا» اللي ليه حساب (linked_user_id أو kind = self) بيتشاف بس لو
--     zad_family_shares (نفس جدول موافقات م٧) فيه granted من صاحب الحساب للمستدعي، وبنطاقات الموافقة بس (medicines/spending/tasks).
--   - فرد من غير حساب (مش self ومالوش linked_user_id) مايتشافش إلا لصاحب البيت.

create or replace function public.zad_view_num(p_value numeric, p_source text)
returns jsonb language sql immutable set search_path = public, pg_temp as $$
  select jsonb_build_object('value', p_value, 'source', p_source) $$;
revoke all on function public.zad_view_num(numeric, text) from public, anon;
grant execute on function public.zad_view_num(numeric, text) to authenticated;

-- ── المصاريف ────────────────────────────────────────────────────────────────
create or replace function public.zad_view_money()
returns jsonb language plpgsql stable set search_path = public, pg_temp as $$
declare
  v_me uuid := auth.uid();
  v_s jsonb;
  v_debts numeric; v_debt_n int;
  v_subs numeric; v_sub_n int;
  v_threat text;
  v_actions jsonb := '[]'::jsonb;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  v_s := public.zad_budget_state(v_me);
  v_threat := v_s ->> 'threat';

  select coalesce(sum(remaining_balance), 0), count(*) into v_debts, v_debt_n
    from public.zad_debts where user_id = v_me and coalesce(is_active, true);
  select coalesce(sum(amount), 0), count(*) into v_subs, v_sub_n
    from public.zad_subscriptions where user_id = v_me and coalesce(is_active, true);

  v_actions := v_actions || jsonb_build_array(jsonb_build_object('id', 'add_expense', 'label', 'سجّل مصروف'));
  if v_threat in ('WATCH', 'DANGER', 'OVER') then
    v_actions := v_actions || jsonb_build_array(jsonb_build_object('id', 'review_budget', 'label', 'راجع الميزانية'));
  end if;
  if v_debt_n > 0 then
    v_actions := v_actions || jsonb_build_array(jsonb_build_object('id', 'pay_debt', 'label', 'سدّد دين'));
  end if;

  return jsonb_build_object(
    'ok', true, 'view', 'money',
    'numbers', jsonb_build_object(
      'balance', public.zad_view_num((v_s ->> 'balance')::numeric, 'zad_budget_state.balance'),
      'available', public.zad_view_num((v_s ->> 'available')::numeric, 'zad_budget_state.available'),
      'spent', public.zad_view_num((v_s ->> 'spent')::numeric, 'zad_budget_state.spent'),
      'income', public.zad_view_num((v_s ->> 'income')::numeric, 'zad_budget_state.income'),
      'committed', public.zad_view_num((v_s ->> 'committed')::numeric, 'zad_budget_state.committed'),
      'daily_allowance_left', public.zad_view_num((v_s ->> 'daily_allowance_left')::numeric, 'zad_budget_state.daily_allowance_left'),
      'debts_remaining', public.zad_view_num(v_debts, 'zad_debts.remaining_balance'),
      'debts_count', public.zad_view_num(v_debt_n, 'zad_debts.id'),
      'subscriptions_amount', public.zad_view_num(v_subs, 'zad_subscriptions.amount'),
      'subscriptions_count', public.zad_view_num(v_sub_n, 'zad_subscriptions.id')
    ),
    'threat', jsonb_build_object('value', v_threat, 'source', 'zad_budget_state.threat'),
    'available_actions', v_actions
  );
end $$;

-- ── البيت ───────────────────────────────────────────────────────────────────
create or replace function public.zad_view_house()
returns jsonb language plpgsql stable set search_path = public, pg_temp as $$
declare
  v_me uuid := auth.uid();
  v_total int; v_low int; v_exp int; v_meds int; v_appts int; v_next jsonb;
  v_actions jsonb := '[]'::jsonb;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  select count(*),
         count(*) filter (where low_stock_threshold is not null and quantity <= low_stock_threshold),
         count(*) filter (where expiry_date ~ '^\d{4}-\d{2}-\d{2}'
                            and substring(expiry_date from 1 for 10)::date between current_date and current_date + 7)
    into v_total, v_low, v_exp
    from public.zad_inventory where user_id = v_me;
  select count(*) into v_meds from public.zad_pharmacy_items where user_id = v_me and coalesce(remaining_quantity, 1) > 0;
  select count(*) into v_appts from public.zad_appointments
   where user_id = v_me and status = 'upcoming' and starts_at >= now() and starts_at < now() + interval '7 days';
  select jsonb_build_object('title', title, 'starts_at', starts_at) into v_next
    from public.zad_appointments where user_id = v_me and status = 'upcoming' and starts_at >= now()
   order by starts_at limit 1;

  if v_low > 0 then v_actions := v_actions || jsonb_build_array(jsonb_build_object('id', 'restock', 'label', 'كمّل الناقص')); end if;
  if v_exp > 0 then v_actions := v_actions || jsonb_build_array(jsonb_build_object('id', 'use_expiring', 'label', 'استهلك اللي هيخلص صلاحيته')); end if;
  v_actions := v_actions || jsonb_build_array(jsonb_build_object('id', 'add_item', 'label', 'ضيف صنف'));

  return jsonb_build_object(
    'ok', true, 'view', 'house',
    'numbers', jsonb_build_object(
      'inventory_items', public.zad_view_num(v_total, 'zad_inventory.id'),
      'low_stock', public.zad_view_num(v_low, 'zad_inventory.quantity<=low_stock_threshold'),
      'expiring_7d', public.zad_view_num(v_exp, 'zad_inventory.expiry_date'),
      'medicines_active', public.zad_view_num(v_meds, 'zad_pharmacy_items.remaining_quantity'),
      'appointments_7d', public.zad_view_num(v_appts, 'zad_appointments.starts_at')
    ),
    'next_appointment', v_next,
    'available_actions', v_actions
  );
end $$;

-- ── الرئيسية: تركيب من الاتنين فوق + الأهداف، فالرقم هو هو ──────────────────
create or replace function public.zad_view_home()
returns jsonb language plpgsql stable set search_path = public, pg_temp as $$
declare
  v_me uuid := auth.uid();
  v_money jsonb; v_house jsonb; v_goals int; v_members int;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  v_money := public.zad_view_money();
  v_house := public.zad_view_house();
  select count(*) into v_goals from public.agent_goals where user_id = v_me and status = 'active';
  select count(*) into v_members from public.zad_household_members where user_id = v_me and archived_at is null;
  return jsonb_build_object(
    'ok', true, 'view', 'home',
    'numbers', jsonb_build_object(
      'available', v_money -> 'numbers' -> 'available',
      'daily_allowance_left', v_money -> 'numbers' -> 'daily_allowance_left',
      'low_stock', v_house -> 'numbers' -> 'low_stock',
      'expiring_7d', v_house -> 'numbers' -> 'expiring_7d',
      'appointments_7d', v_house -> 'numbers' -> 'appointments_7d',
      'goals_active', public.zad_view_num(v_goals, 'agent_goals.status'),
      'household_members', public.zad_view_num(v_members, 'zad_household_members.id')
    ),
    'threat', v_money -> 'threat',
    'next_appointment', v_house -> 'next_appointment',
    'available_actions', (v_money -> 'available_actions') || (v_house -> 'available_actions')
  );
end $$;

-- ── فرد من العيلة ───────────────────────────────────────────────────────────
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
    v_sections := array['goals', 'inventory'];
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

revoke all on function public.zad_view_money() from public, anon;
revoke all on function public.zad_view_house() from public, anon;
revoke all on function public.zad_view_home() from public, anon;
revoke all on function public.zad_view_family(uuid) from public, anon;
grant execute on function public.zad_view_money() to authenticated;
grant execute on function public.zad_view_house() to authenticated;
grant execute on function public.zad_view_home() to authenticated;
grant execute on function public.zad_view_family(uuid) to authenticated;
