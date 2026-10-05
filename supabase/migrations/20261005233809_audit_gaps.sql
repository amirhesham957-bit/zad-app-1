-- المراجعة الشاملة (٢٠٢٦-١٠-٠٥، طلب المالك: «في داتا غلط… والعقل أعمى عن أشياء… وانفصال لسوبابيز وجداولها عن العقل»).
-- اتقاس على الداتابيز الحية الأول؛ الأرقام في docs/agent/ZAD_LIVING_BRAIN.md §١١. الملف ده بيقفل اللي ليه علاج آمن في SQL:
--
--   ١. «ملخص البيت الأسبوعي» كان يومي: الماسح كل ساعة بيناديه وقيد التكرار يومي، فاتعمل ٧ مرات في الأسبوع لنفس الحساب
--      (agent_tasks: ٦٤ ملخص) — وكل واحد نداء موديل. دلوقتي: مرة كل ٦ أيام على الأقل.
--   ٢. ثلاث دوال كانت بتقرا `renewal_date` الخام: تذكير الفواتير، الملخص، وملاحظات المجالات. التطبيق والميزانية و«دفتر الأيام»
--      بيحسبوا التجديد الجاي (zad_subscription_next_renewal)، فتاريخ فات كان بيتقال فات، وتذكير الاشتراك بيرن أول شهر بس.
--      دلوقتي التلاتة على نفس الدالة.
--   ٣. الفئات: الاستخراج والماسح والتطبيق بيكتبوا «البقالة/الفواتير/الرعاية الصحية»، وأداة العقل بتقترح «بقالة/فواتير/صحة»، وفيه
--      «عام» و«شهر » بمسافة — نفس الصرف بيتقسم على اسمين، وكل حارس بيحسب بالفئة بيشوف نصه. دالة واحدة للاسم القياسي، تريجر على
--      كل كتابة (التطبيق والعقل والبوت وقناة البنك)، وتنضيف مرة واحدة للموجود. تريجرات الإشعارات على الإدخال بس — التنضيف مابيبعتش حاجة.
--
-- رقم الإصدار بعد كل اللي على الحي (آخره 20261005190000) ومش على ساعة مدوّرة.

-- ── ١. الملخص الأسبوعي أسبوعي، والتجديد من الدالة ─────────────────────────────────────
-- نسخة الحي بالظبط (pg_get_functiondef، ٢٠٢٦-١٠-٠٥) + بلوك «اتعمل آخر ٦ أيام؟» + التجديد الجاي بدل الخام.
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

  -- مفيش حاجة تستاهل ملخص؟ متبعتش حاجة خالص — مينفعش نختلق محتوى
  if v_spent = 0 and v_low_stock = 0 and v_due_soon = 0 and v_meds_low = 0 then
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
• أدوية قربت: %s

حلّل الأرقام دي للعميل في جملتين، وقول أهم حاجة واحدة يعملها الأسبوع الجاي.$t$,
      round(v_spent)::text,
      round(v_last)::text,
      case when v_last > 0
        then '، ' || case when v_spent > v_last then 'زادت' else 'قلّت' end
             || ' ' || abs(round(v_spent - v_last))::text else '' end,
      v_low_stock, v_due_soon, v_meds_low
    ),
    now()
  )
  on conflict (user_id, kind, ((created_at at time zone 'UTC')::date))
    where kind in ('spending_ahead','med_followup','bill_reminder','warranty_reminder','home_weekly_digest')
  do nothing;
exception
  when unique_violation then
    return;
  when others then
    raise;
end;
$function$;

-- ── ٢. تذكير الفواتير وملاحظات المجالات على التجديد الجاي ─────────────────────────────
-- الدالتين اتعدّلوا على الحي بتعديلات ديناميكية قبل كده (20260913161000)، فالتعديل هنا على نص الحي نفسه، وبيقع لو
-- النص المتوقع مش موجود — مفيش «اتعمل» وهو ماتعملش.
do $$
declare
  v_def text;
  v_new text;
  -- التذكير بيشمل «فات من غير تجديد مسجل» لحد يومين: التجديد الجاي من (النهارده − ٢) بيحافظ على ده، وبيكمّل الشهور الجاية.
  v_next text := 'public.zad_subscription_next_renewal(s.renewal_date, s.due_day, s.billing_cycle, ((now() at time zone ''utc'')::date - 2))';
