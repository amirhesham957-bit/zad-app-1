-- ZAD_PLAN ٥.٥ (ب): نداء الرفيق. بعد scratch_scaffold.sql، 20261020090000_companion_care.sql،
-- pet_call_scaffold.sql، و20261020100000_pet_call.sql.

\set ON_ERROR_STOP on

insert into auth.users (id) values
  ('00000000-0000-4000-8000-0000000000a1'),  -- جعان، على تليجرام، مش فاتح التطبيق
  ('00000000-0000-4000-8000-0000000000a2'),  -- جعان بس فاتح التطبيق من ساعة
  ('00000000-0000-4000-8000-0000000000a3'),  -- شبعان وريّان
  ('00000000-0000-4000-8000-0000000000a4'),  -- عطشان، موبايل بإشعارات بس
  ('00000000-0000-4000-8000-0000000000a5');  -- جعان ومالوش أي قناة

insert into zad_companion_care (user_id, fed_at, watered_at) values
  ('00000000-0000-4000-8000-0000000000a1', now() - interval '18 hours', now() - interval '1 hour'),
  ('00000000-0000-4000-8000-0000000000a2', now() - interval '18 hours', now() - interval '1 hour'),
  ('00000000-0000-4000-8000-0000000000a3', now() - interval '2 hours', now() - interval '2 hours'),
  ('00000000-0000-4000-8000-0000000000a4', now() - interval '3 hours', now() - interval '12 hours'),
  ('00000000-0000-4000-8000-0000000000a5', now() - interval '18 hours', now() - interval '1 hour');

insert into telegram_bindings (user_id, chat_id) values
  ('00000000-0000-4000-8000-0000000000a1', 1), ('00000000-0000-4000-8000-0000000000a2', 2),
  ('00000000-0000-4000-8000-0000000000a3', 3);
insert into zad_fcm_tokens (user_id, token) values ('00000000-0000-4000-8000-0000000000a4', 'tok-a4');
insert into zad_product_events (user_id, name, at) values
  ('00000000-0000-4000-8000-0000000000a2', 'app_open', now() - interval '1 hour'),
  -- فتح قديم مايمنعش.
  ('00000000-0000-4000-8000-0000000000a1', 'app_open', now() - interval '20 hours');

do $$
declare n int; got text;
begin
  n := zad_enqueue_pet_calls();
  select string_agg(right(user_id::text, 2) || ':' || task_description, ',' order by user_id) into got
  from agent_tasks where kind = 'pet_call';
  if got is distinct from 'a1:hungry,a4:thirsty' then
    raise exception 'expected a1:hungry,a4:thirsty, got % (n=%)', got, n;
  end if;

  -- مرة واحدة: النداء التاني في نفس الساعة مابيضيفش.
  n := zad_enqueue_pet_calls();
  if n <> 0 then raise exception 'second run queued % more', n; end if;

  -- اتبعت النهارده: مفيش تاني لحد ٢٠ ساعة.
  update agent_tasks set status = 'done' where kind = 'pet_call';
  n := zad_enqueue_pet_calls();
  if n <> 0 then raise exception 'a done call today did not hold the next: %', n; end if;

  -- اتلغت (اتأكل في النص): ماتتحسبش، والنداء يرجع لو لسه جعان.
  update agent_tasks set status = 'cancelled'
   where kind = 'pet_call' and user_id = '00000000-0000-4000-8000-0000000000a1';
  n := zad_enqueue_pet_calls();
  if n <> 1 then raise exception 'a cancelled call held the next: %', n; end if;
end $$;

-- العميل مايقدرش يندهها.
set role authenticated;
do $$ begin
  begin
    perform zad_enqueue_pet_calls();
    raise exception 'authenticated could queue pet calls';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- مؤشر الرجوع: a1 بدأ من ٣ أيام وأكّل الرفيق ورجع تاني يوم؛ a3 بدأ من ٣ أيام ومارجعش.
delete from zad_product_events;
insert into zad_product_events (user_id, name, at) values
  ('00000000-0000-4000-8000-0000000000a1', 'app_open', now() - interval '3 days'),
  ('00000000-0000-4000-8000-0000000000a1', 'pet.feed', now() - interval '3 days'),
  ('00000000-0000-4000-8000-0000000000a1', 'app_open', now() - interval '2 days'),
  ('00000000-0000-4000-8000-0000000000a3', 'app_open', now() - interval '3 days');
do $$
declare r jsonb := zad_pet_retention();
begin
  if (r -> 'pet_carers' ->> 'cohort_d1')::int <> 1 or (r -> 'pet_carers' ->> 'returned_d1')::int <> 1 then
    raise exception 'pet carers side wrong: %', r; end if;
  if (r -> 'others' ->> 'cohort_d1')::int <> 1 or (r -> 'others' ->> 'returned_d1')::int <> 0 then
    raise exception 'others side wrong: %', r; end if;
end $$;

select 'pet_call_test: ok';
