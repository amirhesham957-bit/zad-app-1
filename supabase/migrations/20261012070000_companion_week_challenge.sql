-- تحدي الأسبوع لرفيق زاد (خطة «رفيق زاد» ٢٠٢٦-١٠-١١، جدول الـXP: «خلّص تحدي الأسبوع +١٠٠»).
--
-- التحدي: سجّل (مصروف أو فاتورة) في ٥ أيام من ٧. الأسبوع بيبدأ السبت بيوم سوق العميل،
-- زي zad_week_start. لما اليوم الخامس يتسجل، zad_companion_award بتدّي +١٠٠ XP مرة واحدة
-- في الأسبوع (سطر 'challenge' في السجل، ref = أول يوم في الأسبوع)، وده بيكبّر الرفيق ويدفع
-- بذور اللفل لو طلع لفل. zad_companion_status بترجع 'week' للاستوديو: الأيام، الهدف، خلص ولا لأ.
--
-- وكمان: البذور اللي في 'celebrate' كانت بتحوّل ref لرقم من غير ما تتأكد إنه رقم، وأي
-- خطة تنفيذ بتقيّم الشرطين بترتيب تاني كانت هتقع على ref بتاع مصروف (uuid). اتأمّنت.

alter table public.zad_companion_ledger drop constraint if exists zad_companion_ledger_source_check;
alter table public.zad_companion_ledger add constraint zad_companion_ledger_source_check check (source in
  ('log', 'scan', 'pantry', 'streak', 'family', 'level', 'streak_milestone', 'missions',
   'invite', 'welcome', 'buy', 'purchase', 'challenge'));

create or replace function public.zad_companion_week_start(p_day date)
returns date language sql immutable set search_path = public as $$
  -- isodow: الاتنين ١ … الحد ٧. (isodow + 1) % 7 = كام يوم لورا لحد السبت.
  select p_day - ((extract(isodow from p_day)::int + 1) % 7)
$$;

create or replace function public.zad_companion_award(p_user uuid, p_source text, p_ref text, p_xp int)
returns int language plpgsql security definer set search_path = public as $$
declare
  v public.zad_companion;
  v_day date;
  v_cap int;
  v_used int;
  v_xp int;
  v_id bigint;
  v_before int;
  v_after int;
  v_streak int;
begin
  if p_user is null or p_xp <= 0 then return 0; end if;
  v := public.zad_companion_ensure(p_user);
  v_day := public.zad_companion_today(p_user);
  v_cap := case p_source when 'log' then 80 when 'scan' then 60 when 'pantry' then 20
                         when 'streak' then 25 else 100000 end;
  select coalesce(sum(xp), 0) into v_used from public.zad_companion_ledger
   where user_id = p_user and day = v_day and source = p_source;
  v_xp := least(p_xp, v_cap - v_used);
  -- Capped out still counts as having done the habit today (the missions read it),
  -- so the row lands with 0 XP rather than not at all.
  v_xp := greatest(v_xp, 0);
  insert into public.zad_companion_ledger (user_id, source, ref, day, xp)
  values (p_user, p_source, p_ref, v_day, v_xp)
  on conflict (user_id, source, ref) do nothing
  returning id into v_id;
  if v_id is null then return 0; end if;

  v_before := public.zad_companion_level(v.xp);
  update public.zad_companion set xp = xp + v_xp, updated_at = now()
   where user_id = p_user returning * into v;
  v_after := public.zad_companion_level(v.xp);
  for l in v_before + 1 .. v_after loop
    perform public.zad_companion_seed(p_user, 'level', l::text, 50);
  end loop;

  -- A day of logging (by hand or from a receipt) keeps the streak.
  if p_source in ('log', 'scan') and v.streak_day is distinct from v_day then
    v_streak := case when v.streak_day = v_day - 1 then v.streak + 1 else 1 end;
    update public.zad_companion
       set streak = v_streak, streak_day = v_day, best_streak = greatest(best_streak, v_streak)
     where user_id = p_user;
    perform public.zad_companion_award(p_user, 'streak', v_day::text, 25);
    if v_streak in (7, 30, 100, 365) then
      perform public.zad_companion_seed(p_user, 'streak_milestone', v_streak::text,
        case v_streak when 7 then 100 when 30 then 300 when 100 then 1000 else 3000 end);
    end if;
  end if;

  -- تحدي الأسبوع: ٥ أيام فيها تسجيل من ٧ (الأسبوع بيبدأ السبت بيوم سوق العميل) = +١٠٠ XP مرة.
  if p_source in ('log', 'scan')
     and (select count(distinct day) from public.zad_companion_ledger
           where user_id = p_user and source in ('log', 'scan')
             and day >= public.zad_companion_week_start(v_day) and day <= v_day) >= 5 then
    perform public.zad_companion_award(p_user, 'challenge', public.zad_companion_week_start(v_day)::text, 100);
  end if;

  -- مهام اليوم: سجّل، حدّث البيت، صوّر فاتورة.
  if p_source in ('log', 'scan', 'pantry')
     and (select count(distinct source) from public.zad_companion_ledger
           where user_id = p_user and day = v_day and source in ('log', 'scan', 'pantry')) = 3 then
    perform public.zad_companion_seed(p_user, 'missions', v_day::text, 30);
  end if;
  return v_xp;
