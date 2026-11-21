-- ZAD_OR_PLAN م٢.٥: الإعدادات، الأهداف والتحديات، وتأجيل الجرعة من الباب. كل نوع: نجاح، رفض بسببه، القديم في الحدث،
-- ومستخدم تاني ماتلمسش. كل رفض لازم يتسجل في zad_guard_events.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
-- نية كاملة: النوع، الحمولة، مفتاح التكرار، والمستخدم (١ لو مااتحددش).
create or replace function pg_temp.ci(k text, p text, cid text, u uuid default '11111111-1111-1111-1111-111111111111')
returns jsonb language sql as $$
  select zad_commit_intent(jsonb_build_object('user_id', u, 'kind', k, 'client_event_id', cid, 'payload', p::jsonb)) $$;
create or replace function pg_temp.ok(k text, p text, cid text, u uuid default '11111111-1111-1111-1111-111111111111')
returns boolean language sql as $$ select coalesce((pg_temp.ci(k, p, cid, u) ->> 'ok')::boolean, false) $$;
create or replace function pg_temp.why(k text, p text, cid text, u uuid default '11111111-1111-1111-1111-111111111111')
returns text language sql as $$ select pg_temp.ci(k, p, cid, u) ->> 'reason' $$;

update zad_users set cycle_start_day = 1, currency = 'EGP', country = 'EG', emergency_fund_balance = 500
 where id in ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');

-- ١) الإعدادات
select pg_temp.check(pg_temp.ok('settings.cycle_start_set', '{"day":25}', 's1'), 'cycle day set');
select pg_temp.check((select cycle_start_day = 25 from zad_users where id = '11111111-1111-1111-1111-111111111111'), 'cycle day written');
select pg_temp.check((select (payload -> 'before' ->> 'cycle_start_day')::int = 1 and (payload -> 'after' ->> 'cycle_start_day')::int = 25 from zad_events where client_event_id = 's1'), 'event keeps before and after');
select pg_temp.check(pg_temp.why('settings.cycle_start_set', '{"day":32}', 's2') = 'cycle_day_invalid', 'day 32');
select pg_temp.check(pg_temp.why('settings.cycle_start_set', '{"day":0}', 's2b') = 'cycle_day_invalid', 'day 0');
select pg_temp.check(pg_temp.why('settings.cycle_start_set', '{"day":"x"}', 's2c') = 'cycle_day_invalid', 'day not a number');
select pg_temp.check(pg_temp.why('settings.cycle_start_set', '{"day":15.5}', 's2d') = 'cycle_day_invalid', 'day not whole');
select pg_temp.check((select cycle_start_day = 25 from zad_users where id = '11111111-1111-1111-1111-111111111111'), 'refused days wrote nothing');

select pg_temp.check(pg_temp.ok('settings.market_set', '{"currency":"SAR","country":"SA"}', 's3'), 'market set');
select pg_temp.check((select currency = 'SAR' and country = 'SA' from zad_users where id = '11111111-1111-1111-1111-111111111111'), 'market written');
select pg_temp.check((select payload -> 'before' ->> 'currency' = 'EGP' from zad_events where client_event_id = 's3'), 'event keeps the old market');
select pg_temp.check(pg_temp.why('settings.market_set', '{"currency":"sar","country":"SA"}', 's4') = 'currency_invalid', 'lowercase currency');
select pg_temp.check(pg_temp.why('settings.market_set', '{"currency":"SAR","country":"SAU"}', 's5') = 'country_invalid', 'three-letter country');
select pg_temp.check((select currency = 'SAR' from zad_users where id = '11111111-1111-1111-1111-111111111111'), 'refused market wrote nothing');

select pg_temp.check(pg_temp.ok('settings.emergency_fund_set', '{"balance":1234.567}', 's6'), 'fund set');
select pg_temp.check((select emergency_fund_balance = 1234.57 from zad_users where id = '11111111-1111-1111-1111-111111111111'), 'fund rounded to two places');
select pg_temp.check(pg_temp.ok('settings.emergency_fund_set', '{"balance":0}', 's6b'), 'fund can be zero');
select pg_temp.check(pg_temp.why('settings.emergency_fund_set', '{"balance":-1}', 's7') = 'balance_invalid', 'negative fund');
select pg_temp.check(pg_temp.why('settings.emergency_fund_set', '{"balance":"abc"}', 's7b') = 'balance_invalid', 'fund as text');
select pg_temp.check(pg_temp.why('settings.emergency_fund_set', '{"balance":200000000}', 's8') = 'amount_over_cap', 'absurd fund');
select pg_temp.check((select emergency_fund_balance = 0 from zad_users where id = '11111111-1111-1111-1111-111111111111'), 'refused funds wrote nothing');

