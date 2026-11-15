-- zad_game_reward (20261116020000): formula, caps, ad doubling, and every refusal.
--   psql < scratch_scaffold.sql ; companion_scaffold.sql ; ../../migrations/20261012030000_companion.sql ; worlds_scaffold.sql
--   psql < ../../migrations/20261116010000_achievements_writer.sql ; ../../migrations/20261116020000_game_rewards.sql ; this file

\set ON_ERROR_STOP on

insert into auth.users (id) values
  ('00000000-0000-4000-8000-0000000000a1'), ('00000000-0000-4000-8000-0000000000a2'),
  ('00000000-0000-4000-8000-0000000000a3'), ('00000000-0000-4000-8000-0000000000a4'),
  ('00000000-0000-4000-8000-0000000000a5');
-- Receipts (written by the SSV function with the service role): a1 fresh x2, a1 stale, a2 fresh (someone else's).
insert into public.zad_ad_ssv_receipts (transaction_id, user_id, created_at) values
  ('tx-a1-fresh-1', '00000000-0000-4000-8000-0000000000a1', now() - interval '1 minute'),
  ('tx-a1-stale',   '00000000-0000-4000-8000-0000000000a3', now() - interval '30 minutes'),
  ('tx-a2-fresh',   '00000000-0000-4000-8000-0000000000a2', now() - interval '1 minute');

-- ── anon and no-identity are refused ────────────────────────────────────────
set role anon;
do $$ begin
  begin perform zad_game_reward('ball', 100, false); raise exception 'anon was allowed';
  exception when insufficient_privilege then null; end;
end $$;

set role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated"}', false);
do $$ begin
  begin perform zad_game_reward('ball', 100, false); raise exception 'no uid was allowed';
  exception when sqlstate '28000' then null; end;
end $$;

-- ── a1: validation, formula, doubling ───────────────────────────────────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', false);
do $$
declare r jsonb;
begin
  begin perform zad_game_reward('hax', 100, false); raise exception 'unknown game was allowed';
  exception when sqlstate '22023' then null; end;
  begin perform zad_game_reward('ball', -1, false); raise exception 'negative score allowed';
  exception when sqlstate '22023' then null; end;
  begin perform zad_game_reward('ball', 2000000, false); raise exception 'absurd score allowed';
  exception when sqlstate '22023' then null; end;

  -- ball: score/10, max 8 per round.
  r := zad_game_reward('ball', 30, false);
  if (r ->> 'granted')::int <> 3 or (r ->> 'doubled')::boolean then raise exception 'ball 30 -> %', r; end if;
  r := zad_game_reward('ball', 5000, false);
  if (r ->> 'granted')::int <> 8 then raise exception 'ball max per round not 8: %', r; end if;
  r := zad_game_reward('ball', 5, false);  -- 0 seeds: nothing written
  if (r ->> 'granted')::int <> 0 then raise exception 'ball 5 should pay 0: %', r; end if;

  -- doubled with a fresh receipt of mine: 2x, receipt consumed.
  r := zad_game_reward('zado_sort', 20, true);  -- base 4
  if (r ->> 'base')::int <> 4 or (r ->> 'granted')::int <> 8 or not (r ->> 'doubled')::boolean then
    raise exception 'doubled with receipt -> %', r; end if;
  -- the same receipt again: not doubled.
  r := zad_game_reward('zado_sort', 20, true);
  if (r ->> 'granted')::int <> 4 or (r ->> 'doubled')::boolean then raise exception 'receipt reused -> %', r; end if;
end $$;

-- the usage is on the ledger, one row, keyed by the receipt.
reset role;
do $$ begin
  if (select count(*) from zad_companion_ledger where user_id = '00000000-0000-4000-8000-0000000000a1'
        and source = 'game_double' and ref = 'tx-a1-fresh-1') <> 1 then raise exception 'receipt use not recorded'; end if;
  if (select seeds from zad_companion where user_id = '00000000-0000-4000-8000-0000000000a1') <> 3 + 8 + 8 + 4 then
    raise exception 'a1 seeds wrong: %', (select seeds from zad_companion where user_id = '00000000-0000-4000-8000-0000000000a1'); end if;
end $$;

-- ── a2: someone else's receipt does not double; no receipt does not double ──
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a4","role":"authenticated"}', false);
do $$
declare r jsonb;
begin
  r := zad_game_reward('ball', 40, true);  -- a4 has no receipt at all
  if (r ->> 'granted')::int <> 4 or (r ->> 'doubled')::boolean then raise exception 'doubled without receipt -> %', r; end if;
end $$;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', false);
do $$
declare r jsonb;
begin
  r := zad_game_reward('ball', 40, true);  -- a3's only receipt is 30 minutes old
  if (r ->> 'granted')::int <> 4 or (r ->> 'doubled')::boolean then raise exception 'stale receipt doubled -> %', r; end if;
end $$;
-- a4 tries to use a1's/a2's receipts: they are not theirs.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a4","role":"authenticated"}', false);
do $$
declare r jsonb;
begin
  r := zad_game_reward('ball', 40, true);
  if (r ->> 'doubled')::boolean then raise exception 'used another account receipt: %', r; end if;
end $$;

-- ── per-game round cap: 10 rounds of 1 seed, the 11th pays nothing ─────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', false);
do $$
declare r jsonb;
begin
  for i in 1..10 loop
    r := zad_game_reward('zado_sort', 5, false);
    if (r ->> 'granted')::int <> 1 then raise exception 'round % -> %', i, r; end if;
  end loop;
  r := zad_game_reward('zado_sort', 5, false);
  if (r ->> 'granted')::int <> 0 then raise exception 'round cap not enforced: %', r; end if;
  -- another game is still open.
  r := zad_game_reward('star_catch', 10, false);
  if (r ->> 'granted')::int <> 2 then raise exception 'other game blocked by round cap: %', r; end if;
end $$;

-- ── daily cap across games: never more than 60, doubling included ──────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a5","role":"authenticated"}', false);
do $$
declare r jsonb; total int := 0; g text;
begin
  foreach g in array array['ball', 'ball', 'ball', 'zado_run', 'zado_sort', 'star_catch', 'ball', 'ball', 'tasbih_garden'] loop
    r := zad_game_reward(g, 100000, false);
    total := total + (r ->> 'granted')::int;
  end loop;
  if total <> 60 then raise exception 'daily cap: granted % in total, expected 60', total; end if;
  r := zad_game_reward('ball', 100000, true);
  if (r ->> 'granted')::int <> 0 or (r ->> 'remaining_today')::int <> 0 then raise exception 'past the cap: %', r; end if;
end $$;
reset role;
-- a5 holds a fresh receipt now; at the cap it must not be spent either.
insert into public.zad_ad_ssv_receipts (transaction_id, user_id) values ('tx-a5', '00000000-0000-4000-8000-0000000000a5');
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a5","role":"authenticated"}', false);
do $$ declare r jsonb; begin
  r := zad_game_reward('ball', 100000, true);
  if (r ->> 'granted')::int <> 0 or (r ->> 'doubled')::boolean then raise exception 'doubling past the cap: %', r; end if;
end $$;
reset role;
do $$ begin
  if exists (select 1 from zad_companion_ledger where ref = 'tx-a5') then raise exception 'receipt burned at the cap'; end if;
  if (select seeds from zad_companion where user_id = '00000000-0000-4000-8000-0000000000a5') <> 60 then
    raise exception 'a5 total <> 60'; end if;
end $$;

-- doubling is itself bounded by the cap: a5-like near-cap user. a3 is at 4; push to 56 then double a 6 -> only 0 extra beyond cap.
insert into public.zad_ad_ssv_receipts (transaction_id, user_id) values ('tx-a3-fresh', '00000000-0000-4000-8000-0000000000a3');
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', false);
do $$ declare r jsonb; begin
  perform zad_game_reward('ball', 100000, false);  -- +8 (12)
  perform zad_game_reward('zado_run', 100000, false);  -- +10 (22)
  perform zad_game_reward('zado_sort', 100000, false);  -- +8 (30)
  perform zad_game_reward('star_catch', 100000, false);  -- +8 (38)
  perform zad_game_reward('tasbih_garden', 100000, false);  -- +6 (44)
  perform zad_game_reward('ball', 100000, false);  -- +8 (52)
  perform zad_game_reward('ball', 100000, false);  -- +8 (60)... capped at 8 -> 60
  r := zad_game_reward('ball', 100000, true);
  if (r ->> 'granted')::int <> 0 then raise exception 'a3 not at cap: %', r; end if;
end $$;

-- ── the client cannot write seeds or ledger by hand ────────────────────────
do $$ begin
  begin update zad_companion set seeds = 99999; raise exception 'client updated seeds';
  exception when insufficient_privilege then null; end;
  begin insert into zad_companion_ledger (user_id, source, ref, day, seeds)
    values ('00000000-0000-4000-8000-0000000000a3', 'game', 'x', current_date, 50); raise exception 'client wrote the ledger';
  exception when insufficient_privilege then null; end;
end $$;

-- ── zado_run 300 unlocks the achievement; 299 does not ─────────────────────
reset role;
insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000a6');
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a6","role":"authenticated"}', false);
select zad_game_reward('zado_run', 299, false);
reset role;
do $$ begin
  if exists (select 1 from user_achievements where achievement_id = 'zado_run_300' and user_id = '00000000-0000-4000-8000-0000000000a6') then raise exception '299 unlocked zado_run_300'; end if;
end $$;
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a6","role":"authenticated"}', false);
select zad_game_reward('zado_run', 300, false);
select zad_game_reward('zado_run', 400, false);  -- again: still one row
reset role;
do $$ begin
  if (select count(*) from user_achievements where achievement_id = 'zado_run_300'
        and user_id = '00000000-0000-4000-8000-0000000000a6') <> 1 then raise exception 'zado_run_300 not exactly once'; end if;
end $$;
select 'game_reward_test OK' as result;
