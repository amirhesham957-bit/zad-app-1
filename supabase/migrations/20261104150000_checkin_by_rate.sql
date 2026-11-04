-- «لسه عندك؟» بمعدل استهلاك البيت لما يكون معروف، مش بالحد الثابت (المالك ٤/١١).
--
-- القاعدة كانت «تحت الحد (افتراضي ٢) أو هيخلص في يومين بالمعدل». الحد الافتراضي واحد لكل صنف، فلبن
-- اتضاف بـ١٫٥ كان «قرب يخلص» من أول ثانية، وأربع إزايز مياه عند بيت بيشرب اتنين في اليوم ماكانوش.
-- دلوقتي: لو فيه معدل، المعدل لوحده بيحكم (يومين أو أقل)؛ من غير معدل، الحد زي ما هو. الموبايل
-- (shortage.dart) والبوت اليومي (_shared/consumptionRate.ts) بنفس القاعدة؛ وفوقها الاتنين مابيعدّوش صنف
-- اتضاف النهارده من غير معدل. التريجر ده بيشتغل على UPDATE بس (لحظة العبور)، فالإضافة نفسها مابتسألش.

create or replace function public._inventory_needs_checkin(
  p_quantity numeric, p_threshold numeric, p_avg_daily_qty numeric, p_rate_known boolean)
 returns boolean
 language sql
 immutable
 set search_path = public
as $function$
    select p_quantity > 0
       and case when coalesce(p_avg_daily_qty, 0) > 0
                then p_quantity / p_avg_daily_qty <= 2
                else p_quantity <= coalesce(p_threshold, 2) end;
$function$;
