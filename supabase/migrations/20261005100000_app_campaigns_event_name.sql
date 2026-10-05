-- اسم المناسبة نفسها، للعدّاد التنازلي في الويدجت: «باقي ٣ أيام على الوايت فرايداي».
--
-- banner_title جملة («الوايت فرايداي وصل 🛍️») مينفعش تتحط بعد «على»، فالاسم عمود لوحده.
-- null = الحملة مالهاش عدّاد (الويدجت بيعرض الحملة وهي شغالة بس). الصفوف اللي اتعدّلت من
-- اللوحة مابتتلمسش: التحديث بيملا الاسم لو فاضي بس.

alter table public.app_campaigns
  add column if not exists event_name text
    check (event_name is null or char_length(event_name) between 1 and 40);

comment on column public.app_campaigns.event_name is
  'اسم المناسبة للعدّاد التنازلي («باقي ٣ أيام على <event_name>»). null = من غير عدّاد.';

update public.app_campaigns c
set event_name = n.name
from (values
  ('halloween', 'الهالوين'),
  ('white_friday', 'الوايت فرايداي'),
  ('new_year', 'راس السنة'),
  ('saudi_national_day', 'اليوم الوطني'),
  ('saudi_founding_day', 'يوم التأسيس'),
  ('uae_union_day', 'عيد الاتحاد'),
  ('egypt_october_6', '٦ أكتوبر'),
  ('egypt_july_23', '٢٣ يوليو'),
  ('ramadan', 'رمضان'),
  ('eid_al_fitr', 'عيد الفطر'),
  ('eid_al_adha', 'عيد الأضحى'),
  ('back_to_school', 'رجوع المدارس')
) as n(key, name)
where c.event_key = n.key and c.event_name is null;

-- الخليجي: نفس الأسماء ماعدا راس السنة والمدارس.
update public.app_campaigns set event_name = 'رأس السنة'
  where event_key = 'new_year' and dialect = 'GULF' and event_name = 'راس السنة';
update public.app_campaigns set event_name = 'العودة للمدارس'
  where event_key = 'back_to_school' and dialect = 'GULF' and event_name = 'رجوع المدارس';
