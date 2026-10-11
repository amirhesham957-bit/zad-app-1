-- 20261011140000 — قايمة تسوق واحدة للبيت (الموجة ٥، قرار المالك ٢٠٢٦-١٠-١١: «نعم وبقوة»).
--
-- قبل كده كان فيه قايمتين:
--   zad_shopping_list   — قايمة الشخص (RLS: صاحبها بس). دي اللي الفاتورة بتشطب منها،
--                          والعقل بيقراها، و«انت جنب المحل» بيعرفها.
--   shared_grocery_list — قايمة تبويب العيلة. العقل مابيشوفهاش، والفاتورة مابتشطبش منها.
-- والمخزن نفسه مشترك مع العيلة من زمان (family_id + populate_family_inventory + RLS).
--
-- هنا القايمة بتمشي زي المخزن بالظبط:
--   ١. عمود family_id، والتريجر نفسه بتاع المخزن بيملاه من عضوية صاحب الصف (الدالة
--      عامة: بتقرا new.user_id وبتكتب new.family_id، مافيهاش اسم جدول).
--   ٢. RLS «البيت»: صاحب الصف، أو أي حد في عيلته — في القراية والتعديل والمسح والإضافة.
--      الإضافة لازم تبقى بيت كمان: التطبيق بيكتب بـupsert (on conflict id)، وPostgres
--      بيفحص شرط INSERT على الصف المقترح حتى لو هيبقى update. فالأب اللي بيشطب صف الأم
--      كان هيترفض بـ«new row violates row-level security policy» (اتمسك في الاختبار).
--      family_id بيحطه التريجر من عضوية صاحب الصف (BEFORE، والـRLS بيتفحص بعده)، مش من
--      الموبايل، فمحدش يقدر يكتب صف باسم حد برة بيته. الفرق الوحيد عن المخزن: صاحب الصف
--      بيشوف صفه دايماً، حتى لو ساب العيلة (المخزن بيخبّيه عنه في الحالة دي — اتلاحظ
--      ومااتلمسش هنا).
--   ٣. الانضمام للعيلة أو عملها بينادوا zad_inventory_backfill_on_family_join بالفعل،
--      فهي بتنقل القايمة كمان — من غير لمس zad_join_family / zad_create_family.
--   ٤. صفوف shared_grocery_list اللي لسه مااتشترتش بتتنسخ للقايمة. added_by فيها
--      family_members.id (مش user_id) — اتقاس على الحي: صف واحد عضوه موجود، وصف عضوه
--      اتمسح (بيتساب). الجدول القديم مابيتمسحش (مسح جدول قرار لوحده)؛ التطبيق بيبطّل
--      يكتب فيه من الكومِت ده.
--
-- الفهرس الفريد فاضل على (user_id, الاسم) ومش بيتنقل لمستوى البيت عن قصد: لو الأم والأب
-- الاتنين عندهم «لبن» مفتوح، فهرس على البيت كان هيوقّع الانضمام للعيلة نفسه (الـbackfill
-- بيقع في 23505). منع التكرار بين أفراد البيت مكانه اللي بيضيف: نواقص التطبيق التلقائية
-- بتقارن بالقايمة اللي شايفها (بقت قايمة البيت)، والعقل في الشريحة اللي بعدها.

alter table public.zad_shopping_list
  add column if not exists family_id uuid references public.family_groups(id) on delete set null;

create index if not exists idx_zad_shopping_list_family
  on public.zad_shopping_list (family_id) where family_id is not null;

drop trigger if exists trigger_populate_family_shopping on public.zad_shopping_list;
create trigger trigger_populate_family_shopping
  before insert or update on public.zad_shopping_list
  for each row execute function public.populate_family_inventory();

-- الصفوف الموجودة: نفس اللي التريجر كان هيكتبه.
update public.zad_shopping_list s
   set family_id = (select m.family_id from public.family_members m where m.user_id = s.user_id limit 1)
 where s.family_id is distinct from (select m.family_id from public.family_members m where m.user_id = s.user_id limit 1);

drop policy if exists "Users can view their own shopping list" on public.zad_shopping_list;
drop policy if exists "Users can insert their own shopping list" on public.zad_shopping_list;
drop policy if exists "Users can update their own shopping list" on public.zad_shopping_list;
drop policy if exists "Users can delete their own shopping list" on public.zad_shopping_list;

create policy zad_shopping_list_select on public.zad_shopping_list for select
  using ((select auth.uid()) = user_id
         or (family_id is not null and family_id in (select public.get_my_family_ids())));
create policy zad_shopping_list_insert on public.zad_shopping_list for insert
  with check ((select auth.uid()) = user_id
         or (family_id is not null and family_id in (select public.get_my_family_ids())));
create policy zad_shopping_list_update on public.zad_shopping_list for update
  using ((select auth.uid()) = user_id
         or (family_id is not null and family_id in (select public.get_my_family_ids())))
  with check ((select auth.uid()) = user_id
         or (family_id is not null and family_id in (select public.get_my_family_ids())));
create policy zad_shopping_list_delete on public.zad_shopping_list for delete
  using ((select auth.uid()) = user_id
         or (family_id is not null and family_id in (select public.get_my_family_ids())));

-- نص الحي بالظبط (pg_get_functiondef، ٢٠٢٦-١٠-١١) + سطر القايمة.
create or replace function public.zad_inventory_backfill_on_family_join(p_family uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.family_members where user_id = auth.uid() and family_id = p_family
  ) then
    raise exception 'not_a_member';
  end if;
  update public.zad_inventory
     set family_id = p_family
   where user_id = auth.uid() and (family_id is null or family_id <> p_family);
  update public.zad_shopping_list
     set family_id = p_family
   where user_id = auth.uid() and (family_id is null or family_id <> p_family);
end;
$function$;

-- نفس الكسر في المخزن المشترك من يوم ما اتعمل: zad_inventory_insert كان «صاحب الصف بس»،
-- فأي تعديل من فرد على صنف فرد تاني (upsert من التطبيق) كان بيترفض ويقعد في الـoutbox.
-- على الحي فيه عضوين بس في كل العيلات، فمحدش خبطه لسه.
drop policy if exists zad_inventory_insert on public.zad_inventory;
create policy zad_inventory_insert on public.zad_inventory for insert
  with check ((select auth.uid()) = user_id
         or (family_id is not null and family_id in (select public.get_my_family_ids())));

-- قايمة العيلة القديمة ← قايمة البيت. اللي اتشترى خلاص مالوش لازمة يتنقل.
insert into public.zad_shopping_list (user_id, item_name, quantity, is_purchased, created_at)
select m.user_id, btrim(g.item_name), 1, false, coalesce(g.created_at, now())
  from public.shared_grocery_list g
  join public.family_members m on m.id = g.added_by
  join auth.users a on a.id = m.user_id
 where not coalesce(g.is_purchased, false)
   and btrim(coalesce(g.item_name, '')) <> ''
on conflict do nothing;
