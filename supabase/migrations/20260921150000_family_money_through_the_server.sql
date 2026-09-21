-- A family member's balance moves only on the server.
--
-- What was open (read off the live project 2026-09-21, after the membership fix):
--
--   family_members_update   a member may update their own row, balance included — a
--                           child could type any balance they liked;
--   family_chores           any member may insert, update or complete any chore of the
--                           family, reward_amount included, and the reward was credited
--                           by whichever phone ticked it: Kotlin's toggleChore adds the
--                           reward on every tick, so un-tick and re-tick paid again;
--   family_financial_challenges / financial_challenge_progress
--                           any member may set a challenge's target and reward, and
--                           write their own progress and completion flag;
--   chat_messages           any member may rewrite any message — a child could flip
--                           their own PURCHASE_REQUEST to APPROVED without a parent, or
--                           send one in a sibling's name so the sibling is debited;
--   family_messages         an unused table whose one policy lets every signed-in
--                           account read and write every family's rows.
--
-- Owner decision 2026-09-21: move chore and challenge rewards into server functions and
-- never let a client change a balance, children's above all. After this migration:
--
--   * balance changes only inside zad_complete_chore, zad_reopen_chore,
--     zad_contribute_to_challenge and zad_decide_purchase_request — they set a
--     transaction-local flag the balance guard checks, and nothing else can set it
--     (PostgREST runs each request as its own transaction and exposes no way to call
--     set_config);
--   * a chore's reward is paid once, to the member it is assigned to, when it is
--     completed by that member or an admin; reopening is an admin's and takes back what
--     was paid, to whom it was paid;
--   * rewards, targets and challenge windows are set by admins only; a challenge's
--     progress is written only by its function, which pays the reward once;
--   * a purchase request is created PENDING in its sender's own name and decided only by
--     an admin through zad_decide_purchase_request, which debits the sender on approval.
--
-- Guards skip calls with no auth.uid() — the service role, i.e. edge functions — which
-- are trusted and run their own checks, as in 20260921130000.
--
-- Also run by hand on the live project on 2026-09-21 on the owner's instruction, through
-- execute_sql so no version was stamped, and verified there in rolled-back blocks as real
-- accounts; every statement is idempotent, so CI re-running this file changes nothing.

-- ── The flag the money functions raise ───────────────────────────────────────

create or replace function public.zad_family_ledger_open()
returns boolean language sql stable set search_path = public as $$
  select coalesce(current_setting('zad.family_ledger', true), '') = 'on';
$$;

-- ── Balances ─────────────────────────────────────────────────────────────────

create or replace function public.zad_family_members_guard_balance()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.zad_family_ledger_open() then return new; end if;
  if tg_op = 'INSERT' then
    if coalesce(new.balance, 0) <> 0 then
      raise exception 'balance_is_server_only' using errcode = '42501';
    end if;
  elsif new.balance is distinct from old.balance then
    raise exception 'balance_is_server_only' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists family_members_guard_balance on public.family_members;
create trigger family_members_guard_balance
  before insert or update on public.family_members
  for each row execute function public.zad_family_members_guard_balance();

-- ── Chores ───────────────────────────────────────────────────────────────────

alter table public.family_chores
  add column if not exists completed_at timestamptz,
  add column if not exists completed_by uuid,
  add column if not exists reward_paid numeric,
  add column if not exists reward_paid_to uuid;

