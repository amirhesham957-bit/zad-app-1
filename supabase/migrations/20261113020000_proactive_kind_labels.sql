-- ZAD_PLAN ١٠.٥ «التنبيه يسمع الاختيار»: رد البوت على زرار تحت رسالة زاد بيقول اسم النوع بالكلام.
-- بلاغ المالك (٣/١١، اتقاس ١٣/١١ على الحي): داس «عرفت خلاص» تحت «زادو عطشان» والرد كان
-- «مش هكرر «pet_call» قبل ٣ أيام» — اسم داخلي، لأن الدالة دي ماكانتش تعرف الأنواع اللي اتضافت بعد ١٣/٩.
-- ٧ أنواع بتتبعت من الماسح ومالهاش اسم: pet_call (٤٢٦ مهمة في ٣٠ يوم)، memory_check، restock_link،
-- predicted_shortage، habit_budget، habit_trial، habit_trial_result. نفس الاسم بيتكتب في ملاحظة الذاكرة
-- (zad_memory_record_proactive_dismissal) اللي العقل بيقراها.
create or replace function public._agent_proactive_kind_label(p_kind text)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select case p_kind
    when 'home_weekly_digest' then 'ملخص البيت'
    when 'spend_forecast'     then 'توقّع مصروف الأسبوع'
    when 'spending_ahead'     then 'الصرف أسرع من الميزانية'
    when 'med_followup'       then 'متابعة الدوا'
    when 'bill_reminder'      then 'تذكير الفواتير'
    when 'warranty_reminder'  then 'تذكير الضمان'
    when 'listener_gap_alert' then 'وقوف إشعارات البنك'
    when 'goal_review'        then 'متابعة الهدف'
    when 'store_arrival'      then 'قايمة النواقص جنب المحلات'
    when 'pet_call'           then 'نداء زادو'
    when 'memory_check'       then 'سؤال عن حاجة فاكرها'
    when 'restock_link'       then 'لينك شرا اللي خلص'
    when 'predicted_shortage' then 'حاجات هتخلص قريب'
    when 'habit_budget'       then 'العادة قصاد الميزانية'
    when 'habit_trial'        then 'تجربة عادة'
    when 'habit_trial_result' then 'نتيجة تجربة العادة'
    else p_kind
  end;
$$;
