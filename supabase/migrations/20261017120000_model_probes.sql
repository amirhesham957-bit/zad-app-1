-- نتايج فحص الكوتة الحقيقية لكل موديل على كل مفتاح (zad-core-intelligence/modelProbe.ts،
-- ZAD_DREAM_PLAN.md — قرار المالك ٢٠٢٦-١٠-١٧). أرقام وحالات بس: مفيش مفتاح ولا جزء منه،
-- المفتاح متعرّف برقم خانته (ZAD_API_KEY_n / GROQ_API_KEY_n بترتيب المسبح).
-- السيرفر بس بيكتب ويقرا (service role)؛ RLS شغالة ومفيش سياسة للعميل.

create table if not exists public.zad_model_probes (
  id bigint generated always as identity primary key,
  probed_at timestamptz not null default now(),
  provider text not null check (provider in ('gemini', 'groq')),
  key_slot int not null check (key_slot > 0),
  model text not null,
  status int,
  ok boolean not null default false,
  limit_requests int,      -- Groq: طلبات في اليوم (x-ratelimit-limit-requests)
  remaining_requests int,
  limit_tokens int,        -- Groq: توكنز في الدقيقة (x-ratelimit-limit-tokens)
  remaining_tokens int,
  quota_note text          -- Gemini: quotaId=quotaValue من الـ429، أو سبب الفشل
);

create index if not exists zad_model_probes_probed_at_idx on public.zad_model_probes (probed_at desc);

alter table public.zad_model_probes enable row level security;
revoke all on public.zad_model_probes from anon, authenticated;