create or replace function public.zad_family_chores_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_admin boolean;
begin
  if auth.uid() is null or public.zad_family_ledger_open() then return new; end if;
  v_admin := public.zad_is_family_admin(new.family_id);

  if new.assigned_to is not null and not exists (
    select 1 from public.family_members
    where id = new.assigned_to and family_id = new.family_id
  ) then
    raise exception 'assignee_not_in_family' using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    if coalesce(new.is_completed, false) or new.completed_at is not null
       or new.completed_by is not null or new.reward_paid is not null
       or new.reward_paid_to is not null then
      raise exception 'completion_is_server_only' using errcode = '42501';
    end if;
    if coalesce(new.reward_amount, 0) <> 0 and not v_admin then
      raise exception 'only_admins_set_rewards' using errcode = '42501';
    end if;
    if coalesce(new.reward_amount, 0) < 0 then
      raise exception 'negative_reward' using errcode = '22023';
    end if;
    return new;
  end if;

  if new.family_id is distinct from old.family_id then
    raise exception 'chore_is_immutable' using errcode = '42501';
  end if;
  if new.is_completed is distinct from old.is_completed
     or new.completed_at is distinct from old.completed_at
     or new.completed_by is distinct from old.completed_by
     or new.reward_paid is distinct from old.reward_paid
     or new.reward_paid_to is distinct from old.reward_paid_to then
    raise exception 'completion_is_server_only' using errcode = '42501';
  end if;
  if not v_admin then
    if new.reward_amount is distinct from old.reward_amount then
      raise exception 'only_admins_set_rewards' using errcode = '42501';
    end if;
    -- Moving a rewarded chore to yourself is taking its reward.
    if new.assigned_to is distinct from old.assigned_to
       and coalesce(old.reward_amount, 0) > 0 then
      raise exception 'only_admins_reassign_rewards' using errcode = '42501';
    end if;
  elsif coalesce(new.reward_amount, 0) < 0 then
    raise exception 'negative_reward' using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists family_chores_guard on public.family_chores;
create trigger family_chores_guard
  before insert or update on public.family_chores
  for each row execute function public.zad_family_chores_guard();

