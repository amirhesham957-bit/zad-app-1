-- ج٢.٤: ميزانية الرحلة على السيرفر (كانت على الجهاز بس، فبتضيع مع تغيير الموبايل).
-- المبلغ بعملة البلد اللي مسافر ليه. بيتمسح لوحده لما الرحلة تخلص أو تتغيّر الدولة.

alter table public.zad_users add column if not exists travel_budget numeric;
alter table public.zad_users drop constraint if exists zad_users_travel_budget_positive;
alter table public.zad_users
  add constraint zad_users_travel_budget_positive check (travel_budget is null or (travel_budget > 0 and travel_budget < 1e9));

comment on column public.zad_users.travel_budget is
  'ميزانية الرحلة بعملة travel_country. null = مفيش. بتتمسح لما travel_country يتغيّر أو يترجع null.';

create or replace function public.zad_trip_budget_clear() returns trigger language plpgsql as $$
begin
  if new.travel_country is distinct from old.travel_country then new.travel_budget := null; end if;
  return new;
end $$;
drop trigger if exists zad_users_trip_budget_clear on public.zad_users;
create trigger zad_users_trip_budget_clear before update of travel_country on public.zad_users
  for each row execute function public.zad_trip_budget_clear();

create or replace function public.zad_trip_budget_set(p_amount numeric)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_trip text;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  select travel_country into v_trip from public.zad_users where id = v_me;
  if v_trip is null then return jsonb_build_object('ok', false, 'reason', 'not_traveling'); end if;
  if p_amount is not null and (p_amount <= 0 or p_amount >= 1e9) then
    return jsonb_build_object('ok', false, 'reason', 'bad_amount');
  end if;
  update public.zad_users set travel_budget = p_amount where id = v_me;
  return jsonb_build_object('ok', true, 'budget', p_amount);
end $$;

revoke all on function public.zad_trip_budget_set(numeric) from public, anon;
grant execute on function public.zad_trip_budget_set(numeric) to authenticated;
