-- ── سقف يومي للبحث المدفوع (المالك ربط ZAD_SEARCH_KEY، ٢٠٢٦-١٠-١٨) ──────────────────────
--
-- البحث بجوجل من Gemini على المشروع المدفوع: ٥٬٠٠٠ بحث مجاني في الشهر وبعدها بفلوس. كل نسخة
-- من zad-core-intelligence بتاخد بحث من الرصيد ده قبل أي نداء مدفوع، فالعدّ واحد مهما اتعدّدت
-- النسخ. اليوم بتوقيت UTC. مفيش دالة موجودة اتعدّلت هنا.

create table if not exists public.zad_search_budget (
  day date primary key,
  used int not null default 0 check (used >= 0)
);

alter table public.zad_search_budget enable row level security;
-- No policy: only the service role (the edge function) reads or writes it.

comment on table public.zad_search_budget is
  'Paid Google Search grounding calls per UTC day (zad_search_budget_take).';

create or replace function public.zad_search_budget_take(p_cap int)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  taken int;
begin
  if p_cap is null or p_cap <= 0 then return false; end if;
  insert into public.zad_search_budget as b (day, used)
  values ((now() at time zone 'utc')::date, 1)
  on conflict (day) do update set used = b.used + 1
    where b.used < p_cap
  returning used into taken;
  return taken is not null;
end;
$function$;

revoke all on function public.zad_search_budget_take(int) from public, anon, authenticated;
grant execute on function public.zad_search_budget_take(int) to service_role;
