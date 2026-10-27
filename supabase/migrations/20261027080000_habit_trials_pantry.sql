-- حلقة المبادرة (ZAD_PLAN ٥.٤، الشريحة التانية): سلوكين من المخزن مش من المعاملات، والتطبيق قناة زي تليجرام.
--
--   • waste_less — zad_waste_log (الترايجر بيكتب سطر لما صنف منتهي الصلاحية يتمسح أو يتصفّر): ٣ حاجات أو أكتر
--     اترمت في ٢٨ يوم ⇐ «الطازة على قد أسبوع، واللي قرب يخلص صلاحيته يتاكل الأول».
--   • fewer_stockouts — zad_inventory_observations بكمية صفر: ٣ مرات أو أكتر (صنف في يوم) في ٢٨ يوم ⇐ «أول ما صنف
--     أساسي يقرب يخلص يدخل القايمة».
--   الاتنين عدد مش فلوس، فالأساس والنتيجة «في الأسبوع» بالعدد، والكلام بيقول «حاجات» مش جنيه.
--
-- والترتيب بين السلوكيات بقى بقد إيه البيت فوق الحد (المرات ÷ الحد)، مش بالفلوس: الفلوس والعدد مايتقارنوش.
--
-- القناة: تليجرام أو الموبايل. التطبيق بقى بيعرض زرارين التجربة على الإشعار نفسه (zad-brain بيبعتها data-only
-- بمعرّف التجربة ومرحلتها)، والضغطة بتنادي zad_habit_trial_answer بجلسة العميل — الملكية من auth.uid().

alter table public.zad_habit_trials drop constraint if exists zad_habit_trials_kind_check;
alter table public.zad_habit_trials add constraint zad_habit_trials_kind_check
  check (kind in ('eat_out_less', 'one_grocery_trip', 'waste_less', 'fewer_stockouts'));

/** بيتقاس بالفلوس ولا بالعدد. */
create or replace function public.zad_habit_trial_is_money(p_kind text)
returns boolean
language sql
immutable
as $fn$
  select p_kind in ('eat_out_less', 'one_grocery_trip')
$fn$;

/**
 * المجموع و«المرات» بين [p_from] و[p_to]. فلوس: مجموع [p_category]، والمرات معاملات (أكل برّه) أو أيام (بقالة).
 * عدد: المجموع = المرات = سطور الهالك، أو (صنف، يوم) خلص فيه.
 */
create or replace function public.zad_habit_trial_measure(
  p_user uuid, p_kind text, p_category text, p_tz text, p_from timestamptz, p_to timestamptz
)
returns table (total numeric, times int)
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
begin
  if p_kind = 'waste_less' then
    return query
      select count(*)::numeric, count(*)::int
        from public.zad_waste_log w
       where w.user_id = p_user and w.logged_at >= p_from and w.logged_at < p_to;
  elsif p_kind = 'fewer_stockouts' then
    return query
      select count(*)::numeric, count(*)::int
        from (select distinct o.item_name, (o.observed_at at time zone p_tz)::date
                from public.zad_inventory_observations o
               where o.user_id = p_user and o.qty <= 0
                 and o.observed_at >= p_from and o.observed_at < p_to) s;
  else
    return query
      select coalesce(sum(t.amount), 0)::numeric,
             case when p_kind = 'one_grocery_trip'
                  then count(distinct (t.created_at at time zone p_tz)::date)::int
                  else count(*)::int end
        from public.zad_transactions t
       where t.user_id = p_user and t.is_expense is true and t.category = p_category
         and t.amount > 0 and t.created_at >= p_from and t.created_at < p_to;
  end if;
end
$fn$;

