-- ZAD_OR_PLAN م٢.٦ (نص السيرفر): member_id إلزامي على zad_inventory وzad_item_preferences وagent_goals.
--
-- ليه: ذوق البنت مايختلطش بأكل الجيم بتاع أخوها. النهارده الفرد موجود على الحركات (zad_events.member_id) وfor_person بس.
-- المقاس على الحي ٢٢/١١: zad_inventory ٦٦ صف، agent_goals ٤، zad_item_preferences صفر، وكل المستخدمين ليهم صف «أنا» (self)،
-- وuser_id مش null في التلاتة.
--
--   ١. العمود + backfill بصف «أنا» لصاحب الصف (zad_self_member بتعمله لو ناقص) + NOT NULL.
--   ٢. (zad_inventory.user_id مالوش FK على auth.users، فمسح الحساب كان بيسيب صفوفه يتيمة. FK المخزن ON DELETE CASCADE عشان مسح
--      الأفراد (بمسح الحساب) مايوقعش على NO ACTION. التفضيلات والأهداف user_id بتاعهم cascade من auth.users فـNO ACTION كفاية.)
--   ٢. FK مركب (member_id, user_id) ⇒ zad_household_members(id, user_id): الفرد لازم يبقى من نفس صاحب الصف، زي zad_events.
--   ٣. تريجر BEFORE INSERT: member_id غايب ⇒ صف «أنا». كده الكلاينت القديم (من غير member_id) والكرون وzad_set_item_preference
--      والتريجرات اللي بتكتب (populate_family_inventory…) بيفضلوا شغالين من غير أي تعديل.
--   ٤. zad_intent_inventory (inventory.added) وzad_intent_goal (goal.set) بيقبلوا payload.member_id اختياري. لو اتبعت ومش من بيت
--      p_uid (أو مؤرشف أو مش UUID) ⇒ {ok:false, reason:'member_not_found'}، ومفيش تلميح عن بيت حد تاني.
--      التفضيلات مالهاش دالة مجال لسه (بتكتب بـzad_set_item_preference): بتاخد «أنا» بالتريجر.
-- الباقي في الدالتين زي 20261122220000 (المخزن) و20261122110000 (الأهداف) بالحرف. RLS زي ما هي.

-- ── الأعمدة ──────────────────────────────────────────────────────────────────────────────────────────────
alter table public.zad_inventory add column if not exists member_id uuid;
alter table public.zad_item_preferences add column if not exists member_id uuid;
alter table public.agent_goals add column if not exists member_id uuid;

-- كل صاحب صف عنده صف «أنا» قبل الـbackfill.
select public.zad_self_member(u) from (
  select user_id as u from public.zad_inventory
  union select user_id from public.zad_item_preferences
  union select user_id from public.agent_goals) x;

update public.zad_inventory t set member_id = m.id
  from public.zad_household_members m where m.user_id = t.user_id and m.kind = 'self' and t.member_id is null;
update public.zad_item_preferences t set member_id = m.id
  from public.zad_household_members m where m.user_id = t.user_id and m.kind = 'self' and t.member_id is null;
update public.agent_goals t set member_id = m.id
  from public.zad_household_members m where m.user_id = t.user_id and m.kind = 'self' and t.member_id is null;

alter table public.zad_inventory alter column member_id set not null;
alter table public.zad_item_preferences alter column member_id set not null;
alter table public.agent_goals alter column member_id set not null;

alter table public.zad_inventory drop constraint if exists zad_inventory_member_fk;
alter table public.zad_inventory add constraint zad_inventory_member_fk
  foreign key (member_id, user_id) references public.zad_household_members (id, user_id) on delete cascade;
alter table public.zad_item_preferences drop constraint if exists zad_item_preferences_member_fk;
alter table public.zad_item_preferences add constraint zad_item_preferences_member_fk
  foreign key (member_id, user_id) references public.zad_household_members (id, user_id);
alter table public.agent_goals drop constraint if exists agent_goals_member_fk;
alter table public.agent_goals add constraint agent_goals_member_fk
  foreign key (member_id, user_id) references public.zad_household_members (id, user_id);