select pg_temp.check(pg_temp.ok('settings.sleep_set', '{"bed":"23:30","wake":"07:15"}', 's9'), 'sleep set');
select pg_temp.check((select sleep_bed = time '23:30' and sleep_wake = time '07:15' and sleep_source = 'manual' and sleep_updated_at is not null from zad_users where id = '11111111-1111-1111-1111-111111111111'), 'sleep written as manual');
select pg_temp.check(pg_temp.why('settings.sleep_set', '{"bed":"12:00","wake":"07:00"}', 's10') = 'sleep_bed_out_of_range', 'noon bedtime');
select pg_temp.check(pg_temp.why('settings.sleep_set', '{"bed":"23:00","wake":"13:00"}', 's11') = 'sleep_wake_out_of_range', 'wake after noon');
select pg_temp.check(pg_temp.why('settings.sleep_set', '{"bed":"24:00","wake":"07:00"}', 's12') = 'sleep_time_invalid', '24:00');
select pg_temp.check(pg_temp.why('settings.sleep_set', '{"bed":"23:00"}', 's12b') = 'sleep_time_invalid', 'wake missing');
select pg_temp.check((select sleep_bed = time '23:30' from zad_users where id = '11111111-1111-1111-1111-111111111111'), 'refused sleep wrote nothing');
select pg_temp.check(pg_temp.ok('settings.sleep_cleared', '{}', 's13'), 'sleep cleared');
select pg_temp.check((select sleep_bed is null and sleep_wake is null and sleep_source is null from zad_users where id = '11111111-1111-1111-1111-111111111111'), 'sleep cleared in the row');
select pg_temp.check((select payload -> 'before' ->> 'sleep_bed' = '23:30:00' from zad_events where client_event_id = 's13'), 'event keeps the old sleep window');

select pg_temp.check(pg_temp.ok('settings.app_flag_set', '{"setting":"pet_calls","on":false}', 's14'), 'pet calls off');
select pg_temp.check(pg_temp.ok('settings.app_flag_set', '{"setting":"food_pattern","on":true}', 's15'), 'food pattern on');
select pg_temp.check((select pet_calls_enabled = false and food_pattern_enabled = true from zad_users where id = '11111111-1111-1111-1111-111111111111'), 'flags written');
select pg_temp.check((select (payload -> 'before' ->> 'pet_calls_enabled')::boolean from zad_events where client_event_id = 's14'), 'event keeps the old flag');
select pg_temp.check(pg_temp.why('settings.app_flag_set', '{"setting":"is_admin","on":true}', 's16') = 'setting_unknown', 'unknown flag');
select pg_temp.check(pg_temp.why('settings.app_flag_set', '{"setting":"pet_calls","on":"yes"}', 's17') = 'bad_payload', 'flag value as text');
select pg_temp.check(pg_temp.why('settings.nothing', '{}', 's18') = 'unknown_kind', 'unknown settings kind');
select pg_temp.check((select cycle_start_day = 1 and currency = 'EGP' and country = 'EG' and emergency_fund_balance = 500 and sleep_bed is null and pet_calls_enabled and not food_pattern_enabled from zad_users where id = '22222222-2222-2222-2222-222222222222'), 'other user untouched by every settings kind');

-- ٢) الأهداف
select pg_temp.check(pg_temp.ok('goal.set', '{"title":"مصيف الصيف","metric":"توفير","target_value":5000,"deadline_date":"2027-06-01","unit":"money"}', 'g1'), 'goal set');
select pg_temp.check((select count(*) = 1 and max(progress_kind) = 'amount' and max(target_value) = 5000 and max(status) = 'active' from agent_goals where title = 'مصيف الصيف'), 'goal row, money kind');
select pg_temp.check(pg_temp.ok('goal.set', '{"title":"مصيف الصيف","target_value":6000,"unit":"money"}', 'g1b'), 'goal set again');
select pg_temp.check((select count(*) = 1 and max(target_value) = 6000 and max(metric) is null from agent_goals where title = 'مصيف الصيف'), 'same title is the same row');
select pg_temp.check((select (payload -> 'before' ->> 'target_value')::numeric = 5000 from zad_events where client_event_id = 'g1b'), 'event keeps the old goal');
select pg_temp.check(pg_temp.ok('goal.set', '{"title":"مصيف الصيف","target_value":7000}', 'g1c'), 'goal set without unit');
select pg_temp.check((select progress_kind = 'amount' from agent_goals where title = 'مصيف الصيف'), 'absent unit keeps the kind');
select pg_temp.check(pg_temp.why('goal.set', '{"title":"هد"}', 'g2') = 'goal_title_invalid', 'short title');
select pg_temp.check(pg_temp.why('goal.set', '{"title":"هدف جديد","target_value":0}', 'g3') = 'target_invalid', 'zero target');
select pg_temp.check(pg_temp.why('goal.set', '{"title":"هدف جديد","target_value":999999999}', 'g3b') = 'target_invalid', 'absurd target');
select pg_temp.check(pg_temp.why('goal.set', '{"title":"هدف جديد","deadline_date":"قريب"}', 'g4') = 'deadline_invalid', 'bad deadline');
select pg_temp.check(pg_temp.why('goal.set', '{"title":"هدف جديد","unit":"kg"}', 'g5') = 'unit_invalid', 'bad unit');
select pg_temp.check(not exists (select 1 from agent_goals where title = 'هدف جديد'), 'refused goals wrote nothing');