begin
  v_def := pg_get_functiondef('public._agent_bill_reminder_for_user(uuid)'::regprocedure);
  v_new := replace(v_def, $q$'due', s.renewal_date,$q$, format($q$'due', to_char(%s, 'YYYY-MM-DD'),$q$, v_next));
  v_new := replace(v_new, $q$and s.renewal_date ~ '^\d{4}-\d{2}-\d{2}$'$q$, $q$and s.renewal_date is not null$q$);
  v_new := replace(v_new, $q$(s.renewal_date::date - (now() at time zone 'utc')::date)$q$,
                   format($q$(%s - (now() at time zone 'utc')::date)$q$, v_next));
  if v_new = v_def or v_new like '%s.renewal_date::date%' or v_new like $q$%'due', s.renewal_date,%$q$ then
    raise exception 'audit_gaps: _agent_bill_reminder_for_user is not the text this migration expects';
  end if;
  execute v_new;

  v_def := pg_get_functiondef('public.zad_domain_observations(uuid)'::regprocedure);
  v_new := replace(v_def, 'zad_try_date(renewal_date) AS rd',
                   'public.zad_subscription_next_renewal(renewal_date, due_day, billing_cycle, v_today) AS rd');
  if v_new = v_def then
    raise exception 'audit_gaps: zad_domain_observations is not the text this migration expects';
  end if;
  execute v_new;
end $$;

-- ── ٣. اسم واحد لكل فئة ──────────────────────────────────────────────────────────────
-- القياسي = قايمة الاستخراج/الماسح (kStandardCategories في التطبيق) + الترفيه والملابس (العقل كان بيستخدمهم). اللي مش معروف
-- بيفضل زي ما هو بعد قص المسافات — مفيش تخمين. «دخل» فئة الدخل العام، مش «الراتب»، فبتفضل.
create or replace function public.zad_canonical_category(p text)
returns text language sql immutable set search_path = public as $$
  with k as (
    select btrim(p) as raw,
           lower(translate(regexp_replace(btrim(coalesce(p, '')), '\s+', ' ', 'g'), 'أإآةى', 'اااهي')) as key
  )
  select case
    when p is null then null
    when key in ('', 'عام', 'غير مصنف', 'متنوع', 'other', 'general', 'اخري', 'اخرى') then 'أخرى'
    when key in ('بقاله', 'البقاله', 'سوبر ماركت', 'سوبرماركت', 'تموين') then 'البقالة'
    when key in ('مطاعم', 'مطعم', 'المطاعم', 'اكل بره') then 'المطاعم'
    when key in ('فواتير', 'فاتوره', 'الفواتير', 'فواتير ومرافق', 'مرافق') then 'الفواتير'
    when key in ('مواصلات', 'المواصلات', 'تاكسي', 'اوبر') then 'المواصلات'
    when key in ('وقود', 'الوقود', 'بنزين') then 'الوقود'
    when key in ('اشتراكات', 'اشتراك', 'الاشتراكات') then 'الاشتراكات'
    when key in ('اقساط', 'قسط', 'الاقساط') then 'الأقساط'
    when key in ('صحه', 'الصحه', 'صيدليه', 'الصيدليه', 'دوا', 'ادويه', 'علاج', 'الرعايه الصحيه', 'رعايه صحيه') then 'الرعاية الصحية'
    when key in ('تعليم', 'التعليم', 'مدارس', 'دراسه') then 'التعليم'
    when key in ('ترفيه', 'الترفيه', 'خروجات') then 'الترفيه'
    when key in ('ملابس', 'الملابس', 'لبس') then 'الملابس'
    when key in ('راتب', 'مرتب', 'الراتب', 'المرتب') then 'الراتب'
    when key in ('تحويل', 'تحويلات') then 'تحويلات'
    else raw
  end from k
$$;

comment on function public.zad_canonical_category(text) is
  'اسم الفئة القياسي (المراجعة الشاملة ٢٠٢٦-١٠-٠٥): نفس قايمة الاستخراج والتطبيق + الترفيه والملابس. المجهول بيفضل بعد قص المسافات.';

create or replace function public.zad_transactions_canonical_category()
returns trigger language plpgsql set search_path = public as $$
begin
  new.category := public.zad_canonical_category(new.category);
  return new;
end;
$$;

drop trigger if exists zad_transactions_canonical_category on public.zad_transactions;
create trigger zad_transactions_canonical_category
  before insert or update of category on public.zad_transactions
  for each row execute function public.zad_transactions_canonical_category();

revoke all on function public.zad_transactions_canonical_category() from public, anon, authenticated;

-- الموجود: مرة واحدة. تريجرات الإشعارات على الإدخال بس، فده مابيبعتش ولا رسالة.
update public.zad_transactions
   set category = public.zad_canonical_category(category)
 where category is distinct from public.zad_canonical_category(category);
