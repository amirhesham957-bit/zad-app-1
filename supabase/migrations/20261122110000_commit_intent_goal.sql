-- الباب الوحيد: مجال الأهداف والتحديات (ZAD_OR_PLAN م٢.٥، ٢٢/١١). أدوات الأهداف في العقل بتكتب من هنا بس.
--
--   goal.set                {title, metric?, target_value?, deadline_date?, unit?}  هدف جديد أو إعادة تفعيل بنفس العنوان
--                           (agent_goals، unique (user_id, title))؛ unit: money ⇐ progress_kind amount، count ⇐ tasks، غايب = زي ما هو.
--   goal.cancelled          {title}                    الهدف بيبقى cancelled (مش بيتمسح).
--   goal.progress           {goal_id, amount}          «حطيت ٥٠٠ للمصيف»: بيعدّي على zad_goal_add_progress (هدف فلوس نشط لصاحبه بس).
--   goal.challenge_started  {daily_cap, length_days, started_on, currency?, source?}  تحدي التوفير (واحد نشط بس).
--   goal.challenge_stopped  {}                         التحدي النشط بيبقى abandoned، والعدادات بتفضل زي ما هي.
--
-- القيود، نفس validators.ts والـCHECKs: العنوان ٤–٢٠٠، المقياس ≤٢٠٠، الهدف > ٠ و≤ ١٠٠ مليون، التاريخ مفهوم؛ سقف التحدي
-- ١–١٠ مليون، مدته ٧–٩٠ يوم. اتنين تحدي نشطين بيترفضوا هنا بسبب مفهوم (challenge_already_active) قبل ما فهرس
-- zad_savings_challenges_one_active يترمي منه استثناء.
-- التحدي بيتقيّم على السيرفر بس (zad_evaluate_savings_challenges) والعدادات مش بتتكتب من هنا.

