-- Tables the deal-buttons migration (20261026183500) reads, in the shape the live schema has them, on top of
-- scratch_scaffold.sql. Only the columns it touches.
create table public.zad_voice_moments (id uuid primary key default gen_random_uuid(), user_id uuid, moment text, facts jsonb,
  status text default 'pending', created_at timestamptz default now());
create table public.zad_shopping_list (id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text not null,
  quantity integer, is_purchased boolean default false, family_id uuid, created_at timestamptz default now());
-- Live: lower, أشكال الألف، ة ⇒ ه، ى ⇒ ي، و«ال» من أول كل كلمة (20261010140000).
create function public.zad_inventory_name_key(p_name text) returns text language sql immutable as $$
  select array_to_string(array(
    select case when w like 'ال%' and char_length(w) > 2 then substr(w, 3) else w end
      from unnest(regexp_split_to_array(
        translate(lower(btrim(coalesce(p_name, ''))), 'أإآةى', 'اااهي'), '\s+')) w
     where w <> ''), ' ') $$;