create index if not exists idx_zad_inventory_member on public.zad_inventory (member_id);
create index if not exists idx_zad_item_preferences_member on public.zad_item_preferences (member_id);
create index if not exists idx_agent_goals_member on public.agent_goals (member_id);

comment on column public.zad_inventory.member_id is 'م٢.٦: فرد البيت صاحب الصنف. إلزامي. غايب عند الإدخال ⇒ صف «أنا» (تريجر).';
comment on column public.zad_item_preferences.member_id is 'م٢.٦: فرد البيت صاحب التفضيل. إلزامي. غايب عند الإدخال ⇒ صف «أنا» (تريجر).';
comment on column public.agent_goals.member_id is 'م٢.٦: فرد البيت صاحب الهدف. إلزامي. غايب عند الإدخال ⇒ صف «أنا» (تريجر).';

-- ── الافتراضي: «أنا» لو member_id غايب ──────────────────────────────────────────────────────────────────
create or replace function public.zad_member_default()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.member_id is null then
    new.member_id := public.zad_self_member(new.user_id);
  end if;
  return new;
end;
$fn$;
revoke all on function public.zad_member_default() from public, anon, authenticated, service_role;

drop trigger if exists zad_inventory_member_default on public.zad_inventory;
create trigger zad_inventory_member_default before insert on public.zad_inventory
  for each row execute function public.zad_member_default();
drop trigger if exists zad_item_preferences_member_default on public.zad_item_preferences;
create trigger zad_item_preferences_member_default before insert on public.zad_item_preferences
  for each row execute function public.zad_member_default();
drop trigger if exists agent_goals_member_default on public.agent_goals;
create trigger agent_goals_member_default before insert on public.agent_goals
  for each row execute function public.zad_member_default();

-- ── فرد من بيت صاحب الطلب (من الـpayload) ───────────────────────────────────────────────────────────────
-- بيرجّع الـid، أو null لو مش UUID أو مش من بيت p_uid أو مؤرشف.
create or replace function public.zad_intent_member(p_uid uuid, p_member text)
returns uuid
language plpgsql
stable
set search_path = public
as $fn$
declare
  v_id uuid;
begin
  begin
    v_id := btrim(p_member)::uuid;
  exception when others then
    return null;
  end;
  return (select m.id from public.zad_household_members m
           where m.id = v_id and m.user_id = p_uid and m.archived_at is null);
end;
$fn$;
revoke all on function public.zad_intent_member(uuid, text) from public, anon, authenticated, service_role;

