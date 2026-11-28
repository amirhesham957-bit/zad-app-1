-- P1.6b (العيلة). بعد: events_ledger_scaffold، events_ledger، household_traits، member_facts، events_trace_id،
-- family_buttons_scaffold، 20261129050000. بيثبت إن أزرار العيلة بتعدي من zad_commit_my_intent بصفة auth.uid() بس،
-- وإن الباب (security definer، من غير RLS) لسه بيرفض اللي RLS والتريجرات كانت بترفضه: عيلة غيري، مكافأة/سقف/تحدي لغير أدمن،
-- أهداف العيلة للقاصر.
\set ON_ERROR_STOP on

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin if ok is not true then raise exception 'FAILED: %', msg; end if; end $$;

-- أب (admin)، أم (member)، بنت قاصر (child)، وعيلة تانية فيها غريب (admin).
insert into auth.users values ('aaaaaaaa-0000-0000-0000-00000000000a'), ('aaaaaaaa-0000-0000-0000-00000000000b'),
  ('aaaaaaaa-0000-0000-0000-00000000000c'), ('aaaaaaaa-0000-0000-0000-00000000000d');
insert into public.zad_users (id, name) values ('aaaaaaaa-0000-0000-0000-00000000000a', 'بابا'), ('aaaaaaaa-0000-0000-0000-00000000000b', 'ماما'),
  ('aaaaaaaa-0000-0000-0000-00000000000c', 'سارة'), ('aaaaaaaa-0000-0000-0000-00000000000d', 'غريب');
insert into public.family_groups (id) values ('f0000000-0000-0000-0000-00000000000f'), ('f0000000-0000-0000-0000-0000000000a0');
insert into public.family_members (id, family_id, user_id, role, alias) values
  ('a1000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-00000000000f', 'aaaaaaaa-0000-0000-0000-00000000000a', 'admin', 'بابا'),
  ('a1000000-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-00000000000f', 'aaaaaaaa-0000-0000-0000-00000000000b', 'member', 'ماما'),
  ('a1000000-0000-0000-0000-000000000003', 'f0000000-0000-0000-0000-00000000000f', 'aaaaaaaa-0000-0000-0000-00000000000c', 'child', 'سارة'),
  ('a1000000-0000-0000-0000-000000000004', 'f0000000-0000-0000-0000-0000000000a0', 'aaaaaaaa-0000-0000-0000-00000000000d', 'admin', 'غريب');

-- ── الأب (admin)
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"aaaaaaaa-0000-0000-0000-00000000000a"}', false);

-- ١) مهمة بمكافأة
select pg_temp.check((public.zad_commit_my_intent('family.chore_added', 'fam:1',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","assigned_to":"a1000000-0000-0000-0000-000000000003","title":"ترتيب الأوضة","reward":15,"minutes":20}',
  null, 'trace-fam-0001') ->> 'ok')::boolean, 'chore added');
