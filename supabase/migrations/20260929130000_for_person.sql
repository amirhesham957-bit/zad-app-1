-- «لمين؟» — دوا ماما، دكتور بابا، تطعيم يوسف (طلب المالك ٢٠٢٦-٠٩-٢٨).
--
-- المالك: زاد يدير «أولاده وأبوه وأمه» — أدويتهم ومواعيدهم — من غير ما كل واحد يعمل حساب.
-- المقيس ٢٠٢٦-٠٩-٢٩: family_members مافيهوش اسم أصلاً وكل صف فيه متربط بحساب (عضوية سيرفر
-- بس، 20260921130000)، فمفيش مكان لـ«ماما». zad_pharmacy_items.family_member_id بيشاور على عضو
-- بحساب بس.
--
-- الأبسط اللي بيدّي القيمة: اسم حر للشخص على الدوا والميعاد. مفيش جدول معالين ولا شاشة إدارة:
-- الاسم بيتكتب في الفورم («لمين؟») أو العقل بيحطه من الكلام («أمي بتاخد دوا الضغط الساعة ٤»)،
-- والعقل بيجمّع باسم الشخص في الـsnapshot. null = العميل نفسه (السلوك القديم بالظبط).
-- جدول معالين كامل (سن، حساسية، مصروف لكل شخص) يستاهل لما الاسم الحر يبان إنه مش كفاية.
--
-- الاسم بيانات من العميل: ١–٤٠ حرف، والعقل بيقراه جوه السياق كبيانات.

alter table public.zad_pharmacy_items
  add column if not exists for_person text;
alter table public.zad_appointments
  add column if not exists for_person text;

alter table public.zad_pharmacy_items
  drop constraint if exists zad_pharmacy_items_for_person_len;
alter table public.zad_pharmacy_items
  add constraint zad_pharmacy_items_for_person_len
  check (for_person is null or char_length(btrim(for_person)) between 1 and 40);

alter table public.zad_appointments
  drop constraint if exists zad_appointments_for_person_len;
alter table public.zad_appointments
  add constraint zad_appointments_for_person_len
  check (for_person is null or char_length(btrim(for_person)) between 1 and 40);

comment on column public.zad_pharmacy_items.for_person is
  'لمين الدوا ده باسم العميل («ماما»، «يوسف»). null = العميل نفسه.';
comment on column public.zad_appointments.for_person is
  'لمين الميعاد ده باسم العميل («بابا»، «يوسف»). null = العميل نفسه.';
