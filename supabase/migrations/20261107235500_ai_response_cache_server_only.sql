-- ai_response_cache: server only (ZAD_PLAN ٨.٥، مراجعة الأمان ٧/١١).
--
-- 20260724030000 opened it for reading to every signed-in account because
-- the cache was meant to hold only shared answers (an item's price, a meal
-- for a list of ingredients). It no longer does: measured 2026-11-07 on 659
-- rows, keys carry a user id (agent_summary:<uid>, brain_evaluate:<uid>,
-- meal_suggestions:v2:<uid>), the coordinates someone was at
-- (nearby_pois:pharmacy:<lat>:<lng>), and the medicines people searched for
-- (web_search:…سعر دواء…). Any account could read all of it through
-- /rest/v1/ai_response_cache.
--
-- Nothing on a phone reads this table; its one reader and writer is
-- zad-core-intelligence's service-role client, which RLS does not apply to.
-- So the read policy goes and RLS stays on: clients see nothing, the server
-- keeps its cache.

drop policy if exists "authenticated_read_ai_response_cache" on public.ai_response_cache;

alter table public.ai_response_cache enable row level security;

revoke all on table public.ai_response_cache from anon, authenticated;

-- The advisor's «function_search_path_mutable»: ten small helpers, none of
-- them SECURITY DEFINER, so not exploitable today — pinned anyway so a
-- schema earlier on a caller's path can never shadow what they call.
alter function public.zad_companion_care_json(public.zad_companion_care) set search_path = public;
alter function public.zad_habit_trial_amount(text, numeric, text) set search_path = public;
alter function public.zad_habit_trial_behaviour(text) set search_path = public;
alter function public.zad_habit_trial_is_money(text) set search_path = public;
alter function public.zad_habit_trial_times_label(text, integer, integer) set search_path = public;
alter function public.zad_hold_code(text) set search_path = public;
alter function public.zad_in_slot(time, time, integer) set search_path = public;
alter function public.zad_night_slot(time) set search_path = public;
alter function public.zad_problem_kind(text) set search_path = public;
alter function public.zad_redact_lesson(text) set search_path = public;
