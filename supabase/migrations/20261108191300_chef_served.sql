-- ٧.٤: اللي شيف زاد عرضته لكل عميل، عشان مفيش وصفة تتكرر قبل ١٤ يوم. الكاتب والقارئ: meal_suggestions في
-- zad-core-intelligence بمفتاح الخدمة، فمفيش policy للعميل. الصف بيتحدّث مع كل عرض، فالجدول مابيكبرش بالتكرار.
create table if not exists public.zad_chef_served (
  user_id uuid not null references auth.users(id) on delete cascade,
  name_key text not null check (char_length(name_key) between 1 and 160),
  recipe_name text not null check (char_length(recipe_name) between 1 and 120),
  served_at timestamptz not null default now(),
  primary key (user_id, name_key)
);

alter table public.zad_chef_served enable row level security;
revoke all on public.zad_chef_served from anon, authenticated;
grant all on public.zad_chef_served to service_role;
