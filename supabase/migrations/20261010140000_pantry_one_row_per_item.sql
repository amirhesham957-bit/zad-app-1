-- One pantry row per item (2026-10-10).
--
-- «بلح» showed twice on the owner's pantry — once under البقالة, once under الفواكه, 1 كيلو
-- each. Buying an item again added a row instead of topping the one already there: the
-- brain's `add_inventory_item` and the app's manual add both inserted blindly (only the
-- app's receipt intake matched names). Those writers now match first (zad-brain
-- `pantryMatch.ts`, Flutter `PantryController.add`); this migration merges what is
-- already split.
--
-- The merge is the careful half of the app's rule: only rows of the same account whose
-- names are equal once normalised (`zad_inventory_name_key` — the app's
-- `normalizeItemName`: case, alef forms, taa marbuta, alef maqsura, the article on every
-- word) and whose unit is the same. Looser matches («لبن» / «لبن زبادي») are left alone:
-- a wrong merge loses an item, a missed one only shows it twice. Measured before writing:
-- one such group on production («بلح» ×2); the looser rule found no other pair.
--
-- The newest row of a group stays, with:
--   quantity  = the group's stock added up (each row was a real purchase);
--   category  = a specific one over «عام»/«أخرى»/«البقالة» (الفواكه wins for بلح);
--   expiry    = the earliest among rows that still have stock (the one to use first);
--   threshold = the highest set.
-- The others are deleted with the waste trigger off: their stock moved, it was not
-- thrown away, and `zad_log_inventory_waste` would otherwise log an expired duplicate as
-- waste. Quantities only rise, so the low-stock Telegram trigger (fires on a drop) stays
-- silent.

create or replace function public.zad_inventory_name_key(p_name text)
 returns text
 language sql
 immutable
 parallel safe
as $function$
  select array_to_string(array(
    select case when w like 'ال%' and length(w) > 2 then substr(w, 3) else w end
      from unnest(regexp_split_to_array(lower(translate(trim(coalesce(p_name, '')), 'أإآةى', 'اااهي')), '\s+')) w
     where w <> ''
  ), ' ');
$function$;

alter table public.zad_inventory disable trigger trigger_log_inventory_waste;

with keyed as (
  select i.*,
         public.zad_inventory_name_key(i.item_name) as name_key,
         coalesce(nullif(trim(i.unit), ''), '') as unit_key
    from public.zad_inventory i
), groups as (
  select user_id, name_key, unit_key,
         (array_agg(id order by created_at desc, id desc))[1] as keep_id,
         sum(greatest(coalesce(quantity, 0), 0))::int as total_qty,
         coalesce(
           (array_agg(category order by created_at desc)
             filter (where nullif(trim(category), '') is not null
                       and category not in ('عام', 'أخرى', 'البقالة')))[1],
           (array_agg(category order by created_at desc)
             filter (where nullif(trim(category), '') is not null))[1]
         ) as best_category,
         (array_agg(expiry_date order by public.zad_try_date(expiry_date))
           filter (where coalesce(quantity, 0) > 0 and public.zad_try_date(expiry_date) is not null))[1] as best_expiry,
         max(low_stock_threshold) as best_threshold
    from keyed
   where name_key <> ''
   group by user_id, name_key, unit_key
  having count(*) > 1
), kept as (
  update public.zad_inventory i
     set quantity = g.total_qty,
         category = coalesce(g.best_category, i.category),
         expiry_date = coalesce(g.best_expiry, i.expiry_date),
         low_stock_threshold = coalesce(g.best_threshold, i.low_stock_threshold)
    from groups g
   where i.id = g.keep_id
  returning i.id
)
delete from public.zad_inventory d
 using keyed k, groups g
 where d.id = k.id
   and k.user_id = g.user_id and k.name_key = g.name_key and k.unit_key = g.unit_key
   and d.id <> g.keep_id
   and exists (select 1 from kept where kept.id = g.keep_id);

alter table public.zad_inventory enable trigger trigger_log_inventory_waste;
