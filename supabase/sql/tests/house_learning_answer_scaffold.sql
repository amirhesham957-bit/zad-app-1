-- What 20261027013000_house_learning_answer.sql reads beyond house_learnings_scaffold.sql, as live 2026-10-26.
create table public.zad_memory (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, scope text not null default 'general',
  note text not null, confidence real not null default 0.5, evidence_count int not null default 1,
  superseded_by uuid, created_at timestamptz not null default now()
);
