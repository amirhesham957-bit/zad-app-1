-- zad_item_preferences (ZAD_PLAN 10.1 slice 4d).
\set ON_ERROR_STOP on
\set me    '''11111111-1111-1111-1111-111111111111'''
\set wife  '''22222222-2222-2222-2222-222222222222'''
\set other '''33333333-3333-3333-3333-333333333333'''

insert into auth.users values (:me), (:wife), (:other);
insert into public.family_groups (id) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
insert into public.family_members (family_id, user_id) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', :me), ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', :wife);
insert into public.zad_inventory (id, user_id, family_id, item_name, quantity) values
  ('00000000-0000-0000-0000-000000000001', :me, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'صوص الترافل', 1),
  ('00000000-0000-0000-0000-000000000002', :other, null, 'صوص ترافل', 1);

set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :me)::text, false);
do $$
declare a jsonb; n int;
begin
  -- Preferred: one per item; setting another replaces it, and clears a rejection of that brand.
  perform public.zad_set_item_preference('الحليب', 'rejected_brand', 'المراعي');
  perform public.zad_set_item_preference('حليب', 'preferred_brand', 'نادك');
  perform public.zad_set_item_preference('حليب', 'preferred_brand', 'المراعي');
  select count(*) into n from public.zad_item_preferences where kind = 'preferred_brand';
  if n <> 1 or (select brand from public.zad_item_preferences where kind = 'preferred_brand') is distinct from 'المراعي' then
    raise exception 'one preferred brand per item, the last said'; end if;
  if exists (select 1 from public.zad_item_preferences where kind = 'rejected_brand') then
    raise exception 'preferring a brand clears its rejection'; end if;

  -- Rejecting the preferred brand clears it.
  perform public.zad_set_item_preference('حليب', 'rejected_brand', 'المراعي');
  if exists (select 1 from public.zad_item_preferences where kind = 'preferred_brand') then
    raise exception 'rejecting the preferred brand clears it'; end if;

  -- Bad input is refused, not stored.
  if (public.zad_set_item_preference('حليب', 'preferred_brand', '  ') ->> 'reason') is distinct from 'brand_needed' then
    raise exception 'a brand kind needs a brand'; end if;
  if (public.zad_set_item_preference('حليب', 'love', 'x') ->> 'reason') is distinct from 'bad_kind' then
    raise exception 'unknown kinds are refused'; end if;

  -- Accidental: the home's rows of that item stop being restocked; another account's are untouched.
  a := public.zad_set_item_preference('صوص ترافل', 'accidental');
  if (a ->> 'marked_occasional')::int <> 1 then raise exception 'accidental: %', a; end if;
  if (select restock_mode from public.zad_inventory where id = '00000000-0000-0000-0000-000000000001') is distinct from 'occasional' then
    raise exception 'the home row is occasional now'; end if;

  -- Writing for someone else is refused; direct writes are refused.
  begin
    perform public.zad_set_item_preference('حليب', 'preferred_brand', 'نادك', '33333333-3333-3333-3333-333333333333');
    raise exception 'writing for another account must be refused';
  exception when raise_exception then
    if sqlerrm <> 'not_authorized' then raise; end if;
  end;
  begin
    insert into public.zad_item_preferences (user_id, item_name, item_key, kind) values (auth.uid(), 'x', 'x', 'accidental');
    raise exception 'a direct insert must be refused';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

do $$
begin
  if (select restock_mode from public.zad_inventory where id = '00000000-0000-0000-0000-000000000002') is not null then
    raise exception 'another account''s row was changed'; end if;
end $$;

-- The wife reads the home's preferences and can clear one; a stranger sees none and clears none.
set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :wife)::text, false);
do $$
declare v uuid;
begin
  if (select count(*) from public.zad_item_preferences) <> 2 then raise exception 'the home reads its preferences'; end if;
  select id into v from public.zad_item_preferences where kind = 'rejected_brand';
  perform set_config('zad.test.pref', v::text, false);
end $$;
select set_config('request.jwt.claims', json_build_object('sub', :other)::text, false);
do $$
begin
  if (select count(*) from public.zad_item_preferences) <> 0 then raise exception 'a stranger reads nothing'; end if;
  if (public.zad_clear_item_preference(current_setting('zad.test.pref')::uuid) ->> 'ok')::boolean then
    raise exception 'a stranger must not clear the home''s preference'; end if;
end $$;
select set_config('request.jwt.claims', json_build_object('sub', :wife)::text, false);
do $$
begin
  if not (public.zad_clear_item_preference(current_setting('zad.test.pref')::uuid) ->> 'ok')::boolean then
    raise exception 'a member clears the home''s preference'; end if;
end $$;
reset role;

-- The server writes for a user by p_user (no JWT, as the brain's service role).
select set_config('request.jwt.claims', '{}', false);
do $$
begin
  if not (public.zad_set_item_preference('شاي', 'preferred_brand', 'ربيع', '33333333-3333-3333-3333-333333333333') ->> 'ok')::boolean then
    raise exception 'service writes for a user'; end if;
end $$;

select 'item_preferences_test passed' as result;
