-- سقف شهري للذكاء الاصطناعي وتنبيه عند ٨٠٪ (ZAD_PLAN ٨.٢).
--
-- قبل أي مختبِر من برّه، داتا العملاء لازم تمشي على مفتاح جيميناي مدفوع (`ZAD_PAID_KEY_n`،
-- _shared/keyPool.ts) — شروط المجاني بتمنع البيانات الشخصية. المدفوع بفلوس، فالمالك محتاج يعرف
-- قبل ما الفاتورة تعدّي اللي حطه:
-- • zad_ai_budget — صف واحد: السقف بالدولار في الشهر ونسبة التنبيه. بيتغير بـ update، من غير نشر.
-- • zad_ai_budget_check() — تكلفة الشهر لحد دلوقتي من zad_brain_cost_monthly (٣.٨)، وتنبيه واحد
--   للمالك في الشهر عند النسبة، وواحد عند ١٠٠٪، في zad_brain_health_alerts و zad_notify_admin.
-- الرقم تقدير من التوكنز بالأسعار الرسمية، ولفّات العقل بس: المسح والشيف والصوت (zad-core-intelligence)
-- مش محسوبين لسه، والموديل اللي مالوش سعر منشور بيتعدّ لوحده. الحد الحقيقي اللي بيوقف الصرف هو حصة
-- المشروع المدفوع في Google Cloud (طلبات في اليوم)، والتنبيه ده عشان مانوصلوش من غير ما نعرف.

create table if not exists public.zad_ai_budget (
  id boolean primary key default true check (id),
  monthly_cap_usd numeric not null default 20 check (monthly_cap_usd > 0),
  alert_pct int not null default 80 check (alert_pct between 1 and 99),
  updated_at timestamptz not null default now()
);

insert into public.zad_ai_budget (id) values (true) on conflict (id) do nothing;

alter table public.zad_ai_budget enable row level security;
revoke all on public.zad_ai_budget from anon, authenticated;
grant all on public.zad_ai_budget to service_role;

create or replace function public.zad_ai_budget_check(p_now timestamptz default now())
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_month date := date_trunc('month', p_now at time zone 'utc')::date;
  v_cap numeric;
  v_alert_pct int;
  v_spent numeric;
  v_unpriced int;
  v_pct int;
  v_kind text;
begin
  select monthly_cap_usd, alert_pct into v_cap, v_alert_pct from zad_ai_budget where id;
  if v_cap is null then
    return jsonb_build_object('checked', false, 'reason', 'no budget row');
  end if;

  select coalesce(sum(cost_usd), 0), coalesce(sum(unpriced_runs), 0)::int into v_spent, v_unpriced
    from zad_brain_cost_monthly(v_month);
  v_pct := floor(100 * v_spent / v_cap)::int;

  v_kind := case when v_pct >= 100 then 'ai_budget_100' when v_pct >= v_alert_pct then 'ai_budget_80' end;
  if v_kind is null or exists (select 1 from zad_brain_health_alerts where alert_date = v_month and kind = v_kind) then
    return jsonb_build_object('checked', true, 'alerted', false, 'spent_usd', round(v_spent, 4), 'cap_usd', v_cap, 'pct', v_pct);
  end if;

  insert into zad_brain_health_alerts (alert_date, kind, bad_pct, top_error)
  values (v_month, v_kind, v_pct, round(v_spent, 2) || ' of ' || v_cap || ' USD');

  perform public.zad_notify_admin(
    case when v_kind = 'ai_budget_100' then '⛔ سقف الذكاء الاصطناعي خلص' else '⚠️ سقف الذكاء الاصطناعي قرّب' end,
    'تكلفة الشهر لحد دلوقتي حوالي ' || round(v_spent, 2) || ' دولار من سقف ' || v_cap || ' (' || v_pct || '٪).'
      || case when v_unpriced > 0 then E'\n' || v_unpriced || ' لفة على موديل مالوش سعر منشور مش محسوبة.' else '' end
      || E'\nالسقف بيتغير من zad_ai_budget، والحد اللي بيوقف الصرف فعلاً هو حصة المشروع في Google Cloud.'
  );
  return jsonb_build_object('checked', true, 'alerted', true, 'kind', v_kind, 'spent_usd', round(v_spent, 4), 'cap_usd', v_cap, 'pct', v_pct);
end;
$$;

revoke all on function public.zad_ai_budget_check(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_ai_budget_check(timestamptz) to service_role;

do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.schedule('health-daily', '41 5 * * *',
    'select public.zad_health_snapshot(); select public.zad_health_brain_cost(); select public.zad_ai_budget_check();');
end
$cron$;
