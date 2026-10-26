-- «الرز هيخلص الحد» بيدخل دفتر التوقعات (ZAD_PLAN ٥.٥، الشريحة التالتة بعد 20261026214500 و20261026223500).
--
-- zad_home_state.state.pantry.running_out (homeState.ts) فيه كل صنف هيخلص خلال ٧ أيام بأيامه، و«approx» لو
-- معدل الاستهلاك مش معروف. ده كان بيتقال من غير ما حد يعرف اتحقق ولا لأ. المقاس ٢٦/١٠: بيت واحد عنده ٨ أصناف
-- في القايمة، ٧ منهم approx و٧ «خلصانة النهارده» (٠ يوم).
--
-- النتيجة من إجابات البيت نفسه في zad_inventory_observations (٢٢٦ صف، منهم ٥٩ إجابة على سؤال الليل «خلص؟»
-- و٤١ منهم صفر). كل توقع بيتقفل بعد اليوم المتوقع بـ٣ أيام:
--   • out        — اتسجل صفر بين التوقع والقفل. actual = بعد كام يوم.
--   • still_had  — اتسجلت كمية من غير شرا بعد اليوم المتوقع، ومفيش صفر: كان لسه موجود.
--   • restocked  — اتشرى ومفيش لا صفر ولا كمية: اتجاب، بس مش معروف خلص ولا لأ.
--   • unknown    — ولا ملاحظة: مايتحسبش في الدقة، زي أسبوع الصرف اللي من غير حركات.
-- الدقة = out ÷ (out + still_had)، والفرق بالأيام في اللي خلص؛ أقل من ٥ أحكام = «الداتا قليلة».
--
-- الصنف بيتطابق بـzad_inventory_name_key (ال والهمزات والتاء المربوطة). نفس الصنف مايتفتحلوش توقع تاني قبل
-- ٧ أيام من آخر واحد، عشان صنف قاعد «٠ يوم» أسابيع مايتعدّش كل يوم.

alter table public.zad_forecasts drop constraint if exists zad_forecasts_kind_check;
alter table public.zad_forecasts add constraint zad_forecasts_kind_check check (kind in ('weekly_spend', 'runs_out'));
alter table public.zad_forecasts add column if not exists subject text check (subject is null or char_length(subject) between 1 and 80);
alter table public.zad_forecasts add column if not exists outcome text
  check (outcome is null or outcome in ('out', 'still_had', 'restocked', 'unknown'));

-- صرف الأسبوع: الفعلي والتسجيل بيتقفلوا مع بعض زي الأول. «هيخلص»: الحكم بيتقفل مع القفل، والفعلي بس لو خلص.
alter table public.zad_forecasts drop constraint if exists zad_forecasts_settled;
alter table public.zad_forecasts add constraint zad_forecasts_settled check (
  case kind
    when 'weekly_spend' then (settled_at is null) = (actual is null) and (actual is null) = (recorded is null) and subject is null
    else subject is not null and (settled_at is null) = (outcome is null) and (actual is null or outcome = 'out')
  end
);

drop index if exists public.zad_forecasts_one_open;
create unique index zad_forecasts_one_open
  on public.zad_forecasts (user_id, kind, (public.zad_inventory_name_key(coalesce(subject, ''))))
  where settled_at is null;

create or replace function public.zad_forecasts_tick(p_now timestamptz default now())
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_settled int;
  v_settled_out int;
  v_made int;
  v_made_out int;
