-- رفيق زاد: the companion grows with the home (owner-approved 2026-10-11/12, the
-- «رفيق زاد» and «استوديو رفيق زاد» plans).
--
-- Three currencies, one job each, never converted into one another:
--
--   * XP     — the companion's age and level. Earned ONLY from the habits the app
--              exists for (logging, a receipt, the pantry and list, a day's streak,
--              a family member joining). Never sold, never from an advert.
--   * seeds  — the wardrobe's coin (🌱). From levelling up, streak milestones, the
--              day's three missions, a friend who really starts, coming back after
--              a while. Spent on characters, outfits and backgrounds. Seeds never
--              buy AI attempts: an attempt costs a model call, an outfit costs
--              nothing each time someone wears it.
--   * attempts (zad_entitlements) — untouched here.
--
-- Everything is computed here. The phone never says «give me 10 XP»: a row landing
-- in zad_transactions / zad_inventory / zad_shopping_list / family_members is what
-- earns it, through the triggers at the bottom, in the account's market day. Each
-- award is a ledger row with a unique (user, source, ref), so a retried insert or a
-- replayed outbox earns nothing twice, and the daily caps are sums over the ledger.
--
-- A companion never dies and never loses a level. Away two days or more, it sleeps;
-- the next status call wakes it with «وحشتني» and 10 seeds.
--
-- Mercy rule: a pet must never block money. Every trigger swallows its own errors
-- (a warning in the logs), so a broken award can never fail an expense insert.

-- ── Catalog ──────────────────────────────────────────────────────────────────

create table if not exists public.zad_companion_items (
  id text primary key check (id ~ '^[a-z0-9_]{2,32}$'),
  kind text not null check (kind in ('persona', 'outfit', 'background')),
  name_ar text not null,
  -- How it opens without paying. 'seeds' = only seeds or money.
  unlock text not null check (unlock in ('free', 'level', 'invite', 'plus', 'season', 'seeds')),
  unlock_value int,
  season text check (season is null or season in ('ramadan', 'eid')),
  seed_price int check (seed_price is null or seed_price > 0),
  -- The Play one-time product that sells it, when there is one.
  play_product text unique check (play_product is null or play_product ~ '^zad_pet_[a-z0-9_]+$'),
  usd_price numeric(6, 2),
  sort int not null default 0
);

insert into public.zad_companion_items
  (id, kind, name_ar, unlock, unlock_value, season, seed_price, play_product, usd_price, sort) values
  ('zado',        'persona',    'زادو',          'free',   null, null,       null, null,                     null, 0),
  ('basbous',     'persona',    'بسبوس',         'level',  10,   null,       1500, 'zad_pet_basbous',        1.99, 1),
  ('fella',       'persona',    'فلة',           'invite', 1,    null,       1500, 'zad_pet_fella',          1.99, 2),
  ('felfool',     'persona',    'فلفول',         'seeds',  null, null,       2000, 'zad_pet_felfool',        1.99, 3),
  ('mishmish',    'persona',    'مشمش',          'seeds',  null, null,       2000, 'zad_pet_mishmish',       1.99, 4),
  ('toota',       'persona',    'توتة',          'plus',   null, null,       3000, 'zad_pet_toota',          2.99, 5),
  ('fanoos',      'persona',    'فانوس',         'season', null, 'ramadan',  2500, 'zad_pet_fanoos',         2.99, 6),
  ('maamoul',     'persona',    'معمول',         'season', null, 'eid',      2500, 'zad_pet_maamoul',        2.99, 7),
  ('sunglasses',  'outfit',     'نضارة شمس',     'seeds',  null, null,       300,  'zad_pet_sunglasses',     0.99, 10),
  ('winter_hat',  'outfit',     'طاقية شتوي',    'seeds',  null, null,       400,  'zad_pet_winter_hat',     0.99, 11),
  ('chef_hat',    'outfit',     'طاقية الشيف',   'level',  15,   null,       450,  'zad_pet_chef_hat',       0.99, 12),
  ('shemagh',     'outfit',     'شماغ',          'seeds',  null, null,       500,  'zad_pet_shemagh',        0.99, 13),
  ('grad_cap',    'outfit',     'طاقية التخرج',  'invite', 3,    null,       600,  'zad_pet_grad_cap',       0.99, 14),
  ('morning',     'background', 'الصبح',         'free',   null, null,       null, null,                     null, 20),
  ('night',       'background', 'بالليل',        'seeds',  null, null,       200,  'zad_pet_bg_night',       0.49, 21),
  ('garden',      'background', 'الجنينة',       'level',  5,    null,       300,  'zad_pet_bg_garden',      0.49, 22),
  ('kitchen',     'background', 'المطبخ',        'seeds',  null, null,       350,  'zad_pet_bg_kitchen',     0.49, 23),
  ('stars',       'background', 'سما النجوم',    'level',  25,   null,       500,  'zad_pet_bg_stars',       0.99, 24),
  ('shilla',      'background', 'الشلة',         'invite', 3,    null,       500,  'zad_pet_bg_shilla',      0.99, 25)
