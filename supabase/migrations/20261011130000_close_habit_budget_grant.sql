-- 20261011130000 — قفل دالتين اتعملوا من غير revoke (نفس غلطة 20260913162000).
--
-- Supabase بيدّي `anon`/`authenticated` صلاحية EXECUTE على أي دالة جديدة في `public`.
-- فحص ما قبل الإطلاق (2026-10-11، get_advisors + has_function_privilege على الحي) لقى:
--
--   _agent_habit_budget_for_user(uuid) — 20260929120000. security definer، ومافيهاش أي
--     تحقق من auth.uid(). أي حد معاه الـanon key (موجود في كل APK)، حتى من غير حساب،
--     يقدر ينادي /rest/v1/rpc/_agent_habit_budget_for_user بأي p_user ويكتب مهمة
--     `habit_budget` في agent_tasks لأي حساب — مهمة = نداء موديل + رسالة للعميل.
--     الدالة بتقف لو فيه مهمة من ٧ أيام، فالسقف مرة في الأسبوع لكل حساب، والمحتوى بيروح
--     للعميل نفسه (مفيش تسريب)، بس ده سبام وتكلفة على حساب أي حد.
--   zad_sync_pay_day_from_cycle() — دالة تريجر (20261010130000). نداها مباشرة بيقع
--     («trigger functions can only be called as triggers») والتريجر نفسه مابيتحققش من
--     EXECUTE وقت ما بيشتغل، فالقفل للنضافة بس وعشان التنبيه يختفي.
--
-- كل أخوات الأولى (`_agent_*_for_user`) على الحي صلاحيتها postgres + service_role بس.
-- محدش بيناديها غير agent_proactive_scan (security definer، مالكها postgres)، فالقفل
-- مابيكسرش حاجة.

revoke execute on function public._agent_habit_budget_for_user(uuid) from public, anon, authenticated;
grant execute on function public._agent_habit_budget_for_user(uuid) to service_role;

revoke execute on function public.zad_sync_pay_day_from_cycle() from public, anon, authenticated;
grant execute on function public.zad_sync_pay_day_from_cycle() to service_role;
