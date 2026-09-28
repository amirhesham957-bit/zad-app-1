-- «مين في رعايتك» — الابن اللي مسؤول عن أبوه وأمه مش هو رب الأسرة اللي مسؤول عن عيال.
--
-- ملف العميل كان فيه «الدور في البيت» (أب، أم، ابن…) و«عدد العيال» بس. مفيش مكان يتقال
-- فيه «أنا مسؤول عن أبويا وأمي»، فالعقل كان بيفترض إن اللي بيكلمه رب أسرة عنده عيال،
-- ومابيعرفش ياخد باله من دوا أو مواعيد الأهل الكبار. العمود ده بيقول مين في رعاية العميل؛
-- العقل بيقراه في كل لفة (customerCard / addressingBlock)، والتطبيق بيسأل عنه مرة واحدة
-- في شاشة «عرّفني بيك» الإجبارية.
--
-- null = لسه ماتسألش. مصفوفة فاضية = مسؤول عن نفسه بس.

alter table public.zad_customer_profile
  add column if not exists cares_for text[];

alter table public.zad_customer_profile
  drop constraint if exists zad_customer_profile_cares_for_check;
alter table public.zad_customer_profile
  add constraint zad_customer_profile_cares_for_check
  check (cares_for is null or cares_for <@ array['children', 'parents', 'spouse', 'siblings', 'grandparents']::text[]);