on conflict (id) do update set
  kind = excluded.kind, name_ar = excluded.name_ar, unlock = excluded.unlock,
  unlock_value = excluded.unlock_value, season = excluded.season, seed_price = excluded.seed_price,
  play_product = excluded.play_product, usd_price = excluded.usd_price, sort = excluded.sort;

alter table public.zad_companion_items enable row level security;
drop policy if exists zad_companion_items_read on public.zad_companion_items;
create policy zad_companion_items_read on public.zad_companion_items for select to authenticated using (true);
revoke insert, update, delete on public.zad_companion_items from anon, authenticated;

-- ── The companion, its ledger, its wardrobe, its invites ────────────────────

create table if not exists public.zad_companion (
  user_id uuid primary key references auth.users(id) on delete cascade,
  persona text not null default 'zado' references public.zad_companion_items(id),
  outfit text references public.zad_companion_items(id),
  background text not null default 'morning' references public.zad_companion_items(id),
  xp int not null default 0 check (xp >= 0),
  seeds int not null default 0 check (seeds >= 0),
  streak int not null default 0,
  streak_day date,
  best_streak int not null default 0,
  born_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  -- What the app last celebrated, so a level-up or an evolution is shown once.
  seen_level int not null default 1,
  seen_stage int not null default 0,
  invite_code text unique,
  invite_attempts int not null default 0,
  invite_attempts_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.zad_companion_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  source text not null check (source in
    ('log', 'scan', 'pantry', 'streak', 'family', 'level', 'streak_milestone', 'missions',
     'invite', 'welcome', 'buy', 'purchase')),
  ref text not null,
  day date not null,
  xp int not null default 0,
  seeds int not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, source, ref)
);
create index if not exists zad_companion_ledger_day on public.zad_companion_ledger (user_id, day);