-- Expected refusals are answers, not exceptions, as in zad_join_family.
create or replace function public.zad_complete_chore(p_chore uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_chore public.family_chores%rowtype;
  v_me public.family_members%rowtype;
  v_reward numeric;
  v_payee uuid;
  v_payee_user uuid;
  v_balance numeric;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select * into v_chore from public.family_chores where id = p_chore for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  select * into v_me from public.family_members
  where user_id = v_uid and family_id = v_chore.family_id;
  if not found then
    -- Another family's chore reads as no chore at all.
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_me.role <> 'admin' and v_chore.assigned_to is distinct from v_me.id then
    return jsonb_build_object('ok', false, 'reason', 'not_yours');
  end if;
  if v_chore.is_completed then
    return jsonb_build_object('ok', true, 'already', true,
                              'paid', coalesce(v_chore.reward_paid, 0));
  end if;

  perform set_config('zad.family_ledger', 'on', true);

  v_reward := coalesce(v_chore.reward_amount, 0);
  if v_reward > 0 and v_chore.assigned_to is not null then
    update public.family_members
    set balance = coalesce(balance, 0) + v_reward
    where id = v_chore.assigned_to and family_id = v_chore.family_id
    returning id, user_id, balance into v_payee, v_payee_user, v_balance;
  end if;

  update public.family_chores
  set is_completed = true,
      completed_at = now(),
      completed_by = v_uid,
      reward_paid = case when v_payee is null then null else v_reward end,
      reward_paid_to = v_payee
  where id = p_chore;

  if v_payee_user is not null then
    insert into public.app_notifications (user_id, title, message)
    values (v_payee_user, 'عمل رائع! 🌟',
            'أنجزت المهمة: ' || v_chore.title || '. اتضاف ' || v_reward || ' لرصيدك.');
  end if;

  perform set_config('zad.family_ledger', 'off', true);

  return jsonb_build_object(
    'ok', true, 'already', false,
    'paid', case when v_payee is null then 0 else v_reward end,
    'member_id', v_payee, 'balance', v_balance);
end;
$$;

-- Undoes a completion, and takes back what it paid from whoever it paid. Admins only:
-- otherwise a child reopens and completes to be paid twice — which is what Kotlin's
-- toggle did.
create or replace function public.zad_reopen_chore(p_chore uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_chore public.family_chores%rowtype;
  v_balance numeric;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select * into v_chore from public.family_chores where id = p_chore for update;
  if not found or not exists (
    select 1 from public.family_members
    where user_id = auth.uid() and family_id = v_chore.family_id
  ) then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if not public.zad_is_family_admin(v_chore.family_id) then
    return jsonb_build_object('ok', false, 'reason', 'not_an_admin');
  end if;
  if not v_chore.is_completed then
    return jsonb_build_object('ok', true, 'already', true, 'taken_back', 0);
  end if;

  perform set_config('zad.family_ledger', 'on', true);

  if coalesce(v_chore.reward_paid, 0) > 0 and v_chore.reward_paid_to is not null then
    update public.family_members
    set balance = coalesce(balance, 0) - v_chore.reward_paid
    where id = v_chore.reward_paid_to and family_id = v_chore.family_id
    returning balance into v_balance;
  end if;

  update public.family_chores
  set is_completed = false, completed_at = null, completed_by = null,
      reward_paid = null, reward_paid_to = null
  where id = p_chore;

  perform set_config('zad.family_ledger', 'off', true);

  return jsonb_build_object(
    'ok', true, 'already', false,
    'taken_back', coalesce(v_chore.reward_paid, 0), 'balance', v_balance);
end;
$$;

-- ── Financial challenges ─────────────────────────────────────────────────────

alter table public.financial_challenge_progress
  add column if not exists reward_paid numeric;

-- One progress row per member per challenge. Kotlin looked the row up and inserted when
-- it found none, so two quick contributions could make two rows and two completions.
create unique index if not exists financial_challenge_progress_one_per_user
  on public.financial_challenge_progress (challenge_id, user_id);

create or replace function public.zad_family_challenges_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.zad_family_ledger_open() then return new; end if;
  if coalesce(new.reward_amount, 0) < 0 or coalesce(new.target_amount, 0) < 0 then
    raise exception 'negative_amount' using errcode = '22023';
  end if;
  if public.zad_is_family_admin(new.family_id) then return new; end if;

  if tg_op = 'INSERT' then
    if coalesce(new.reward_amount, 0) <> 0 then
      raise exception 'only_admins_set_rewards' using errcode = '42501';
    end if;
    return new;
  end if;

  -- Lowering the target or reopening the window is winning without saving.
  if new.family_id is distinct from old.family_id
     or new.reward_amount is distinct from old.reward_amount
     or new.target_amount is distinct from old.target_amount
     or new.start_date is distinct from old.start_date
     or new.end_date is distinct from old.end_date
     or new.is_active is distinct from old.is_active then
    raise exception 'only_admins_change_challenges' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists family_challenges_guard on public.family_financial_challenges;
create trigger family_challenges_guard
  before insert or update on public.family_financial_challenges
  for each row execute function public.zad_family_challenges_guard();

-- Progress is the function's: no client insert or update policy any more.
drop policy if exists financial_challenge_progress_insert on public.financial_challenge_progress;
drop policy if exists financial_challenge_progress_update on public.financial_challenge_progress;

-- Adds to a member's progress — the caller's own, or, for an admin, any member of the
-- family's — and pays the reward the first time the target is reached.
create or replace function public.zad_contribute_to_challenge(
  p_challenge uuid,
  p_amount numeric,
  p_member uuid default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_challenge public.family_financial_challenges%rowtype;
  v_member public.family_members%rowtype;
  v_progress public.financial_challenge_progress%rowtype;
  v_amount numeric;
  v_reward numeric;
  v_paid numeric := 0;
  v_balance numeric;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount > 10000000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  select * into v_challenge from public.family_financial_challenges where id = p_challenge;
  if not found or not exists (
    select 1 from public.family_members
    where user_id = v_uid and family_id = v_challenge.family_id
  ) then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if not coalesce(v_challenge.is_active, false)
     or (v_challenge.start_date is not null and now() < v_challenge.start_date)
     or (v_challenge.end_date is not null and now() > v_challenge.end_date) then
    return jsonb_build_object('ok', false, 'reason', 'closed');
  end if;

  if p_member is null then
    select * into v_member from public.family_members
    where user_id = v_uid and family_id = v_challenge.family_id;
  else
    select * into v_member from public.family_members
    where id = p_member and family_id = v_challenge.family_id;
    if not found then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;
    if v_member.user_id is distinct from v_uid
       and not public.zad_is_family_admin(v_challenge.family_id) then
      return jsonb_build_object('ok', false, 'reason', 'not_yours');
    end if;
  end if;
  if v_member.user_id is null then
    -- Progress is kept per account; a member with no account has nowhere to keep it.
    return jsonb_build_object('ok', false, 'reason', 'member_has_no_account');
  end if;

  insert into public.financial_challenge_progress (challenge_id, user_id, current_amount)
  values (p_challenge, v_member.user_id, 0)
  on conflict (challenge_id, user_id) do nothing;

  select * into v_progress from public.financial_challenge_progress
  where challenge_id = p_challenge and user_id = v_member.user_id
  for update;

  v_amount := coalesce(v_progress.current_amount, 0) + p_amount;
  v_reward := coalesce(v_challenge.reward_amount, 0);

  perform set_config('zad.family_ledger', 'on', true);

  if v_amount >= coalesce(v_challenge.target_amount, 0)
     and v_progress.reward_paid is null and v_reward > 0 then
    update public.family_members
    set balance = coalesce(balance, 0) + v_reward
    where id = v_member.id
    returning balance into v_balance;
    v_paid := v_reward;

    insert into public.app_notifications (user_id, title, message)
    values (v_member.user_id, 'تحدي مكتمل! 🎉',
            'أنجزت تحدي: ' || v_challenge.title || '. اتضاف ' || v_reward || ' لرصيدك.');
  end if;

  update public.financial_challenge_progress
  set current_amount = v_amount,
      is_completed = v_amount >= coalesce(v_challenge.target_amount, 0),
      completed_at = case
        when v_amount >= coalesce(v_challenge.target_amount, 0)
        then coalesce(completed_at, now()) end,
      reward_paid = case when v_paid > 0 then v_paid else reward_paid end
  where id = v_progress.id;

  perform set_config('zad.family_ledger', 'off', true);

  return jsonb_build_object(
    'ok', true,
    'current_amount', v_amount,
    'completed', v_amount >= coalesce(v_challenge.target_amount, 0),
    'paid', v_paid,
    'balance', v_balance);
end;
$$;

-- ── Purchase requests ────────────────────────────────────────────────────────

create or replace function public.zad_chat_messages_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_meta jsonb;
begin
  if auth.uid() is null or public.zad_family_ledger_open() then return new; end if;

  if tg_op = 'INSERT' then
    if new.message_type = 'PURCHASE_REQUEST' then
      -- In the sender's own name: approval debits the sender.
      if not exists (
        select 1 from public.family_members
        where id::text = new.sender_id and user_id = auth.uid()
          and family_id = new.family_id
      ) then
        raise exception 'request_in_own_name_only' using errcode = '42501';
      end if;
      begin
        v_meta := new.metadata::jsonb;
      exception when others then
        raise exception 'invalid_request' using errcode = '22023';
      end;
      if coalesce(v_meta ->> 'status', '') <> 'PENDING'
         or coalesce((v_meta ->> 'amount')::numeric, 0) <= 0 then
        raise exception 'invalid_request' using errcode = '22023';
      end if;
    end if;
    return new;
  end if;

  -- Pins and reactions stay open; what a request says, and who it is from, do not.
  if (old.message_type = 'PURCHASE_REQUEST' or new.message_type = 'PURCHASE_REQUEST')
     and (new.message_type is distinct from old.message_type
          or new.metadata is distinct from old.metadata
          or new.sender_id is distinct from old.sender_id
          or new.family_id is distinct from old.family_id
          or new.message is distinct from old.message) then
    raise exception 'requests_are_decided_on_the_server' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists chat_messages_guard on public.chat_messages;
create trigger chat_messages_guard
  before insert or update on public.chat_messages
  for each row execute function public.zad_chat_messages_guard();

create or replace function public.zad_decide_purchase_request(p_message uuid, p_approve boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_msg public.chat_messages%rowtype;
  v_meta jsonb;
  v_amount numeric;
  v_status text;
  v_sender uuid;
  v_sender_user uuid;
  v_balance numeric;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_approve is null then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  select * into v_msg from public.chat_messages where id = p_message for update;
  if not found or not exists (
    select 1 from public.family_members
    where user_id = auth.uid() and family_id = v_msg.family_id
  ) then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if not public.zad_is_family_admin(v_msg.family_id) then
    return jsonb_build_object('ok', false, 'reason', 'not_an_admin');
  end if;
  if v_msg.message_type is distinct from 'PURCHASE_REQUEST' then
    return jsonb_build_object('ok', false, 'reason', 'not_a_request');
  end if;

  begin
    v_meta := v_msg.metadata::jsonb;
    v_amount := (v_meta ->> 'amount')::numeric;
  exception when others then
    return jsonb_build_object('ok', false, 'reason', 'invalid_request');
  end;
  if coalesce(v_meta ->> 'status', '') <> 'PENDING' then
    return jsonb_build_object('ok', true, 'already', true, 'status', v_meta ->> 'status');
  end if;
  if v_amount is null or v_amount <= 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_request');
  end if;

  v_status := case when p_approve then 'APPROVED' else 'REJECTED' end;

  perform set_config('zad.family_ledger', 'on', true);

  update public.chat_messages
  set metadata = (v_meta || jsonb_build_object(
        'status', v_status, 'decided_by', auth.uid(), 'decided_at', now()))::text
  where id = p_message;

  select id, user_id, balance into v_sender, v_sender_user, v_balance
  from public.family_members
  where id::text = v_msg.sender_id and family_id = v_msg.family_id;

  if p_approve and v_sender is not null then
    update public.family_members
    set balance = coalesce(balance, 0) - v_amount
    where id = v_sender
    returning balance into v_balance;
  end if;

  if v_sender_user is not null then
    insert into public.app_notifications (user_id, title, message)
    values (v_sender_user,
            case when p_approve then 'موافق! ✅' else 'الطلب اترفض' end,
            case when p_approve
                 then 'اتوافق على طلبك واتخصم ' || v_amount || ' من رصيدك.'
                 else 'طلبك بـ ' || v_amount || ' ماتوافقش عليه.' end);
  end if;

  perform set_config('zad.family_ledger', 'off', true);

  return jsonb_build_object(
    'ok', true, 'already', false, 'status', v_status,
    'debited', case when p_approve and v_sender is not null then v_amount else 0 end,
    'balance', v_balance);
end;
$$;

-- ── family_messages: unused, and open to every account ───────────────────────

drop policy if exists family_messages_auth on public.family_messages;
drop policy if exists family_messages_members on public.family_messages;
create policy family_messages_members on public.family_messages
  for all to authenticated
  using (family_id in (select public.get_my_family_ids()))
  with check (family_id in (select public.get_my_family_ids()));

-- ── Who may call what ────────────────────────────────────────────────────────

revoke all on function public.zad_complete_chore(uuid) from public, anon;
revoke all on function public.zad_reopen_chore(uuid) from public, anon;
revoke all on function public.zad_contribute_to_challenge(uuid, numeric, uuid) from public, anon;
revoke all on function public.zad_decide_purchase_request(uuid, boolean) from public, anon;
grant execute on function public.zad_complete_chore(uuid) to authenticated;
grant execute on function public.zad_reopen_chore(uuid) to authenticated;
grant execute on function public.zad_contribute_to_challenge(uuid, numeric, uuid) to authenticated;
grant execute on function public.zad_decide_purchase_request(uuid, boolean) to authenticated;

revoke all on function public.zad_family_ledger_open() from public, anon, authenticated;
revoke all on function public.zad_family_members_guard_balance() from public, anon, authenticated;
revoke all on function public.zad_family_chores_guard() from public, anon, authenticated;
revoke all on function public.zad_family_challenges_guard() from public, anon, authenticated;
revoke all on function public.zad_chat_messages_guard() from public, anon, authenticated;