begin
  -- ── صرف الأسبوع (20261026214500، من غير تغيير) ──
  with due as (
    select f.id,
           coalesce(sum(t.amount) filter (where t.id is not null), 0) as spent,
           count(t.id) as n
      from public.zad_forecasts f
      left join public.zad_transactions t
        on t.user_id = f.user_id and t.is_expense
       and t.created_at >= f.made_at and t.created_at < f.due_at
     where f.settled_at is null and f.due_at <= p_now and f.kind = 'weekly_spend'
     group by f.id
  )
  update public.zad_forecasts f
     set actual = round(due.spent::numeric, 2), recorded = due.n, settled_at = p_now
    from due where f.id = due.id;
  get diagnostics v_settled = row_count;

  -- ── «هيخلص»: الحكم من إجابات البيت بين التوقع والقفل ──
  with due as (
    select f.id,
           min(o.observed_at) filter (where o.qty = 0) as first_zero,
           bool_or(o.qty > 0 and o.source <> 'purchase'
                   and o.observed_at >= f.made_at + make_interval(days => f.predicted::int)) as had_after,
           bool_or(o.source = 'purchase') as bought,
           count(o.id) as n,
           f.made_at
      from public.zad_forecasts f
      left join public.zad_inventory_observations o
        on o.user_id = f.user_id
       and public.zad_inventory_name_key(o.item_name) = public.zad_inventory_name_key(f.subject)
       and o.observed_at > f.made_at and o.observed_at <= f.due_at
     where f.settled_at is null and f.due_at <= p_now and f.kind = 'runs_out'
     group by f.id
  )
  update public.zad_forecasts f
     set outcome = case when due.first_zero is not null then 'out'
                        when coalesce(due.had_after, false) then 'still_had'
                        when coalesce(due.bought, false) then 'restocked'
                        else 'unknown' end,
         actual = case when due.first_zero is not null
                       then round((extract(epoch from due.first_zero - due.made_at) / 86400)::numeric, 1) end,
         recorded = due.n,
         settled_at = p_now
    from due where f.id = due.id;
  get diagnostics v_settled_out = row_count;

  -- ── فتح توقع الأسبوع: نفس بوابة spend_forecast (ملف أقدم من ١٤ يوم أو متوسط صفر = مفيش أساس) ──
  insert into public.zad_forecasts (user_id, kind, made_at, due_at, predicted, basis)
  select b.user_id, 'weekly_spend', p_now, p_now + interval '7 days', b.avg_weekly_spending,
         jsonb_build_object('source', 'user_behavior_profile.avg_weekly_spending', 'profile_at', b.last_updated_at)
    from public.user_behavior_profile b
   where b.avg_weekly_spending > 0
     and b.last_updated_at > p_now - interval '14 days'
     and exists (select 1 from auth.users u where u.id = b.user_id)
     and not exists (
       select 1 from public.zad_forecasts f
        where f.user_id = b.user_id and f.kind = 'weekly_spend' and f.settled_at is null
     );
  get diagnostics v_made = row_count;

  -- ── فتح «هيخلص» من حالة بيت اتحسبت آخر يوم ──
  insert into public.zad_forecasts (user_id, kind, subject, made_at, due_at, predicted, basis)
  select distinct on (h.user_id, public.zad_inventory_name_key(r.name))
         h.user_id, 'runs_out', left(r.name, 80), p_now,
         p_now + make_interval(days => greatest(r.days, 0) + 3), greatest(r.days, 0),
         jsonb_build_object('source', 'zad_home_state.pantry.running_out', 'approx', coalesce(r.approx, true),
                            'state_at', h.computed_at)
    from public.zad_home_state h
   cross join lateral jsonb_to_recordset(coalesce(h.state -> 'pantry' -> 'running_out', '[]'::jsonb))
         as r(name text, days int, approx boolean)
   where h.computed_at > p_now - interval '1 day'
     and char_length(trim(coalesce(r.name, ''))) between 1 and 80
     and r.days is not null and r.days between 0 and 7
     and exists (select 1 from auth.users u where u.id = h.user_id)
     and not exists (
       select 1 from public.zad_forecasts f
        where f.user_id = h.user_id and f.kind = 'runs_out'
          and public.zad_inventory_name_key(f.subject) = public.zad_inventory_name_key(r.name)
          and (f.settled_at is null or f.made_at > p_now - interval '7 days')
     )
   order by h.user_id, public.zad_inventory_name_key(r.name), r.days;
  get diagnostics v_made_out = row_count;

  return jsonb_build_object('settled', v_settled, 'made', v_made, 'settled_runs_out', v_settled_out, 'made_runs_out', v_made_out);
end
$fn$;

revoke all on function public.zad_forecasts_tick(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_forecasts_tick(timestamptz) to service_role;

/**
 * صرف الأسبوع: زي 20261026214500. «هيخلص»: كام حكم (خلص + كان لسه موجود)، ونسبة اللي خلص فعلاً في ميعاده
 * أو قبله بـ٣ أيام، ووسيط الفرق بالأيام، والمشتري والمجهول بعددهم بس. أقل من ٥ أحكام = {enough: false}.
 */
create or replace function public.zad_forecast_accuracy(p_user uuid, p_kind text default 'weekly_spend')
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
declare
  v jsonb;
begin
  -- من غير JWT خالص = SQL جوه السيرفر (الكرون، تنبيه spend_forecast)؛ أي طلب من PostgREST شايل role.
  if auth.role() is not null and auth.role() <> 'service_role' and auth.uid() is distinct from p_user then
    return null;
  end if;
  if p_kind = 'runs_out' then
    select jsonb_build_object(
             'kind', p_kind,
             'judged', count(*) filter (where outcome in ('out', 'still_had')),
             'enough', count(*) filter (where outcome in ('out', 'still_had')) >= 5,
             'out', count(*) filter (where outcome = 'out'),
             'still_had', count(*) filter (where outcome = 'still_had'),
             'restocked', count(*) filter (where outcome = 'restocked'),
             'unknown', count(*) filter (where outcome = 'unknown'),
             'hit_pct', round(100.0 * count(*) filter (where outcome = 'out')
                              / nullif(count(*) filter (where outcome in ('out', 'still_had')), 0)),
             'median_days_off', percentile_cont(0.5) within group (order by abs(actual - predicted))
                                  filter (where outcome = 'out')
           )
      into v
      from public.zad_forecasts
     where user_id = p_user and kind = 'runs_out' and settled_at is not null;
    return v;
  end if;
  select jsonb_build_object(
           'kind', p_kind,
           'weeks', count(*),
           'enough', count(*) >= 3,
           'median_error_pct', round((percentile_cont(0.5) within group (order by abs(actual - predicted) / actual) * 100)::numeric),
           'within_25pct', count(*) filter (where abs(actual - predicted) <= 0.25 * actual),
           'skipped_unrecorded', (select count(*) from public.zad_forecasts s
                                   where s.user_id = p_user and s.kind = p_kind and s.recorded = 0)
         )
    into v
    from public.zad_forecasts
   where user_id = p_user and kind = p_kind and settled_at is not null and recorded > 0 and actual > 0;
  return v;
end
$fn$;

revoke all on function public.zad_forecast_accuracy(uuid, text) from public, anon;
grant execute on function public.zad_forecast_accuracy(uuid, text) to authenticated, service_role;