select pg_temp.check(pg_temp.ok('goal.progress', jsonb_build_object('goal_id', (select id from agent_goals where title = 'مصيف الصيف'), 'amount', 500)::text, 'g6'), 'progress');
select pg_temp.check((select current_value = 500 from agent_goals where title = 'مصيف الصيف'), 'progress added');
select pg_temp.check((select (payload -> 'before' ->> 'current_value')::numeric = 0 and (payload -> 'after' ->> 'current_value')::numeric = 500 from zad_events where client_event_id = 'g6'), 'event keeps before and after');
select pg_temp.check(pg_temp.why('goal.progress', jsonb_build_object('goal_id', (select id from agent_goals where title = 'مصيف الصيف'), 'amount', 0)::text, 'g7') = 'goal_amount_invalid', 'zero progress');
select pg_temp.check(pg_temp.why('goal.progress', jsonb_build_object('goal_id', (select id from agent_goals where title = 'مصيف الصيف'), 'amount', 10)::text, 'g8', '22222222-2222-2222-2222-222222222222') = 'goal_not_found', 'someone else''s goal');
select pg_temp.check(pg_temp.why('goal.progress', '{"goal_id":"00000000-0000-0000-0000-000000000000","amount":10}', 'g9') = 'goal_not_found', 'unknown goal');
select pg_temp.check(pg_temp.ok('goal.set', '{"title":"قراءة كتاب","unit":"count"}', 'g10'), 'task goal');
select pg_temp.check(pg_temp.why('goal.progress', jsonb_build_object('goal_id', (select id from agent_goals where title = 'قراءة كتاب'), 'amount', 10)::text, 'g11') = 'goal_not_amount', 'task goals take no money');
select pg_temp.check((select current_value = 500 from agent_goals where title = 'مصيف الصيف'), 'refused progress changed nothing');
select pg_temp.check(pg_temp.ok('goal.cancelled', '{"title":"قراءة كتاب"}', 'g12'), 'goal cancelled');
select pg_temp.check((select status = 'cancelled' from agent_goals where title = 'قراءة كتاب'), 'goal cancelled in the row');
select pg_temp.check((select payload -> 'before' ->> 'status' = 'active' from zad_events where client_event_id = 'g12'), 'event keeps the old status');
select pg_temp.check(pg_temp.why('goal.cancelled', '{"title":"مفيش هدف كده"}', 'g13') = 'goal_not_found', 'cancel an unknown goal');
select pg_temp.check(pg_temp.why('goal.cancelled', '{"title":"مصيف الصيف"}', 'g14', '22222222-2222-2222-2222-222222222222') = 'goal_not_found', 'other user cannot see my title');
select pg_temp.check((select status = 'active' from agent_goals where title = 'مصيف الصيف'), 'other user cannot cancel my goal');

