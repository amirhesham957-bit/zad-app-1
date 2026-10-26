-- مراجعة الذاكرة الشهرية (ZAD_PLAN ٥.٣، أول شريحة): عينة من اللي زاد فاكره بتتسأل «صح؟»، والجواب بيتسجل.
--
-- المقاس ٢٦/١٠: ٢٨ ملاحظة حية، منهم ١٠ في scope general (اللي الشات حفظه بـremember والتأمل الليلي) عند ٣ حسابات،
-- ومحدش عمره اتسأل عليهم. ومنهم ملاحظتين نوم متناقضين لنفس البيت («من ١٠ الصبح لـ٧ المسا» و«من ٥ الفجر لـ٤ العصر»):
-- واحدة على الأقل غلط، والعقل بيقرا الاتنين.
--
--   • zad_enqueue_memory_checks: مرة كل ٢٨ يوم لكل بيت ليه قناة، الساعة ٧ المسا بتوقيت السوق: لحد ٣ ملاحظات من
--     general، حية (مش superseded ولا خلصت)، عمرها أسبوع أو أكتر، ومااتسألش عليها آخر ٩٠ يوم. الترتيب شبه عشوائي
--     ثابت (md5) عشان العينة تمثّل الذاكرة مش أقواها بس. مهمة memory_check في agent_tasks، والملاحظات بتتسجل
--     في zad_memory_checks بالمهمة؛ البوت بيحطها مترقّمة بأزرارها تحت الرسالة.
--   • zad_memory_check_answer_service: الملكية من الصف وجواب واحد. «صح» = evidence_count + 1 والثقة تعلى (لحد
--     ٠٫٩٥)؛ «مش صح» = valid_until = دلوقتي، فـzad_memory_live_notes مابقاش يرجّعها. مفيش مسح: الغلط دليل برضه.
--   • zad_memory_accuracy: آخر ٩٠ يوم — كام اتسأل، كام اتجاوب، كام صح؛ أقل من ٥ أجوبة = «الداتا قليلة».

create table if not exists public.zad_memory_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  memory_id uuid not null references public.zad_memory (id) on delete cascade,
  note text not null,
  task_id uuid references public.agent_tasks (id) on delete set null,
  position int not null check (position between 1 and 3),
  asked_at timestamptz not null default now(),
  answer text check (answer is null or answer in ('yes', 'no')),
  answered_at timestamptz,
  constraint zad_memory_checks_answered check ((answer is null) = (answered_at is null))
);
create index if not exists zad_memory_checks_task on public.zad_memory_checks (task_id) where task_id is not null;
create index if not exists zad_memory_checks_user on public.zad_memory_checks (user_id, asked_at desc);

alter table public.zad_memory_checks enable row level security;
revoke all on table public.zad_memory_checks from anon, authenticated;
grant select on table public.zad_memory_checks to authenticated;
grant all on table public.zad_memory_checks to service_role;
drop policy if exists zad_memory_checks_own on public.zad_memory_checks;
create policy zad_memory_checks_own on public.zad_memory_checks for select to authenticated
  using (user_id = (select auth.uid()));

comment on table public.zad_memory_checks is
  'ZAD_PLAN 5.3 — monthly sample of memory notes asked «صح؟», with the answer. Written by the server only.';