create table if not exists public.zad_companion_owned (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null references public.zad_companion_items(id),
  source text not null check (source in ('free', 'level', 'invite', 'plus', 'seeds', 'purchase')),
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

create table if not exists public.zad_companion_referrals (
  invitee uuid primary key references auth.users(id) on delete cascade,
  inviter uuid not null references auth.users(id) on delete cascade,
  claimed_at timestamptz not null default now(),
  -- Set when the invitee records their first expense — the only proof that counts.
  confirmed_at timestamptz,
  check (invitee <> inviter)
);
create index if not exists zad_companion_referrals_inviter on public.zad_companion_referrals (inviter);

alter table public.zad_companion enable row level security;
alter table public.zad_companion_ledger enable row level security;
alter table public.zad_companion_owned enable row level security;
alter table public.zad_companion_referrals enable row level security;
drop policy if exists zad_companion_own on public.zad_companion;
create policy zad_companion_own on public.zad_companion for select using ((select auth.uid()) = user_id);
drop policy if exists zad_companion_ledger_own on public.zad_companion_ledger;
create policy zad_companion_ledger_own on public.zad_companion_ledger for select using ((select auth.uid()) = user_id);
drop policy if exists zad_companion_owned_own on public.zad_companion_owned;
create policy zad_companion_owned_own on public.zad_companion_owned for select using ((select auth.uid()) = user_id);
-- Referrals: no client policy at all. Read and written only by the functions below.
revoke insert, update, delete on public.zad_companion, public.zad_companion_ledger,
  public.zad_companion_owned, public.zad_companion_referrals from anon, authenticated;

-- ── Arithmetic ───────────────────────────────────────────────────────────────

-- Level L → L+1 costs 100 + 40·(L−1) XP, so reaching L takes 100(L−1) + 20(L−1)(L−2).
create or replace function public.zad_companion_level_floor(p_level int)
returns int language sql immutable set search_path = public as $$
  select 100 * (greatest(p_level, 1) - 1) + 20 * (greatest(p_level, 1) - 1) * (greatest(p_level, 1) - 2)
$$;

create or replace function public.zad_companion_level(p_xp int)
returns int language plpgsql immutable set search_path = public as $$
declare
  v int := 1;
begin
  while public.zad_companion_level_floor(v + 1) <= coalesce(p_xp, 0) and v < 200 loop
    v := v + 1;
  end loop;
  return v;
end;
$$;

-- بذرة 0 · بُرعم 1 · صغيّر 2 · رفيق 3 · حكيم 4 — a level AND an age, both. The age
-- keeps anyone from racing a companion to حكيم in an afternoon.
create or replace function public.zad_companion_stage(p_level int, p_age_days int)
returns int language sql immutable set search_path = public as $$
  select case
    when p_level >= 25 and p_age_days >= 90 then 4
    when p_level >= 15 and p_age_days >= 30 then 3
    when p_level >= 8  and p_age_days >= 10 then 2
    when p_level >= 4  and p_age_days >= 3  then 1
    else 0 end
$$;

create or replace function public.zad_companion_today(p_user uuid)
returns date language sql stable security definer set search_path = public as $$
  select (now() at time zone public.zad_market_timezone(
    (select u.country from public.zad_users u where u.id = p_user)))::date
$$;

-- ── The companion's row ─────────────────────────────────────────────────────

create or replace function public.zad_companion_ensure(p_user uuid)
returns public.zad_companion language plpgsql security definer set search_path = public as $$
declare
  v public.zad_companion;
  v_code text;
begin
  select * into v from public.zad_companion where user_id = p_user;
  if found then return v; end if;
  loop
    -- 32 random bits, no 0/O/1/I to misread aloud: «ZAD-7KQ4-M9TX».
    v_code := 'ZAD-' || translate(upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)), '01', 'AB');
    v_code := substr(v_code, 1, 8) || '-' || substr(v_code, 9);
    exit when not exists (select 1 from public.zad_companion where invite_code = v_code);
  end loop;
  insert into public.zad_companion (user_id, invite_code) values (p_user, v_code)
  on conflict (user_id) do nothing;
  insert into public.zad_companion_owned (user_id, item_id, source)
  select p_user, i.id, 'free' from public.zad_companion_items i where i.unlock = 'free'
  on conflict do nothing;
  select * into v from public.zad_companion where user_id = p_user;
  return v;
end;
$$;

-- Seeds in or out, once per (source, ref). False when that ref was already paid.
create or replace function public.zad_companion_seed(p_user uuid, p_source text, p_ref text, p_seeds int)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  v_id bigint;
begin
  perform public.zad_companion_ensure(p_user);
  insert into public.zad_companion_ledger (user_id, source, ref, day, seeds)
  values (p_user, p_source, p_ref, public.zad_companion_today(p_user), p_seeds)
  on conflict (user_id, source, ref) do nothing
  returning id into v_id;
  if v_id is null then return false; end if;
  update public.zad_companion set seeds = seeds + p_seeds, updated_at = now() where user_id = p_user;
  return true;
end;
$$;

