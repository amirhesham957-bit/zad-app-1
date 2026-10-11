-- ميعاد دكتور ⇒ مبلغ الكشف في «المحجوز» (الموجة ٣ من «خطة سد فجوات زاد»، ٢٠٢٦-١٠-١٠).
--
-- ميزانية المواعيد (الشريحة ٤٢، eventDayBudget) بتعيد توزيع المتاح على أيام الأسبوع بس — مافيش رقم للمشوار نفسه،
-- فكشف بـ٤٠٠ يوم الخميس كان بيطلع من «المتاح» يومها مفاجأة. دلوقتي الميعاد يقدر يشيل تكلفته المتوقعة
-- (expected_cost) — **اللي العميل قالها بس** («الكشف بـ٤٠٠»، أداة add_appointment/update_appointment)، مفيش
-- تقدير — وzad_budget_state بتحجزها: بند في committed_items (kind = appointment) لحد ما ميعاده ييجي.
-- بعد الميعاد البند بيقع، والكشف نفسه بيتسجل مصروف عادي — مفيش عدّ مرتين.
--
-- zad_budget_state بتتعدل على نصها الحي، مش متكتبة من الأول (§١١ في ZAD_LIVING_BRAIN.md): الجملة اللي بتفلتر
-- committed_items على نهاية الدورة لازم تتلاقي بكلماتها مرة واحدة بالظبط، وإلا المايجريشن تقف.

alter table public.zad_appointments add column if not exists expected_cost numeric;
alter table public.zad_appointments drop constraint if exists zad_appointments_expected_cost_range;
alter table public.zad_appointments add constraint zad_appointments_expected_cost_range
  check (expected_cost is null or (expected_cost > 0 and expected_cost <= 1000000));

comment on column public.zad_appointments.expected_cost is
  'التكلفة اللي العميل قالها للميعاد («الكشف بـ٤٠٠»). zad_budget_state بتحجزها في committed_items لحد الميعاد. null = مش معروفة، مش صفر.';

do $migrate$
declare
  v_def text;
  v_pat text;
  v_hits int;
begin
  select pg_get_functiondef('public.zad_budget_state(uuid,text)'::regprocedure) into v_def;

  -- بعد ما الترقيع ده اتعمل مرة، مايتعملش تاني (المايجريشن تتعاد على قاعدة اتصفّرت).
  if v_def like '%kind'', ''appointment''%' then
    raise notice 'zad_budget_state already reserves appointment fees';
    return;
  end if;

  v_pat := 'where (item ->> ''next_due'')::date < v_end;';
  v_pat := regexp_replace(v_pat, '([.*+?^${}()|\[\]\\])', '\\\1', 'g');
  v_pat := regexp_replace(v_pat, '\\\( ', '\\(\\s*', 'g');
  v_pat := regexp_replace(v_pat, ' \\\)', '\\s*\\)', 'g');
  v_pat := regexp_replace(v_pat, ' ', '\\s+', 'g');

  v_hits := regexp_count(v_def, v_pat);
  if v_hits <> 1 then
    raise exception 'appointment fee: zad_budget_state has % committed-items filters matching, expected 1', v_hits;
  end if;

  execute regexp_replace(v_def, v_pat,
    'where (item ->> ''next_due'')::date < v_end;

  -- مبلغ الكشف (20261010190000): ميعاد جاي قبل نهاية الدورة وتكلفته اللي العميل قالها.
  select coalesce(jsonb_agg(item order by item ->> ''next_due''), ''[]''::jsonb)
    into v_items
  from (
    select item from jsonb_array_elements(v_items) item
    union all
    select jsonb_build_object(
             ''title'', a.title,
             ''amount'', a.expected_cost,
             ''kind'', ''appointment'',
             ''next_due'', to_char((a.starts_at at time zone v_tz)::date, ''YYYY-MM-DD''),
             ''appointment_id'', a.id)
    from public.zad_appointments a
    where a.user_id = p_user
      and a.status = ''upcoming''
      and a.expected_cost > 0
      and a.starts_at >= now()
      and (a.starts_at at time zone v_tz)::date < v_end
  ) all_items;');
end
$migrate$;
