-- م٨.٢/م٨.٥: حالة الـbandit لكل فرد (member_id) ونوع رسالة وقالب. service_role بس.
-- مفيش FK على الفرد: الحالة ممكن تتمسح لوحدها، والقراية الفاشلة = القالب الأساسي.
create table if not exists public.zad_bandit_state (
  user_id uuid not null,
  member_id uuid not null,
  kind text not null check (length(kind) between 1 and 80),
  arm text not null check (length(arm) between 1 and 80),
  successes integer not null default 0 check (successes >= 0),
  failures integer not null default 0 check (failures >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, member_id, kind, arm)
);
alter table public.zad_bandit_state enable row level security;
revoke all on public.zad_bandit_state from public, anon, authenticated;
grant select, insert, update on public.zad_bandit_state to service_role;