-- ٣) تحدي التوفير
select pg_temp.check(pg_temp.ok('goal.challenge_started', '{"daily_cap":150,"length_days":30,"started_on":"2026-11-22","currency":"EGP","source":"chat"}', 'c1'), 'challenge started');
select pg_temp.check((select count(*) = 1 and max(daily_cap) = 150 and max(length_days) = 30 and max(source) = 'chat' and max(status) = 'active' from zad_savings_challenges where user_id = '11111111-1111-1111-1111-111111111111'), 'challenge row');
select pg_temp.check(pg_temp.why('goal.challenge_started', '{"daily_cap":100,"length_days":30,"started_on":"2026-11-22"}', 'c2') = 'challenge_already_active', 'one active challenge');
select pg_temp.check((select count(*) = 1 from zad_savings_challenges where user_id = '11111111-1111-1111-1111-111111111111'), 'still one challenge');
select pg_temp.check(pg_temp.ok('goal.challenge_started', '{"daily_cap":100,"length_days":14,"started_on":"2026-11-22"}', 'c2b', '22222222-2222-2222-2222-222222222222'), 'the other user starts theirs');
select pg_temp.check(pg_temp.ok('goal.challenge_stopped', '{}', 'c3'), 'challenge stopped');
select pg_temp.check((select status = 'abandoned' and best_streak = 0 from zad_savings_challenges where user_id = '11111111-1111-1111-1111-111111111111'), 'abandoned, counters untouched');
select pg_temp.check((select payload -> 'before' ->> 'status' = 'active' and payload -> 'after' ->> 'status' = 'abandoned' from zad_events where client_event_id = 'c3'), 'event keeps before and after');
select pg_temp.check((select status = 'active' from zad_savings_challenges where user_id = '22222222-2222-2222-2222-222222222222'), 'other user''s challenge untouched');
select pg_temp.check(pg_temp.why('goal.challenge_stopped', '{}', 'c4') = 'no_active_challenge', 'nothing to stop');
select pg_temp.check(pg_temp.why('goal.challenge_started', '{"daily_cap":0,"length_days":30,"started_on":"2026-11-22"}', 'c5') = 'challenge_cap_invalid', 'zero cap');
select pg_temp.check(pg_temp.why('goal.challenge_started', '{"daily_cap":100,"length_days":3,"started_on":"2026-11-22"}', 'c6') = 'challenge_length_invalid', 'three days');
select pg_temp.check(pg_temp.why('goal.challenge_started', '{"daily_cap":100,"length_days":30,"started_on":"بكرة"}', 'c7') = 'challenge_date_invalid', 'bad date');
select pg_temp.check(pg_temp.why('goal.challenge_started', '{"daily_cap":100,"length_days":30,"started_on":"2026-11-22","source":"web"}', 'c8') = 'bad_payload', 'bad source');
select pg_temp.check(pg_temp.why('goal.challenge_started', '{"daily_cap":100,"length_days":30,"started_on":"2026-11-22","currency":"ABCDEFGHIJK"}', 'c9') = 'currency_invalid', 'long currency');
select pg_temp.check(pg_temp.why('goal.nothing', '{}', 'c10') = 'unknown_kind', 'unknown goal kind');

-- ٤) تأجيل الجرعة (دوا ١ بتاع العميل، ودوا ٢ بتاع ٢ ومعاه موافقة قراية لـ١: التأجيل لصاحب الدوا بس)
insert into zad_pharmacy_items (id, user_id, name, remaining_quantity, dose_times, daily_dose_count) values
  ('c0000000-0000-0000-0000-0000000000a1', '11111111-1111-1111-1111-111111111111', 'كونكور', 10, '08:00', 1),
  ('c0000000-0000-0000-0000-0000000000a2', '22222222-2222-2222-2222-222222222222', 'بنادول', 5, '09:00', 1);
insert into family_members values ('f0000000-0000-0000-0000-000000000009', '11111111-1111-1111-1111-111111111111'),
                                  ('f0000000-0000-0000-0000-000000000009', '22222222-2222-2222-2222-222222222222');
