-- ── حصة Google CSE اليومية متقسّمة (قرار المالك ١٣/١١، ZAD_PLAN ١٠.٩) ─────────────────────────
--
-- Custom Search JSON API: ١٠٠ بحث مجاني في اليوم لكل مفتاح، واليوم بيتصفّر نص الليل بتوقيت
-- المحيط الهادي (America/Los_Angeles)، مش UTC. كرونات بحث العروض كانت بتخلّص الحصة كلها الساعة
-- ~٥ الصبح UTC (٤٢٩)، فتيك توك في الشيف كان بيقع على أخبار جوجل اللي مابترجّعش روابط تيك توك.
--
-- كل نداء CSE بياخد من العدّاد ده الأول: «all» ماتعدّيش السقف الكلي، والعروض («deals») ماتعدّيش
-- نصيبها (افتراضي ٧٠ من ١٠٠) ⇒ الباقي محجوز للوصفات وأسئلة الشات. مفيش دالة موجودة اتعدّلت.

create table if not exists public.zad_cse_budget (
  day date not null,
  purpose text not null,
  used int not null default 0 check (used >= 0),
  primary key (day, purpose)
);

alter table public.zad_cse_budget enable row level security;
-- No policy: only the service role (the edge function) reads or writes it.
revoke all on table public.zad_cse_budget from anon, authenticated;

comment on table public.zad_cse_budget is
  'Google Custom Search calls per Pacific day, overall (purpose = all) and per purpose (zad_cse_take).';

-- true = النداء ده مسموح واتعدّ. p_purpose_cap null = الغرض ده مالوش نصيب (ياخد من الكلي بس).
create or replace function public.zad_cse_take(p_purpose text, p_purpose_cap int, p_total_cap int)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  d date := (now() at time zone 'America/Los_Angeles')::date;
  total int;
  mine int;
begin
  if p_total_cap is null or p_total_cap <= 0 or p_purpose is null or p_purpose = 'all' then return false; end if;
  insert into public.zad_cse_budget (day, purpose, used) values (d, 'all', 0) on conflict do nothing;
  -- قفل صف «all» بيرتّب النسخ اللي بتاخد في نفس اللحظة، فالعدّ مايعدّيش السقف.
  select used into total from public.zad_cse_budget where day = d and purpose = 'all' for update;
  if total >= p_total_cap then return false; end if;
  if p_purpose_cap is not null then
    select used into mine from public.zad_cse_budget where day = d and purpose = p_purpose;
    if coalesce(mine, 0) >= p_purpose_cap then return false; end if;
  end if;
  update public.zad_cse_budget set used = used + 1 where day = d and purpose = 'all';
  insert into public.zad_cse_budget as b (day, purpose, used) values (d, p_purpose, 1)
    on conflict (day, purpose) do update set used = b.used + 1;
  return true;
end;
$function$;

revoke all on function public.zad_cse_take(text, int, int) from public, anon, authenticated;
grant execute on function public.zad_cse_take(text, int, int) to service_role;
