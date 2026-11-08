-- أسئلة التأمل الليلي (طلب المالك ٨/١١: «العقل يبني مسارات لحياته حتى لو مش متبرمجة»): الموديل بيقترح سؤال يخص العميل ده بالذات من
-- كلامه، وبيتسأل في خانة الفضول. فرضية مش حقيقة: جواب العميل بس اللي بيدخل zad_memory. الكاتب والقارئ zad-brain. مقفول للعميل.
create table if not exists public.zad_life_tracks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  question text not null check (char_length(question) between 10 and 140),
  because text check (char_length(because) <= 200),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create index if not exists zad_life_tracks_user_idx on public.zad_life_tracks (user_id, created_at desc);

alter table public.zad_life_tracks enable row level security;
revoke all on public.zad_life_tracks from anon, authenticated;
grant all on public.zad_life_tracks to service_role;
