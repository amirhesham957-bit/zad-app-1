-- What 20261027031500_learning_needs_channel.sql reads beyond house_learning_answer_scaffold.sql, as live 2026-10-27.
create table if not exists public.telegram_bindings (
  id uuid primary key default gen_random_uuid(), user_id uuid, chat_id bigint, bound_at timestamptz
);