select pg_temp.check((select reward_amount = 15 and minutes = 20 and title = 'ترتيب الأوضة' and not is_completed from public.family_chores), 'chore row written');
select pg_temp.check((select trace_id from public.zad_events where client_event_id = 'fam:1') = 'trace-fam-0001', 'trace on ledger');
select pg_temp.check((select source from public.zad_events where client_event_id = 'fam:1') = 'manual', 'source manual');
select pg_temp.check((select count(*) from public.family_chores) = 1, 'one chore');
select pg_temp.check((public.zad_commit_my_intent('family.chore_added', 'fam:1',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","assigned_to":"a1000000-0000-0000-0000-000000000003","title":"ترتيب الأوضة"}') ->> 'duplicate')::boolean, 'replay is duplicate');
select pg_temp.check((select count(*) from public.family_chores) = 1, 'replay wrote nothing');
select pg_temp.check(public.zad_commit_my_intent('family.chore_added', 'fam:2',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","assigned_to":"a1000000-0000-0000-0000-000000000004","title":"x"}') ->> 'reason' = 'assignee_not_in_family', 'assignee from another family refused');
select pg_temp.check(public.zad_commit_my_intent('family.chore_added', 'fam:3',
  '{"family_id":"f0000000-0000-0000-0000-0000000000a0","assigned_to":"a1000000-0000-0000-0000-000000000004","title":"x"}') ->> 'reason' = 'not_in_family', 'foreign family refused');
select pg_temp.check(public.zad_commit_my_intent('family.chore_added', 'fam:4',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","assigned_to":"a1000000-0000-0000-0000-000000000003","title":"  "}') ->> 'reason' = 'title_invalid', 'blank title refused');
select pg_temp.check(public.zad_commit_my_intent('family.chore_added', 'fam:5',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","assigned_to":"a1000000-0000-0000-0000-000000000003","title":"x","minutes":900}') ->> 'reason' = 'minutes_invalid', 'minutes out of range');

-- ٢) سقوف الصرف: أدمن بس
select pg_temp.check((public.zad_commit_my_intent('family.spend_limits_set', 'fam:6',
  '{"member_id":"a1000000-0000-0000-0000-000000000003","daily":50,"weekly":null}') ->> 'ok')::boolean, 'limits set, weekly cleared with null');
select pg_temp.check((select daily_limit = 50 and weekly_limit is null from public.family_members where id = 'a1000000-0000-0000-0000-000000000003'), 'limits written');
select pg_temp.check((public.zad_commit_my_intent('family.spend_limits_set', 'fam:6b',
  '{"member_id":"a1000000-0000-0000-0000-000000000003","daily":50}') ->> 'reason') = 'bad_payload', 'both keys required');
select pg_temp.check((public.zad_commit_my_intent('family.spend_limits_set', 'fam:7',
  '{"member_id":"a1000000-0000-0000-0000-000000000004","daily":1,"weekly":1}') ->> 'reason') = 'member_not_found', 'other family member reads as missing');
select pg_temp.check((public.zad_commit_my_intent('family.spend_limits_set', 'fam:8',
  '{"member_id":"a1000000-0000-0000-0000-000000000003","daily":-5,"weekly":1}') ->> 'reason') = 'limit_invalid', 'negative limit refused');

-- ٣) تفضيلات المهام: الفرد لنفسه أو الأدمن لأي فرد، ومرتين = تحديث
select pg_temp.check((public.zad_commit_my_intent('family.chore_pref_set', 'fam:9',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","member_id":"a1000000-0000-0000-0000-000000000003","minutes_per_week":90,"dislikes":["المواعين"],"likes":[]}') ->> 'ok')::boolean, 'admin sets a member preference');
select pg_temp.check((public.zad_commit_my_intent('family.chore_pref_set', 'fam:10',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","member_id":"a1000000-0000-0000-0000-000000000003","minutes_per_week":60,"dislikes":["المواعين","الكنس"],"likes":["الزرع"]}') ->> 'ok')::boolean, 'second save updates');
select pg_temp.check((select count(*) = 1 and max(minutes_per_week) = 60 and max(cardinality(dislikes)) = 2 from public.family_chore_preferences), 'one row, updated');
select pg_temp.check(public.zad_commit_my_intent('family.chore_pref_set', 'fam:11',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","member_id":"a1000000-0000-0000-0000-000000000003","minutes_per_week":5000,"dislikes":[],"likes":[]}') ->> 'reason' = 'minutes_invalid', 'minutes cap');
select pg_temp.check(public.zad_commit_my_intent('family.chore_pref_set', 'fam:12',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","member_id":"a1000000-0000-0000-0000-000000000003","minutes_per_week":5,"dislikes":"x","likes":[]}') ->> 'reason' = 'list_invalid', 'list shape');

-- ٤) هدف العيلة
select pg_temp.check((public.zad_commit_my_intent('family.goal_added', 'fam:13',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","target_amount":2000,"month_year":"2026-11","reward_suggestion":"خروجة"}') ->> 'ok')::boolean, 'goal added');
select pg_temp.check((select target_amount = 2000 and current_amount = 0 and month_year = '2026-11' from public.family_goals), 'goal row');
select pg_temp.check(public.zad_commit_my_intent('family.goal_added', 'fam:14',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","target_amount":2000,"month_year":"2026-13"}') ->> 'reason' = 'month_invalid', 'bad month');
select pg_temp.check(public.zad_commit_my_intent('family.goal_added', 'fam:15',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","target_amount":0,"month_year":"2026-11"}') ->> 'reason' = 'amount_not_positive', 'zero target');

-- ٥) صندوق تجميع، ومساهمتين مع بعض بتتجمع على السيرفر
select pg_temp.check((public.zad_commit_my_intent('family.fund_added', 'fam:16',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","name":"عيد","target_amount":1000}') ->> 'ok')::boolean, 'fund added');
select pg_temp.check((select created_by = 'aaaaaaaa-0000-0000-0000-00000000000a' and current_amount = 0 from public.sinking_funds), 'fund created_by is the caller');
select pg_temp.check(public.zad_commit_my_intent('family.fund_added', 'fam:17',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","name":"عيد","target_amount":1000,"event_id":"99999999-9999-9999-9999-999999999999"}') ->> 'reason' = 'event_not_found', 'unknown event refused');
select pg_temp.check((public.zad_commit_my_intent('family.fund_contributed', 'fam:18',
  jsonb_build_object('fund_id', (select id from public.sinking_funds), 'amount', 100)) ->> 'ok')::boolean, 'contribution 1');
select pg_temp.check((public.zad_commit_my_intent('family.fund_contributed', 'fam:19',
  jsonb_build_object('fund_id', (select id from public.sinking_funds), 'amount', 50)) ->> 'ok')::boolean, 'contribution 2');
select pg_temp.check((select current_amount = 150 from public.sinking_funds), 'contributions add up on the server');
select pg_temp.check(public.zad_commit_my_intent('family.fund_contributed', 'fam:20',
  jsonb_build_object('fund_id', (select id from public.sinking_funds), 'amount', 0)) ->> 'reason' = 'amount_not_positive', 'zero contribution refused');
select pg_temp.check(public.zad_commit_my_intent('family.fund_contributed', 'fam:21',
  '{"fund_id":"not-a-uuid","amount":5}') ->> 'reason' = 'fund_not_found', 'bad fund id');

-- ٦) تحدي
select pg_temp.check((public.zad_commit_my_intent('family.challenge_added', 'fam:22',
  '{"challenge_type":"weekly","family_id":"f0000000-0000-0000-0000-00000000000f","title":"تحدي العيد","target_amount":500,"reward_amount":25,"start_date":"2026-11-28T00:00:00Z","end_date":"2026-12-05T00:00:00Z","season_key":"eid","badge":"x"}') ->> 'ok')::boolean, 'challenge added');
select pg_temp.check((select reward_amount = 25 and is_active and season_key = 'eid' and badge = 'x' from public.family_financial_challenges), 'challenge row');
select pg_temp.check(public.zad_commit_my_intent('family.challenge_added', 'fam:23',
  '{"challenge_type":"weekly","family_id":"f0000000-0000-0000-0000-00000000000f","title":"t","target_amount":5,"start_date":"2026-12-05T00:00:00Z","end_date":"2026-11-28T00:00:00Z"}') ->> 'reason' = 'dates_invalid', 'end before start');

-- ── الأم (member): مكافأة وسقف وتحدي بمكافأة = لأ، ومهمة وتحدي من غير مكافأة = أيوه
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"aaaaaaaa-0000-0000-0000-00000000000b"}', false);
select pg_temp.check(public.zad_commit_my_intent('family.chore_added', 'fam:24',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","assigned_to":"a1000000-0000-0000-0000-000000000002","title":"x","reward":10}') ->> 'reason' = 'only_admins_set_rewards', 'member cannot set a chore reward');
select pg_temp.check((public.zad_commit_my_intent('family.chore_added', 'fam:25',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","assigned_to":"a1000000-0000-0000-0000-000000000002","title":"x"}') ->> 'ok')::boolean, 'member adds an unrewarded chore');
select pg_temp.check(public.zad_commit_my_intent('family.spend_limits_set', 'fam:26',
  '{"member_id":"a1000000-0000-0000-0000-000000000003","daily":999999,"weekly":999999}') ->> 'reason' = 'admins_only', 'member cannot set limits');
select pg_temp.check((select daily_limit = 50 from public.family_members where id = 'a1000000-0000-0000-0000-000000000003'), 'limit untouched');
select pg_temp.check(public.zad_commit_my_intent('family.challenge_added', 'fam:27',
  '{"challenge_type":"weekly","family_id":"f0000000-0000-0000-0000-00000000000f","title":"t","target_amount":5,"reward_amount":5,"start_date":"2026-11-28T00:00:00Z","end_date":"2026-12-05T00:00:00Z"}') ->> 'reason' = 'only_admins_set_rewards', 'member cannot set a challenge reward');
select pg_temp.check((public.zad_commit_my_intent('family.challenge_added', 'fam:28',
  '{"challenge_type":"weekly","family_id":"f0000000-0000-0000-0000-00000000000f","title":"t","target_amount":5,"start_date":"2026-11-28T00:00:00Z","end_date":"2026-12-05T00:00:00Z"}') ->> 'ok')::boolean, 'member adds a challenge without reward');
select pg_temp.check(public.zad_commit_my_intent('family.chore_pref_set', 'fam:29',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","member_id":"a1000000-0000-0000-0000-000000000003","minutes_per_week":1,"dislikes":[],"likes":[]}') ->> 'reason' = 'not_allowed', 'member cannot set another member preference');
select pg_temp.check((public.zad_commit_my_intent('family.chore_pref_set', 'fam:30',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","member_id":"a1000000-0000-0000-0000-000000000002","minutes_per_week":30,"dislikes":[],"likes":[]}') ->> 'ok')::boolean, 'member sets their own preference');
select pg_temp.check((public.zad_commit_my_intent('family.goal_added', 'fam:31',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","target_amount":10,"month_year":"2026-12"}') ->> 'ok')::boolean, 'adult member may add a family goal (as RLS allowed)');

-- ── البنت القاصر: أهداف العيلة مقفولة (minor_blind_budget)، ولسه بتحط تفضيلاتها هي
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"aaaaaaaa-0000-0000-0000-00000000000c"}', false);
select pg_temp.check(public.zad_commit_my_intent('family.goal_added', 'fam:32',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","target_amount":10,"month_year":"2026-12"}') ->> 'reason' = 'minor_no_budget', 'child refused family goals');
select pg_temp.check((select count(*) = 2 from public.family_goals), 'child wrote no goal');
select pg_temp.check((public.zad_commit_my_intent('family.chore_pref_set', 'fam:33',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","member_id":"a1000000-0000-0000-0000-000000000003","minutes_per_week":45,"dislikes":[],"likes":[]}') ->> 'ok')::boolean, 'child sets her own preference');
select pg_temp.check(public.zad_commit_my_intent('family.spend_limits_set', 'fam:34',
  '{"member_id":"a1000000-0000-0000-0000-000000000003","daily":null,"weekly":null}') ->> 'reason' = 'admins_only', 'child cannot lift her own limits');
select pg_temp.check(public.zad_commit_my_intent('family.chore_added', 'fam:35',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","assigned_to":"a1000000-0000-0000-0000-000000000003","title":"x","reward":5}') ->> 'reason' = 'only_admins_set_rewards', 'child cannot set a reward');

-- ── غريب (عيلة تانية): مالوش دعوة بعيلتنا
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"aaaaaaaa-0000-0000-0000-00000000000d"}', false);
select pg_temp.check(public.zad_commit_my_intent('family.fund_contributed', 'fam:36',
  jsonb_build_object('fund_id', (select id from public.sinking_funds), 'amount', 1000)) ->> 'reason' = 'fund_not_found', 'stranger cannot touch our fund');
select pg_temp.check((select current_amount = 150 from public.sinking_funds), 'fund unchanged by stranger');
select pg_temp.check(public.zad_commit_my_intent('family.goal_added', 'fam:37',
  '{"family_id":"f0000000-0000-0000-0000-00000000000f","target_amount":10,"month_year":"2026-12"}') ->> 'reason' = 'not_in_family', 'stranger cannot add our goal');

-- ── من غير JWT، ونوع مش من الغلاف
select set_config('request.jwt.claims', '{}', false);
select pg_temp.check(public.zad_commit_my_intent('family.goal_added', 'fam:38', '{}') ->> 'reason' = 'not_authenticated', 'no JWT refused');
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"aaaaaaaa-0000-0000-0000-00000000000a"}', false);
select pg_temp.check(public.zad_commit_my_intent('family.chore_completed', 'fam:39', '{}') ->> 'reason' = 'unknown_kind', 'kind not in the wrapper');

select 'family_buttons_test ok';