create or replace function public.zad_intent_goal(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_goal public.agent_goals%rowtype;
  v_ch public.zad_savings_challenges%rowtype;
  v_title text;
  v_metric text;
  v_target numeric;
  v_deadline date;
  v_unit text;
  v_kind text;
  v_amount numeric;
  v_cap numeric;
  v_len int;
  v_started date;
  v_source text;
  v_res jsonb;
  v_before jsonb;
  v_row_id uuid;
begin
  if p_kind not in ('goal.set', 'goal.cancelled', 'goal.progress', 'goal.challenge_started', 'goal.challenge_stopped') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind in ('goal.set', 'goal.cancelled') then
    v_title := btrim(coalesce(v_payload ->> 'title', ''));
    if length(v_title) < 4 or length(v_title) > 200 then
      return jsonb_build_object('ok', false, 'reason', 'goal_title_invalid');
    end if;
    select * into v_goal from public.agent_goals where user_id = p_uid and title = v_title for update;
  end if;

  if p_kind = 'goal.set' then
    v_metric := nullif(btrim(coalesce(v_payload ->> 'metric', '')), '');
    if length(coalesce(v_metric, '')) > 200 then
      return jsonb_build_object('ok', false, 'reason', 'metric_too_long');
    end if;
    if nullif(v_payload ->> 'target_value', '') is not null then
      begin
        v_target := (v_payload ->> 'target_value')::numeric;
      exception when others then
        v_target := null;
      end;
      if v_target is null or v_target <= 0 or v_target > 100000000 then
        return jsonb_build_object('ok', false, 'reason', 'target_invalid');
      end if;
    end if;
    if nullif(btrim(coalesce(v_payload ->> 'deadline_date', '')), '') is not null then
      begin
        v_deadline := left(btrim(v_payload ->> 'deadline_date'), 10)::date;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'deadline_invalid');
      end;
    end if;
    v_unit := nullif(v_payload ->> 'unit', '');
    if v_unit is not null and v_unit not in ('money', 'count') then
      return jsonb_build_object('ok', false, 'reason', 'unit_invalid');
    end if;
    v_kind := case v_unit when 'money' then 'amount' when 'count' then 'tasks' end;
    insert into public.agent_goals (user_id, title, metric, target_value, deadline_date, status, updated_at, progress_kind)
    values (p_uid, v_title, v_metric, v_target, v_deadline, 'active', now(), coalesce(v_kind, 'tasks'))
    on conflict (user_id, title) do update
      set metric = excluded.metric, target_value = excluded.target_value, deadline_date = excluded.deadline_date,
          status = 'active', updated_at = now(), progress_kind = coalesce(v_kind, public.agent_goals.progress_kind)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', case when v_goal.id is null then null else to_jsonb(v_goal) end,
      'after', (select to_jsonb(g) from public.agent_goals g where g.id = v_row_id));

  elsif p_kind = 'goal.cancelled' then
    if v_goal.id is null then
      return jsonb_build_object('ok', false, 'reason', 'goal_not_found');
    end if;
    update public.agent_goals set status = 'cancelled', updated_at = now() where id = v_goal.id;
    v_row_id := v_goal.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_goal),
      'after', (select to_jsonb(g) from public.agent_goals g where g.id = v_row_id));

  elsif p_kind = 'goal.progress' then
    begin
      v_amount := (v_payload ->> 'amount')::numeric;
    exception when others then
      v_amount := null;
    end;
    if v_amount is null or v_amount = 0 or abs(v_amount) > 100000000 then
      return jsonb_build_object('ok', false, 'reason', 'goal_amount_invalid');
    end if;
    begin
      select * into v_goal from public.agent_goals where id = (v_payload ->> 'goal_id')::uuid and user_id = p_uid;
    exception when others then
      v_goal := null;
    end;
    if v_goal.id is null then
      return jsonb_build_object('ok', false, 'reason', 'goal_not_found');
    end if;
    v_res := public.zad_goal_add_progress(p_uid, v_goal.id, v_amount);
    if (v_res ->> 'ok')::boolean is not true then
      return jsonb_build_object('ok', false, 'reason', case v_res ->> 'reason'
        when 'not_amount' then 'goal_not_amount' when 'unknown_goal' then 'goal_not_found' else 'goal_amount_invalid' end);
    end if;
    v_row_id := v_goal.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_goal),
      'after', (select to_jsonb(g) from public.agent_goals g where g.id = v_row_id));

  elsif p_kind = 'goal.challenge_started' then
    begin
      v_cap := (v_payload ->> 'daily_cap')::numeric;
    exception when others then
      v_cap := null;
    end;
    if v_cap is null or v_cap < 1 or v_cap > 10000000 then
      return jsonb_build_object('ok', false, 'reason', 'challenge_cap_invalid');
    end if;
    begin
      v_len := (v_payload ->> 'length_days')::numeric::int;
      if (v_payload ->> 'length_days')::numeric <> v_len then v_len := null; end if;
    exception when others then
      v_len := null;
    end;
    if v_len is null or v_len not between 7 and 90 then
      return jsonb_build_object('ok', false, 'reason', 'challenge_length_invalid');
    end if;
    begin
      v_started := (v_payload ->> 'started_on')::date;
    exception when others then
      v_started := null;
    end;
    if v_started is null then
      return jsonb_build_object('ok', false, 'reason', 'challenge_date_invalid');
    end if;
    if length(coalesce(v_payload ->> 'currency', '')) > 10 then
      return jsonb_build_object('ok', false, 'reason', 'currency_invalid');
    end if;
    v_source := coalesce(nullif(v_payload ->> 'source', ''), 'chat');
    if v_source not in ('app', 'voice', 'chat', 'telegram') then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end if;
    if exists (select 1 from public.zad_savings_challenges where user_id = p_uid and status = 'active') then
      return jsonb_build_object('ok', false, 'reason', 'challenge_already_active');
    end if;
    insert into public.zad_savings_challenges (user_id, started_on, length_days, daily_cap, currency, source)
    values (p_uid, v_started, v_len, round(v_cap), nullif(v_payload ->> 'currency', ''), v_source)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'after',
      (select to_jsonb(c) from public.zad_savings_challenges c where c.id = v_row_id));

  else
    select * into v_ch from public.zad_savings_challenges where user_id = p_uid and status = 'active' for update;
    if v_ch.id is null then
      return jsonb_build_object('ok', false, 'reason', 'no_active_challenge');
    end if;
    update public.zad_savings_challenges set status = 'abandoned', updated_at = now() where id = v_ch.id;
    v_row_id := v_ch.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_ch),
      'after', (select to_jsonb(c) from public.zad_savings_challenges c where c.id = v_row_id));
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_goal(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
