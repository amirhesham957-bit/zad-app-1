-- قراءة جداول المحتوى العام اللي التطبيق لازم يعرضها (كانت مقفولة للعميل: revoke all من غير سياسات).
-- كلها بتتفلتر على بلد المنادي بالدالة zad_my_countries()، فمحدش بيشوف صف بلد تاني. الكتابة لسه للسيرفر بس.
--
--   zad_social_recipes / zad_social_picks / zad_medicine_prices — محتوى عام لكل بلد، من غير user_id.
--       بلد المنادي = zad_users.country (و travel_country لو مسافر). صف بلا بلد (country null في الوصفات)
--       مش بيتعرض — مش معروف يخص مين.
--   zad_user_city — صف المنادي بس. الجدول فيه اسم مدينة مش نقطة، والكتابة لسه من السيرفر (عشان
--       العميل مايدخّلش كلام في محرك البحث).

create or replace function public.zad_my_countries()
returns text[]
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(array_remove(array[upper(btrim(u.country)), upper(btrim(u.travel_country))], null), '{}')
    from public.zad_users u where u.id = auth.uid()
$$;

revoke all on function public.zad_my_countries() from public, anon;
grant execute on function public.zad_my_countries() to authenticated, service_role;

grant select on public.zad_social_recipes, public.zad_social_picks, public.zad_medicine_prices, public.zad_user_city
  to authenticated;

drop policy if exists zad_social_recipes_my_country on public.zad_social_recipes;
create policy zad_social_recipes_my_country on public.zad_social_recipes for select to authenticated
  using (country in (select unnest(public.zad_my_countries())));

drop policy if exists zad_social_picks_my_country on public.zad_social_picks;
create policy zad_social_picks_my_country on public.zad_social_picks for select to authenticated
  using (country in (select unnest(public.zad_my_countries())) and expires_at > now());

drop policy if exists zad_medicine_prices_my_country on public.zad_medicine_prices;
create policy zad_medicine_prices_my_country on public.zad_medicine_prices for select to authenticated
  using (country in (select unnest(public.zad_my_countries())));

drop policy if exists zad_user_city_own on public.zad_user_city;
create policy zad_user_city_own on public.zad_user_city for select to authenticated
  using (user_id = (select auth.uid()));
