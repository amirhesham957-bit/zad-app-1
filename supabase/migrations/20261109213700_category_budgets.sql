-- سقوف الفئات كانت على الموبايل بس (زي Kotlin)، فالبوت مالوش طريق ليها: طلب «حط سقف 300 للترفيه»
-- كان بيروح لـset_monthly_limit ويترفض (حساب المالك، ٥/١١). الجدول ده بيخليها على الحساب.
create table if not exists public.zad_category_budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (char_length(category) between 1 and 60),
  amount numeric(14, 2) not null check (amount > 0),
  updated_at timestamptz not null default now(),
  unique (user_id, category)
);

alter table public.zad_category_budgets enable row level security;

create policy "own category budgets: read" on public.zad_category_budgets
  for select to authenticated using (auth.uid() = user_id);
create policy "own category budgets: add" on public.zad_category_budgets
  for insert to authenticated with check (auth.uid() = user_id);
create policy "own category budgets: change" on public.zad_category_budgets
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own category budgets: remove" on public.zad_category_budgets
  for delete to authenticated using (auth.uid() = user_id);
