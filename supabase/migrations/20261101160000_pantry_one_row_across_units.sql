-- One pantry row per item, across the spellings of a unit and of a number (2026-11-01).
--
-- The owner's pantry «مش بيجمع الكميات صح». Measured on production that day: the tea sat in
-- three rows — «شاي اسود 40 جم بروك» [EA] 3, «شاي اسود 40جم بروك» [EA] 2, «شاي اسود 40 جم
-- بروك» [قطعة] 1 — and «طماطم» in two, [كيلو] 0 and [كجم] 3. The 2026-10-10 rule
-- (20261010140000) matched on the name key and the unit written exactly, so «EA» ≠ «قطعة»,
-- «كيلو» ≠ «كجم», and «40جم» ≠ «40 جم». The chat's add (`pantryMatch.ts`) and the app's
-- (`PantryController.add`) refused a match over the unit too, which is how the third tea row
-- was born on 30/10.
--
-- Here, and in the same commit in `pantryMatch.ts` and the app's `normalizeItemName` /
-- `unitKey`:
--   * the name key splits a number off a word («40جم» = «40 جم»);
--   * `zad_inventory_unit_key` folds one unit's spellings (EA/قطعة/حبة/عدد → piece,
--     كجم/كيلو/kg → kg, لتر/l → l); a missing unit is a piece, like the app's default;
--   * the rows already split merge the 2026-10-10 way: the newest row stays with the group's
--     stock added up, a specific category, the earliest live expiry and the highest threshold.
--
-- Still left apart on purpose: different brands of one thing (water ×8 on the owner's pantry —
-- «ماء إيلان», «مياه نستله»…). A wrong merge loses an item; a missed one only shows twice.
-- Measured before writing: these two groups are the only ones on production.
--
-- The consumption readings of a merged row move to the kept name, so the learner reads one
-- history. The waste trigger is off for the deletes (stock moved, nothing was thrown away),
-- and the companion's XP trigger is off for the update (a merge is not a purchase).

create or replace function public.zad_inventory_name_key(p_name text)
 returns text
 language sql
 immutable
 parallel safe
 set search_path = pg_catalog
as $function$
  select array_to_string(array(
    select case when w like 'ال%' and length(w) > 2 then substr(w, 3) else w end
      from unnest(regexp_split_to_array(
             regexp_replace(regexp_replace(
               lower(translate(trim(coalesce(p_name, '')), 'أإآةى', 'اااهي')),
               '([0-9])([^0-9[:space:].])', '\1 \2', 'g'),
               '([^0-9[:space:].])([0-9])', '\1 \2', 'g'),
             '\s+')) w
     where w <> ''
  ), ' ');
$function$;

create or replace function public.zad_inventory_unit_key(p_unit text)
 returns text
 language sql
 immutable
 parallel safe
 set search_path = pg_catalog
as $function$
  select case
    when u in ('', 'ea', 'pc', 'pcs', 'piece', 'قطعة', 'قطعه', 'حبة', 'حبه', 'عدد') then 'piece'
    when u in ('كجم', 'كيلو', 'كيلوجرام', 'كيلوغرام', 'كغ', 'kg') then 'kg'
    when u in ('لتر', 'l', 'liter', 'litre') then 'l'
    else u
  end
  from (select lower(trim(coalesce(p_unit, ''))) as u) s;
$function$;

-- Stored pair keys follow the new key (none had a number stuck to a word on 2026-11-01; the
-- key of a key is the key, so this is safe to run on any row).
update public.zad_product_pairs
   set a_key = public.zad_inventory_name_key(a_key),
       b_key = public.zad_inventory_name_key(b_key)
 where a_key <> public.zad_inventory_name_key(a_key)
    or b_key <> public.zad_inventory_name_key(b_key);

alter table public.zad_inventory disable trigger trigger_log_inventory_waste;
alter table public.zad_inventory disable trigger zad_companion_xp;

create temporary table _zad_pantry_merge on commit drop as
with keyed as (
  select i.*,
         public.zad_inventory_name_key(i.item_name) as name_key,
         public.zad_inventory_unit_key(i.unit) as unit_key
    from public.zad_inventory i
), groups as (
  select user_id, name_key, unit_key,
         (array_agg(id order by created_at desc, id desc))[1] as keep_id,
         sum(greatest(coalesce(quantity, 0), 0)) as total_qty,
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
)
select k.id, k.user_id, k.item_name, g.keep_id, g.total_qty, g.best_category, g.best_expiry, g.best_threshold
  from keyed k
  join groups g on g.user_id = k.user_id and g.name_key = k.name_key and g.unit_key = k.unit_key;

update public.zad_inventory i
   set quantity = m.total_qty,
       category = coalesce(m.best_category, i.category),
       expiry_date = coalesce(m.best_expiry, i.expiry_date),
       low_stock_threshold = coalesce(m.best_threshold, i.low_stock_threshold)
  from _zad_pantry_merge m
 where i.id = m.keep_id and m.id = m.keep_id;

update public.zad_inventory_observations o
   set item_name = keep.item_name
  from _zad_pantry_merge m
  join public.zad_inventory keep on keep.id = m.keep_id
 where m.id <> m.keep_id
   and o.user_id = m.user_id
   and o.item_name = m.item_name
   and o.item_name <> keep.item_name;

delete from public.zad_inventory d
 using _zad_pantry_merge m
 where d.id = m.id and m.id <> m.keep_id;

alter table public.zad_inventory enable trigger trigger_log_inventory_waste;
alter table public.zad_inventory enable trigger zad_companion_xp;