revoke all on function public.zad_habit_trial_measure(uuid, text, text, text, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.zad_habit_trial_measure(uuid, text, text, text, timestamptz, timestamptz) to service_role;

create or replace function public.zad_habit_trial_behaviour(p_kind text)
returns text
language sql
immutable
as $fn$
  select case p_kind
    when 'eat_out_less' then 'أكل برّه أو دليفري مرة واحدة بس في الأسبوع'
    when 'one_grocery_trip' then 'مشوار بقالة واحد في الأسبوع بقايمة، بدل كذا مرة'
    when 'waste_less' then 'الطازة تتشري على قد أسبوع، واللي قرب يخلص صلاحيته يتاكل الأول'
    when 'fewer_stockouts' then 'أول ما صنف أساسي يقرب يخلص يدخل القايمة على طول'
  end
$fn$;

/** «600 EGP» للفلوس، «٣ حاجات اترمت» / «٣ مرات صنف خلص» للعدد — في الأسبوع بيتقال بعدها. */
create or replace function public.zad_habit_trial_amount(p_kind text, p_value numeric, p_currency text)
returns text
language sql
immutable
as $fn$
  select case
    when public.zad_habit_trial_is_money(p_kind) then round(p_value, 2) || coalesce(' ' || p_currency, '')
    when p_kind = 'waste_less' then trim_scale(round(p_value, 1)) || ' حاجة اترمت'
    else trim_scale(round(p_value, 1)) || ' مرة صنف خلص'
  end
$fn$;

create or replace function public.zad_habit_trial_times_label(p_kind text, p_times int, p_weeks int)
returns text
language sql
immutable
as $fn$
  select p_times || case p_kind
           when 'one_grocery_trip' then ' يوم'
           when 'waste_less' then ' حاجة اترمت'
           when 'fewer_stockouts' then ' مرة صنف خلص'
           else ' مرة' end
         || case p_weeks when 2 then ' في أسبوعين' when 4 then ' في ٤ أسابيع' else ' في ' || p_weeks || ' أسابيع' end
$fn$;

create or replace function public.zad_enqueue_habit_trials(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  r record;
  t record;
  c record;
  v_task uuid;
  v_made int := 0;
  v_verdict text;
  v_weekly numeric;
begin
  update public.zad_habit_trials
     set status = 'expired', decided_at = p_now
   where status = 'proposed' and proposed_at <= p_now - interval '7 days';
  update public.zad_habit_trials
     set status = 'expired', decided_at = p_now
   where status = 'measured' and ends_at <= p_now - interval '8 days';

  for r in
    select u.id as user_id, u.currency, public.zad_market_timezone(u.country) as tz
      from public.zad_users u
      join auth.users au on au.id = u.id
     where extract(hour from p_now at time zone public.zad_market_timezone(u.country)) = 18
       and (exists (select 1 from public.telegram_bindings b where b.user_id = u.id and b.bound_at is not null)
            or exists (select 1 from public.zad_fcm_tokens f where f.user_id = u.id))
  loop
    -- ١) تجربة خلصت: تتقاس.
    select * into t from public.zad_habit_trials
     where user_id = r.user_id and status = 'active' and ends_at <= p_now
     limit 1;
    if found then
      select m.total, m.times into c
        from public.zad_habit_trial_measure(r.user_id, t.kind, t.category, r.tz, t.started_at, t.ends_at) m;
      v_weekly := round(c.total / 2, 2);
      v_verdict := case
        when v_weekly <= t.baseline_weekly * 0.85 then 'better'
        when v_weekly >= t.baseline_weekly * 1.15 then 'worse'
        else 'same' end;
      insert into public.agent_tasks (user_id, kind, task_description, scheduled_for)
      values (
        r.user_id, 'habit_trial_result',
        format($t$[نتيجة تجربة الأسبوعين] التجربة كانت: «%s». قبلها: %s في الأسبوع (%s). أثناءها: %s في الأسبوع (%s). الحكم: %s.
اكتب سطرين بس بلهجة العميل: النتيجة بالأرقام دي بالظبط من غير مبالغة، وسؤال «نثبّتها ولا نبطّلها؟». الأرقام وأزرار «ثبّتها / بطّلها» هتتحط تحت رسالتك، فماتكتبهاش.$t$,
               public.zad_habit_trial_behaviour(t.kind),
               public.zad_habit_trial_amount(t.kind, t.baseline_weekly, t.currency),
               public.zad_habit_trial_times_label(t.kind, t.baseline_count, 4),
               public.zad_habit_trial_amount(t.kind, v_weekly, t.currency),
               public.zad_habit_trial_times_label(t.kind, c.times, 2),
               case v_verdict
                 when 'better' then case when public.zad_habit_trial_is_money(t.kind) then 'الصرف نزل' else 'العدد نزل' end
                 when 'worse' then case when public.zad_habit_trial_is_money(t.kind) then 'الصرف زاد' else 'العدد زاد' end
                 else 'زي ما هو تقريباً' end),
        p_now
      )
      returning id into v_task;
      update public.zad_habit_trials
         set status = 'measured', result_weekly = v_weekly, result_count = c.times, verdict = v_verdict,
             result_task_id = v_task
       where id = t.id;
      v_made := v_made + 1;
      continue;
    end if;

    -- ٢) اقتراح جديد: مفيش مفتوحة، ومفيش اقتراح آخر ٢٨ يوم.
    if exists (select 1 from public.zad_habit_trials h
                where h.user_id = r.user_id
                  and (h.status in ('proposed', 'active', 'measured') or h.proposed_at > p_now - interval '28 days')) then
      continue;
    end if;

    select k.kind, k.category, m.total, m.times into c
      from (values ('eat_out_less', 'المطاعم', 4), ('one_grocery_trip', 'البقالة', 8),
                   ('waste_less', 'الهالك', 3), ('fewer_stockouts', 'المخزن', 3)) as k(kind, category, min_times)
      cross join lateral public.zad_habit_trial_measure(r.user_id, k.kind, k.category, r.tz, p_now - interval '28 days', p_now) m
     where m.times >= k.min_times and m.total > 0
       and not exists (select 1 from public.zad_habit_trials h
                        where h.user_id = r.user_id and h.kind = k.kind
                          and (h.status = 'kept'
                               or (h.status in ('declined', 'dropped') and h.decided_at > p_now - interval '90 days')))
     -- بقد إيه فوق الحد، والفلوس تكسر التعادل.
     order by m.times::numeric / k.min_times desc, m.total desc
     limit 1;
    if not found then
      continue;
    end if;

    v_weekly := round(c.total / 4, 2);
    insert into public.agent_tasks (user_id, kind, task_description, scheduled_for)
    values (
      r.user_id, 'habit_trial',
      format($t$[اقتراح تجربة أسبوعين] زاد لاحظ من آخر ٤ أسابيع: %s في «%s»، بمتوسط %s في الأسبوع. الاقتراح: «%s» لمدة أسبوعين، وبعدها زاد يقيس ويقول النتيجة.
اكتب سطرين بس بلهجة العميل: اللي لاحظته بالأرقام دي بالظبط من غير لوم، والاقتراح كتجربة مش أمر. الأرقام وأزرار «نجرب / لأ» هتتحط تحت رسالتك، فماتكتبهاش.$t$,
             public.zad_habit_trial_times_label(c.kind, c.times, 4), c.category,
             public.zad_habit_trial_amount(c.kind, v_weekly, r.currency),
             public.zad_habit_trial_behaviour(c.kind)),
      p_now
    )
    returning id into v_task;
    insert into public.zad_habit_trials (user_id, kind, category, currency, baseline_weekly, baseline_count, proposed_at, proposal_task_id)
    values (r.user_id, c.kind, c.category, r.currency, v_weekly, c.times, p_now, v_task);
    v_made := v_made + 1;
  end loop;
  return v_made;
