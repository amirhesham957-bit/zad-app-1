-- م٢.٥ e2e (الإعدادات والأهداف وتأجيل الجرعة): الدوال اللي أدوات العقل بتناديها حوالين الباب. شكل مختصر، Postgres محلي بس.
\set ON_ERROR_STOP on
create or replace function public.zad_budget_state(p_user uuid, p_tz text default null) returns jsonb language sql as $$
  select jsonb_build_object('daily_allowance_left', 200, 'currency', 'EGP', 'available', 1000) $$;
create or replace function public.zad_goal_ensure_review(p_user uuid, p_goal uuid) returns uuid language sql as $$ select gen_random_uuid() $$;
grant execute on all functions in schema public to service_role;
