-- family_tasbiha as live 2026-11-03 (the columns the policies and the increment touch), with its old family-only
-- policies, on top of scratch_scaffold.sql — and the increment RPC, which runs as the caller.
create table public.family_tasbiha (
  id uuid primary key default gen_random_uuid(), family_id uuid, user_id uuid not null, tree_name text default 'بذرة',
  level int default 1, score int default 0, total_clicks int default 0, garden_name text not null default 'بستاني');
alter table public.family_tasbiha enable row level security;
create policy family_tasbiha_select on public.family_tasbiha for select using (family_id in (select get_my_family_ids()));
create policy family_tasbiha_insert on public.family_tasbiha for insert with check (family_id in (select get_my_family_ids()));
create policy family_tasbiha_update on public.family_tasbiha for update using (family_id in (select get_my_family_ids()));
grant select, insert, update on public.family_tasbiha to authenticated;
create function public.increment_tasbiha_clicks_t(p_tree_id uuid, p_delta int) returns public.family_tasbiha
language plpgsql set search_path to 'public' as $$
declare result family_tasbiha;
begin
  update family_tasbiha set total_clicks = total_clicks + p_delta, score = score + p_delta where id = p_tree_id returning * into result;
  if not found then raise exception 'not visible'; end if;
  return result;
end $$;
grant execute on function public.increment_tasbiha_clicks_t(uuid, int) to authenticated;
