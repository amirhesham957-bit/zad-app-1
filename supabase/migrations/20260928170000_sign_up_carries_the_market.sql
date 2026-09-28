-- The account is born with its market: the provisioning trigger reads the country
-- and currency the sign-up form sent as user metadata.
--
-- Why (2026-09-28): the owner reported "no country entry at sign-up", and two live
-- accounts had country = null. The Flutter client asked for the market only after the
-- first sign-in, through a gate that — by design — opens the app anyway when the
-- server cannot be reached within 8s. On a slow first launch that skipped the question
-- and left the account on UTC. The form now asks, and this makes the answer land in
-- the same transaction that creates the row, so no later screen or network can lose it.
--
-- Validated to the shapes zad_users already holds (ISO alpha-2 / ISO 4217, upper case);
-- anything else is stored as null, exactly as before — the in-app picker still covers it.

create or replace function public.zad_provision_user_row()
returns trigger
language plpgsql
security definer          -- auth.users triggers run outside any user's RLS context
set search_path = public
as $$
declare
  v_country  text := upper(trim(coalesce(new.raw_user_meta_data ->> 'country', '')));
  v_currency text := upper(trim(coalesce(new.raw_user_meta_data ->> 'currency', '')));
begin
  if v_country !~ '^[A-Z]{2}$' then v_country := null; end if;
  if v_currency !~ '^[A-Z]{3}$' or v_country is null then v_currency := null; end if;

  -- on conflict do nothing: signUp()'s own upsert may win the race, and a customer who
  -- signs up, deletes, and re-registers under the same id must not error out here.
  insert into public.zad_users (id, name, country, currency)
  values (
    new.id,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'name',
                         new.raw_user_meta_data ->> 'full_name', '')), ''),
    v_country,
    v_currency
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
