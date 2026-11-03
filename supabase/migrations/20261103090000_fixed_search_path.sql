-- ZAD_PLAN ٨.٥ أمان الإطلاق: الدوال الـ٩ دي كانت من غير search_path ثابت (Supabase advisor
-- function_search_path_mutable، ٣/١١). كلها دوال مساعدة نقية (نص، وقت، كود) بتقرا public بس، فـ
-- public هنا نفس سلوكها النهارده — من غيره دالة ممكن تتنادى بـsearch_path بيحط schema تانية قدام public.
alter function public.zad_companion_care_json(public.zad_companion_care) set search_path = public;
alter function public.zad_habit_trial_amount(text, numeric, text) set search_path = public;
alter function public.zad_habit_trial_behaviour(text) set search_path = public;
alter function public.zad_habit_trial_is_money(text) set search_path = public;
alter function public.zad_habit_trial_times_label(text, integer, integer) set search_path = public;
alter function public.zad_hold_code(text) set search_path = public;
alter function public.zad_in_slot(time, time, integer) set search_path = public;
alter function public.zad_night_slot(time) set search_path = public;
alter function public.zad_redact_lesson(text) set search_path = public;
