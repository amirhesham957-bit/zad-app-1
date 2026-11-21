-- م٣.١ (ZAD_OR_PLAN): مدخلات تنبؤ المخزن لكل صنف عند البيت، للعقل والبوت (service role بس).
-- الحساب نفسه (TSB + المعدل المبدئي + النطاق) في `_shared/or/pantryForecast.ts`؛ هنا قراية بس، مفيش كتابة.
--
-- لكل صنف كميته فوق الصفر ومش «على فترات»: الكمية والوحدة، والمعدل المبدئي للبيت (أفراد × استهلاك الفرد ÷ العبوة،
-- `private.zad_pantry_prior_daily`، null لو النوع مش معروف)، وقرايات المستوى آخر ٩٠ يوم من كل أفراد البيت بنفس
-- اسم الصنف أو اسمه الموحّد، الأقدم الأول. نفس نطاق البيت اللي `private.zad_pantry_prior_days` بيستعمله.

create or replace function public.zad_pantry_forecast_inputs(p_user uuid)
returns table (item_name text, quantity numeric, unit text, prior_daily numeric, readings jsonb)
language sql
stable
security definer
set search_path = public
as $$
  with fam as (
    select f.family_id from public.family_members f where f.user_id = p_user
  ),
  home as (
    select p_user as uid
    union
    select m.user_id from public.family_members m where m.family_id in (select family_id from fam) and m.user_id is not null
  ),
  ppl as (select private.zad_household_people(p_user) as n),
  inv as (
    select i.id, i.item_name, i.quantity, i.unit,
           private.zad_product_canonical_for(p_user, i.item_name) as canon
      from public.zad_inventory i
     where (i.user_id = p_user or (i.family_id is not null and i.family_id in (select family_id from fam)))
       and i.quantity > 0
       and i.restock_mode is distinct from 'occasional'
     order by i.id
     limit 400
  )
  select inv.item_name,
         inv.quantity,
         inv.unit,
         private.zad_pantry_prior_daily(inv.item_name, inv.unit, (select n from ppl)),
         coalesce((
           select jsonb_agg(jsonb_build_object('qty', o.qty, 'at', o.observed_at) order by o.observed_at)
             from public.zad_inventory_observations o
            where o.user_id in (select uid from home)
              and o.item_name in (inv.canon, inv.item_name)
              and o.observed_at > now() - interval '90 days'
         ), '[]'::jsonb)
    from inv;
$$;

revoke all on function public.zad_pantry_forecast_inputs(uuid) from public, anon, authenticated;
grant execute on function public.zad_pantry_forecast_inputs(uuid) to service_role;
