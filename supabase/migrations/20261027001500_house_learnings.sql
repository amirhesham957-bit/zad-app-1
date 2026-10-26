-- «اتعلمت إن» (ZAD_PLAN ٥.٢، أول شريحة): نمط واحد من حركات البيت بأرقامه، جوه ملخص البيت الأسبوعي.
--
-- الملخص الأسبوعي (_agent_home_weekly_digest_for_user، ٧٣ مرة اتبعت لحد ٢٦/١٠) بيقول أرقام الأسبوع بس: صرف
-- الأسبوع قصاد اللي فات والنواقص والمستحقات. مفيش فيه حاجة «زاد اتعلمها» عن البيت. المقاس ٢٦/١٠ (٣٩ حركة صرف
-- في ٧ أسابيع، بيت واحد): البقالة يوم الأربع ٨ مرات في ٣ أسابيع مختلفة، ٤٧٪ من مرات البقالة — ده النوع اللي
-- البند بيوصفه («بقيتوا تطلبوا أكل برّه يوم الخميس»).
--
-- القاعدة (من غير موديل، كل رقم من zad_transactions):
--   • فئة × يوم في الأسبوع بتوقيت سوق الحساب (zad_market_timezone)، آخر ٨ أسابيع.
--   • تتقال بس لو: ٣ أسابيع مختلفة أو أكتر، و٤٠٪ أو أكتر من مرات الفئة، والفئة ليها ٥ مرات على الأقل.
--     «أخرى» و«غير مصنف» مش فئات.
--   • نفس النمط مايتقالش تاني قبل ٢٨ يوم، واللي العميل جاوب عليه مايتقالش تاني خالص: «مش صح» عشان بوابة
--     المرحلة ٥ (صفر ملاحظات اتقالت غلط مرتين)، و«صح» عشان بقى معروف ومش محتاج يتقال تاني.
-- كل نمط اتقال بيتسجل في zad_house_learnings، والإجابة (answer) هي الشريحة الجاية.
--
-- جسم الملخص = النسخة الحية (pg_get_functiondef ٢٦/١٠)، والجديد بس v_learned وسطره وتسجيله.

create table if not exists public.zad_house_learnings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  key text not null check (char_length(key) between 3 and 160),
  note text not null check (char_length(note) between 5 and 400),
  evidence jsonb not null default '{}'::jsonb,
  said_at timestamptz not null default now(),
  answer text check (answer is null or answer in ('yes', 'no')),
  answered_at timestamptz,
  constraint zad_house_learnings_answered check ((answer is null) = (answered_at is null)),
  unique (user_id, key)
);

alter table public.zad_house_learnings enable row level security;
revoke all on table public.zad_house_learnings from anon, authenticated;
grant select on table public.zad_house_learnings to authenticated;
grant all on table public.zad_house_learnings to service_role;

drop policy if exists zad_house_learnings_own on public.zad_house_learnings;
create policy zad_house_learnings_own on public.zad_house_learnings for select to authenticated
  using (user_id = (select auth.uid()));

comment on table public.zad_house_learnings is
  'ZAD_PLAN 5.2 — every «اتعلمت إن» said to a home, with its evidence and the customer''s answer. Written by the server only.';

/** أقوى نمط فئة × يوم يستاهل يتقال دلوقتي، أو null. */
create or replace function public.zad_house_pattern(p_user uuid, p_now timestamptz default now())
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $fn$
  with tz as (
    select public.zad_market_timezone(u.country) as zone from public.zad_users u where u.id = p_user
  ),
  t as (
    select trim(x.category) as cat,
           extract(isodow from x.created_at at time zone coalesce((select zone from tz), 'Africa/Cairo'))::int as dow,
           date_trunc('week', x.created_at at time zone coalesce((select zone from tz), 'Africa/Cairo')) as wk
      from public.zad_transactions x
     where x.user_id = p_user and x.is_expense is true
       and x.created_at > p_now - interval '56 days' and x.created_at <= p_now
       and nullif(trim(x.category), '') is not null
       and trim(x.category) not in ('أخرى', 'اخرى', 'غير مصنف')
  ),
  per_cat as (select cat, count(*) as n_cat from t group by cat),
  cand as (
    select t.cat, t.dow, count(*) as n, count(distinct t.wk) as weeks, c.n_cat
      from t join per_cat c using (cat)
     group by t.cat, t.dow, c.n_cat
  )
  select jsonb_build_object(
           'key', 'category_weekday:' || cand.cat || ':' || cand.dow,
           'kind', 'category_weekday',
           'category', cand.cat,
           'weekday', (array['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'])[cand.dow],
           'times', cand.n, 'weeks', cand.weeks, 'of_weeks', 8, 'category_times', cand.n_cat,
           'share_pct', round(100.0 * cand.n / cand.n_cat),
           'source', 'zad_transactions',
           'note', format('%s غالباً يوم %s: %s مرة في %s أسابيع مختلفة من آخر ٨، يعني %s٪ من مرات %s.',
                          cand.cat, (array['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'])[cand.dow],
                          cand.n, cand.weeks, round(100.0 * cand.n / cand.n_cat), cand.cat)
         )
    from cand
   where cand.weeks >= 3 and cand.n_cat >= 5 and cand.n * 100 >= 40 * cand.n_cat
     and not exists (
       select 1 from public.zad_house_learnings l
        where l.user_id = p_user and l.key = 'category_weekday:' || cand.cat || ':' || cand.dow
          and (l.answer is not null or l.said_at > p_now - interval '28 days')
     )
   order by cand.weeks desc, cand.n desc, cand.cat
   limit 1;
$fn$;

revoke all on function public.zad_house_pattern(uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.zad_house_pattern(uuid, timestamptz) to service_role;

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
  v_rows int;
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
  do nothing;
  get diagnostics v_rows = row_count;

  -- اتسجل إنه اتقال بس لو الملخص اتكتب فعلاً.
  if v_rows > 0 and v_learned is not null then
    insert into public.zad_house_learnings (user_id, key, note, evidence, said_at)
    values (p_user, v_learned ->> 'key', v_learned ->> 'note', v_learned - 'note', now())
    on conflict (user_id, key) do update
      set note = excluded.note, evidence = excluded.evidence, said_at = excluded.said_at
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
