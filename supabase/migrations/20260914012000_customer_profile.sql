-- ملف العميل عند زاد — «إنت مين» (٢٠٢٦-٠٩-١٤).
--
-- شكوى المستخدم: «الإيجنت مايعرفش أنا مين — ولد ولا بنت، أب ولا أم، بشتغل إيه، بقبض إمتى».
-- القياس في الكود: buildSnapshot كان بيقرا zad_users.gender ومايحطوش في السياق، ومابيقراش الاسم
-- أصلاً، والذاكرة في الشات كانت أقرب ١٢ ملاحظة للرسالة الحالية بس — فحقيقة زي «بقبض يوم ٢٥»
-- بتختفي لما الكلام يبقى عن الأكل. البرومبت نفسه كان بيقول «متخمّنش جنس العميل» ومفيش مكان
-- يتسجّل فيه لما العميل يقوله.
--
-- الجدول ده الحقايق الثابتة المنظّمة (بتدخل السياق كل مرة)؛ zad_memory بتفضل للملاحظات الحرة.
-- العقل بيملاه من الكلام (update_customer_profile)، والعميل يشوفه ويعدّله ويمسحه من «زاد عارف
-- عني إيه». مفيش بيانات صحية ولا دينية هنا عن قصد.

create table if not exists public.zad_customer_profile (
  user_id uuid primary key references auth.users(id) on delete cascade,
  preferred_name text check (preferred_name is null or char_length(btrim(preferred_name)) between 1 and 40),
  gender text check (gender is null or gender in ('male', 'female')),
  household_role text check (household_role is null or household_role in
    ('father', 'mother', 'husband', 'wife', 'son', 'daughter', 'single', 'student', 'grandparent', 'other')),
  age_range text check (age_range is null or age_range in ('under_18', '18_24', '25_34', '35_44', '45_54', '55_plus')),
  occupation text check (occupation is null or char_length(occupation) <= 80),
  work_schedule text check (work_schedule is null or char_length(work_schedule) <= 120),
  pay_day int check (pay_day is null or pay_day between 1 and 31),
  pay_frequency text check (pay_frequency is null or pay_frequency in ('monthly', 'biweekly', 'weekly', 'daily', 'irregular')),
  income_source text check (income_source is null or char_length(income_source) <= 80),
  household_size int check (household_size is null or household_size between 1 and 30),
  kids_count int check (kids_count is null or kids_count between 0 and 20),
  city text check (city is null or char_length(city) <= 60),
  dialect text check (dialect is null or dialect in ('EG', 'SA', 'GULF', 'LEVANT', 'IQ', 'MA', 'TN', 'DZ', 'LY', 'SD', 'YE', 'TR', 'EN')),
  interests text[] check (interests is null or cardinality(interests) <= 12),
  notes text check (notes is null or char_length(notes) <= 500),
  updated_by text not null default 'app' check (updated_by in ('app', 'chat', 'voice', 'telegram')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.zad_customer_profile enable row level security;

drop policy if exists "customer profile: owner reads" on public.zad_customer_profile;
create policy "customer profile: owner reads" on public.zad_customer_profile
  for select using (auth.uid() = user_id);
drop policy if exists "customer profile: owner inserts" on public.zad_customer_profile;
create policy "customer profile: owner inserts" on public.zad_customer_profile
  for insert with check (auth.uid() = user_id);
drop policy if exists "customer profile: owner updates" on public.zad_customer_profile;
create policy "customer profile: owner updates" on public.zad_customer_profile
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "customer profile: owner deletes" on public.zad_customer_profile;
create policy "customer profile: owner deletes" on public.zad_customer_profile
  for delete using (auth.uid() = user_id);
