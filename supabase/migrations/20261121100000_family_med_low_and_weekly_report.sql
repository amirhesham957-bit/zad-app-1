-- متابعة العيلة: التنبيه الفوري لدوا قرّب يخلص، والتقرير الأسبوعي للمتابع (قرار المالك، ٢٠٢٦-١١-٢١).
--
-- «اللي وافق على متابعة (zad_family_shares, status = granted) ينبَّه فوراً ويجيله تقرير أسبوعي.»
-- الجرعة الفايتة شغالة من 20261001140000. هنا الاتنين الباقيين، بنفس النمط: الكتابة في zad_voice_moments
-- والصياغة والتوصيل في zad-brain (voiceMoments.ts)، والاتنين بيتطلبوا الموافقة على نطاق medicines/spending/tasks
-- والاتنين لسه في نفس العيلة. مفيش جدول جديد.
--
-- ١) family_med_low — فوري. «قرّب يخلص» بنفس تعريف مسار الدوا المنخفض عند العميل
--    (zad-brain/index.ts، medication_low): remaining_quantity <= daily_dose_count × ٣ (الافتراضي ١).
--    الدهان (units_per_dose = 0، الكمية عدد الأنابيب مش جرعات — 20261001220000) مالوش حد هنا.
--    الـtrigger بيشتغل على لحظة العبور بس (كان فوق الحد وبقى تحته)، فمرة واحدة لكل دوا في كل «حلقة نقص»،
--    ومايتكررش لحد ما يتجدد المخزون ويرجع ينزل. الـdedupe: الدوا + اليوم + المتابع.
--
-- ٢) family_weekly_report — جمعة ٩ الصبح بتوقيت المتابع (zad_market_timezone)، مرة في الأسبوع ISO.
--    لكل فرد متابَع، النطاقات الموافَق عليها بس:
--      medicines: التزام آخر ٧ أيام (أخد ÷ المفروض)، الفايت، وعدد الأدوية القريبة تخلص (من غير أسماء)
--      spending:  مجموع ٧ أيام وأعلى ٣ فئات — مش حركات فردية (زي zad_family_member_view)
--      tasks:     مهام البيت المفتوحة/المتأخرة ومواعيد ٧ أيام والمتأخر منها
--    «المفروض» = عدد مواعيد dose_times الصالحة × أيام الدوا (٧ كحد أقصى): مفيش صف 'missed' بيتسجل
--    (الفايت بيتحسب، 20260925120000)، فالتقدير ده بيطلع من الجدولة نفسها، مش من الجدول.
--    مفيش فرد عنده بيانات = مفيش تقرير.

-- ── ١) دوا قرّب يخلص ────────────────────────────────────────────────────────

create or replace function public.zad_family_med_low_fanout()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_low boolean;
  v_new_low boolean;
begin
  -- دهان: الكمية عدد أنابيب، مش جرعات.
  if coalesce(new.units_per_dose, 1) = 0 or new.remaining_quantity is null then
    return new;
  end if;
  v_new_low := new.remaining_quantity <= coalesce(new.daily_dose_count, 1) * 3;
  v_old_low := old.remaining_quantity is not null
               and old.remaining_quantity <= coalesce(old.daily_dose_count, 1) * 3;
  if not v_new_low or v_old_low then
    return new;
  end if;

  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select s.viewer_id,
         'family_med_low',
         jsonb_build_object(
           'member_id', s.owner_id,
           'member_alias', coalesce(nullif(btrim(fo.alias), ''), 'فرد من العيلة'),
           'item_id', new.id,
           'item_name', new.name,
           'remaining', new.remaining_quantity,
           'unit', nullif(btrim(coalesce(new.unit, '')), '')
         ),
         'family_med_low:' || new.id || ':' || to_char(now() at time zone 'utc', 'YYYY-MM-DD') || ':' || s.viewer_id
    from public.zad_family_shares s
    join public.family_members fo on fo.user_id = s.owner_id and fo.family_id = s.family_id
    join public.family_members fv on fv.user_id = s.viewer_id and fv.family_id = s.family_id
   where s.owner_id = new.user_id
     and s.scope = 'medicines'
     and s.status = 'granted'
  on conflict (user_id, dedupe_key) do nothing;

  return new;
end $$;

revoke all on function public.zad_family_med_low_fanout() from public, anon, authenticated;

