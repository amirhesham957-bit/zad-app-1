-- Family membership goes through the server, and only through the server.
--
-- What was open (read off pg_policies 2026-09-21):
--
--   family_members_insert              with check (auth.role() = 'authenticated')
--   family_groups_select_authenticated using (true)
--   family_members_update              using (family_id in get_my_family_ids())
--
-- Together: any signed-in account could read every family's id and invite code and
-- insert itself — or anyone — into any family, as admin. Membership is what
-- get_my_family_ids() hands to every family-scoped policy, so that was the household's
-- shared pantry, its chat and, as admin, its children's spending. And any member could
-- promote itself to admin. Invite codes were 'ZAD-' + 4 digits: 9,000 values.
--
-- Owner decision 2026-09-21: fix it strictly, with no allowance for the Kotlin client
-- (it has no live users). After this migration:
--
--   * creating and joining a family happen only in zad_create_family / zad_join_family
--     (security definer). A client cannot insert into family_members or family_groups
--     at all — there is no insert policy on either;
--   * a family is visible only to its members; invite codes are 40 random bits, unique,
--     and a wrong code costs an attempt (10 an hour);
--   * one family per account, as every reader already assumes (maybeSingle on user_id);
--   * a member updates their own row, an admin any row in their family; a trigger stops
--     anyone moving a membership, non-admins changing roles or spending limits, and the
--     last admin leaving or stepping down while others remain;
--   * a family with no members left is deleted, instead of lingering (12 of the 14 rows
--     on 2026-09-21 had no members).
--
-- Guards skip calls with no auth.uid() — the service role, i.e. edge functions and
-- delete-account — which are trusted and run their own checks.
--
-- Not in this migration, deliberately: member balances are still written by whoever
-- completes a chore or a challenge (the Kotlin reward logic runs client-side). Moving
-- rewards server-side is its own change.
--
-- Also run by hand on the live project on 2026-09-21 on the owner's instruction,
-- through execute_sql so no version was stamped; every statement is idempotent, so CI
-- re-running this file changes nothing.

-- ── Columns, codes, uniqueness ───────────────────────────────────────────────

alter table public.family_groups
  add column if not exists created_by uuid;

create or replace function public.zad_family_new_invite_code()
returns text language plpgsql volatile set search_path = public as $$
declare
  v_code text;
begin
  -- The first ten hex digits of a v4 UUID are all random: 40 bits.
  loop
    v_code := 'ZAD-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    exit when not exists (select 1 from public.family_groups where upper(invite_code) = v_code);
  end loop;
  return v_code;
end;
$$;

-- Every existing code was guessable. Families that already have their members lose
-- nothing; an invitation still in flight has to be re-sent with the new code.
update public.family_groups
set invite_code = public.zad_family_new_invite_code()
where invite_code !~ '^ZAD-[0-9A-F]{10}$';

update public.family_groups g
set created_by = m.user_id
from public.family_members m
where m.family_id = g.id and m.role = 'admin' and g.created_by is null;

create unique index if not exists family_groups_invite_code_unique
  on public.family_groups (upper(invite_code));

create unique index if not exists family_members_one_family_per_user
  on public.family_members (user_id) where user_id is not null;

-- ── Failed join attempts ─────────────────────────────────────────────────────

create table if not exists public.zad_family_join_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  succeeded boolean not null,
  attempted_at timestamptz not null default now()
);
create index if not exists zad_family_join_attempts_user_time
  on public.zad_family_join_attempts (user_id, attempted_at);
-- Written only by zad_join_family. No policy on purpose.
alter table public.zad_family_join_attempts enable row level security;
revoke all on public.zad_family_join_attempts from anon, authenticated;

-- ── Helpers ──────────────────────────────────────────────────────────────────