insert into scratch_medicine_grants values ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
select pg_temp.check(pg_temp.ok('pharmacy.dose_snoozed', '{"item_id":"c0000000-0000-0000-0000-0000000000a1","scheduled_at":"2026-11-22T08:00:00Z","minutes":15}', 'z1'), 'snoozed');
select pg_temp.check((select count(*) = 1 and bool_and(snooze_until > now() + interval '14 minutes' and snooze_until < now() + interval '16 minutes') from zad_dose_snoozes where item_id = 'c0000000-0000-0000-0000-0000000000a1'), 'one snooze row, 15 minutes ahead');
select pg_temp.check(pg_temp.ok('pharmacy.dose_snoozed', '{"item_id":"c0000000-0000-0000-0000-0000000000a1","scheduled_at":"2026-11-22T08:00:00Z","minutes":60}', 'z2'), 'snoozed again');
select pg_temp.check((select count(*) = 1 and bool_and(snooze_until > now() + interval '59 minutes') from zad_dose_snoozes where item_id = 'c0000000-0000-0000-0000-0000000000a1'), 'same slot is the same row, moved');
select pg_temp.check((select payload -> 'before' ->> 'snooze_until' is not null from zad_events where client_event_id = 'z2'), 'event keeps the previous snooze');
select pg_temp.check(pg_temp.ok('pharmacy.dose_snoozed', '{"item_id":"c0000000-0000-0000-0000-0000000000a1","scheduled_at":"2026-11-22T20:00:00Z","minutes":15}', 'z3'), 'another slot');
select pg_temp.check((select count(*) = 2 from zad_dose_snoozes where item_id = 'c0000000-0000-0000-0000-0000000000a1'), 'slots are separate rows');
select pg_temp.check(pg_temp.why('pharmacy.dose_snoozed', '{"item_id":"c0000000-0000-0000-0000-0000000000a1","scheduled_at":"2026-11-22T08:00:00Z","minutes":1}', 'z4') = 'snooze_minutes_invalid', 'one minute');
select pg_temp.check(pg_temp.why('pharmacy.dose_snoozed', '{"item_id":"c0000000-0000-0000-0000-0000000000a1","scheduled_at":"2026-11-22T08:00:00Z","minutes":500}', 'z4b') = 'snooze_minutes_invalid', 'a whole day');
select pg_temp.check(pg_temp.why('pharmacy.dose_snoozed', '{"item_id":"c0000000-0000-0000-0000-0000000000a1","scheduled_at":"غدا","minutes":15}', 'z5') = 'dose_slot_invalid', 'bad slot');
select pg_temp.check(pg_temp.why('pharmacy.dose_snoozed', '{"item_id":"c0000000-0000-0000-0000-0000000000a2","scheduled_at":"2026-11-22T09:00:00Z","minutes":15}', 'z6') = 'item_not_found', 'someone else''s medicine, consent or not');
select pg_temp.check(pg_temp.why('pharmacy.dose_snoozed', '{"item_id":"00000000-0000-0000-0000-000000000000","scheduled_at":"2026-11-22T09:00:00Z","minutes":15}', 'z7') = 'item_not_found', 'unknown medicine');
-- «فوّتها» (pharmacy.dose_skipped): صف skipped بـ٠، والمخزون ماتحركش، وإجابة تانية على نفس الخانة مرفوضة من غير صف تاني.
select pg_temp.check(pg_temp.ok('pharmacy.dose_skipped', '{"item_id":"c0000000-0000-0000-0000-0000000000a1","scheduled_at":"2026-11-22T08:00:00Z"}', 'k1'), 'skipped');
select pg_temp.check((select count(*) = 1 and bool_and(status = 'skipped' and units = 0) from zad_pharmacy_doses where item_id = 'c0000000-0000-0000-0000-0000000000a1'), 'one skipped row, zero units');
select pg_temp.check((select remaining_quantity = 10 from zad_pharmacy_items where id = 'c0000000-0000-0000-0000-0000000000a1'), 'stock untouched by a skip');
select pg_temp.check(pg_temp.why('pharmacy.dose_skipped', '{"item_id":"c0000000-0000-0000-0000-0000000000a1","scheduled_at":"2026-11-22T08:00:00Z"}', 'k2') = 'dose_already_logged', 'second answer on the same slot');
select pg_temp.check((select count(*) = 1 from zad_pharmacy_doses where item_id = 'c0000000-0000-0000-0000-0000000000a1'), 'still one row');
select pg_temp.check(pg_temp.why('pharmacy.dose_skipped', '{"item_id":"c0000000-0000-0000-0000-0000000000a2","scheduled_at":"2026-11-22T09:00:00Z"}', 'k3') = 'item_not_found', 'someone else''s medicine is not skipped');
select pg_temp.check(pg_temp.why('pharmacy.dose_skipped', '{"item_id":"c0000000-0000-0000-0000-0000000000a1","scheduled_at":"x"}', 'k4') = 'dose_slot_invalid', 'bad skip slot');
select pg_temp.check((select count(*) from zad_guard_events where intent ->> 'client_event_id' in ('k2','k3','k4')) = 3, 'skip refusals logged');
select pg_temp.check((select count(*) = 0 from zad_dose_snoozes where user_id = '22222222-2222-2222-2222-222222222222'), 'other user has no snoozes');

select pg_temp.check((select count(*) from zad_guard_events where intent ->> 'client_event_id' in
  ('s2','s2b','s2c','s2d','s4','s5','s7','s7b','s8','s10','s11','s12','s12b','s16','s17','s18',
   'g2','g3','g3b','g4','g5','g7','g8','g9','g11','g13','g14',
   'c2','c4','c5','c6','c7','c8','c9','c10','z4','z4b','z5','z6','z7')) = 40, 'every refusal logged');
select pg_temp.check((select count(*) from zad_events where kind like 'settings.%' or kind like 'goal.%' or kind = 'pharmacy.dose_snoozed') = 20, 'one event per success');
select 'commit_intent_self: all checks passed';