-- XP for one habit, capped per day per source. Level-ups pay 50 seeds each; the
-- day's three missions (log, pantry, receipt) pay 30 once; a streak day pays 25 XP
-- and its milestones pay seeds. Returns the XP actually given.
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
-- items, Plus items while subscribed. Called by the status read.
create or replace function public.zad_companion_unlock(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_level int;
  v_invites int;
  v_paid boolean;
begin
  select public.zad_companion_level(c.xp) into v_level from public.zad_companion c where c.user_id = p_user;
  select count(*) into v_invites from public.zad_companion_referrals
   where inviter = p_user and confirmed_at is not null;
  select coalesce(e.tier <> 'free' and (e.tier_expires_at is null or e.tier_expires_at > now()), false)
    into v_paid from public.zad_entitlements e where e.user_id = p_user;
  insert into public.zad_companion_owned (user_id, item_id, source)
  select p_user, i.id, i.unlock from public.zad_companion_items i
   where (i.unlock = 'level' and coalesce(v_level, 1) >= i.unlock_value)
      or (i.unlock = 'invite' and v_invites >= i.unlock_value)
      or (i.unlock = 'plus' and coalesce(v_paid, false))
  on conflict do nothing;
end;
$$;

-- ── What the app calls ──────────────────────────────────────────────────────

-- Everything the studio and the orb need, in one read. Also: the check-in (a wake
-- after two days away pays 10 seeds once a day) and the lazy unlocks.
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
                  where user_id = v_user and source = 'level' and ref::int > v.seen_level and ref::int <= v_level))
       end,
    'welcome_back', v_welcome,
    'away_hours', floor(extract(epoch from v_away) / 3600)::int
  );
end;
$$;

-- The celebration was shown.
create or replace function public.zad_companion_ack()
returns void language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v public.zad_companion;
  v_level int;
begin
  if v_user is null then raise exception 'not signed in' using errcode = '42501'; end if;
  select * into v from public.zad_companion where user_id = v_user;
  if not found then return; end if;
  v_level := public.zad_companion_level(v.xp);
  update public.zad_companion
     set seen_level = v_level,
         seen_stage = public.zad_companion_stage(v_level, greatest(0,
           public.zad_companion_today(v_user) - (v.born_at at time zone public.zad_market_timezone(
             (select u.country from public.zad_users u where u.id = v_user)))::date))
   where user_id = v_user;
end;
$$;

