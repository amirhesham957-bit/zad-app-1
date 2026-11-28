-- P2.5 + P2.8 (جزء الرؤية): مصفوفة «مين يشوف إيه عن مين» في RLS ودوال العرض، قبل الواجهة. قرار المالك ٢٠٢٦-١١-٢٨.
--
-- المصفوفة (القاصر = حساب family_members.role = 'child'، أو فرد بيت kind = 'child' ليه حساب مربوط):
--   القاصر نفسه : مهامه وأهدافه بس. صفر أرقام ميزانية (معاملات/ديون/اشتراكات/التزامات/ميزانيات الفئات/أهداف العيلة المالية)،
--                 وصفر صيدلية (أدوية/جرعات/تأجيل/إعادة تعبئة): لا قراية ولا كتابة، RLS مقيّدة (as restrictive).
--                 ومهام البيت (family_chores) المسندة له بس.
--   ولي الأمر   : admin في نفس عيلة القاصر. بيشوف مهام وأهداف القاصر (سياسة جديدة)، والباقي زي ما كان (ميزانيته وأدويته بالموافقة
--                 التلقائية من 20261121090000 وسياسات family_admin_read_child_*). القاصر تحت وصاية كاملة (قرار الخطة).
--   بالغ ← بالغ  : مصروفه وأهدافه ومهامه بموافقة صريحة بس (zad_family_shares). الصيدلية المنزلية مفتوحة للبالغين افتراضياً
--                 إلا اللي is_private. موافقة 'medicines' الصريحة بتكشف كل أدويته. الاستثناءات (تنبيه مالي حرج، طلب دعم)
--                 بتعدّي من الإشعارات مش من القراية، فمش جوه الملف ده.
--   إجمالي ميزانية العيلة: رقم واحد (zad_family_budget_total) من غير تفاصيل، للبالغين بس.
-- الصفوف القديمة في zad_pharmacy_items بتتعلّم is_private = true مرة واحدة (عشان الدوا اللي اتسجّل قبل القرار مايتفتحش من غير ما
-- صاحبه يقول). أي صف جديد is_private = false (مفتوح) لحد ما صاحبه يقفله من الباب (pharmacy.updated patch.is_private).
-- الكتابة: is_private بس من الباب الوحيد (zad_intent_pharmacy). مفيش مسار كتابة جديد. القاصر ممنوع يكتب صيدلية من الباب كمان.
-- ترتيب النشر: المايجريشن قبل الفانكشنز (مفيش تغيير في الفانكشنز هنا غير إن الباب بيقبل is_private).

-- ── العمود ──────────────────────────────────────────────────────────────────
do $$ begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'zad_pharmacy_items' and column_name = 'is_private') then
    alter table public.zad_pharmacy_items add column is_private boolean;
    update public.zad_pharmacy_items set is_private = true;
    alter table public.zad_pharmacy_items alter column is_private set default false;
    alter table public.zad_pharmacy_items alter column is_private set not null;
  end if;
end $$;