create or replace function public.zad_is_family_admin(p_family uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.family_members
    where family_id = p_family and user_id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.zad_family_member_code()
returns text language sql volatile set search_path = public as $$
  select 'ZAD-' || lpad((floor(random() * 1000000))::int::text, 6, '0');
$$;

-- ── The two ways in ──────────────────────────────────────────────────────────

create or replace function public.zad_create_family(p_alias text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_family uuid;
  v_member uuid;
  v_code text;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if exists (select 1 from public.family_members where user_id = v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'already_in_family');
  end if;

  v_code := public.zad_family_new_invite_code();
  insert into public.family_groups (invite_code, created_by)
  values (v_code, v_uid)
  returning id into v_family;

  insert into public.family_members (family_id, user_id, role, alias, zad_id)
  values (v_family, v_uid, 'admin',
          coalesce(nullif(btrim(p_alias), ''), 'رب الأسرة'),
          public.zad_family_member_code())
  returning id into v_member;

  perform public.zad_inventory_backfill_on_family_join(v_family);

  return jsonb_build_object(
    'ok', true, 'family_id', v_family, 'member_id', v_member, 'invite_code', v_code);
end;
$$;

-- Expected failures are answers, not exceptions: an exception would roll back the
-- attempt row and a wrong code would cost nothing.
create or replace function public.zad_join_family(p_invite_code text, p_alias text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_family uuid;
  v_mine record;
  v_member uuid;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if (select count(*) from public.zad_family_join_attempts
      where user_id = v_uid and not succeeded
        and attempted_at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'reason', 'too_many_attempts');
  end if;

  -- Forgiving about how it was typed: spaces, case, a missing prefix.
  v_code := upper(regexp_replace(coalesce(p_invite_code, ''), '\s', '', 'g'));
  if v_code <> '' and v_code !~ '^ZAD-' then
    v_code := 'ZAD-' || v_code;
  end if;

  select id into v_family from public.family_groups where upper(invite_code) = v_code;
  if v_family is null then
    insert into public.zad_family_join_attempts (user_id, succeeded) values (v_uid, false);
    return jsonb_build_object('ok', false, 'reason', 'invalid_code');
  end if;

  select id, family_id into v_mine from public.family_members where user_id = v_uid;
  if v_mine.family_id = v_family then
    return jsonb_build_object(
      'ok', true, 'family_id', v_family, 'member_id', v_mine.id, 'already', true);
  end if;
  if v_mine.family_id is not null then
    return jsonb_build_object('ok', false, 'reason', 'already_in_family');
  end if;

  insert into public.family_members (family_id, user_id, role, alias, zad_id)
  values (v_family, v_uid, 'member',
          coalesce(nullif(btrim(p_alias), ''), 'فرد من العيلة'),
          public.zad_family_member_code())
  returning id into v_member;
  insert into public.zad_family_join_attempts (user_id, succeeded) values (v_uid, true);

  perform public.zad_inventory_backfill_on_family_join(v_family);

  return jsonb_build_object('ok', true, 'family_id', v_family, 'member_id', v_member);
end;
$$;

-- For a code that was shared too widely. Admins only.
create or replace function public.zad_rotate_family_invite_code()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_family uuid;
  v_code text;
begin
  select family_id into v_family from public.family_members
  where user_id = auth.uid() and role = 'admin';
  if v_family is null then
    return jsonb_build_object('ok', false, 'reason', 'not_an_admin');
  end if;
  v_code := public.zad_family_new_invite_code();
  update public.family_groups set invite_code = v_code where id = v_family;
  return jsonb_build_object('ok', true, 'invite_code', v_code);
end;
$$;

-- ── Guards on family_members ─────────────────────────────────────────────────

create or replace function public.zad_family_members_guard_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return new; end if;

  if new.user_id is distinct from old.user_id
     or new.family_id is distinct from old.family_id then
    raise exception 'membership_is_immutable' using errcode = '42501';
  end if;

  if new.role is distinct from old.role then
    if not public.zad_is_family_admin(old.family_id) then
      raise exception 'only_admins_change_roles' using errcode = '42501';
    end if;
    if new.role not in ('admin', 'member', 'child') then
      raise exception 'unknown_role' using errcode = '22023';
    end if;
    if old.role = 'admin' and new.role <> 'admin' and not exists (
      select 1 from public.family_members
      where family_id = old.family_id and role = 'admin' and id <> old.id
    ) then
      raise exception 'last_admin' using errcode = 'P0001';
    end if;
  end if;

  -- Spending limits are a parent's control; a child raising their own defeats them.
  if (new.daily_limit is distinct from old.daily_limit
      or new.weekly_limit is distinct from old.weekly_limit)
     and not public.zad_is_family_admin(old.family_id) then
    raise exception 'only_admins_set_limits' using errcode = '42501';
  end if;

  return new;
end;
$$;

create or replace function public.zad_family_members_guard_delete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return old; end if;
  if old.role = 'admin'
     and not exists (select 1 from public.family_members
                     where family_id = old.family_id and role = 'admin' and id <> old.id)
     and exists (select 1 from public.family_members
                 where family_id = old.family_id and id <> old.id) then
    raise exception 'last_admin' using errcode = 'P0001';
  end if;
  return old;
end;
$$;

create or replace function public.zad_family_drop_if_empty()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.family_groups g
  where g.id = old.family_id
    and not exists (select 1 from public.family_members where family_id = old.family_id);
  return null;
end;
$$;

drop trigger if exists family_members_guard_update on public.family_members;
create trigger family_members_guard_update
  before update on public.family_members
  for each row execute function public.zad_family_members_guard_update();

drop trigger if exists family_members_guard_delete on public.family_members;
create trigger family_members_guard_delete
  before delete on public.family_members
  for each row execute function public.zad_family_members_guard_delete();

drop trigger if exists family_members_drop_empty_family on public.family_members;
create trigger family_members_drop_empty_family
  after delete on public.family_members
  for each row execute function public.zad_family_drop_if_empty();

-- ── Policies ─────────────────────────────────────────────────────────────────

drop policy if exists family_members_insert on public.family_members;

drop policy if exists family_members_update on public.family_members;
create policy family_members_update on public.family_members
  for update to authenticated
  using (user_id = (select auth.uid()) or public.zad_is_family_admin(family_id))
  with check (family_id in (select public.get_my_family_ids()));

drop policy if exists family_members_delete on public.family_members;
create policy family_members_delete on public.family_members
  for delete to authenticated
  using (user_id = (select auth.uid()) or public.zad_is_family_admin(family_id));

drop policy if exists family_groups_select_authenticated on public.family_groups;
drop policy if exists family_groups_insert_authenticated on public.family_groups;
drop policy if exists family_groups_update_members on public.family_groups;
drop policy if exists family_groups_delete_members on public.family_groups;
drop policy if exists family_groups_select_members on public.family_groups;
create policy family_groups_select_members on public.family_groups
  for select to authenticated
  using (id in (select public.get_my_family_ids()));

-- ── Who may call what ────────────────────────────────────────────────────────

revoke all on function public.zad_create_family(text) from public, anon;
revoke all on function public.zad_join_family(text, text) from public, anon;
revoke all on function public.zad_rotate_family_invite_code() from public, anon;
revoke all on function public.zad_is_family_admin(uuid) from public, anon;
grant execute on function public.zad_create_family(text) to authenticated;
grant execute on function public.zad_join_family(text, text) to authenticated;
grant execute on function public.zad_rotate_family_invite_code() to authenticated;
grant execute on function public.zad_is_family_admin(uuid) to authenticated;

revoke all on function public.zad_family_new_invite_code() from public, anon, authenticated;
revoke all on function public.zad_family_member_code() from public, anon, authenticated;
revoke all on function public.zad_family_members_guard_update() from public, anon, authenticated;
revoke all on function public.zad_family_members_guard_delete() from public, anon, authenticated;
revoke all on function public.zad_family_drop_if_empty() from public, anon, authenticated;
