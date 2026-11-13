-- ZAD_PLAN ١٠.٢(د): أهداف على أيام — «وفّرلي ٢٠٠٠ قبل رمضان» تتقسم خطوات، ويتابعها، ويرجع يسأل.
--
-- اتقاس ١٣/١١ على الحي (٤ أهداف نشطة عند ٤ عملا):
--   - الهدفين اللي من التطبيق (zad_seed_life_goal) ليهم متابعة أسبوعية شغالة (goal_review، اتنفّذت ومجدولة تاني).
--   - الهدفين اللي من الشات (set_life_goal، «ميزانية طلعات الشتا ٤٠٠» و«سقف الوايت فرايداي ٥٠٠٠») **مالهمش متابعة
--     خالص**: الأداة بتقول للموديل «فكّكه لمهام بـschedule_task»، والموديل ماعملش، فالهدف اتنسى.
--   - التقدم (trg_agent_goal_progress) بيزوّد current_value بواحد مع كل مهمة مربوطة بتخلص — صح لهدف «١٢ متابعة
--     أسبوعية»، وغلط لهدف فلوس: متابعة أسبوعية كانت هتزوّد «ريال» للـ٤٠٠. ومفيش طريقة يتسجل بيها «حطيت ٥٠٠».
--
-- الحل:
--   - progress_kind: tasks (زي ما هو، كل مهمة منجزة = ١) أو amount (فلوس: بيتحرك بس لما العميل يقول حط كام).
--   - zad_goal_ensure_review: المتابعة الأسبوعية لأي هدف، من أي باب — نفس نص zad_seed_life_goal، والفلوس بتسأل
--     «حطيت كام؟». بتتنادى من set_life_goal، وبالمرة على الأهداف الحية اللي مالهاش متابعة دلوقتي.
--   - zad_goal_add_progress: «حطيت ٥٠٠ للمصيف» ⇒ current_value للهدف ده بس (صاحبه، نشط، amount).

alter table public.agent_goals
  add column if not exists progress_kind text not null default 'tasks';
alter table public.agent_goals drop constraint if exists agent_goals_progress_kind_check;
alter table public.agent_goals
  add constraint agent_goals_progress_kind_check check (progress_kind in ('tasks', 'amount'));

comment on column public.agent_goals.progress_kind is
  'tasks = التقدم = عدد المهام المربوطة اللي خلصت (أهداف التطبيق: عدد متابعات). amount = مبلغ: بيتحرك من zad_goal_add_progress بس.';

-- التقدم التلقائي للأهداف اللي بتتعد بالمهام بس.
create or replace function public.agent_goal_touch_progress()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.goal_id is not null and new.status = 'done' then
    update agent_goals
      set current_value = case when progress_kind = 'tasks' then current_value + 1 else current_value end,
          last_reviewed_at = now(),
          updated_at = now()
      where id = new.goal_id and status = 'active';
  end if;
  return null;
end;
$$;

/** المتابعة الأسبوعية لهدف (لو مفيش واحدة مستنية أو شغالة). نفس نص zad_seed_life_goal، والفلوس بتسأل حط كام. */
create or replace function public.zad_goal_ensure_review(p_user uuid, p_goal uuid)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_goal public.agent_goals%rowtype;
  v_task uuid;
begin
  select * into v_goal from public.agent_goals where id = p_goal and user_id = p_user and status = 'active';
  if v_goal.id is null then
    return null;
  end if;
  select id into v_task from public.agent_tasks
   where user_id = p_user and goal_id = p_goal and kind = 'goal_review' and status in ('pending', 'running')
   limit 1;
  if v_task is not null then
    return v_task;
  end if;
  insert into public.agent_tasks (user_id, kind, goal_id, recurrence, scheduled_for, task_description)
  values (
    p_user, 'goal_review', p_goal, 'weekly', now() + interval '7 days',
    case when v_goal.progress_kind = 'amount' then
      format(
        'متابعة أسبوعية لهدف العميل «%s» (المبلغ: %s، اتحط منه %s لحد دلوقتي%s). اسأله في جملة خفيفة حط كام الأسبوع ده '
        '(لو قال رقم سجّله بـadd_goal_progress)، وقوله خطوة الأسبوع الجاي من step_per_week في life_goals لو موجودة. '
        'من غير لوم، ومتسجّلش أي رقم هو ماقالوش.',
        v_goal.title, coalesce(v_goal.target_value::text, '؟'), v_goal.current_value::text,
        coalesce('، والميعاد ' || v_goal.deadline_date::text, '')
      )
    else
      format(
        'متابعة أسبوعية لهدف العميل «%s»%s. بص على بياناته الفعلية آخر أسبوع (المصاريف، الميزانية، '
        'الديون، المخزون — اللي يخص الهدف) واكتب له في جملتين: هو ماشي إزاي ناحية الهدف، وأهم خطوة '
        'واحدة يعملها الأسبوع الجاي. متسجّلش ولا تعدّل أي بيانات في المتابعة دي.',
        v_goal.title, coalesce(' (المقياس: ' || v_goal.metric || ')', '')
      )
    end
  )
  returning id into v_task;
  return v_task;
end
$function$;

/** «حطيت ٥٠٠ للمصيف»: مبلغ (سالب = شال منه) على هدف فلوس نشط لصاحبه. التقدم مابيقلش عن صفر. */
create or replace function public.zad_goal_add_progress(p_user uuid, p_goal uuid, p_amount numeric)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_goal public.agent_goals%rowtype;
begin
  if p_amount is null or p_amount = 0 then
    return jsonb_build_object('ok', false, 'reason', 'no_amount');
  end if;
  select * into v_goal from public.agent_goals
   where id = p_goal and user_id = p_user and status = 'active' for update;
  if v_goal.id is null then
    return jsonb_build_object('ok', false, 'reason', 'unknown_goal');
  end if;
  if v_goal.progress_kind <> 'amount' then
    return jsonb_build_object('ok', false, 'reason', 'not_amount');
  end if;
  update public.agent_goals
     set current_value = greatest(0, current_value + p_amount), updated_at = now()
   where id = p_goal
  returning * into v_goal;
  return jsonb_build_object('ok', true, 'current_value', v_goal.current_value, 'target_value', v_goal.target_value);
end
$function$;

revoke all on function public.zad_goal_ensure_review(uuid, uuid) from public, anon, authenticated;
revoke all on function public.zad_goal_add_progress(uuid, uuid, numeric) from public, anon, authenticated;
grant execute on function public.zad_goal_ensure_review(uuid, uuid) to service_role;
grant execute on function public.zad_goal_add_progress(uuid, uuid, numeric) to service_role;

-- الأهداف الحية من الشات: مبلغ من غير مقياس (أهداف التطبيق دايماً ليها مقياس «N متابعة»). اتقاس ١٣/١١: اتنين بالظبط
-- (٤٠٠ و٥٠٠٠)، ومحدش منهم اتحرك (current_value = 0) فمفيش تقدم غلط يتصلح.
update public.agent_goals
   set progress_kind = 'amount'
 where status = 'active' and metric is null and target_value >= 50 and progress_kind = 'tasks';

-- وكل هدف حي مالوش متابعة دلوقتي ياخد واحدة (بعد أسبوع من النهارده، زي هدف جديد).
select public.zad_goal_ensure_review(g.user_id, g.id)
  from public.agent_goals g
 where g.status = 'active'
   and not exists (
     select 1 from public.agent_tasks t
      where t.goal_id = g.id and t.kind = 'goal_review' and t.status in ('pending', 'running'));