create or replace function public.zad_intent_inventory(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_row public.zad_inventory%rowtype;
  v_reason text;
  v_qty numeric;
  v_after numeric;
  v_row_id uuid;
  v_name text;
  v_expiry date;
  v_new_id uuid;
  v_member uuid;
begin
  if p_kind not in ('inventory.added', 'inventory.consumed', 'inventory.quantity_set', 'inventory.deleted',
                    'inventory.restock_mode_set') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  -- الصنف: لازم للكل ماعدا الإضافة (اختياري فيها = تزويد).
  if p_kind <> 'inventory.added' or nullif(v_payload ->> 'item_id', '') is not null then
    v_row := public.zad_intent_household_item(p_uid, v_payload ->> 'item_id');
    if v_row.id is null then
      -- الإضافة بـitem_id مش موجود في البيت: id جديد من العميل (الـOutbox المحلي)، بشرطين: UUID صالح، ومش موجود
      -- خالص في zad_inventory (صف مستخدم تاني = item_not_found، من غير ما نقول إنه موجود).
      if p_kind = 'inventory.added' then
        begin
          v_new_id := (v_payload ->> 'item_id')::uuid;
        exception when others then
          v_new_id := null;
        end;
        if v_new_id is null or exists (select 1 from public.zad_inventory i where i.id = v_new_id) then
          return jsonb_build_object('ok', false, 'reason', 'item_not_found');
        end if;
      else
        return jsonb_build_object('ok', false, 'reason', 'item_not_found');
      end if;
    end if;
  end if;

  -- م٢.٦: الفرد اختياري (غايب = «أنا» بالتريجر)، ولو اتبعت لازم يبقى من بيت صاحب الطلب ومش مؤرشف.
  -- التزويد (الصنف موجود) بيتجاهل member_id: فرد قديم مايرفضش تزويد.
  if p_kind = 'inventory.added' and v_row.id is null
     and nullif(btrim(coalesce(v_payload ->> 'member_id', '')), '') is not null then
    v_member := public.zad_intent_member(p_uid, v_payload ->> 'member_id');
    if v_member is null then
      return jsonb_build_object('ok', false, 'reason', 'member_not_found');
    end if;
  end if;

  -- القيود.
  if p_kind = 'inventory.added' then
    v_name := btrim(coalesce(v_payload ->> 'item_name', ''));
    begin
      -- العمود numeric(12,3): 0.0004 كانت هتعدي «> 0» وتتخزن صفر.
      v_qty := round((v_payload ->> 'quantity')::numeric, 3);
    exception when others then
      v_qty := null;
    end;
    if length(v_name) < 2 or length(v_name) > 120 then
      v_reason := 'name_invalid';
    elsif v_qty is null or v_qty <= 0 then
      v_reason := 'qty_not_positive';
    elsif v_qty > 999 then
      v_reason := 'qty_too_large';
    elsif coalesce(v_payload ->> 'category', '') not in
          ('البقالة', 'الخضار', 'الفواكه', 'اللحوم', 'الألبان', 'المشروبات', 'العناية', 'أخرى') then
      v_reason := 'category_unknown';
    elsif nullif(v_payload ->> 'expiry_date', '') is not null then
      if (v_payload ->> 'expiry_date') !~ '^\d{4}-\d{2}-\d{2}$' then
        v_reason := 'expiry_bad_format';
      else
        begin
          v_expiry := (v_payload ->> 'expiry_date')::date;
        exception when others then
          v_reason := 'expiry_bad_format';
        end;
        if v_reason is null and v_expiry < p_occurred::date then
          v_reason := 'expiry_before_purchase';
        end if;
      end if;
    end if;
  elsif p_kind = 'inventory.consumed' then
    begin
      v_qty := round((v_payload ->> 'amount')::numeric, 3);
    exception when others then
      v_qty := null;
    end;
    if v_qty is null or v_qty < 0 or (v_qty = 0 and (v_payload -> 'opened') is distinct from 'true'::jsonb) then
      v_reason := 'amount_invalid';
    elsif v_qty > 1000 then
      v_reason := 'amount_too_large';
    end if;
  elsif p_kind = 'inventory.quantity_set' then
    begin
      v_qty := round((v_payload ->> 'quantity')::numeric, 3);
    exception when others then
      v_qty := null;
    end;
    if v_qty is null or v_qty < 0 then
      v_reason := 'qty_negative';
    elsif v_qty > greatest(coalesce(v_row.quantity, 0) * 20, 100) then
      v_reason := 'qty_too_large';
    end if;
  elsif p_kind = 'inventory.restock_mode_set' then
    if coalesce(v_payload ->> 'restock_mode', '') not in ('staple', 'occasional') then
      v_reason := 'restock_mode_unknown';
    end if;
  end if;
  if v_reason is not null then
    return jsonb_build_object('ok', false, 'reason', v_reason);
  end if;

  -- الكتابة.
  if p_kind = 'inventory.added' and v_row.id is not null then
    v_after := greatest(coalesce(v_row.quantity, 0), 0) + v_qty;
    update public.zad_inventory
       set quantity = v_after,
           category = coalesce(v_row.category, v_payload ->> 'category'),
           expiry_date = coalesce(nullif(v_payload ->> 'expiry_date', ''), v_row.expiry_date)
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.quantity, 'after', v_after);
  elsif p_kind = 'inventory.added' then
    insert into public.zad_inventory (id, user_id, member_id, item_name, quantity, unit, category, expiry_date)
    values (coalesce(v_new_id, gen_random_uuid()), p_uid, v_member, v_name, v_qty, coalesce(nullif(btrim(v_payload ->> 'unit'), ''), 'حبة'), v_payload ->> 'category',
            nullif(v_payload ->> 'expiry_date', ''))
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'after', v_qty);
  elsif p_kind = 'inventory.consumed' then
    v_after := greatest(coalesce(v_row.quantity, 0) - v_qty, 0);
    update public.zad_inventory
       set quantity = v_after,
           opened_at = case when (v_payload -> 'opened') = 'true'::jsonb then coalesce(opened_at, now()) else opened_at end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.quantity, 'after', v_after);
  elsif p_kind = 'inventory.quantity_set' then
    update public.zad_inventory set quantity = v_qty where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.quantity, 'after', v_qty);
  elsif p_kind = 'inventory.deleted' then
    -- الصف كامل في الحدث، وتريجر zad_trash بيحفظه للتراجع.
    delete from public.zad_inventory where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  else
    update public.zad_inventory set restock_mode = v_payload ->> 'restock_mode' where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.restock_mode,
                                                 'after', v_payload ->> 'restock_mode');
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

