-- التوقع بيتقال ومعاه دقته المقاسة (ZAD_PLAN ٥.٥، الشريحة التانية بعد 20261026214500_forecast_ledger).
--
-- تنبيه spend_forecast كان بيقول «المتوقع يخرج كذا» من avg_weekly_spending لوحده، والمقاس ٢٦/١٠: بيت متوقعله
-- ٢٬٠٨٢ في الأسبوع وصرف ٩٦٨ ثم ١٥٢. دلوقتي الرسالة بتحمل سطر من zad_forecast_accuracy: كام أسبوع اتقاس،
-- والوسيط للفرق كنسبة من اللي اتصرف، وكام أسبوع جه في حدود ٢٥٪ — أو إن التوقع لسه ماتقاسش (أقل من ٣ أسابيع).
-- حقيقة جوه الرسالة، مش تعليمة جديدة للموديل.
--
-- الجسم = النسخة الحية (pg_get_functiondef ٢٦/١٠: `when others then raise` من 20260913161000)، والجديد بس
-- v_accuracy والسطر.

create or replace function public._agent_spend_forecast_for_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_avg_weekly numeric;
  v_profile_age interval;
  v_currency text;
  v_balance numeric;
  v_due_soon numeric;
  v_projected numeric;
  v_accuracy jsonb;
  v_accuracy_line text;
begin
  select b.avg_weekly_spending, now() - b.last_updated_at
    into v_avg_weekly, v_profile_age
  from public.user_behavior_profile b
  where b.user_id = p_user;

  -- ملف مش موجود أو قديم أو صفر = مفيش أساس للتوقع.
  if v_avg_weekly is null or v_avg_weekly <= 0 then
    return;
  end if;
  if v_profile_age is null or v_profile_age > interval '14 days' then
    return;
  end if;

  -- مرة كل ٧ أيام بالكتير.
  if exists (
    select 1 from public.agent_tasks t
    where t.user_id = p_user
      and t.kind = 'spend_forecast'
      and t.created_at > now() - interval '7 days'
  ) then
    return;
  end if;

  select u.currency into v_currency from public.zad_users u where u.id = p_user;

  -- نفس الرقم اللي الكارت بيعرضه للعميل — مش حساب تاني موازي.
  select public.zad_cash_balance(p_user) into v_balance;
  -- صفر أو سالب مش «رصيد قليل» — دي في الغالب «مفيش رصيد متسجّل أصلاً» (حساب ما ثبّتش
  -- نقطة رصيد). التجربة الجافة 2026-09-12 لقت حساب متوسطه ١٣٦ ورصيده 0.00، وكان هياخد
  -- تنبيه «ناقص ١٣٦» كل أسبوع مبني على رقم مش حقيقي. التنبيه ده للفرق بين رقمين
  -- معروفين؛ الحساب اللي مالوش رصيد بتغطيه تنبيهات الميزانية التانية.
  if v_balance is null or v_balance <= 0 then
    return;
  end if;

  -- الالتزامات المؤكَّدة المستحقة خلال ٧ أيام. `least(due_day, 28)` بيتفادى تواريخ
  -- غير صالحة (٣٠ فبراير) — تقريب مقصود، والفرق يوم أو يومين مايغيّرش قرار التنبيه.
  select coalesce(sum(x.amount), 0) into v_due_soon
  from (
    select o.amount,
           case
             when o.due_day >= extract(day from current_date)::int
               then make_date(
                 extract(year from current_date)::int,
                 extract(month from current_date)::int,
                 least(o.due_day, 28)
               )
             else (date_trunc('month', current_date) + interval '1 month')::date
                  + (least(o.due_day, 28) - 1)
           end as next_due
    from public.zad_obligations o
    where o.user_id = p_user
      and coalesce(o.active, true) is true
      and coalesce(o.confirmed, false) is true
      and o.amount is not null
      and o.due_day is not null
  ) x
  where x.next_due <= current_date + 7;

  v_projected := v_avg_weekly + v_due_soon;

  -- ٥.٥: دقة المعدل ده عند العميل ده بالذات، من دفتر التوقعات.
  v_accuracy := public.zad_forecast_accuracy(p_user, 'weekly_spend');
  v_accuracy_line := case
    when coalesce((v_accuracy ->> 'enough')::boolean, false) then format(
      'دقة المعدل ده عندك: آخر %s أسابيع اتقاسوا، الفرق بين المتوقع واللي اتصرف فعلاً كان حوالي %s٪ (الوسيط)، و%s منهم جم في حدود ٢٥٪.',
      v_accuracy ->> 'weeks', v_accuracy ->> 'median_error_pct', v_accuracy ->> 'within_25pct')
    else 'المعدل ده لسه ماتقاسش على صرفك الفعلي (أقل من ٣ أسابيع متسجلة)، فهو تقريبي.'
  end;

  if v_projected <= v_balance then
    return; -- الأسبوع الجاي مغطّى، مفيش داعي لكلام
  end if;

  insert into public.agent_tasks (user_id, kind, task_description, scheduled_for)
  values (
    p_user,
    'spend_forecast',
    format(
      $t$[توقّع الأسبوع الجاي] على معدل صرفك المحسوب (%s %s في الأسبوع) وبإضافة %s %s التزامات مستحقة خلال ٧ أيام، المتوقع يخرج %s %s والمتاح دلوقتي %s %s.
يعني ناقص حوالي %s %s. اقترح على العميل تعديل بسيط في الأيام الجاية أو تأجيل مصروف مؤجَّل، وقول له الرقم اللي اتبنى عليه الكلام.
%s$t$,
      round(v_avg_weekly, 2), coalesce(v_currency, ''),
      round(v_due_soon, 2), coalesce(v_currency, ''),
      round(v_projected, 2), coalesce(v_currency, ''),
      round(v_balance, 2), coalesce(v_currency, ''),
      round(v_projected - v_balance, 2), coalesce(v_currency, ''),
      v_accuracy_line
    ),
    now()
  )
  on conflict (user_id, kind, ((created_at at time zone 'UTC')::date))
    where kind in (
      'spending_ahead', 'med_followup', 'bill_reminder',
      'warranty_reminder', 'home_weekly_digest', 'listener_gap_alert',
      'spend_forecast'
    )
  do nothing;
exception
  when unique_violation then
    return;
  when others then
    raise;
end;
$fn$;

revoke execute on function public._agent_spend_forecast_for_user(uuid) from public, anon, authenticated;
grant execute on function public._agent_spend_forecast_for_user(uuid) to service_role;