end
$fn$;

revoke all on function public.zad_enqueue_habit_trials(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_enqueue_habit_trials(timestamptz) to service_role;

create or replace function public.zad_habit_trial_answer_service(p_user uuid, p_trial uuid, p_yes boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_row public.zad_habit_trials%rowtype;
begin
  select * into v_row from public.zad_habit_trials where id = p_trial and user_id = p_user for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_row.status = 'proposed' then
    if p_yes then
      update public.zad_habit_trials
         set status = 'active', started_at = now(), ends_at = now() + interval '14 days'
       where id = p_trial;
      return jsonb_build_object('ok', true, 'answer', 'start', 'ends_at', now() + interval '14 days');
    end if;
    update public.zad_habit_trials set status = 'declined', decided_at = now() where id = p_trial;
    return jsonb_build_object('ok', true, 'answer', 'decline');
  end if;
  if v_row.status = 'measured' then
    if p_yes then
      update public.zad_habit_trials set status = 'kept', decided_at = now() where id = p_trial;
      insert into public.zad_memory (user_id, scope, note, confidence, evidence_count)
      values (p_user, 'house_habit',
              format('البيت جرّب «%s» أسبوعين وقرر يثبّتها: «%s» كانت %s في الأسبوع وبقت %s.',
                     public.zad_habit_trial_behaviour(v_row.kind), v_row.category,
                     public.zad_habit_trial_amount(v_row.kind, v_row.baseline_weekly, v_row.currency),
                     public.zad_habit_trial_amount(v_row.kind, v_row.result_weekly, v_row.currency)),
              0.9, 1);
      return jsonb_build_object('ok', true, 'answer', 'keep');
    end if;
    update public.zad_habit_trials set status = 'dropped', decided_at = now() where id = p_trial;
    return jsonb_build_object('ok', true, 'answer', 'drop');
  end if;
  return jsonb_build_object('ok', true, 'already', true, 'status', v_row.status);
end
$fn$;

revoke all on function public.zad_habit_trial_answer_service(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.zad_habit_trial_answer_service(uuid, uuid, boolean) to service_role;

/** زرار الإشعار في التطبيق: نفس الجواب بجلسة العميل نفسه. */
create or replace function public.zad_habit_trial_answer(p_trial uuid, p_yes boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  return public.zad_habit_trial_answer_service(auth.uid(), p_trial, p_yes);
end
$fn$;

revoke all on function public.zad_habit_trial_answer(uuid, boolean) from public, anon;
grant execute on function public.zad_habit_trial_answer(uuid, boolean) to authenticated, service_role;