drop trigger if exists zad_family_med_low_fanout on public.zad_pharmacy_items;
create trigger zad_family_med_low_fanout
  after update of remaining_quantity, daily_dose_count on public.zad_pharmacy_items
  for each row
  when (new.remaining_quantity is distinct from old.remaining_quantity
        or new.daily_dose_count is distinct from old.daily_dose_count)
  execute function public.zad_family_med_low_fanout();

-- ── ٢) التقرير الأسبوعي ──────────────────────────────────────────────────────

create or replace function public.zad_family_weekly_report_facts(p_viewer uuid, p_now timestamptz default now())
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tz text;
  v_members jsonb := '[]'::jsonb;
  r record;
  v_entry jsonb;
  v_has boolean;
  v_scheduled int;
  v_taken int;
  v_skipped int;
  v_low int;
  v_spent numeric;
  v_top jsonb;
  v_chores_open int;
  v_chores_overdue int;
  v_appts int;
  v_appts_overdue int;
  v_today text;
begin
  select public.zad_market_timezone(country) into v_tz from public.zad_users where id = p_viewer;
  v_tz := coalesce(v_tz, 'UTC');
  v_today := to_char(p_now at time zone v_tz, 'YYYY-MM-DD');

  for r in
    select s.owner_id, s.family_id,
           coalesce(nullif(btrim(fo.alias), ''), 'فرد من العيلة') as alias,
           bool_or(s.scope = 'medicines') as can_meds,
           bool_or(s.scope = 'spending') as can_spend,
           bool_or(s.scope = 'tasks') as can_tasks
      from public.zad_family_shares s
      join public.family_members fo on fo.user_id = s.owner_id and fo.family_id = s.family_id
      join public.family_members fv on fv.user_id = s.viewer_id and fv.family_id = s.family_id
     where s.viewer_id = p_viewer and s.status = 'granted' and s.scope in ('medicines', 'spending', 'tasks')
     group by s.owner_id, s.family_id, fo.alias
     order by 3
  loop
    v_entry := jsonb_build_object('member_id', r.owner_id, 'member_alias', r.alias);
    v_has := false;

    if r.can_meds then
      select coalesce(sum(
               (select count(*) from unnest(string_to_array(p.dose_times, ',')) as x
                 where trim(x) ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$')
               * least(7, greatest(0, floor(extract(epoch from p_now - p.created_at) / 86400)))
             ), 0)::int,
             count(*) filter (where coalesce(p.units_per_dose, 1) <> 0
                                and p.remaining_quantity is not null
                                and p.remaining_quantity <= coalesce(p.daily_dose_count, 1) * 3)::int
        into v_scheduled, v_low
        from public.zad_pharmacy_items p
       where p.user_id = r.owner_id;
      select count(*) filter (where d.status = 'taken')::int,
             count(*) filter (where d.status = 'skipped')::int
        into v_taken, v_skipped
        from public.zad_pharmacy_doses d
       where d.user_id = r.owner_id
         and coalesce(d.scheduled_at, d.taken_at, d.created_at) >= p_now - interval '7 days';
      if v_scheduled > 0 or v_taken > 0 or v_low > 0 then
        v_has := true;
        v_entry := v_entry || jsonb_build_object('medicines', jsonb_build_object(
          'scheduled', greatest(v_scheduled, v_taken + v_skipped),
          'taken', v_taken,
          'missed', greatest(0, v_scheduled - v_taken - v_skipped),
          'adherence_pct', case when greatest(v_scheduled, v_taken + v_skipped) > 0
                                then round(100.0 * v_taken / greatest(v_scheduled, v_taken + v_skipped))::int end,
          'low_count', v_low
        ));
      end if;
    end if;

    if r.can_spend then
      select coalesce(sum(amount), 0) into v_spent
        from public.zad_transactions
       where user_id = r.owner_id and is_expense and created_at >= p_now - interval '7 days';
      if v_spent > 0 then
        select coalesce(jsonb_agg(jsonb_build_object('category', c.category, 'amount', round(c.total::numeric, 2)) order by c.total desc), '[]'::jsonb)
          into v_top
          from (
            select coalesce(category, 'أخرى') as category, sum(amount) as total
              from public.zad_transactions
             where user_id = r.owner_id and is_expense and created_at >= p_now - interval '7 days'
             group by 1 order by 2 desc limit 3
          ) c;
        v_has := true;
        v_entry := v_entry || jsonb_build_object('spending', jsonb_build_object(
          'spent_7d', round(v_spent::numeric, 2),
          'top', v_top,
          'currency', (select currency from public.zad_users where id = r.owner_id)
        ));
      end if;
    end if;

    if r.can_tasks then
      select count(*)::int,
             count(*) filter (where c.due_date ~ '^\d{4}-\d{2}-\d{2}' and left(c.due_date, 10) < v_today)::int
        into v_chores_open, v_chores_overdue
        from public.family_chores c
       where c.family_id = r.family_id and c.assigned_to = r.owner_id and not c.is_completed;
      select count(*) filter (where a.starts_at >= p_now and a.starts_at < p_now + interval '7 days')::int,
             count(*) filter (where a.starts_at < p_now)::int
        into v_appts, v_appts_overdue
        from public.zad_appointments a
       where a.user_id = r.owner_id and a.status = 'upcoming';
      if v_chores_open > 0 or v_appts > 0 or v_appts_overdue > 0 then
        v_has := true;
        v_entry := v_entry || jsonb_build_object('tasks', jsonb_build_object(
          'chores_open', v_chores_open,
          'chores_overdue', v_chores_overdue,
          'appointments_7d', v_appts,
          'appointments_overdue', v_appts_overdue
        ));
      end if;
    end if;

    if v_has then
      v_members := v_members || jsonb_build_array(v_entry);
    end if;
  end loop;

  if jsonb_array_length(v_members) = 0 then
    return null;
  end if;
  return jsonb_build_object(
    'week', to_char(p_now at time zone v_tz, 'IYYY-"W"IW'),
    'time_zone', v_tz,
    'members', v_members
  );
end $$;

revoke all on function public.zad_family_weekly_report_facts(uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.zad_family_weekly_report_facts(uuid, timestamptz) to service_role;

/** جمعة ٩ الصبح بتوقيت سوق المتابع: لكل متابع نشط عنده فرد فيه بيانات، تقرير واحد في الأسبوع ISO. */
create or replace function public.zad_enqueue_family_weekly_report(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted int;
begin
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select x.viewer_id, 'family_weekly_report', f.facts, 'family_weekly:' || (f.facts ->> 'week')
    from (
      -- جمعة ٩ بس، قبل أي حساب: الدالة بتتنادى كل ساعة.
      select au.id as viewer_id
        from auth.users au
        join public.zad_users u on u.id = au.id
       where (au.last_sign_in_at > p_now - interval '14 days'
              or exists (select 1 from public.zad_fcm_tokens t where t.user_id = au.id and t.updated_at > p_now - interval '14 days'))
         and extract(dow from p_now at time zone public.zad_market_timezone(u.country)) = 5
         and extract(hour from p_now at time zone public.zad_market_timezone(u.country)) = 9
         and exists (select 1 from public.zad_family_shares s
                      where s.viewer_id = au.id and s.status = 'granted'
                        and s.scope in ('medicines', 'spending', 'tasks'))
    ) x
    cross join lateral (select public.zad_family_weekly_report_facts(x.viewer_id, p_now) as facts) f
   where f.facts is not null
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end $$;

revoke all on function public.zad_enqueue_family_weekly_report(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_enqueue_family_weekly_report(timestamptz) to service_role;

do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  -- كل ساعة عند الدقيقة ١١: الدالة نفسها بتختار جمعة ٩ الصبح لكل سوق، ومعالج اللحظات (كل ٥ دقايق) بيبعتها.
  perform cron.unschedule('family-weekly-report') where exists (select 1 from cron.job where jobname = 'family-weekly-report');
  perform cron.schedule('family-weekly-report', '11 * * * *', $job$ select public.zad_enqueue_family_weekly_report(); $job$);
end
$cron$;

-- ── ٣) كرون الدقيقة يصحّي المعالج لـfamily_med_low كمان ────────────────────────
-- نفس تعريف 20261024231500 بالظبط، والفرق الوحيد 'family_med_low' في قايمة اللحظات الحرجة
-- (criticalLane_test.ts بيفشل لو أي لحظة حرجة مش في القايمة دي).
do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.schedule(
    'reminders-minutely',
    '* * * * *',
    $job$
  select public.zad_enqueue_appointment_moments();
  select public.zad_enqueue_missed_doses();
  select net.http_post(
      url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
      ),
      body := '{"action":"process_voice_moments"}'::jsonb,
      timeout_milliseconds := 55000
    ) as request_id
  where exists (
    select 1 from public.zad_voice_moments
    where status = 'pending'
      and moment in ('dose_due', 'dose_nudge', 'dose_missed', 'dose_missed_again', 'appointment_soon', 'family_zone_exit', 'family_zone_back', 'family_dose_missed', 'family_med_low')
      and created_at > now() - interval '15 minutes'
  );
  $job$
  );
end
$cron$;
