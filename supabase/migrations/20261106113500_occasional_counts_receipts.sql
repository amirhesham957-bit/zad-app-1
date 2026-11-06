-- «حاجات على فترات» ماكانتش بتشتغل خالص (اتقاس ٦/١١، ZAD_PLAN المرحلة ٣ — الملف السلوكي، المخزن).
--
-- zad_item_is_occasional بيعدّ مرات الشرا من zad_inventory_observations بـ source = 'purchase' بس، والمصدر ده
-- مفيش ولا صف بيه على الحي: الفواتير بتتسجل camera_ocr (٣٨ صف) والإضافة من الشات chat_add (١١). فكل صنف كان
-- «أساسي» والرنجة اللي بتتشرى كل شهرين كانت بتنزل القايمة. نفس المصادر اللي `_shared/restockCycle.ts` بيعتبرها شرا.
-- 'manual' برّه عن قصد: زرار +/− في المخزن تعديل كمية، مش شرا.

create or replace function public.zad_item_is_occasional(p_user uuid, p_item text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with mode as (
    select i.restock_mode
    from zad_inventory i
    where (i.user_id = p_user or i.family_id in (select m.family_id from family_members m where m.user_id = p_user))
      and lower(btrim(i.item_name)) = lower(btrim(p_item))
      and i.restock_mode is not null
    order by (i.user_id = p_user) desc, i.created_at desc nulls last
    limit 1
  ),
  buys as (
    select distinct o.observed_at::date as d
    from zad_inventory_observations o
    where o.user_id = p_user and o.source in ('purchase', 'camera_ocr', 'chat_add')
      and lower(btrim(o.item_name)) = lower(btrim(p_item))
  ),
  gaps as (
    select d - lag(d) over (order by d) as g from buys
  )
  select case
    when (select restock_mode from mode) = 'occasional' then true
    when (select restock_mode from mode) = 'staple' then false
    when (select count(*) from buys) = 1 then (select max(d) from buys) < current_date - 45
    else coalesce((select avg(g) >= 30 from gaps where g is not null), false)
  end;
$$;

revoke all on function public.zad_item_is_occasional(uuid, text) from public, anon, authenticated;
grant execute on function public.zad_item_is_occasional(uuid, text) to service_role;
