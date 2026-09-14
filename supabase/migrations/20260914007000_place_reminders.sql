-- تذكيرات مربوطة بمكان مش بوقت — «فكّريني لما أروح الصيدلية أجيب بنادول» (٢٠٢٦-٠٩-١٤).
--
-- طلب المستخدم: زاد تفكّره بحاجات حسب مكانه «زي صاحبته». المواعيد (zad_appointments) ليها
-- وقت؛ دي مالهاش وقت، ليها نوع مكان. بتتنفّذ لما الموبايل يبلّغ store_arrival لنوع المكان ده
-- (أو 'any' = أي محل)، وبتتقال بصوت زاد (لحظة place_reminder في zad_voice_moments)، ومرة
-- واحدة بس: الإطلاق بيحوّل الحالة لـ done في نفس الـUPDATE اللي بيرجّع الصفوف، فحدثين
-- geofence ورا بعض مايقولوش نفس التذكير مرتين.
--
-- الخصوصية: مفيش مكان ولا إحداثيات هنا — نوع المكان بس (supermarket/pharmacy/mall/any).

create table if not exists public.zad_place_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  place text not null default 'any'
    check (place in ('supermarket', 'pharmacy', 'mall', 'any')),
  note text not null check (char_length(btrim(note)) between 2 and 200),
  status text not null default 'open' check (status in ('open', 'done', 'cancelled')),
  source text not null default 'app' check (source in ('app', 'voice', 'chat', 'telegram')),
  fired_at timestamptz,
  fired_store text check (fired_store is null or char_length(fired_store) <= 60),
  created_at timestamptz not null default now()
);

create index if not exists zad_place_reminders_open_idx
  on public.zad_place_reminders (user_id, place)
  where status = 'open';

alter table public.zad_place_reminders enable row level security;

drop policy if exists "place reminders: owner reads" on public.zad_place_reminders;
create policy "place reminders: owner reads" on public.zad_place_reminders
  for select using (auth.uid() = user_id);
drop policy if exists "place reminders: owner inserts" on public.zad_place_reminders;
create policy "place reminders: owner inserts" on public.zad_place_reminders
  for insert with check (auth.uid() = user_id);
drop policy if exists "place reminders: owner updates" on public.zad_place_reminders;
create policy "place reminders: owner updates" on public.zad_place_reminders
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "place reminders: owner deletes" on public.zad_place_reminders;
create policy "place reminders: owner deletes" on public.zad_place_reminders
  for delete using (auth.uid() = user_id);
