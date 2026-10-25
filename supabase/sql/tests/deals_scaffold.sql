-- What 20261025234500_deals.sql reads that scratch_scaffold.sql lacks, as live 2026-10-25:
-- the account's country, and zad_inventory_name_key (20261010140000).
alter table public.zad_users add column if not exists country text;

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
