-- خروجات العميل من البيت ورجوعه — "روحت فين وصرفت إيه" (٢٠٢٦-٠٩-١٤).
--
-- طلب المستخدم: زاد تعرف مكانه من صلاحية الموقع، ولما يخرج ويرجع تقوله "روحت فين بقى وصرفت
-- إيه" زي صاحبته، ونقدر نحفظ تحركاته واستهلاكه. قراره: التحركات تتحفظ على السيرفر بخصوصية.
--
-- الخصوصية هنا في التصميم نفسه، مش في إعداد:
-- - **مفيش إحداثيات خالص في الجدول ده.** مكان البيت بيتعلّم ويتخزن على الموبايل بس
--   (HomePlace.kt)، والسيرفر بيعرف "خرج الساعة كذا ورجع الساعة كذا" بس.
-- - اللي بيتحفظ: وقت الخروج والرجوع، إجمالي المصروف في النافذة دي، وأسماء المحلات اللي
--   دخل نطاقها (store_arrival) — نفس البيانات اللي عنده أصلاً في معاملاته.
-- - بيتمسح بعد ٩٠ يوم تلقائي، والعميل يقدر يمسح أي خروجة (RLS delete).
-- - كله شغال بس لو العميل فعّل تنبيهات الموقع بنفسه (الإفصاح في location_alerts_toggle_hint).

create table if not exists public.zad_place_visits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  left_at timestamptz not null,
  returned_at timestamptz not null,
  spent_total numeric(14, 2) not null default 0,
  currency text,
  merchants jsonb not null default '[]'::jsonb,
  stores jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  check (returned_at > left_at),
  unique (user_id, left_at)
);

create index if not exists zad_place_visits_user_idx on public.zad_place_visits (user_id, returned_at desc);

alter table public.zad_place_visits enable row level security;

drop policy if exists "place visits: owner reads" on public.zad_place_visits;
create policy "place visits: owner reads" on public.zad_place_visits
  for select using (auth.uid() = user_id);
drop policy if exists "place visits: owner deletes" on public.zad_place_visits;
create policy "place visits: owner deletes" on public.zad_place_visits
  for delete using (auth.uid() = user_id);

create or replace function public.zad_purge_old_place_visits()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_deleted int;
begin
  delete from public.zad_place_visits where returned_at < now() - interval '90 days';
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$function$;

revoke all on function public.zad_purge_old_place_visits() from public;
revoke all on function public.zad_purge_old_place_visits() from anon;
revoke all on function public.zad_purge_old_place_visits() from authenticated;

select cron.unschedule('place-visits-retention')
where exists (select 1 from cron.job where jobname = 'place-visits-retention');

select cron.schedule('place-visits-retention', '23 2 * * *', $$ select public.zad_purge_old_place_visits(); $$);
