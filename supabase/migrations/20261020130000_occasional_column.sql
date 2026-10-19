-- ZAD_PLAN ٣.١٠ ب — كروت التطبيق (٢٠٢٦-١٠-٢٠).
--
-- الشريحة أ علّمت السيرفر إن الرنجة على فترات، بس التطبيق لسه بيقرا أي صفر كـ«ناقص»: المخزن بيحطها في
-- قايمة التسوق، والموجز بيقول «ناقصك رنجة»، وشريط أمازون بيقترح يطلبها. التطبيق مايشوفش تاريخ الشرا،
-- فالحكم بيوصله على الصف نفسه: عمود محسوب في PostgREST (`select=*,restock_occasional`) بيسأل
-- zad_item_is_occasional عن صاحب الطلب (auth.uid()) بس — مايقدرش يسأل عن حد تاني.

create or replace function public.restock_occasional(i public.zad_inventory)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case when auth.uid() is null then false
              else public.zad_item_is_occasional(auth.uid(), i.item_name) end;
$$;

revoke all on function public.restock_occasional(public.zad_inventory) from public, anon;
grant execute on function public.restock_occasional(public.zad_inventory) to authenticated, service_role;
