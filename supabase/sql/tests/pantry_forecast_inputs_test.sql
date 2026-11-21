-- م٣.١: zad_pantry_forecast_inputs — كمية الصنف ومعدله المبدئي وقرايات البيت كله، للـservice role بس.
\set ON_ERROR_STOP on
\set me    '''11111111-1111-1111-1111-111111111111'''
\set wife  '''22222222-2222-2222-2222-222222222222'''
\set other '''33333333-3333-3333-3333-333333333333'''

insert into auth.users values (:me), (:wife), (:other);
insert into public.zad_users (id, country) values (:me, 'EG'), (:wife, 'EG'), (:other, 'EG');
insert into public.family_groups (id) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
insert into public.family_members (family_id, user_id) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', :me), ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', :wife);
insert into public.zad_customer_profile (user_id, household_size) values (:me, 2);

insert into public.zad_inventory (id, user_id, family_id, item_name, quantity, unit, created_at) values
  ('00000000-0000-0000-0000-000000000001', :me, null, 'عيش', 10, 'رغيف', now()),
  ('00000000-0000-0000-0000-000000000002', :me, null, 'خيار', 2, 'قطعة', now()),
  ('00000000-0000-0000-0000-000000000003', :me, null, 'سكر', 0, 'قطعة', now()),
  ('00000000-0000-0000-0000-000000000004', :wife, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'مكرونة', 3, 'قطعة', now()),
  ('00000000-0000-0000-0000-000000000005', :other, null, 'عيش', 40, 'رغيف', now());
insert into public.zad_inventory_observations (user_id, item_name, qty, observed_at, source) values
  (:me,    'عيش', 20, now() - interval '3 days', 'purchase'),
  (:wife,  'عيش', 12, now() - interval '1 days', 'question_answer'),  -- الزوجة قرت عيش البيت
  (:me,    'عيش', 30, now() - interval '200 days', 'purchase'),       -- أقدم من ٩٠ يوم
  (:other, 'عيش', 1,  now() - interval '2 days', 'manual');           -- بيت تاني

do $$
declare r record; n int;
begin
  select count(*) into n from public.zad_pantry_forecast_inputs('11111111-1111-1111-1111-111111111111');
  if n <> 3 then raise exception 'bread, cucumber and the family pasta (sugar is empty): got %', n; end if;

  select * into r from public.zad_pantry_forecast_inputs('11111111-1111-1111-1111-111111111111') where item_name = 'عيش';
  if r.quantity <> 10 or r.unit <> 'رغيف' then raise exception 'bread row: %', row_to_json(r); end if;
  if r.prior_daily <> 5 then raise exception 'bread prior for two = 5 a day, got %', r.prior_daily; end if;
  if jsonb_array_length(r.readings) <> 2 then raise exception 'two home readings in 90 days, not the old one nor the other home: %', r.readings; end if;
  if (r.readings -> 0 ->> 'qty')::numeric <> 20 or (r.readings -> 1 ->> 'qty')::numeric <> 12 then
    raise exception 'readings oldest first: %', r.readings;
  end if;

  select * into r from public.zad_pantry_forecast_inputs('11111111-1111-1111-1111-111111111111') where item_name = 'خيار';
  if r.prior_daily is not null or r.readings <> '[]'::jsonb then raise exception 'cucumber: no prior, no readings: %', row_to_json(r); end if;
end $$;

-- العميل نفسه مايقدرش يناديها: البيانات بتعدّي من العقل بس.
set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :me)::text, false);
do $$
begin
  perform public.zad_pantry_forecast_inputs('33333333-3333-3333-3333-333333333333');
  raise exception 'authenticated must not execute zad_pantry_forecast_inputs';
exception when insufficient_privilege then null;
end $$;
reset role;

select 'pantry_forecast_inputs: all checks passed';
