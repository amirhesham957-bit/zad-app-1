-- ترندات المنطقة (قرار المالك ٢٠٢٦-٠٩-٣٠): إيه اللي البيوت في نفس السوق بتشتريه وبتحتاجه
-- اليومين دول — بشرط الحد الأدنى: الصنف مايظهرش غير لو ٥ بيوت مختلفة على الأقل عندهم.
--
-- الإشارة: سطور الفواتير والأسعار (price_index — اللي اتشرى فعلاً وفين) + قايمة
-- التسوق (zad_shopping_list — اللي محتاجينه). المنطقة: بلد السوق (zad_users.country)؛
-- المدينة لسه قليلة في الداتا (صفّين في zad_customer_profile) فمش هتعدّي الحد.
--
-- الخصوصية هي التصميم نفسه، مش إضافة:
--   * الوحدة «بيت» مش «عميل»: عيلة (family_members) = بيت واحد، فعيلة من ٥ ماتعدّيش
--     الحد لوحدها.
--   * الحد ثابت جوه الدالة العامة. الداخلية (_zad_area_trends) بتاخده كمعامل للتجربة
--     ومقفولة على service_role — لو العميل يقدر يبعت p_min = 1 كان هيشوف صنف بيت واحد.
--   * العدد الأسبق (previous) بيتقال بس لو هو كمان ≥ الحد، وإلا الاتجاه «new» — عشان
--     الفرق بين الفترتين مايكشفش بيت.
--   * مفيش أسماء محلات ولا أسعار ولا مين — صنف وعدد بيوت واتجاه بس.

create or replace function public._zad_area_trends(p_country text, p_days integer, p_min integer)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'public'
as $function$
with win as (
  select greatest(7, least(coalesce(p_days, 14), 60)) as d
),
area_users as (
  select u.id as user_id, coalesce(fm.family_id::text, u.id::text) as household
  from public.zad_users u
  join auth.users a on a.id = u.id
  left join public.family_members fm on fm.user_id = u.id
  where upper(btrim(u.country)) = upper(btrim(p_country))
),
signals as (
  select a.household, p.item_name as name, p."timestamp" as at
    from public.price_index p
    join area_users a on a.user_id = p.user_id
   where p."timestamp" > now() - make_interval(days => 2 * (select d from win))
  union all
  select a.household, s.item_name, s.created_at
    from public.zad_shopping_list s
    join area_users a on a.user_id = s.user_id
   where s.created_at > now() - make_interval(days => 2 * (select d from win))
),
keyed as (
  -- نفس تطبيع الأسماء اللي في lowStock.ts: مسافات، حروف صغيرة، ألف/تاء مربوطة/ياء.
  select household, name, at,
    translate(lower(regexp_replace(btrim(name), '\s+', ' ', 'g')), 'أإآةى', 'اااهي') as k
  from signals
  where char_length(btrim(coalesce(name, ''))) >= 2
),
per_item as (
  select k,
    mode() within group (order by btrim(name)) as name,
    count(distinct household) filter (where at > now() - make_interval(days => (select d from win))) as now_h,
    count(distinct household) filter (where at <= now() - make_interval(days => (select d from win))) as before_h
  from keyed
  group by k
)
select jsonb_build_object(
  'country', upper(btrim(p_country)),
  'days', (select d from win),
  'min_households', p_min,
  'items', coalesce((
    select jsonb_agg(jsonb_build_object(
      'item', name,
      'households', now_h,
      'previous', case when before_h >= p_min then before_h end,
      'trend', case
        when before_h < p_min then 'new'
        when now_h > before_h then 'up'
        when now_h < before_h then 'down'
        else 'flat' end
    ) order by now_h desc, name)
    from per_item where now_h >= p_min
  ), '[]'::jsonb)
);
$function$;

-- الدالة العامة: الحد ٥ ثابت. عميل مسجّل بيسأل عن نفسه بس؛ service_role (العقل) عن أي حد.
create or replace function public.zad_area_trends(p_user uuid, p_days integer default 14)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
declare
  v_country text;
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select nullif(btrim(country), '') into v_country from public.zad_users where id = p_user;
  if v_country is null then
    return jsonb_build_object('country', null, 'days', p_days, 'min_households', 5,
                              'items', '[]'::jsonb, 'reason', 'no_market');
  end if;
  return public._zad_area_trends(v_country, p_days, 5);
end;
$function$;

revoke execute on function public._zad_area_trends(text, integer, integer) from public, anon, authenticated;
grant execute on function public._zad_area_trends(text, integer, integer) to service_role;
revoke execute on function public.zad_area_trends(uuid, integer) from public, anon;
grant execute on function public.zad_area_trends(uuid, integer) to authenticated, service_role;
