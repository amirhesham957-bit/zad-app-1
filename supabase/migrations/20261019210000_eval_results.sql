-- التقييم الليلي (ZAD_PLAN ٧.١): الجدول اللي zad-brain بيكتب فيه نتيجة كل حالة (action eval_run).
--
-- #190 دخل main بالكود اللي بيعمل insert في zad_eval_results من غير المايجريشن، فاختبار عقد السكيما
-- وقع على main وعلى كل PR بعده، والنشر اتوقف. ده الجدول بالأعمدة اللي index.ts بيكتبها بالظبط.
--
-- السيرفر بس (service_role بيتخطى RLS): RLS شغال ومفيش سياسة، ومفيش صلاحيات للعميل.

create table if not exists public.zad_eval_results (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null,
  case_id text not null,
  category text,
  pass boolean not null default false,
  failure text,
  reply text,
  detail jsonb not null default '{}'::jsonb,
  ms integer,
  created_at timestamptz not null default now()
);

create index if not exists zad_eval_results_run on public.zad_eval_results (run_id, case_id);
create index if not exists zad_eval_results_created on public.zad_eval_results (created_at desc);

alter table public.zad_eval_results enable row level security;
revoke all on public.zad_eval_results from anon, authenticated;
