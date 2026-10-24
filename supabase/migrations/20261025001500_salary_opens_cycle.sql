-- المرتب يفتح الدورة (ZAD_PLAN ٢.٤).
--
-- الدورة موجودة (zad_users.cycle_start_day، 20260730120000) بس محدش بيربطها بالفلوس اللي بتنزل فعلاً:
-- لو المرتب نزل يوم ٢٨ والدورة على ٢٥، الميزانية بتحسب من يوم غلط لحد ما العميل يغيّرها بإيده.
--
-- دلوقتي: دخل من إشعار البنك اتسجّل (أكّده من التطبيق أو تليجرام) وقريب من المرتب المعتاد ⇐ لحظة
-- `salary_cycle` بتسأله «ده المرتب؟ أبدأ الدورة من النهارده؟» بزرار، ومعاها اللي في المخزن يكفي
-- أسبوع وأكتر («ركّز على الطازة»). الزرار بينادي zad_salary_cycle_service، والدورة بتتنقل بنفس
-- العمود اللي باقي التطبيق بيقرا منه (والتريجر بيزامن zad_customer_profile.pay_day).
--
-- «قريب من المعتاد» = بين ٠٫٧٥ و١٫٣٣ من وسيط أكبر دخل في كل شهر من آخر ٦ شهور (شهرين على الأقل).
-- من غير تاريخ كفاية = نص صرف آخر ٣٠ يوم أو أكتر. نفس يوم الدورة الحالي = مفيش سؤال، وسؤال واحد
-- كل ٢٠ يوم بالكتير. دخل بتاريخ أقدم من يومين (اتسجّل متأخر) مابيسألش.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

/** الدخل ده شكله المرتب؟ بيرجّع facts اللحظة، أو null. منفصلة عن التريجر عشان تتختبر. */
create or replace function public.zad_salary_candidate(p_user uuid, p_txn uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_t record;
  v_tz text;
  v_day int;
  v_pay int;
  v_cur text;
  v_usual numeric;
  v_spent numeric;
  v_pantry jsonb;
begin
  select t.id, t.amount, t.txn_kind, t.source_type, t.created_at, t.currency
    into v_t from public.zad_transactions t where t.id = p_txn and t.user_id = p_user;
  if v_t.id is null or v_t.txn_kind is distinct from 'income' or v_t.source_type is distinct from 'notification_listener'
     or coalesce(v_t.amount, 0) <= 0
     -- دخل قديم بيتسجّل متأخر (بتاريخه) مش «النهارده».
     or v_t.created_at < now() - interval '2 days' then
    return null;
  end if;
  select public.zad_market_timezone(u.country), u.cycle_start_day, coalesce(v_t.currency, u.currency)
    into v_tz, v_pay, v_cur from public.zad_users u where u.id = p_user;
  if v_tz is null then
    return null;
  end if;
  v_day := extract(day from v_t.created_at at time zone v_tz)::int;
  if v_pay = v_day then
    return null;
  end if;
  if exists (select 1 from public.zad_voice_moments m
              where m.user_id = p_user and m.moment = 'salary_cycle' and m.created_at > now() - interval '20 days') then
    return null;
  end if;

  select percentile_cont(0.5) within group (order by mx) into v_usual
    from (select max(t.amount) mx from public.zad_transactions t
           where t.user_id = p_user and t.txn_kind = 'income' and t.id <> p_txn
             and t.created_at > now() - interval '6 months'
           group by date_trunc('month', t.created_at at time zone v_tz)) m
   having count(*) >= 2;
  if v_usual is not null then
    if v_t.amount < 0.75 * v_usual or v_t.amount > 1.33 * v_usual then
      return null;
    end if;
  else
    select coalesce(sum(t.amount), 0) into v_spent from public.zad_transactions t
     where t.user_id = p_user and t.txn_kind = 'expense' and t.created_at > now() - interval '30 days';
    if v_spent <= 0 or v_t.amount < 0.5 * v_spent then
      return null;
    end if;
  end if;

  -- المخزن اللي يكفي أسبوع وأكتر بمعدل استهلاكه المتعلَّم — أكتر ٣.
  select coalesce(jsonb_agg(jsonb_build_object('name', p.item_name, 'days', p.days) order by p.days desc), '[]'::jsonb)
    into v_pantry
    from (select i.item_name, floor(i.quantity / c.avg_daily_qty)::int days
            from public.zad_inventory i
            join public.zad_consumption c on c.user_id = i.user_id and c.item_name = i.item_name
           where i.user_id = p_user and c.rate_known and c.avg_daily_qty > 0 and i.quantity > 0
             and i.quantity / c.avg_daily_qty >= 7
           order by i.quantity / c.avg_daily_qty desc
           limit 3) p;

  return jsonb_build_object(
    'txn_id', v_t.id, 'amount', v_t.amount, 'currency', v_cur, 'day', v_day,
    'pay_day', v_pay, 'usual', v_usual, 'pantry', v_pantry);
end;
$function$;

revoke all on function public.zad_salary_candidate(uuid, uuid) from public, anon, authenticated;

create or replace function public.zad_salary_moment_on_income()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_facts jsonb;
begin
  v_facts := public.zad_salary_candidate(new.user_id, new.id);
  if v_facts is not null then
    insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
    values (new.user_id, 'salary_cycle', v_facts, 'salary_cycle:' || new.id)
    on conflict (user_id, dedupe_key) do nothing;
  end if;
  return new;
exception when others then
  -- السؤال عمره ما يوقف تسجيل الفلوس.
  raise warning 'zad_salary_moment_on_income: %', sqlerrm;
  return new;
end;
$function$;

revoke all on function public.zad_salary_moment_on_income() from public, anon, authenticated;

drop trigger if exists zad_salary_moment_on_income on public.zad_transactions;
create trigger zad_salary_moment_on_income
  after insert on public.zad_transactions
  for each row when (new.txn_kind = 'income' and new.source_type = 'notification_listener')
  execute function public.zad_salary_moment_on_income();

/**
 * زرار «ده المرتب؟» من تليجرام. [p_yes] = الدورة تبدأ من يوم الدخل ده. الملكية من اللحظة نفسها.
 * بيرجّع {ok, day} أو {ok:false, reason}.
 */
create or replace function public.zad_salary_cycle_service(p_user uuid, p_moment uuid, p_yes boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_day int;
  v_answer text;
begin
  select (m.facts ->> 'day')::int, m.facts ->> 'answer' into v_day, v_answer
    from public.zad_voice_moments m
   where m.id = p_moment and m.user_id = p_user and m.moment = 'salary_cycle';
  if v_day is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_answer is not null then
    return jsonb_build_object('ok', true, 'already', true, 'answer', v_answer, 'day', v_day);
  end if;
  update public.zad_voice_moments
     set facts = facts || jsonb_build_object('answer', case when p_yes then 'yes' else 'no' end)
   where id = p_moment;
  if p_yes then
    update public.zad_users set cycle_start_day = v_day, cycle_anchor = 'day_of_month' where id = p_user;
  end if;
  return jsonb_build_object('ok', true, 'answer', case when p_yes then 'yes' else 'no' end, 'day', v_day);
end;
$function$;

revoke all on function public.zad_salary_cycle_service(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.zad_salary_cycle_service(uuid, uuid, boolean) to service_role;