-- Wear something owned. 'none' takes the outfit off.
create or replace function public.zad_companion_equip(p_item text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_kind text;
begin
  if v_user is null then raise exception 'not signed in' using errcode = '42501'; end if;
  perform public.zad_companion_ensure(v_user);
  if p_item = 'none' then
    update public.zad_companion set outfit = null, updated_at = now() where user_id = v_user;
    return jsonb_build_object('ok', true);
  end if;
  select kind into v_kind from public.zad_companion_items where id = p_item;
  if v_kind is null then return jsonb_build_object('ok', false, 'reason', 'unknown_item'); end if;
  if not exists (select 1 from public.zad_companion_owned where user_id = v_user and item_id = p_item) then
    return jsonb_build_object('ok', false, 'reason', 'not_owned');
  end if;
  update public.zad_companion set
    persona = case when v_kind = 'persona' then p_item else persona end,
    outfit = case when v_kind = 'outfit' then p_item else outfit end,
    background = case when v_kind = 'background' then p_item else background end,
    updated_at = now()
   where user_id = v_user;
  return jsonb_build_object('ok', true);
end;
$$;

-- Buy with seeds. A season item is sold only in its season, which the phone knows
-- (Hijri, per market) and the server does not: p_season is what the phone says is
-- on today. Cosmetic and seed-only, so trusting it costs nothing real.
create or replace function public.zad_companion_buy(p_item text, p_season text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := auth.uid();
  i public.zad_companion_items;
  v_seeds int;
begin
  if v_user is null then raise exception 'not signed in' using errcode = '42501'; end if;
  perform public.zad_companion_ensure(v_user);
  select * into i from public.zad_companion_items where id = p_item;
  if not found or i.seed_price is null then return jsonb_build_object('ok', false, 'reason', 'not_for_seeds'); end if;
  if i.season is not null and i.season is distinct from p_season then
    return jsonb_build_object('ok', false, 'reason', 'out_of_season');
  end if;
  if exists (select 1 from public.zad_companion_owned where user_id = v_user and item_id = p_item) then
    return jsonb_build_object('ok', false, 'reason', 'owned');
  end if;
  -- Locked row: two taps at once cannot both spend the same seeds.
  select seeds into v_seeds from public.zad_companion where user_id = v_user for update;
  if v_seeds < i.seed_price then
    return jsonb_build_object('ok', false, 'reason', 'not_enough', 'missing', i.seed_price - v_seeds);
  end if;
  perform public.zad_companion_seed(v_user, 'buy', p_item, -i.seed_price);
  insert into public.zad_companion_owned (user_id, item_id, source) values (v_user, p_item, 'seeds');
  return jsonb_build_object('ok', true, 'seeds', v_seeds - i.seed_price);
end;
$$;

-- A new account enters a friend's code. Counts for the friend only once this
-- account records its first expense (the trigger below). Ten wrong codes an hour.
create or replace function public.zad_companion_claim_invite(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v public.zad_companion;
  v_inviter uuid;
begin
  if v_user is null then raise exception 'not signed in' using errcode = '42501'; end if;
  v := public.zad_companion_ensure(v_user);
  if exists (select 1 from public.zad_companion_referrals where invitee = v_user) then
    return jsonb_build_object('ok', false, 'reason', 'already_claimed');
  end if;
  if coalesce((select u.created_at from auth.users u where u.id = v_user), now()) <= now() - interval '14 days' then
    return jsonb_build_object('ok', false, 'reason', 'too_late');
  end if;
  if v.invite_attempts >= 10 and v.invite_attempts_at > now() - interval '1 hour' then
    return jsonb_build_object('ok', false, 'reason', 'too_many');
  end if;
  select user_id into v_inviter from public.zad_companion
   where invite_code = upper(trim(p_code)) and user_id <> v_user;
  if v_inviter is null then
    update public.zad_companion set
      invite_attempts = case when invite_attempts_at > now() - interval '1 hour' then invite_attempts + 1 else 1 end,
      invite_attempts_at = case when invite_attempts_at > now() - interval '1 hour' then invite_attempts_at else now() end
     where user_id = v_user;
    return jsonb_build_object('ok', false, 'reason', 'wrong_code');
  end if;
  insert into public.zad_companion_referrals (invitee, inviter) values (v_user, v_inviter);
  -- Already logging? Then it is proven now.
  if exists (select 1 from public.zad_transactions t where t.user_id = v_user) then
    perform public.zad_companion_confirm_referral(v_user);
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.zad_companion_confirm_referral(p_invitee uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_inviter uuid;
begin
  update public.zad_companion_referrals set confirmed_at = now()
   where invitee = p_invitee and confirmed_at is null
  returning inviter into v_inviter;
  if v_inviter is not null then
    perform public.zad_companion_seed(v_inviter, 'invite', p_invitee::text, 200);
    -- The newcomer gets a welcome gift too: both sides are rewarded.
    perform public.zad_companion_seed(p_invitee, 'invite', 'joined', 100);
  end if;
end;
$$;

-- A Play one-time purchase, after verify-purchase checked it with Google.
-- service_role only. 'zad_pet_seeds_<n>' adds n seeds (once per order).
create or replace function public.zad_companion_grant_purchase(p_user uuid, p_product text, p_order text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_item text;
  v_seeds int;
begin
  if auth.uid() is not null then raise exception 'service only' using errcode = '42501'; end if;
  perform public.zad_companion_ensure(p_user);
  if p_product ~ '^zad_pet_seeds_[0-9]+$' then
    v_seeds := substring(p_product from '([0-9]+)$')::int;
    if v_seeds not in (500, 2000, 6000) then return jsonb_build_object('ok', false, 'reason', 'unknown_pack'); end if;
    perform public.zad_companion_seed(p_user, 'purchase', p_order, v_seeds);
    return jsonb_build_object('ok', true, 'seeds', v_seeds);
  end if;
  if p_product = 'zad_pet_all' then
    insert into public.zad_companion_owned (user_id, item_id, source)
    select p_user, id, 'purchase' from public.zad_companion_items where kind = 'persona'
    on conflict do nothing;
    return jsonb_build_object('ok', true, 'items', 'all_personas');
  end if;
  select id into v_item from public.zad_companion_items where play_product = p_product;
  if v_item is null then return jsonb_build_object('ok', false, 'reason', 'unknown_product'); end if;
  insert into public.zad_companion_owned (user_id, item_id, source) values (p_user, v_item, 'purchase')
  on conflict do nothing;
  return jsonb_build_object('ok', true, 'item', v_item);
end;
$$;

-- ── Where XP comes from: the rows themselves ────────────────────────────────

create or replace function public.zad_companion_on_transaction()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.user_id is not null then
      perform public.zad_companion_award(new.user_id,
        case when new.source_type = 'receipt' then 'scan' else 'log' end,
        new.id::text,
        case when new.source_type = 'receipt' then 20 else 10 end);
      perform public.zad_companion_confirm_referral(new.user_id);
    end if;
  exception when others then
    raise warning 'zad_companion_on_transaction: % (%)', sqlerrm, sqlstate;
  end;
  return null;
end;
$$;

create or replace function public.zad_companion_on_home()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := coalesce(auth.uid(), new.user_id);
begin
  begin
    -- One item earns once a day, however often its quantity is nudged.
    perform public.zad_companion_award(v_actor, 'pantry',
      tg_table_name || ':' || new.id::text || ':' || public.zad_companion_today(v_actor)::text, 5);
  exception when others then
    raise warning 'zad_companion_on_home: % (%)', sqlerrm, sqlstate;
  end;
  return null;
end;
$$;

-- Someone joins the family: everyone already in it earns 200 XP, once per member.
create or replace function public.zad_companion_on_family_member()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  m record;
begin
  begin
    for m in select user_id from public.family_members
              where family_id = new.family_id and user_id is not null and user_id <> new.user_id loop
      perform public.zad_companion_award(m.user_id, 'family', new.user_id::text, 200);
    end loop;
  exception when others then
    raise warning 'zad_companion_on_family_member: % (%)', sqlerrm, sqlstate;
  end;
  return null;
end;
$$;

drop trigger if exists zad_companion_xp on public.zad_transactions;
create trigger zad_companion_xp after insert on public.zad_transactions
  for each row execute function public.zad_companion_on_transaction();
drop trigger if exists zad_companion_xp on public.zad_inventory;
create trigger zad_companion_xp after insert or update of quantity on public.zad_inventory
  for each row execute function public.zad_companion_on_home();
drop trigger if exists zad_companion_xp on public.zad_shopping_list;
create trigger zad_companion_xp after insert on public.zad_shopping_list
  for each row execute function public.zad_companion_on_home();
drop trigger if exists zad_companion_xp on public.family_members;
create trigger zad_companion_xp after insert on public.family_members
  for each row execute function public.zad_companion_on_family_member();

-- ── Who may call what ───────────────────────────────────────────────────────

-- Internal: the triggers and the functions above call these; no client can.
revoke execute on function public.zad_companion_ensure(uuid) from public, anon, authenticated;
revoke execute on function public.zad_companion_seed(uuid, text, text, int) from public, anon, authenticated;
revoke execute on function public.zad_companion_award(uuid, text, text, int) from public, anon, authenticated;
revoke execute on function public.zad_companion_unlock(uuid) from public, anon, authenticated;
revoke execute on function public.zad_companion_today(uuid) from public, anon, authenticated;
revoke execute on function public.zad_companion_confirm_referral(uuid) from public, anon, authenticated;
revoke execute on function public.zad_companion_grant_purchase(uuid, text, text) from public, anon, authenticated;
revoke execute on function public.zad_companion_on_transaction() from public, anon, authenticated;
revoke execute on function public.zad_companion_on_home() from public, anon, authenticated;
revoke execute on function public.zad_companion_on_family_member() from public, anon, authenticated;
grant execute on function public.zad_companion_grant_purchase(uuid, text, text) to service_role;

-- The app: signed in only.
revoke execute on function public.zad_companion_status() from public, anon;
grant execute on function public.zad_companion_status() to authenticated;
revoke execute on function public.zad_companion_ack() from public, anon;
grant execute on function public.zad_companion_ack() to authenticated;
revoke execute on function public.zad_companion_equip(text) from public, anon;
grant execute on function public.zad_companion_equip(text) to authenticated;
revoke execute on function public.zad_companion_buy(text, text) from public, anon;
grant execute on function public.zad_companion_buy(text, text) to authenticated;
revoke execute on function public.zad_companion_claim_invite(text) from public, anon;
grant execute on function public.zad_companion_claim_invite(text) to authenticated;
