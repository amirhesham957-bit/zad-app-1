-- =====================================================
-- مراجعة القرارات اللي فاتت (docs/agent/ZAD_LIVING_BRAIN.md الشريحة ٢٦، من «نفذ كامل البرومبت»).
--
-- «أثر قرار كبير» (الشريحة ١٦) بيحسب قبل القرار: الفايض الشهري هيبقى كام. محدش كان بيرجع بعدها يشوف الحسبة طلعت
-- صح ولا لأ — والعميل اللي اشترى عربية واكتشف بعد شهرين إن البنزين والصيانة مش في الحسبة، اكتشفها لوحده.
--
-- دلوقتي: لما العميل يقول إنه قرر فعلاً (مش «لو اشتريت…»)، العقل بيسجّل القرار بأرقامه ومتوسطات البيت ساعتها
-- (log_decision). المحاسب في «فريق زاد» (staff.ts، صفر توكنز) بيراجعه بعد ٣٠ يوم وبعد ٩٠: الفايض الفعلي قصاد
-- المحسوب، ومين اتحرك (الدخل ولا المصاريف). الملاحظة بتعدّي على منسّق الانتباه زي أي ملاحظة.
--
-- الكتابة من السيرفر بس (service_role)؛ العميل بيقرا قراراته ويقدر يمسحها.
-- =====================================================

create table if not exists public.zad_decision_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text not null check (char_length(btrim(label)) between 1 and 80),
  decided_at timestamptz not null default now(),
  one_time_cost numeric not null default 0 check (one_time_cost >= 0),
  monthly_cost numeric not null default 0 check (monthly_cost >= 0),
  monthly_income_change numeric not null default 0,
  -- متوسطات البيت الشهرية ساعة القرار (monthlyAverages، آخر ٩٠ يوم) — المراجعة بتقيس عليها.
  baseline_income numeric not null default 0 check (baseline_income >= 0),
  baseline_spend numeric not null default 0 check (baseline_spend >= 0),
  baseline_days integer not null default 0 check (baseline_days >= 0),
  -- ٠ = لسه، ١ = اتراجع بعد ٣٠ يوم، ٢ = اتراجع بعد ٩٠ (خلص).
  reviews smallint not null default 0 check (reviews between 0 and 2),
  reviewed_at timestamptz,
  outcome jsonb,
  created_at timestamptz not null default now()
);

create index if not exists zad_decision_log_open
  on public.zad_decision_log (user_id, decided_at)
  where reviews < 2;

alter table public.zad_decision_log enable row level security;
revoke all on table public.zad_decision_log from anon, authenticated;
grant select, delete on table public.zad_decision_log to authenticated;

drop policy if exists "decision log: owner reads" on public.zad_decision_log;
create policy "decision log: owner reads" on public.zad_decision_log
  for select using (auth.uid() = user_id);
drop policy if exists "decision log: owner deletes" on public.zad_decision_log;
create policy "decision log: owner deletes" on public.zad_decision_log
  for delete using (auth.uid() = user_id);