end;
$$;

-- Lazily grants what the customer has earned without buying: level items, invite

create or replace function public.zad_companion_status()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v public.zad_companion;
  v_day date;
  v_level int;
  v_stage int;
  v_age int;
  v_away interval;
  v_welcome int := 0;
  v_next jsonb;
begin
  if v_user is null then raise exception 'not signed in' using errcode = '42501'; end if;
  v := public.zad_companion_ensure(v_user);
  v_day := public.zad_companion_today(v_user);
  v_away := now() - v.last_seen_at;
  if v_away >= interval '48 hours' and public.zad_companion_seed(v_user, 'welcome', v_day::text, 10) then
    v_welcome := 10;
  end if;
  update public.zad_companion set last_seen_at = now() where user_id = v_user returning * into v;
  perform public.zad_companion_unlock(v_user);

  v_level := public.zad_companion_level(v.xp);
  v_age := greatest(0, v_day - (v.born_at at time zone public.zad_market_timezone(
    (select u.country from public.zad_users u where u.id = v_user)))::date);
  v_stage := public.zad_companion_stage(v_level, v_age);
  v_next := case v_stage
    when 0 then jsonb_build_object('level', 4, 'days', 3)
    when 1 then jsonb_build_object('level', 8, 'days', 10)
    when 2 then jsonb_build_object('level', 15, 'days', 30)
    when 3 then jsonb_build_object('level', 25, 'days', 90)
    else null end;

  return jsonb_build_object(
    'persona', v.persona, 'outfit', v.outfit, 'background', v.background,
    'xp', v.xp, 'level', v_level,
    'level_xp', v.xp - public.zad_companion_level_floor(v_level),
    'level_need', public.zad_companion_level_floor(v_level + 1) - public.zad_companion_level_floor(v_level),
    'stage', v_stage, 'next_stage', v_next, 'age_days', v_age,
    'seeds', v.seeds, 'streak', case when v.streak_day >= v_day - 1 then v.streak else 0 end,
    'best_streak', v.best_streak,
    'today', jsonb_build_object(
      'log', exists (select 1 from public.zad_companion_ledger where user_id = v_user and day = v_day and source = 'log'),
      'pantry', exists (select 1 from public.zad_companion_ledger where user_id = v_user and day = v_day and source = 'pantry'),
      'scan', exists (select 1 from public.zad_companion_ledger where user_id = v_user and day = v_day and source = 'scan'),
      'xp', (select coalesce(sum(xp), 0) from public.zad_companion_ledger where user_id = v_user and day = v_day)),
    'owned', (select coalesce(jsonb_agg(item_id order by item_id), '[]'::jsonb)
                from public.zad_companion_owned where user_id = v_user),
    'invite_code', v.invite_code,
    'invites', (select count(*) from public.zad_companion_referrals where inviter = v_user and confirmed_at is not null),
    'invites_pending', (select count(*) from public.zad_companion_referrals where inviter = v_user and confirmed_at is null),
    'can_claim_invite', not exists (select 1 from public.zad_companion_referrals where invitee = v_user)
       and coalesce((select u.created_at from auth.users u where u.id = v_user), now()) > now() - interval '14 days',
    'celebrate', case when v_level > v.seen_level or v_stage > v.seen_stage then jsonb_build_object(
       'from_level', v.seen_level, 'to_level', v_level, 'from_stage', v.seen_stage, 'to_stage', v_stage,
       'seeds', (select coalesce(sum(seeds), 0) from public.zad_companion_ledger
                  where user_id = v_user and source = 'level'
                    and (case when ref ~ '^[0-9]+$' then ref::int end) > v.seen_level
                    and (case when ref ~ '^[0-9]+$' then ref::int end) <= v_level))
       end,
    'week', jsonb_build_object(
      'days', (select count(distinct day) from public.zad_companion_ledger
                where user_id = v_user and source in ('log', 'scan')
                  and day >= public.zad_companion_week_start(v_day) and day <= v_day),
      'goal', 5,
      'done', exists (select 1 from public.zad_companion_ledger where user_id = v_user and source = 'challenge'
                       and ref = public.zad_companion_week_start(v_day)::text)),
    'welcome_back', v_welcome,
    'away_hours', floor(extract(epoch from v_away) / 3600)::int
  );
end;
$$;


revoke execute on function public.zad_companion_week_start(date) from public, anon;
revoke execute on function public.zad_companion_award(uuid, text, text, int) from public, anon, authenticated;
