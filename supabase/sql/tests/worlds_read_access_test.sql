-- 20261116030000: per-country read of the public content tables, own row of zad_user_city. Chain: scratch_scaffold,
-- worlds_scaffold, 20261116030000, this file.
\set ON_ERROR_STOP on

insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000c1'), ('00000000-0000-4000-8000-0000000000c2'),
  ('00000000-0000-4000-8000-0000000000c3'), ('00000000-0000-4000-8000-0000000000c4');
insert into zad_users (id, country, travel_country) values
  ('00000000-0000-4000-8000-0000000000c1', 'EG', null),
  ('00000000-0000-4000-8000-0000000000c2', 'SA', null),
  ('00000000-0000-4000-8000-0000000000c3', 'sa', 'EG');  -- lower-case stored + travelling to EG
insert into zad_social_recipes (source_url, handle, country, name) values
  ('https://x/1', 'h', 'EG', 'koshari'), ('https://x/2', 'h', 'SA', 'kabsa'), ('https://x/3', 'h', null, 'nobody');
insert into zad_social_picks (source_url, platform, kind, country, title, expires_at) values
  ('https://p/1', 'tiktok', 'offer', 'EG', 'eg live', now() + interval '1 day'),
  ('https://p/2', 'tiktok', 'offer', 'EG', 'eg expired', now() - interval '1 day'),
  ('https://p/3', 'tiktok', 'offer', 'SA', 'sa live', now() + interval '1 day');
insert into zad_medicine_prices (country, name_key, name, price_low, price_high) values
  ('EG', 'panadol', 'Panadol', 10, 12), ('SA', 'panadol', 'Panadol', 5, 6);
insert into zad_user_city (user_id, country, city) values
  ('00000000-0000-4000-8000-0000000000c1', 'EG', 'القاهرة'), ('00000000-0000-4000-8000-0000000000c2', 'SA', 'الرياض');

-- anon: nothing at all.
set role anon;
do $$ begin
  begin perform 1 from zad_social_recipes; raise exception 'anon read recipes'; exception when insufficient_privilege then null; end;
  begin perform 1 from zad_social_picks; raise exception 'anon read picks'; exception when insufficient_privilege then null; end;
  begin perform 1 from zad_medicine_prices; raise exception 'anon read prices'; exception when insufficient_privilege then null; end;
  begin perform 1 from zad_user_city; raise exception 'anon read city'; exception when insufficient_privilege then null; end;
end $$;

-- c1 (EG): only EG rows, own city, and no writes.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}', false);
do $$ begin
  if (select array_agg(name) from zad_social_recipes) is distinct from array['koshari'] then raise exception 'recipes: %', (select array_agg(name) from zad_social_recipes); end if;
  if (select array_agg(title) from zad_social_picks) is distinct from array['eg live'] then raise exception 'picks: %', (select array_agg(title) from zad_social_picks); end if;
  if (select array_agg(country) from zad_medicine_prices) is distinct from array['EG'] then raise exception 'prices wrong'; end if;
  if (select array_agg(city) from zad_user_city) is distinct from array['القاهرة'] then raise exception 'city: another user visible'; end if;
  begin insert into zad_user_city (user_id, country, city) values ('00000000-0000-4000-8000-0000000000c1', 'EG', 'x'); raise exception 'city write allowed';
  exception when insufficient_privilege then null; end;
  begin insert into zad_social_recipes (source_url, handle, country) values ('https://x/9', 'h', 'EG'); raise exception 'recipe write allowed';
  exception when insufficient_privilege then null; end;
  begin update zad_medicine_prices set price_low = 1; raise exception 'price write allowed';
  exception when insufficient_privilege then null; end;
end $$;

-- c2 (SA): the other side.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c2","role":"authenticated"}', false);
do $$ begin
  if (select array_agg(name) from zad_social_recipes) is distinct from array['kabsa'] then raise exception 'SA recipes'; end if;
  if (select array_agg(city) from zad_user_city) is distinct from array['الرياض'] then raise exception 'SA city'; end if;
end $$;

-- c3 (home SA, travelling EG): both countries.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c3","role":"authenticated"}', false);
do $$ begin
  if (select count(*) from zad_social_recipes) <> 2 then raise exception 'traveller recipes'; end if;
  if (select count(*) from zad_user_city) <> 0 then raise exception 'traveller sees a city that is not theirs'; end if;
end $$;

-- c4: authenticated but no zad_users row -> no country -> nothing.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c4","role":"authenticated"}', false);
do $$ begin
  if (select count(*) from zad_social_recipes) + (select count(*) from zad_social_picks)
     + (select count(*) from zad_medicine_prices) + (select count(*) from zad_user_city) <> 0 then raise exception 'no-profile user saw rows'; end if;
end $$;
reset role;
select 'worlds_read_access_test OK' as result;
