-- تنضيف الداتا (ZAD_PLAN ٦.٨): آخر حاجة فاضلة «نقل shared_grocery_list القديم».
--
-- المالك قال «امسح» للتنضيف ده (٢/١١، بعد نسخة). اتقاس ١٣/١١: الجدول فيه صف واحد بس، عيلته من غير ولا عضو وصاحبه
-- حسابه اتحذف — يعني مفيش حد يتنقله. التطبيق مابقاش بيقرا الجدول (family_life_controller.dart: التاب ده
-- بقى على zad_shopping_list من ساعة ما العقل بقى يكتب هناك). الجدول نفسه بيفضل (مفيش كود بيكتب فيه).
--
-- اللي بيتمسح: صف عيلته مالهاش ولا عضو وصاحبه مش في auth.users. نسخة الأول في zad_backup زي ٢/١١.

create schema if not exists zad_backup;
revoke all on schema zad_backup from public, anon, authenticated;

create table if not exists zad_backup.shared_grocery_list_20261113 as
  select * from public.shared_grocery_list where false;

insert into zad_backup.shared_grocery_list_20261113
select s.* from public.shared_grocery_list s
 where not exists (select 1 from public.family_members m where m.family_id = s.family_id)
   and not exists (select 1 from auth.users u where u.id::text = s.added_by::text);

delete from public.shared_grocery_list s
 where not exists (select 1 from public.family_members m where m.family_id = s.family_id)
   and not exists (select 1 from auth.users u where u.id::text = s.added_by::text);
