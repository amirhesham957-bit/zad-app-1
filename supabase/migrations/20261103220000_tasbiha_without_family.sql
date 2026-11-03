-- التسبيحة من غير عيلة (بلاغ المالك ٣/١١: «التسبيحة مش شغالة»). المقاس: ٢١ من ٢٢ حساب مالهمش عيلة، وكل
-- policies بتاعة family_tasbiha كانت `family_id in get_my_family_ids()` — فالتطبيق مابيلاقيش شجرة، وكل ضغطة
-- بتعيد التحميل بس، والعداد مابيتحركش. `family_id` أصلاً nullable، فالشجرة الشخصية = `family_id is null` وصاحبها
-- هو اللي بيقرا ويكتب. increment_tasbiha_clicks بصلاحية المنادي، فالـpolicies دي بس هي اللي بتحكم.

drop policy if exists family_tasbiha_select on public.family_tasbiha;
create policy family_tasbiha_select on public.family_tasbiha for select
  using (family_id in (select public.get_my_family_ids())
         or (family_id is null and user_id = (select auth.uid())));

drop policy if exists family_tasbiha_insert on public.family_tasbiha;
create policy family_tasbiha_insert on public.family_tasbiha for insert
  with check (family_id in (select public.get_my_family_ids())
              or (family_id is null and user_id = (select auth.uid())));

drop policy if exists family_tasbiha_update on public.family_tasbiha;
create policy family_tasbiha_update on public.family_tasbiha for update
  using (family_id in (select public.get_my_family_ids())
         or (family_id is null and user_id = (select auth.uid())))
  with check (family_id in (select public.get_my_family_ids())
              or (family_id is null and user_id = (select auth.uid())));
