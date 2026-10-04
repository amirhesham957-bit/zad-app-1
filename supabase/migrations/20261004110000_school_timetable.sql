-- جدول الحصص من الكاميرا (ZAD_LIVING_BRAIN.md الشريحة ٢١، قرار المالك ٢٠٢٦-١٠-٠٤).
--
-- ولي الأمر بيصوّر جدول حصص ابنه/بنته، zad-core-intelligence بيقراه (analyze_document_image)، والعميل بيراجعه
-- ويأكد. الجدول هنا: حصة لكل صف (اليوم، الترتيب، الوقت لو مكتوب، المادة) لكل شخص. العقل بيقراه عشان «بكرة عند
-- عمر رياضيات وعلوم — جهّز الشنطة» في تصبح على خير.
--
-- الكتابة من zad_timetable_replace بس: جدول الشخص كله بيتبدل مرة واحدة (صورة جديدة = جدول جديد)، مش صف صف.
-- weekday: 0 = الأحد (نفس extract(dow …)).

create table if not exists public.zad_school_timetable (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  person text not null check (char_length(btrim(person)) between 1 and 40),
  weekday smallint not null check (weekday between 0 and 6),
  period smallint not null check (period between 1 and 15),
  starts time,
  ends time,
  subject text not null check (char_length(btrim(subject)) between 1 and 40),
  created_at timestamptz not null default now(),
  unique (user_id, person, weekday, period)
);

alter table public.zad_school_timetable enable row level security;
-- الصلاحيات الافتراضية في المشروع بتدّي anon وauthenticated كل حاجة على أي جدول جديد (§٧ في المرجع).
revoke all on table public.zad_school_timetable from anon, authenticated;
grant select, delete on table public.zad_school_timetable to authenticated;

drop policy if exists "school timetable: owner reads" on public.zad_school_timetable;
create policy "school timetable: owner reads" on public.zad_school_timetable
  for select using (auth.uid() = user_id);
drop policy if exists "school timetable: owner deletes" on public.zad_school_timetable;
create policy "school timetable: owner deletes" on public.zad_school_timetable
  for delete using (auth.uid() = user_id);

-- p_days = [{"weekday":0,"periods":[{"order":1,"start":"07:45","end":null,"subject":"رياضيات"}]}]
create or replace function public.zad_timetable_replace(p_person text, p_days jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_person text := btrim(coalesce(p_person, ''));
  v_day jsonb;
  v_period jsonb;
  v_weekday int;
  v_order int;
  v_subject text;
  v_count int := 0;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  if char_length(v_person) not between 1 and 40 then
    return jsonb_build_object('ok', false, 'reason', 'bad_person');
  end if;
  if jsonb_typeof(p_days) is distinct from 'array' or jsonb_array_length(p_days) > 7 then
    return jsonb_build_object('ok', false, 'reason', 'bad_days');
  end if;

  delete from public.zad_school_timetable where user_id = v_uid and person = v_person;

  for v_day in select * from jsonb_array_elements(p_days) loop
    v_weekday := (v_day ->> 'weekday')::int;
    continue when v_weekday is null or v_weekday not between 0 and 6
      or jsonb_typeof(v_day -> 'periods') is distinct from 'array';
    v_order := 0;
    for v_period in select * from jsonb_array_elements(v_day -> 'periods') limit 12 loop
      v_subject := btrim(coalesce(v_period ->> 'subject', ''));
      continue when char_length(v_subject) not between 1 and 40;
      v_order := v_order + 1;
      insert into public.zad_school_timetable (user_id, person, weekday, period, starts, ends, subject)
      values (
        v_uid, v_person, v_weekday, v_order,
        case when (v_period ->> 'start') ~ '^([01]\d|2[0-3]):[0-5]\d$' then (v_period ->> 'start')::time end,
        case when (v_period ->> 'end') ~ '^([01]\d|2[0-3]):[0-5]\d$' then (v_period ->> 'end')::time end,
        v_subject
      )
      on conflict (user_id, person, weekday, period) do nothing;
      v_count := v_count + 1;
    end loop;
  end loop;
  return jsonb_build_object('ok', true, 'periods', v_count);
end
$function$;

revoke all on function public.zad_timetable_replace(text, jsonb) from public, anon;
grant execute on function public.zad_timetable_replace(text, jsonb) to authenticated;
