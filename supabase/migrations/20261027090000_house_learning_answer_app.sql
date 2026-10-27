-- «صح / مش صح» من إشعار التطبيق (ZAD_PLAN ٥.٢، آخر شريحة؛ بنفس شكل zad_habit_trial_answer في 20261027080000).
--
-- الجواب كان من تليجرام بس (zad_house_learning_answer_service بالـservice role من البوت). البيت اللي معاه التطبيق بس
-- كان بيسمع «اتعلمت إن… صح؟» في الملخص ومالوش زرار يرد بيه. دلوقتي التطبيق بيرد بجلسة العميل نفسه: الملكية من
-- auth.uid()، مش من id جاي من الجهاز.

create or replace function public.zad_house_learning_answer(p_learning uuid, p_yes boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  return public.zad_house_learning_answer_service(auth.uid(), p_learning, p_yes);
end
$fn$;

revoke all on function public.zad_house_learning_answer(uuid, boolean) from public, anon;
grant execute on function public.zad_house_learning_answer(uuid, boolean) to authenticated, service_role;