create or replace function public.zad_intent_goal(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_goal public.agent_goals%rowtype;
  v_ch public.zad_savings_challenges%rowtype;
  v_title text;
  v_metric text;
  v_target numeric;
  v_deadline date;
  v_unit text;
  v_kind text;
  v_amount numeric;
  v_cap numeric;
  v_len int;
  v_started date;
  v_source text;
  v_res jsonb;
  v_before jsonb;
  v_row_id uuid;
  v_member uuid;
begin
  if p_kind not in ('goal.set', 'goal.cancelled', 'goal.progress', 'goal.challenge_started', 'goal.challenge_stopped') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  -- م٢.٦: الفرد اختياري في goal.set (غايب = «أنا» بالتريجر، أو الفرد القديم لو الهدف موجود).
  if p_kind = 'goal.set' and nullif(btrim(coalesce(v_payload ->> 'member_id', '')), '') is not null then
    v_member := public.zad_intent_member(p_uid, v_payload ->> 'member_id');
    if v_member is null then
      return jsonb_build_object('ok', false, 'reason', 'member_not_found');
    end if;
  end if;

  if p_kind in ('goal.set', 'goal.cancelled') then
    v_title := btrim(coalesce(v_payload ->> 'title', ''));
    if length(v_title) < 4 or length(v_title) > 200 then
      return jsonb_build_object('ok', false, 'reason', 'goal_title_invalid');
    end if;
    select * into v_goal from public.agent_goals where user_id = p_uid and title = v_title for update;
  end if;

  if p_kind = 'goal.set' then
    v_metric := nullif(btrim(coalesce(v_payload ->> 'metric', '')), '');
    if length(coalesce(v_metric, '')) > 200 then
      return jsonb_build_object('ok', false, 'reason', 'metric_too_long');
    end if;
    if nullif(v_payload ->> 'target_value', '') is not null then
      begin
        v_target := (v_payload ->> 'target_value')::numeric;
      exception when others then
        v_target := null;
      end;
      if v_target is null or v_target <= 0 or v_target > 100000000 then
        return jsonb_build_object('ok', false, 'reason', 'target_invalid');
      end if;
    end if;
    if nullif(btrim(coalesce(v_payload ->> 'deadline_date', '')), '') is not null then
      begin
        v_deadline := left(btrim(v_payload ->> 'deadline_date'), 10)::date;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'deadline_invalid');
      end;
    end if;
    v_unit := nullif(v_payload ->> 'unit', '');
    if v_unit is not null and v_unit not in ('money', 'count') then
      return jsonb_build_object('ok', false, 'reason', 'unit_invalid');
    end if;
    v_kind := case v_unit when 'money' then 'amount' when 'count' then 'tasks' end;
    insert into public.agent_goals (user_id, member_id, title, metric, target_value, deadline_date, status, updated_at, progress_kind)
    values (p_uid, v_member, v_title, v_metric, v_target, v_deadline, 'active', now(), coalesce(v_kind, 'tasks'))
    on conflict (user_id, title) do update
      set member_id = coalesce(v_member, public.agent_goals.member_id), metric = excluded.metric, target_value = excluded.target_value, deadline_date = excluded.deadline_date,
          status = 'active', updated_at = now(), progress_kind = coalesce(v_kind, public.agent_goals.progress_kind)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', case when v_goal.id is null then null else to_jsonb(v_goal) end,
      'after', (select to_jsonb(g) from public.agent_goals g where g.id = v_row_id));

  elsif p_kind = 'goal.cancelled' then
    if v_goal.id is null then
      return jsonb_build_object('ok', false, 'reason', 'goal_not_found');
    end if;
    update public.agent_goals set status = 'cancelled', updated_at = now() where id = v_goal.id;
    v_row_id := v_goal.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_goal),
      'after', (select to_jsonb(g) from public.agent_goals g where g.id = v_row_id));

  elsif p_kind = 'goal.progress' then
    begin
      v_amount := (v_payload ->> 'amount')::numeric;
    exception when others then
      v_amount := null;
    end;
    if v_amount is null or v_amount = 0 or abs(v_amount) > 100000000 then
      return jsonb_build_object('ok', false, 'reason', 'goal_amount_invalid');
    end if;
    begin
      select * into v_goal from public.agent_goals where id = (v_payload ->> 'goal_id')::uuid and user_id = p_uid;
    exception when others then
      v_goal := null;
    end;
    if v_goal.id is null then
      return jsonb_build_object('ok', false, 'reason', 'goal_not_found');
    end if;
    v_res := public.zad_goal_add_progress(p_uid, v_goal.id, v_amount);
    if (v_res ->> 'ok')::boolean is not true then
      return jsonb_build_object('ok', false, 'reason', case v_res ->> 'reason'
        when 'not_amount' then 'goal_not_amount' when 'unknown_goal' then 'goal_not_found' else 'goal_amount_invalid' end);
    end if;
    v_row_id := v_goal.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_goal),
      'after', (select to_jsonb(g) from public.agent_goals g where g.id = v_row_id));

  elsif p_kind = 'goal.challenge_started' then
    begin
      v_cap := (v_payload ->> 'daily_cap')::numeric;
    exception when others then
      v_cap := null;
    end;
    if v_cap is null or v_cap < 1 or v_cap > 10000000 then
      return jsonb_build_object('ok', false, 'reason', 'challenge_cap_invalid');
    end if;
    begin
      v_len := (v_payload ->> 'length_days')::numeric::int;
      if (v_payload ->> 'length_days')::numeric <> v_len then v_len := null; end if;
    exception when others then
      v_len := null;
    end;
    if v_len is null or v_len not between 7 and 90 then
      return jsonb_build_object('ok', false, 'reason', 'challenge_length_invalid');
    end if;
    begin
      v_started := (v_payload ->> 'started_on')::date;
    exception when others then
      v_started := null;
    end;
    if v_started is null then
      return jsonb_build_object('ok', false, 'reason', 'challenge_date_invalid');
    end if;
    if length(coalesce(v_payload ->> 'currency', '')) > 10 then
      return jsonb_build_object('ok', false, 'reason', 'currency_invalid');
    end if;
    v_source := coalesce(nullif(v_payload ->> 'source', ''), 'chat');
    if v_source not in ('app', 'voice', 'chat', 'telegram') then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end if;
    if exists (select 1 from public.zad_savings_challenges where user_id = p_uid and status = 'active') then
      return jsonb_build_object('ok', false, 'reason', 'challenge_already_active');
    end if;
    insert into public.zad_savings_challenges (user_id, started_on, length_days, daily_cap, currency, source)
    values (p_uid, v_started, v_len, round(v_cap), nullif(v_payload ->> 'currency', ''), v_source)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'after',
      (select to_jsonb(c) from public.zad_savings_challenges c where c.id = v_row_id));

  else
    select * into v_ch from public.zad_savings_challenges where user_id = p_uid and status = 'active' for update;
    if v_ch.id is null then
      return jsonb_build_object('ok', false, 'reason', 'no_active_challenge');
    end if;
    update public.zad_savings_challenges set status = 'abandoned', updated_at = now() where id = v_ch.id;
    v_row_id := v_ch.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_ch),
      'after', (select to_jsonb(c) from public.zad_savings_challenges c where c.id = v_row_id));
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_inventory(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
revoke all on function public.zad_intent_goal(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
