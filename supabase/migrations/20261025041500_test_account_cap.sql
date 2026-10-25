-- سقف حساب الاختبار (ZAD_PLAN ٣.٧، ق٣ المالك ٢٤/١٠: «سقف يومي ٢٠ لفة برّه نشرات الدوال»).
--
-- المقاس: ٤٧٥ من ٥٨٢ لفة في ١٤ يوم (٨٢٪) كانت حساب الاختبار، و١٧٣ لفة في يوم واحد (١٨/١٠). فحص القبول بعد
-- كل نشر برّه السقف (zad-brain بيعلّمه بـACCEPTANCE_PROBE)، والتقييم الليلي برّه برضه. أي لفة تانية للحساب
-- ده بتاخد واحدة من هنا الأول؛ اليوم بتوقيت UTC، والعدّ واحد مهما اتعدّدت نسخ الفانكشن.
-- السيرفر بس. رقم الإصدار مش على ساعة مدوّرة عن قصد.

create table if not exists public.zad_test_turn_budget (
  day date primary key,
  used int not null default 0 check (used >= 0)
);

alter table public.zad_test_turn_budget enable row level security;
revoke all on public.zad_test_turn_budget from anon, authenticated;
grant all on public.zad_test_turn_budget to service_role;

create or replace function public.zad_test_turn_take(p_cap int)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  taken int;
begin
  if p_cap is null or p_cap <= 0 then return false; end if;
  insert into public.zad_test_turn_budget as b (day, used)
  values ((now() at time zone 'utc')::date, 1)
  on conflict (day) do update set used = b.used + 1
    where b.used < p_cap
  returning used into taken;
  return taken is not null;
end;
$function$;

revoke all on function public.zad_test_turn_take(int) from public, anon, authenticated;
grant execute on function public.zad_test_turn_take(int) to service_role;
