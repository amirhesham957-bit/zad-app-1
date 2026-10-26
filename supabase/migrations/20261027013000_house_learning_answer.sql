-- «صح / مش صح» تحت «اتعلمت إن» (ZAD_PLAN ٥.٢، الشريحة التانية بعد 20261027001500_house_learnings).
--
-- بوابة المرحلة ٥: «ملاحظة واحدة في الأسبوع على الأقل العميل قال عليها صح، وصفر ملاحظات اتقالت غلط مرتين».
-- النمط كان بيتقال في الملخص الأسبوعي ومفيش طريقة يتسجل بيها الجواب. دلوقتي:
--   • zad_house_learnings.task_id = مهمة الملخص اللي قالته؛ رسالة الملخص بتوصل تليجرام بـdismiss_task_id، فالبوت
--     بيلاقي النمط بيه ويحط زرارين تحت الرسالة.
--   • zad_house_learning_answer_service: الملكية من الصف، جواب واحد بس. «صح» = ملاحظة في zad_memory (scope
--     house_pattern) عشان العقل يعرفها؛ «مش صح» = النمط مايتقالش تاني (zad_house_pattern بيتخطاه).
--
-- جسم الملخص = 20261027001500، والجديد بس returning id ⇐ task_id.

alter table public.zad_house_learnings
  add column if not exists task_id uuid references public.agent_tasks (id) on delete set null;
create index if not exists zad_house_learnings_task on public.zad_house_learnings (task_id) where task_id is not null;

create or replace function public.zad_house_learning_answer_service(p_user uuid, p_learning uuid, p_yes boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_row public.zad_house_learnings%rowtype;
begin
  select * into v_row from public.zad_house_learnings where id = p_learning and user_id = p_user for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_row.answer is not null then
    return jsonb_build_object('ok', true, 'already', true, 'answer', v_row.answer);
  end if;
  update public.zad_house_learnings
     set answer = case when p_yes then 'yes' else 'no' end, answered_at = now()
   where id = p_learning;
  if p_yes and not exists (
    select 1 from public.zad_memory m
     where m.user_id = p_user and m.scope = 'house_pattern' and m.note = v_row.note and m.superseded_by is null
  ) then
    insert into public.zad_memory (user_id, scope, note, confidence, evidence_count)
    values (p_user, 'house_pattern', v_row.note, 0.9, coalesce((v_row.evidence ->> 'times')::int, 1));
  end if;
  return jsonb_build_object('ok', true, 'answer', case when p_yes then 'yes' else 'no' end);
end
$fn$;

revoke all on function public.zad_house_learning_answer_service(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.zad_house_learning_answer_service(uuid, uuid, boolean) to service_role;

create or replace function public._agent_home_weekly_digest_for_user(p_user uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_spent numeric;
  v_last numeric;
  v_low_stock int;
  v_due_soon int;
  v_meds_low int;
  v_learned jsonb;
  v_task uuid;
begin
  if coalesce(nullif(trim(p_user::text), ''), '') is null then
    return;
  end if;

  -- أسبوعي فعلاً: الماسح بيعدّي كل ساعة، وقيد التكرار يومي.
  if exists (
    select 1 from public.agent_tasks t
    where t.user_id = p_user and t.kind = 'home_weekly_digest'
      and t.created_at > now() - interval '6 days'
  ) then
    return;
  end if;

  -- صرف الأسبوع الحالي vs الأسبوع اللي فاته
  select coalesce(sum(amount), 0) into v_spent
    from public.zad_transactions
    where user_id = p_user and is_expense is true
      and created_at >= now() - interval '7 days';
  select coalesce(sum(amount), 0) into v_last
    from public.zad_transactions
    where user_id = p_user and is_expense is true
      and created_at >= now() - interval '14 days'
      and created_at < now() - interval '7 days';

  select count(*) into v_low_stock
    from public.zad_inventory
    where user_id = p_user and quantity <= coalesce(low_stock_threshold, 1);

  select count(*) into v_due_soon from (
    select 1 from public.zad_subscriptions s
      where s.user_id = p_user and s.is_active is true
        and (public.zad_subscription_next_renewal(s.renewal_date, s.due_day, s.billing_cycle, (now() at time zone 'utc')::date)
             - (now() at time zone 'utc')::date) between 0 and 7
    union all
    select 1 from public.zad_obligations o
      where o.user_id = p_user and o.active is true and o.due_day is not null
        and ((o.due_day - extract(day from now() at time zone 'utc')::int + 31) % 31) <= 7
  ) d;

  select count(*) into v_meds_low
    from public.zad_pharmacy_items
    where user_id = p_user and remaining_quantity <= coalesce(daily_dose_count, 1) * 5;

  -- ٥.٢: نمط واحد من حركات البيت، لو فيه نمط بيعدّي البوابة.
  v_learned := public.zad_house_pattern(p_user);

  -- مفيش حاجة تستاهل ملخص؟ متبعتش حاجة خالص — مينفعش نختلق محتوى
  if v_spent = 0 and v_low_stock = 0 and v_due_soon = 0 and v_meds_low = 0 and v_learned is null then
    return;
  end if;

  insert into public.agent_tasks (user_id, kind, task_description, scheduled_for)
  values (
    p_user,
    'home_weekly_digest',
    format(
      $t$[ملخص البيت الأسبوعي]
• مصروف الأسبوع: %s (الأسبوع اللي فات: %s%s)
• أصناف قربت تخلص من المخزون: %s
• مستحقات خلال ٧ أيام: %s
• أدوية قربت: %s%s

حلّل الأرقام دي للعميل في جملتين، وقول أهم حاجة واحدة يعملها الأسبوع الجاي.$t$,
      round(v_spent)::text,
      round(v_last)::text,
      case when v_last > 0
        then '، ' || case when v_spent > v_last then 'زادت' else 'قلّت' end
             || ' ' || abs(round(v_spent - v_last))::text else '' end,
      v_low_stock, v_due_soon, v_meds_low,
      case when v_learned is null then ''
        else E'\n• اتعلمت إن (من حركاتك المسجلة): ' || (v_learned ->> 'note')
             || ' قوله بالرقم ده واسأله في الآخر «صح؟».' end
    ),
    now()
  )
  on conflict (user_id, kind, ((created_at at time zone 'UTC')::date))
    where kind in ('spending_ahead','med_followup','bill_reminder','warranty_reminder','home_weekly_digest')
  do nothing
  returning id into v_task;

  -- اتسجل إنه اتقال بس لو الملخص اتكتب فعلاً.
  if v_task is not null and v_learned is not null then
    insert into public.zad_house_learnings (user_id, key, note, evidence, said_at, task_id)
    values (p_user, v_learned ->> 'key', v_learned ->> 'note', v_learned - 'note', now(), v_task)
    on conflict (user_id, key) do update
      set note = excluded.note, evidence = excluded.evidence, said_at = excluded.said_at, task_id = excluded.task_id
      where public.zad_house_learnings.answer is null;
  end if;
exception
  when unique_violation then
    return;
  when others then
    raise;
end;
$function$;

revoke execute on function public._agent_home_weekly_digest_for_user(uuid) from public, anon, authenticated;
grant execute on function public._agent_home_weekly_digest_for_user(uuid) to service_role;