-- ── مين القاصر ──────────────────────────────────────────────────────────────
-- p_who مش p_user: الدالة داخلية للباب ولدوال العرض، مش بتتنادى من العميل (grants_test).
create or replace function public.zad_is_minor_user(p_who uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select p_who is not null and (
    exists (select 1 from public.family_members where user_id = p_who and role = 'child')
    or exists (select 1 from public.zad_household_members
                where linked_user_id = p_who and kind = 'child' and archived_at is null));
$$;
revoke all on function public.zad_is_minor_user(uuid) from public, anon, authenticated;
grant execute on function public.zad_is_minor_user(uuid) to service_role;

create or replace function public.zad_i_am_minor()
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select public.zad_is_minor_user(auth.uid());
$$;
revoke all on function public.zad_i_am_minor() from public, anon;
grant execute on function public.zad_i_am_minor() to authenticated, service_role;

-- المنادي (auth.uid()) وصاحب الصف بالغين في نفس العيلة. أساس «الصيدلية المنزلية المفتوحة للبالغين».
create or replace function public.zad_family_adults_together(p_owner uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select auth.uid() is not null and p_owner is not null and p_owner <> auth.uid()
     and not public.zad_is_minor_user(auth.uid()) and not public.zad_is_minor_user(p_owner)
     and exists (select 1 from public.family_members a join public.family_members b on b.family_id = a.family_id
                  where a.user_id = auth.uid() and b.user_id = p_owner);
$$;
revoke all on function public.zad_family_adults_together(uuid) from public, anon;
grant execute on function public.zad_family_adults_together(uuid) to authenticated, service_role;

-- المنادي admin في عيلة p_target، وp_target قاصر.
create or replace function public.zad_i_guard(p_target uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select auth.uid() is not null and exists (
    select 1 from public.family_members a join public.family_members b on b.family_id = a.family_id
     where a.user_id = auth.uid() and a.role = 'admin' and b.user_id = p_target and b.role = 'child');
$$;
revoke all on function public.zad_i_guard(uuid) from public, anon;
grant execute on function public.zad_i_guard(uuid) to authenticated, service_role;

-- إجمالي ميزانية البالغين في عيلة المنادي: رقم واحد من غير تفاصيل. القاصر: null.
create or replace function public.zad_family_budget_total()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_me uuid := auth.uid();
  v_total numeric; v_n int;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if public.zad_is_minor_user(v_me) then return null; end if;
  select coalesce(sum(u.monthly_limit), 0), count(distinct b.user_id) into v_total, v_n
    from public.family_members a
    join public.family_members b on b.family_id = a.family_id and coalesce(b.role, 'member') <> 'child'
    left join public.zad_users u on u.id = b.user_id
   where a.user_id = v_me;
  return jsonb_build_object('value', v_total, 'adults', v_n, 'source', 'zad_users.monthly_limit');
end $$;
revoke all on function public.zad_family_budget_total() from public, anon;
grant execute on function public.zad_family_budget_total() to authenticated;

-- ── RLS: القاصر أعمى عن الميزانية والصيدلية (restrictive = بتقيّد كل السياسات التانية) ──
-- (select ...) عشان البلانر يحسبها مرة، مش لكل صف. الجداول اللي مش موجودة في بيئة الاختبار بتتخطى.
do $$ declare t text; begin
  foreach t in array array['zad_transactions', 'zad_debts', 'zad_subscriptions', 'zad_obligations', 'zad_category_budgets', 'family_goals'] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop policy if exists minor_blind_budget on public.%I', t);
      execute format('create policy minor_blind_budget on public.%I as restrictive for select to authenticated using (not (select public.zad_i_am_minor()))', t);
    end if;
  end loop;
  foreach t in array array['zad_pharmacy_items', 'zad_pharmacy_doses', 'zad_dose_snoozes', 'zad_pharmacy_restocks'] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop policy if exists minor_blind_pharmacy on public.%I', t);
      execute format('create policy minor_blind_pharmacy on public.%I as restrictive for all to authenticated using (not (select public.zad_i_am_minor())) with check (not (select public.zad_i_am_minor()))', t);
    end if;
  end loop;
end $$;

-- مهام البيت: القاصر يشوف المسندة له بس (assigned_to = family_members.id).
drop policy if exists minor_own_chores_only on public.family_chores;
create policy minor_own_chores_only on public.family_chores as restrictive for select to authenticated
  using (not (select public.zad_i_am_minor())
         or assigned_to in (select id from public.family_members where user_id = (select auth.uid())));

-- ── RLS: مين يشوف أيه زيادة ─────────────────────────────────────────────────
-- الصيدلية المنزلية: بالغ يشوف أدوية بالغ تاني في نفس العيلة لو مش is_private. (القاصر برا بالقيد فوق، وأدوية القاصر بالموافقة.)
drop policy if exists family_adults_read_pharmacy on public.zad_pharmacy_items;
create policy family_adults_read_pharmacy on public.zad_pharmacy_items for select to authenticated
  using (not is_private and public.zad_family_adults_together(user_id));

-- أهداف ومهام فرد تاني: ولي الأمر للقاصر، أو بموافقة صريحة على 'tasks'. (صاحبها بيشوفها بسياسته القديمة.)
drop policy if exists family_consented_read_agent_goals on public.agent_goals;
create policy family_consented_read_agent_goals on public.agent_goals for select to authenticated
  using (public.zad_i_guard(user_id) or public.zad_family_i_can_see(user_id, 'tasks'));
drop policy if exists family_consented_read_agent_tasks on public.agent_tasks;
create policy family_consented_read_agent_tasks on public.agent_tasks for select to authenticated
  using (public.zad_i_guard(user_id) or public.zad_family_i_can_see(user_id, 'tasks'));

-- ── دوال العرض ──────────────────────────────────────────────────────────────
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
  -- P2.5: القاصر مايشوفش أرقام ميزانية خالص (قرار المالك ٢٠٢٦-١١-٢٨).
  if public.zad_i_am_minor() then return jsonb_build_object('ok', false, 'reason', 'minor_no_budget'); end if;
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
  -- P2.5: القاصر مايشوفش الصيدلية (الرقم null مش صفر، عشان الشاشة ماتقولش «مفيش أدوية»).
  if not public.zad_i_am_minor() then
    select count(*) into v_meds from public.zad_pharmacy_items where user_id = v_me and coalesce(remaining_quantity, 1) > 0;
  end if;
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

create or replace function public.zad_view_home()
returns jsonb language plpgsql stable set search_path = public, pg_temp as $$
declare
  v_me uuid := auth.uid();
  v_money jsonb; v_house jsonb; v_goals int; v_members int;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  -- P2.5: القاصر = مهامه وأهدافه بس، من غير أي رقم ميزانية أو صيدلية.
  if public.zad_i_am_minor() then
    select count(*) into v_goals from public.agent_goals where user_id = v_me and status = 'active';
    select count(*) into v_members from public.family_chores c join public.family_members fm on fm.id = c.assigned_to
     where fm.user_id = v_me and not coalesce(c.is_completed, false);
    return jsonb_build_object(
      'ok', true, 'view', 'home',
      'numbers', jsonb_build_object(
        'goals_active', public.zad_view_num(v_goals, 'agent_goals.status'),
        'chores_open', public.zad_view_num(v_members, 'family_chores.is_completed')),
      'available_actions', '[]'::jsonb);
  end if;
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
  v_minor boolean := public.zad_i_am_minor();
  v_share_all boolean;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  select * into m from public.zad_household_members where id = p_member_id and archived_at is null;
  if not found then return jsonb_build_object('ok', false, 'reason', 'member_not_found'); end if;
  v_owner := m.user_id = v_me;

  -- P2.5: القاصر مايشوفش غير أهدافه هو. أي فرد تاني مرفوض.
  if v_minor then
    if not v_owner then return jsonb_build_object('ok', false, 'reason', 'minor_no_access'); end if;
    select count(*) into v_c from public.agent_goals where user_id = v_me and member_id = m.id and status = 'active';
    return jsonb_build_object(
      'ok', true, 'view', 'family',
      'member', jsonb_build_object('id', m.id, 'name', m.display_name, 'kind', m.kind),
      'relation', 'self', 'sections', to_jsonb(array['goals']),
      'numbers', jsonb_build_object('goals_active', public.zad_view_num(v_c, 'agent_goals.member_id')),
      'available_actions', '[]'::jsonb);
  end if;

  if not v_owner then
    if m.kind = 'child' then return jsonb_build_object('ok', false, 'reason', 'child_requires_guardian'); end if;
    v_subject := case when m.kind = 'self' then m.user_id else m.linked_user_id end;
    -- من غير حساب = مفيش حد يوافق غير صاحب البيت. نفس رد «مش موجود» عشان مانأكدش وجود فرد لغريب.
    if v_subject is null or v_subject = v_me then return jsonb_build_object('ok', false, 'reason', 'member_not_found'); end if;
    v_share_all := public.zad_family_share_granted(v_me, v_subject, 'medicines');
    if not (v_share_all
         or public.zad_family_share_granted(v_me, v_subject, 'spending')
         or public.zad_family_share_granted(v_me, v_subject, 'tasks')
         or public.zad_family_adults_together(v_subject)) then
      return jsonb_build_object('ok', false, 'reason', 'consent_required');
    end if;
    -- موافقة صريحة على 'medicines' = كل أدويته. من غيرها: الصيدلية المنزلية المفتوحة للبالغين، واللي مش is_private بس.
    if v_share_all or public.zad_family_adults_together(v_subject) then
      select count(*) into v_c from public.zad_pharmacy_items
       where user_id = v_subject and coalesce(remaining_quantity, 1) > 0 and (v_share_all or not is_private);
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

-- بيت العيلة (P2.8): المساحة المشتركة بـ family_id واحد. من غير security definer: RLS بتحدد اللي يتشاف (المخزن بعيلته،
-- الصيدلية بقواعد فوق، المهام بعيلته). إجمالي الميزانية رقم واحد بس. القاصر: مهامه بس.
create or replace function public.zad_view_family_home()
returns jsonb language plpgsql stable set search_path = public, pg_temp as $$
declare
  v_me uuid := auth.uid();
  v_inv int; v_meds int; v_chores int; v_adults int;
  v_budget jsonb;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  select count(*) into v_chores from public.family_chores c
   where c.family_id in (select public.get_my_family_ids()) and not coalesce(c.is_completed, false);
  if public.zad_i_am_minor() then
    return jsonb_build_object('ok', true, 'view', 'family_home', 'relation', 'minor',
      'numbers', jsonb_build_object('chores_open', public.zad_view_num(v_chores, 'family_chores.is_completed')),
      'available_actions', '[]'::jsonb);
  end if;
  select count(*) into v_inv from public.zad_inventory where family_id in (select public.get_my_family_ids());
  select count(*) into v_meds from public.zad_pharmacy_items where coalesce(remaining_quantity, 1) > 0;
  select count(distinct b.user_id) into v_adults
    from public.family_members a join public.family_members b on b.family_id = a.family_id and coalesce(b.role, 'member') <> 'child'
   where a.user_id = v_me;
  v_budget := public.zad_family_budget_total();
  return jsonb_build_object('ok', true, 'view', 'family_home', 'relation', 'adult',
    'numbers', jsonb_build_object(
      'inventory_items', public.zad_view_num(v_inv, 'zad_inventory.family_id'),
      'medicines_visible', public.zad_view_num(v_meds, 'zad_pharmacy_items.is_private'),
      'chores_open', public.zad_view_num(v_chores, 'family_chores.is_completed'),
      'adults', public.zad_view_num(v_adults, 'family_members.role'),
      'budget_total', v_budget),
    'available_actions', '[]'::jsonb);
end $$;
revoke all on function public.zad_view_family_home() from public, anon;
grant execute on function public.zad_view_family_home() to authenticated;

revoke all on function public.zad_view_money() from public, anon;
revoke all on function public.zad_view_house() from public, anon;
revoke all on function public.zad_view_home() from public, anon;
revoke all on function public.zad_view_family(uuid) from public, anon;
grant execute on function public.zad_view_money() to authenticated;
grant execute on function public.zad_view_house() to authenticated;
grant execute on function public.zad_view_home() to authenticated;
grant execute on function public.zad_view_family(uuid) to authenticated;

-- ── الباب: القاصر ماينفعش يكتب صيدلية، والدوا يتقفل بـ patch.is_private ───────────────────────────
create or replace function public.zad_intent_pharmacy_can_write(p_uid uuid, p_owner uuid)
returns boolean
language sql
stable
set search_path = public
as $fn$
  select not public.zad_is_minor_user(p_uid)
     and (p_owner = p_uid
      or (exists (select 1 from public.family_members a join public.family_members b on a.family_id = b.family_id
                   where a.user_id = p_uid and b.user_id = p_owner)
          and coalesce(public.zad_family_share_granted(p_uid, p_owner, 'medicines'), false)));
$fn$;

create or replace function public.zad_intent_pharmacy(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_patch jsonb;
  v_row public.zad_pharmacy_items%rowtype;
  v_owner uuid;
  v_name text;
  v_times text;
  v_count int;
  v_qty int;
  v_key text;
  v_before jsonb := '{}'::jsonb;
  v_row_id uuid;
  v_dose jsonb;
  v_at timestamptz;
  v_minutes int;
  v_snooze_before jsonb;
  c_times constant text := '^([01][0-9]|2[0-3]):[0-5][0-9](,([01][0-9]|2[0-3]):[0-5][0-9])*$';
begin
  if p_kind not in ('pharmacy.added', 'pharmacy.updated', 'pharmacy.deleted', 'pharmacy.dose_taken', 'pharmacy.dose_snoozed',
                    'pharmacy.dose_skipped') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind <> 'pharmacy.added' then
    begin
      select * into v_row from public.zad_pharmacy_items where id = (v_payload ->> 'item_id')::uuid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null or not public.zad_intent_pharmacy_can_write(p_uid, v_row.user_id)
       or (p_kind in ('pharmacy.dose_taken', 'pharmacy.dose_snoozed', 'pharmacy.dose_skipped') and v_row.user_id <> p_uid) then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
  end if;

  -- القيود المشتركة على الحقول (للإضافة من الـpayload، وللتعديل من الـpatch).
  v_patch := case when p_kind = 'pharmacy.added' then v_payload when p_kind = 'pharmacy.updated' then v_payload -> 'patch' end;
  if p_kind = 'pharmacy.updated' then
    if v_patch is null or jsonb_typeof(v_patch) <> 'object' or v_patch = '{}'::jsonb then
      return jsonb_build_object('ok', false, 'reason', 'patch_empty');
    end if;
    for v_key in select jsonb_object_keys(v_patch) loop
      if v_key not in ('dosage', 'dose_times', 'daily_dose_count', 'remaining_quantity', 'is_recurring', 'is_private') then
        return jsonb_build_object('ok', false, 'reason', 'patch_field_unknown');
      end if;
    end loop;
  end if;
  if v_patch is not null then
    v_times := nullif(btrim(coalesce(v_patch ->> 'dose_times', '')), '');
    if v_times is not null and (v_times !~ c_times or array_length(string_to_array(v_times, ','), 1) > 24) then
      return jsonb_build_object('ok', false, 'reason', 'dose_times_invalid');
    end if;
    if v_patch ? 'daily_dose_count' and v_patch -> 'daily_dose_count' <> 'null'::jsonb then
      begin
        v_count := (v_patch ->> 'daily_dose_count')::numeric::int;
      exception when others then
        v_count := null;
      end;
      if v_count is null or v_count not between 1 and 24 then
        return jsonb_build_object('ok', false, 'reason', 'dose_count_invalid');
      end if;
    end if;
    -- المواعيد هي العدد (العقل كان بيعمل كده، والتلفون بيقسم عليه أيام الكفاية).
    if v_times is not null then
      v_count := array_length(string_to_array(v_times, ','), 1);
    end if;
    if v_patch ? 'remaining_quantity' and v_patch -> 'remaining_quantity' <> 'null'::jsonb then
      begin
        v_qty := round((v_patch ->> 'remaining_quantity')::numeric)::int;
      exception when others then
        v_qty := null;
      end;
      if v_qty is null or v_qty not between 0 and 10000 then
        return jsonb_build_object('ok', false, 'reason', 'qty_invalid');
      end if;
    end if;
    if v_patch ? 'is_private' and jsonb_typeof(v_patch -> 'is_private') <> 'boolean' then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end if;
    if v_patch ? 'is_recurring' and jsonb_typeof(v_patch -> 'is_recurring') not in ('boolean', 'null') then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end if;
    if length(coalesce(v_patch ->> 'dosage', '')) > 120 then
      return jsonb_build_object('ok', false, 'reason', 'dosage_too_long');
    end if;
  end if;

  if p_kind = 'pharmacy.added' then
    v_name := btrim(coalesce(v_payload ->> 'name', ''));
    if length(v_name) < 2 or length(v_name) > 120 then
      return jsonb_build_object('ok', false, 'reason', 'name_invalid');
    end if;
    begin
      v_owner := coalesce(nullif(v_payload ->> 'owner_id', '')::uuid, p_uid);
    exception when others then
      v_owner := null;
    end;
    if v_owner is null or not exists (select 1 from auth.users where id = v_owner)
       or not public.zad_intent_pharmacy_can_write(p_uid, v_owner) then
      return jsonb_build_object('ok', false, 'reason', 'member_not_granted');
    end if;
    insert into public.zad_pharmacy_items (user_id, name, dosage, daily_dose_count, dose_times, unit, remaining_quantity,
                                           category, for_person, is_recurring, is_private)
    values (v_owner, v_name, nullif(btrim(coalesce(v_payload ->> 'dosage', '')), ''), coalesce(v_count, 1), v_times,
            coalesce(nullif(btrim(coalesce(v_payload ->> 'unit', '')), ''), 'قرص'), coalesce(v_qty, 1),
            left(coalesce(nullif(btrim(coalesce(v_payload ->> 'category', '')), ''), 'عام'), 40),
            left(nullif(btrim(coalesce(v_payload ->> 'for_person', '')), ''), 60),
            coalesce((v_payload ->> 'is_recurring')::boolean, false), coalesce((v_payload ->> 'is_private')::boolean, false))
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'owner_id', v_owner, 'after',
      (select to_jsonb(p) from public.zad_pharmacy_items p where p.id = v_row_id));
  elsif p_kind = 'pharmacy.updated' then
    for v_key in select jsonb_object_keys(v_patch) loop
      v_before := v_before || jsonb_build_object(v_key, to_jsonb(v_row) -> v_key);
    end loop;
    if v_times is not null then
      v_before := v_before || jsonb_build_object('daily_dose_count', v_row.daily_dose_count);
    end if;
    update public.zad_pharmacy_items
       set dosage = case when v_patch ? 'dosage' then nullif(btrim(coalesce(v_patch ->> 'dosage', '')), '') else dosage end,
           dose_times = case when v_patch ? 'dose_times' then v_times else dose_times end,
           daily_dose_count = coalesce(v_count, daily_dose_count),
           remaining_quantity = coalesce(v_qty, remaining_quantity),
           is_recurring = case when v_patch ? 'is_recurring' and v_patch -> 'is_recurring' <> 'null'::jsonb
                               then (v_patch ->> 'is_recurring')::boolean else is_recurring end,
           is_private = case when v_patch ? 'is_private' then (v_patch ->> 'is_private')::boolean else is_private end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_before, 'after',
      (select to_jsonb(p) from public.zad_pharmacy_items p where p.id = v_row_id));
  elsif p_kind = 'pharmacy.deleted' then
    delete from public.zad_pharmacy_items where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  elsif p_kind = 'pharmacy.dose_snoozed' then
    -- «فكّرني بعدين»: صف تأجيل واحد لكل (العميل، الدوا، الخانة)، والكرون بيسكت عنها لحد snooze_until. الدوا بتاع العميل نفسه.
    begin
      v_at := (v_payload ->> 'scheduled_at')::timestamptz;
    exception when others then
      v_at := null;
    end;
    if v_at is null then
      return jsonb_build_object('ok', false, 'reason', 'dose_slot_invalid');
    end if;
    begin
      v_minutes := (v_payload ->> 'minutes')::numeric::int;
    exception when others then
      v_minutes := null;
    end;
    if v_minutes is null or v_minutes not between 5 and 240 then
      return jsonb_build_object('ok', false, 'reason', 'snooze_minutes_invalid');
    end if;
    select to_jsonb(s) into v_snooze_before from public.zad_dose_snoozes s
     where s.user_id = p_uid and s.item_id = v_row.id and s.scheduled_at = v_at;
    insert into public.zad_dose_snoozes (user_id, item_id, scheduled_at, snooze_until)
    values (p_uid, v_row.id, v_at, now() + make_interval(mins => v_minutes))
    on conflict (user_id, item_id, scheduled_at) do update set snooze_until = excluded.snooze_until;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_snooze_before, 'after',
      (select to_jsonb(s) from public.zad_dose_snoozes s where s.user_id = p_uid and s.item_id = v_row.id and s.scheduled_at = v_at));
  elsif p_kind = 'pharmacy.dose_skipped' then
    -- «فوّتها»: مفيش حاجة خرجت من العلبة (units = 0)، والصف بيخلي zad_enqueue_missed_doses يبطّل «فاتتك الجرعة».
    begin
      v_at := (v_payload ->> 'scheduled_at')::timestamptz;
    exception when others then
      v_at := null;
    end;
    if v_at is null then
      return jsonb_build_object('ok', false, 'reason', 'dose_slot_invalid');
    end if;
    begin
      insert into public.zad_pharmacy_doses (user_id, item_id, scheduled_at, status, units)
      values (p_uid, v_row.id, v_at, 'skipped', 0)
      returning to_jsonb(zad_pharmacy_doses.*) into v_dose;
    exception when unique_violation then
      return jsonb_build_object('ok', false, 'reason', 'dose_already_logged');
    end;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'dose_id', v_dose -> 'id', 'before', null, 'after', v_dose);
  else
    v_dose := public.zad_log_pharmacy_dose_atomic(p_uid, v_row.id, null,
      coalesce(nullif(v_payload ->> 'taken_at', '')::timestamptz, p_occurred));
    if (v_dose ->> 'ok')::boolean is not true then
      return jsonb_build_object('ok', false, 'reason', 'dose_' || coalesce(v_dose ->> 'reason', 'refused'));
    end if;
    if (v_dose ->> 'duplicate')::boolean is true then
      return jsonb_build_object('ok', false, 'reason', 'dose_already_logged');
    end if;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.remaining_quantity,
      'after', (v_dose -> 'remaining_quantity'), 'dose_id', v_dose -> 'dose_id',
      'shopping_added', coalesce(v_dose -> 'shopping_added', 'false'::jsonb));
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_pharmacy_can_write(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function public.zad_intent_pharmacy(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