create or replace function public.zad_enqueue_memory_checks(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  r record;
  v_ids uuid[];
  v_notes text[];
  v_task uuid;
  v_made int := 0;
begin
  for r in
    select u.id as user_id
      from public.zad_users u
      join auth.users au on au.id = u.id
     where extract(hour from p_now at time zone public.zad_market_timezone(u.country)) = 19
       and (exists (select 1 from public.telegram_bindings b where b.user_id = u.id and b.bound_at is not null)
            or exists (select 1 from public.zad_fcm_tokens f where f.user_id = u.id))
       and not exists (select 1 from public.zad_memory_checks c where c.user_id = u.id and c.asked_at > p_now - interval '28 days')
  loop
    select array_agg(s.id order by s.k), array_agg(left(s.note, 300) order by s.k)
      into v_ids, v_notes
      from (
        select m.id, m.note, md5(m.id::text || to_char(p_now, 'YYYY-MM')) as k
          from public.zad_memory m
         where m.user_id = r.user_id and m.scope = 'general' and m.superseded_by is null
           and (m.valid_until is null or m.valid_until > p_now)
           and m.created_at <= p_now - interval '7 days'
           and not exists (select 1 from public.zad_memory_checks c
                            where c.memory_id = m.id and c.asked_at > p_now - interval '90 days')
         order by k
         limit 3
      ) s;
    if v_ids is null then
      continue;
    end if;

    insert into public.agent_tasks (user_id, kind, task_description, scheduled_for)
    values (
      r.user_id, 'memory_check',
      format($t$[مراجعة الذاكرة الشهرية] زاد عايز يتأكد من %s حاجات فاكرها عن العميل، عشان مايبنيش على حاجة غلط.
اكتب سطر تمهيد واحد بس بلهجة العميل («عايز أتأكد من كام حاجة فاكرها عنك»). الملاحظات نفسها وأزرار «صح / مش صح» هتتحط تحت رسالتك، فماتكتبهاش.$t$,
             cardinality(v_ids)),
      p_now
    )
    returning id into v_task;

    insert into public.zad_memory_checks (user_id, memory_id, note, task_id, position, asked_at)
    select r.user_id, x.id, x.note, v_task, x.pos, p_now
      from unnest(v_ids, v_notes) with ordinality as x(id, note, pos);
    v_made := v_made + 1;
  end loop;
  return v_made;
end
$fn$;

revoke all on function public.zad_enqueue_memory_checks(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_enqueue_memory_checks(timestamptz) to service_role;

create or replace function public.zad_memory_check_answer_service(p_user uuid, p_check uuid, p_yes boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_row public.zad_memory_checks%rowtype;
begin
  select * into v_row from public.zad_memory_checks where id = p_check and user_id = p_user for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_row.answer is not null then
    return jsonb_build_object('ok', true, 'already', true, 'answer', v_row.answer, 'position', v_row.position);
  end if;
  update public.zad_memory_checks
     set answer = case when p_yes then 'yes' else 'no' end, answered_at = now()
   where id = p_check;
  if p_yes then
    update public.zad_memory
       set evidence_count = evidence_count + 1, last_seen = now(), confidence = least(0.95, confidence + 0.1)
     where id = v_row.memory_id and user_id = p_user;
  else
    update public.zad_memory set valid_until = now()
     where id = v_row.memory_id and user_id = p_user and (valid_until is null or valid_until > now());
  end if;
  return jsonb_build_object('ok', true, 'answer', case when p_yes then 'yes' else 'no' end, 'position', v_row.position);
end
$fn$;

revoke all on function public.zad_memory_check_answer_service(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.zad_memory_check_answer_service(uuid, uuid, boolean) to service_role;

/** دقة الذاكرة آخر ٩٠ يوم لبيت، أو لكل البيوت لو [p_user] = null (السيرفر بس). */
create or replace function public.zad_memory_accuracy(p_user uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
declare
  v jsonb;
begin
  if auth.role() is not null and auth.role() <> 'service_role' and (p_user is null or auth.uid() is distinct from p_user) then
    return null;
  end if;
  select jsonb_build_object(
           'asked', count(*),
           'answered', count(answer),
           'yes', count(*) filter (where answer = 'yes'),
           'no', count(*) filter (where answer = 'no'),
           'enough', count(answer) >= 5,
           'yes_pct', round(100.0 * count(*) filter (where answer = 'yes') / nullif(count(answer), 0))
         )
    into v
    from public.zad_memory_checks
   where (p_user is null or user_id = p_user) and asked_at > now() - interval '90 days';
  return v;
end
$fn$;

revoke all on function public.zad_memory_accuracy(uuid) from public, anon;
grant execute on function public.zad_memory_accuracy(uuid) to authenticated, service_role;

do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  -- كل ساعة عند الدقيقة ١١: الدالة بتختار الساعة ٧ المسا لكل سوق ومرة كل ٢٨ يوم؛ معالج المبادرات بيبعتها.
  perform cron.schedule('memory-checks', '11 * * * *', $job$ select public.zad_enqueue_memory_checks(); $job$);
end
$cron$;
