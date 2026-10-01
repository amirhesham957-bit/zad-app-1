-- =====================================================
-- شبكة العيلة بالموافقة (قرار المالك، 2026-10-01).
--
-- «تكون بطلب ودعوة (Opt-in)، وللأب/المسؤول صلاحية متابعة الأدوية، المصروفات، والمهام بعد
-- موافقة الطرف الآخر.»
--
-- قبل كده كان الأدمن بيشوف من غير ما حد يوافق:
--   - أدوية كل عضو، من التطبيق (policy family_admin_read_pharmacy)،
--   - وصرفه في آخر ٣٠ يوم، عن طريق العقل (zad_family_digest).
-- دلوقتي:
--   - كل نطاق (medicines / spending / tasks) ليه صف في zad_family_shares.
--   - الأدمن بيطلب، وصاحب البيانات بيوافق أو يرفض، وأي واحد من الاتنين يقدر يلغي.
--   - الرؤية بتشتغل بس لو الصف granted والاتنين لسه في نفس العيلة.
--   - الكتابة في الجدول من الدوال بس: مفيش policy كتابة للتطبيق.
-- =====================================================

create table if not exists public.zad_family_shares (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.family_groups(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  scope text not null check (scope in ('medicines', 'spending', 'tasks')),
  status text not null default 'pending' check (status in ('pending', 'granted', 'declined', 'revoked')),
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  constraint zad_family_shares_not_self check (owner_id <> viewer_id),
  constraint zad_family_shares_one_per_scope unique (owner_id, viewer_id, scope)
);

create index if not exists zad_family_shares_viewer on public.zad_family_shares (viewer_id, status);

alter table public.zad_family_shares enable row level security;
revoke all on public.zad_family_shares from anon;
revoke insert, update, delete on public.zad_family_shares from authenticated;
grant select on public.zad_family_shares to authenticated;

drop policy if exists "family_shares: the two sides read" on public.zad_family_shares;
create policy "family_shares: the two sides read"
  on public.zad_family_shares for select to authenticated
  using (owner_id = (select auth.uid()) or viewer_id = (select auth.uid()));

-- ── Who sees what ───────────────────────────────────────────────────────────

-- For the server (the brain runs as service_role, where auth.uid() is null). Not callable
-- from the app: it would answer for any two ids.
create or replace function public.zad_family_share_granted(p_viewer uuid, p_owner uuid, p_scope text)
returns boolean language sql stable security definer set search_path = public as $$
  select p_viewer = p_owner or exists (
    select 1
      from public.zad_family_shares s
      join public.family_members fo on fo.user_id = s.owner_id and fo.family_id = s.family_id
      join public.family_members fv on fv.user_id = s.viewer_id and fv.family_id = s.family_id
     where s.owner_id = p_owner and s.viewer_id = p_viewer
       and s.scope = p_scope and s.status = 'granted'
  );
$$;
revoke all on function public.zad_family_share_granted(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.zad_family_share_granted(uuid, uuid, text) to service_role;

-- For RLS: always the caller as the viewer.
create or replace function public.zad_family_i_can_see(p_owner uuid, p_scope text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.zad_family_share_granted(auth.uid(), p_owner, p_scope);
$$;
revoke all on function public.zad_family_i_can_see(uuid, text) from public, anon;
grant execute on function public.zad_family_i_can_see(uuid, text) to authenticated, service_role;

-- ── Ask, answer, stop ───────────────────────────────────────────────────────

create or replace function public.zad_family_request_share(p_owner uuid, p_scopes text[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_family uuid;
  v_alias text;
  v_scope text;
  v_asked int := 0;
  v_labels text[] := '{}';
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_owner is null or p_owner = v_me then
    return jsonb_build_object('ok', false, 'reason', 'self');
  end if;
  select fv.family_id, fv.alias into v_family, v_alias
    from public.family_members fv
    join public.family_members fo on fo.family_id = fv.family_id and fo.user_id = p_owner
   where fv.user_id = v_me and fv.role = 'admin'
   limit 1;
  if v_family is null then
    return jsonb_build_object('ok', false, 'reason', 'not_family_admin');
  end if;

  foreach v_scope in array coalesce(p_scopes, '{}') loop
    continue when v_scope not in ('medicines', 'spending', 'tasks');
    insert into public.zad_family_shares (family_id, owner_id, viewer_id, scope, status, requested_at, decided_at)
    values (v_family, p_owner, v_me, v_scope, 'pending', now(), null)
    on conflict (owner_id, viewer_id, scope) do update
      set status = 'pending', requested_at = now(), decided_at = null, family_id = excluded.family_id
      where public.zad_family_shares.status in ('declined', 'revoked');
    if found then
      v_asked := v_asked + 1;
      v_labels := v_labels || case v_scope
        when 'medicines' then 'أدويتك'
        when 'spending' then 'مصروفك'
        else 'مهامك ومواعيدك' end;
    end if;
  end loop;

  if v_asked > 0 then
    insert into public.app_notifications (user_id, title, message, is_read)
    values (
      p_owner,
      '👨‍👩‍👧 طلب متابعة من العيلة',
      coalesce(nullif(trim(v_alias), ''), 'حد من العيلة') || ' عايز يتابع ' || array_to_string(v_labels, ' و')
        || '. افتح «عيلتي» ووافق أو ارفض — وتقدر تلغي في أي وقت.',
      false
    );
  end if;
  return jsonb_build_object('ok', true, 'requested', v_asked);
end $$;
revoke all on function public.zad_family_request_share(uuid, text[]) from public, anon;
grant execute on function public.zad_family_request_share(uuid, text[]) to authenticated;

create or replace function public.zad_family_answer_share(p_share uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_row public.zad_family_shares%rowtype;
  v_alias text;
begin
  update public.zad_family_shares
     set status = case when p_accept then 'granted' else 'declined' end, decided_at = now()
   where id = p_share and owner_id = auth.uid() and status = 'pending'
  returning * into v_row;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_pending'); end if;

  select alias into v_alias from public.family_members
   where user_id = v_row.owner_id and family_id = v_row.family_id;
  insert into public.app_notifications (user_id, title, message, is_read)
  values (
    v_row.viewer_id,
    case when p_accept then '✅ وافق على المتابعة' else 'مش موافق على المتابعة' end,
    coalesce(nullif(trim(v_alias), ''), 'فرد من العيلة') || case when p_accept then ' وافق إنك تتابع ' else ' مش موافق إنك تتابع ' end
      || case v_row.scope when 'medicines' then 'أدويته' when 'spending' then 'مصروفه' else 'مهامه ومواعيده' end || '.',
    false
  );
  return jsonb_build_object('ok', true, 'status', v_row.status);
end $$;
revoke all on function public.zad_family_answer_share(uuid, boolean) from public, anon;
grant execute on function public.zad_family_answer_share(uuid, boolean) to authenticated;

create or replace function public.zad_family_revoke_share(p_share uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update public.zad_family_shares
     set status = 'revoked', decided_at = now()
   where id = p_share
     and (owner_id = auth.uid() or viewer_id = auth.uid())
     and status in ('pending', 'granted');
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_active'); end if;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.zad_family_revoke_share(uuid) from public, anon;
grant execute on function public.zad_family_revoke_share(uuid) to authenticated;

-- ── What a granted viewer sees of one member ───────────────────────────────

-- One call for «عيلتي»'s member card: every scope's status, and the data of the granted
-- ones only. Spending is the 30-day total and its top categories — never the
-- transactions themselves (the digest's rule since 20260814213856).
create or replace function public.zad_family_member_view(p_owner uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_family uuid;
  v_tz text;
  v_statuses jsonb;
  v_meds jsonb;
  v_spending jsonb;
  v_tasks jsonb;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  select fo.family_id into v_family
    from public.family_members fo
    join public.family_members fv on fv.family_id = fo.family_id and fv.user_id = v_me
   where fo.user_id = p_owner limit 1;
  if v_family is null then return jsonb_build_object('ok', false, 'reason', 'not_same_family'); end if;

  select coalesce(jsonb_object_agg(scope, jsonb_build_object('id', id, 'status', status)), '{}'::jsonb)
    into v_statuses
    from public.zad_family_shares
   where owner_id = p_owner and viewer_id = v_me and family_id = v_family;

  select public.zad_market_timezone(country) into v_tz from public.zad_users where id = p_owner;
  v_tz := coalesce(v_tz, 'UTC');

  if public.zad_family_share_granted(v_me, p_owner, 'medicines') then
    select coalesce(jsonb_agg(jsonb_build_object(
        'name', p.name,
        'for_person', p.for_person,
        'remaining', p.remaining_quantity,
        'today', coalesce((
          select jsonb_agg(jsonb_build_object(
              'time', t.hhmm,
              'state', case
                when d.status = 'taken' then 'taken'
                when d.status = 'skipped' then 'skipped'
                when t.slot > now() then 'upcoming'
                when t.slot + interval '3 hours' < now() then 'missed'
                else 'due' end
            ) order by t.slot)
            from (
              select trim(x) as hhmm,
                     ((to_char(now() at time zone v_tz, 'YYYY-MM-DD') || ' ' || trim(x))::timestamp at time zone v_tz) as slot
                from unnest(string_to_array(p.dose_times, ',')) as x
               where trim(x) ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
            ) t
            left join lateral (
              select status from public.zad_pharmacy_doses d
               where d.item_id = p.id
                 and d.scheduled_at between t.slot - interval '90 minutes' and t.slot + interval '90 minutes'
               order by abs(extract(epoch from d.scheduled_at - t.slot)) limit 1
            ) d on true
        ), '[]'::jsonb)
      ) order by p.name), '[]'::jsonb)
      into v_meds
      from public.zad_pharmacy_items p
     where p.user_id = p_owner
       and coalesce(p.remaining_quantity, 1) > 0;
  end if;

  if public.zad_family_share_granted(v_me, p_owner, 'spending') then
    select jsonb_build_object(
        'spent_30d', round(coalesce(sum(amount), 0)::numeric, 2),
        'top', coalesce((
          select jsonb_agg(jsonb_build_object('category', c.category, 'amount', round(c.total::numeric, 2)) order by c.total desc)
            from (
              select coalesce(category, 'أخرى') as category, sum(amount) as total
                from public.zad_transactions
               where user_id = p_owner and is_expense and created_at >= now() - interval '30 days'
               group by 1 order by 2 desc limit 3
            ) c
        ), '[]'::jsonb)
      )
      into v_spending
      from public.zad_transactions
     where user_id = p_owner and is_expense and created_at >= now() - interval '30 days';
  end if;

  if public.zad_family_share_granted(v_me, p_owner, 'tasks') then
    select jsonb_build_object(
        'appointments', coalesce((
          select jsonb_agg(jsonb_build_object('title', a.title, 'starts_at', a.starts_at) order by a.starts_at)
            from (
              select title, starts_at from public.zad_appointments
               where user_id = p_owner and status = 'upcoming' and starts_at >= now()
               order by starts_at limit 5
            ) a
        ), '[]'::jsonb),
        'chores_open', (
          select count(*) from public.family_chores
           where family_id = v_family and assigned_to = p_owner and not is_completed
        )
      ) into v_tasks;
  end if;

  return jsonb_build_object(
    'ok', true,
    'shares', v_statuses,
    'medicines', v_meds,
    'spending', v_spending,
    'tasks', v_tasks
  );
end $$;
revoke all on function public.zad_family_member_view(uuid) from public, anon;
grant execute on function public.zad_family_member_view(uuid) to authenticated;

-- ── The visibility that existed without consent ─────────────────────────────

-- Was: any family admin read every member's medicines. Now: whoever the member granted.
drop policy if exists "family_admin_read_pharmacy" on public.zad_pharmacy_items;
drop policy if exists "family_shared_read_pharmacy" on public.zad_pharmacy_items;
create policy "family_shared_read_pharmacy"
  on public.zad_pharmacy_items for select to authenticated
  using (public.zad_family_i_can_see(user_id, 'medicines'));

-- The digest (the brain's family view) shows a member's spending only to someone the
-- member granted it to; alias, role, chores and tasbiha stay family-visible as before.
CREATE OR REPLACE FUNCTION zad_family_digest(p_user UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_family UUID;
  v_role TEXT;
  v_can_see_all BOOLEAN;
  v_members JSONB;
  v_goal JSONB;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  SELECT family_id, role INTO v_family, v_role
    FROM family_members WHERE user_id = p_user LIMIT 1;

  IF v_family IS NULL THEN
    RETURN jsonb_build_object('in_family', false);
  END IF;

  v_can_see_all := coalesce(v_role, '') IN ('admin', 'parent', 'owner');

  SELECT jsonb_agg(jsonb_build_object(
      'alias', m.alias,
      'role', m.role,
      'is_self', m.user_id = p_user,
      'spending_shared', s.shared,
      'spent_30d', CASE WHEN s.shared THEN round(coalesce(t.spent, 0)::numeric, 2) END,
      'monthly_limit', CASE WHEN s.shared THEN u.monthly_limit END,
      'limit_used_pct', CASE WHEN s.shared AND coalesce(u.monthly_limit, 0) > 0
                             THEN round((coalesce(t.spent, 0) / u.monthly_limit * 100)::numeric, 0)
                             ELSE NULL END,
      'chores_done_30d', coalesce(ch.done, 0),
      'tasbiha_streak', coalesce(tb.streak_days, 0)
    ) ORDER BY m.user_id = p_user DESC, m.alias)
    INTO v_members
    FROM family_members m
    JOIN zad_users u ON u.id = m.user_id
    CROSS JOIN LATERAL (
      SELECT public.zad_family_share_granted(p_user, m.user_id, 'spending') AS shared
    ) s
    LEFT JOIN LATERAL (
      SELECT sum(amount) AS spent FROM zad_transactions
       WHERE user_id = m.user_id AND txn_kind = 'expense'
         AND created_at >= now() - interval '30 days'
    ) t ON true
    LEFT JOIN LATERAL (
      SELECT count(*) AS done FROM family_chores
       WHERE assigned_to = m.user_id AND is_completed
         AND created_at >= now() - interval '30 days'
    ) ch ON true
    LEFT JOIN LATERAL (
      SELECT max(streak_days) AS streak_days FROM family_tasbiha
       WHERE user_id = m.user_id AND family_id = v_family
    ) tb ON true
   WHERE m.family_id = v_family
     AND (v_can_see_all OR m.user_id = p_user);

  SELECT jsonb_build_object('target', target_amount, 'current', current_amount, 'month', month_year)
    INTO v_goal
    FROM family_goals WHERE family_id = v_family
    ORDER BY created_at DESC LIMIT 1;

  RETURN jsonb_build_object(
    'in_family', true,
    'can_see_all_members', v_can_see_all,
    'members', coalesce(v_members, '[]'::jsonb),
    'goal', v_goal
  );
END $$;

REVOKE ALL ON FUNCTION zad_family_digest(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION zad_family_digest(UUID) TO service_role;
