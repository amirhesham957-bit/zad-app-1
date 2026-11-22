-- ZAD_OR_PLAN م٢.٦: member_id إلزامي على المخزن والتفضيلات والأهداف.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.ci(k text, p text, cid text, u uuid default '11111111-1111-1111-1111-111111111111')
returns jsonb language sql as $$
  select zad_commit_intent(jsonb_build_object('user_id', u, 'kind', k, 'client_event_id', cid, 'payload', p::jsonb)) $$;

\set u1 '11111111-1111-1111-1111-111111111111'
\set u2 '22222222-2222-2222-2222-222222222222'

-- ١) الإلزام والـbackfill.
select pg_temp.check((select count(*) from information_schema.columns where table_schema = 'public'
  and table_name in ('zad_inventory', 'zad_item_preferences', 'agent_goals') and column_name = 'member_id' and is_nullable = 'NO') = 3,
  'member_id is NOT NULL on all three');
select pg_temp.check((select member_id from public.zad_inventory where id = 'e0000000-0000-0000-0000-000000000001')
  = public.zad_self_member(:'u1'), 'old inventory row backfilled with self');
select pg_temp.check((select member_id from public.agent_goals where title = 'هدف قديم') = public.zad_self_member(:'u1'), 'old goal backfilled');
select pg_temp.check((select member_id from public.zad_item_preferences where item_key = 'عيش') = public.zad_self_member(:'u1'), 'old pref backfilled');

-- ٢) التريجر: member_id غايب ⇒ «أنا».
insert into public.zad_item_preferences (user_id, item_name, item_key, kind) values (:'u1', 'رز', 'رز', 'accidental');
select pg_temp.check((select member_id from public.zad_item_preferences where item_key = 'رز') = public.zad_self_member(:'u1'), 'pref defaults to self');
select pg_temp.check((pg_temp.ci('inventory.added', '{"item_name":"زيت","quantity":1,"category":"البقالة"}', 'm1') ->> 'ok')::boolean, 'old client add');
select pg_temp.check((select member_id from public.zad_inventory where item_name = 'زيت') = public.zad_self_member(:'u1'), 'add without member = self');
select pg_temp.check((pg_temp.ci('goal.set', '{"title":"هدف جديد","unit":"count"}', 'm2') ->> 'ok')::boolean, 'old client goal');
select pg_temp.check((select member_id from public.agent_goals where title = 'هدف جديد') = public.zad_self_member(:'u1'), 'goal without member = self');

-- ٣) فرد صالح من البيت، وفرد من بيت تاني، ومؤرشف، ومش UUID.
insert into public.zad_household_members (id, user_id, display_name, kind) values
  ('f0000000-0000-0000-0000-000000000001', :'u1', 'بنت', 'child'),
  ('f0000000-0000-0000-0000-000000000002', :'u1', 'قديم', 'adult');
update public.zad_household_members set archived_at = now() where id = 'f0000000-0000-0000-0000-000000000002';
insert into public.zad_household_members (id, user_id, display_name, kind) values
  ('f0000000-0000-0000-0000-000000000003', :'u2', 'جار', 'child');

select pg_temp.check((pg_temp.ci('inventory.added', '{"item_name":"شيبسي","quantity":1,"category":"البقالة","member_id":"f0000000-0000-0000-0000-000000000001"}', 'm3') ->> 'ok')::boolean, 'add with own member');
select pg_temp.check((select member_id from public.zad_inventory where item_name = 'شيبسي') = 'f0000000-0000-0000-0000-000000000001', 'row carries the chosen member');
select pg_temp.check(pg_temp.ci('inventory.added', '{"item_name":"جبنة","quantity":1,"category":"البقالة","member_id":"f0000000-0000-0000-0000-000000000003"}', 'm4') ->> 'reason' = 'member_not_found', 'other household member refused');
select pg_temp.check(pg_temp.ci('inventory.added', '{"item_name":"جبنة","quantity":1,"category":"البقالة","member_id":"f0000000-0000-0000-0000-000000000002"}', 'm5') ->> 'reason' = 'member_not_found', 'archived member refused');
select pg_temp.check(pg_temp.ci('inventory.added', '{"item_name":"جبنة","quantity":1,"category":"البقالة","member_id":"nope"}', 'm6') ->> 'reason' = 'member_not_found', 'bad uuid refused');
select pg_temp.check((select count(*) from public.zad_inventory where item_name = 'جبنة') = 0, 'refused adds wrote nothing');
select pg_temp.check(pg_temp.ci('goal.set', '{"title":"هدف غريب","member_id":"f0000000-0000-0000-0000-000000000003"}', 'm7') ->> 'reason' = 'member_not_found', 'goal with foreign member refused');
select pg_temp.check((select count(*) from public.agent_goals where title = 'هدف غريب') = 0, 'refused goal wrote nothing');

-- ٤) التزويد على صف موجود بيتجاهل member_id، فرد قديم/غريب مايرفضش.
select pg_temp.check((pg_temp.ci('inventory.added', '{"item_id":"e0000000-0000-0000-0000-000000000001","item_name":"قديم","quantity":2,"category":"البقالة","member_id":"f0000000-0000-0000-0000-000000000003"}', 'm8') ->> 'ok')::boolean, 'top-up with stale member still ok');
select pg_temp.check((select quantity from public.zad_inventory where id = 'e0000000-0000-0000-0000-000000000001') = 3, 'top-up added');
select pg_temp.check((select member_id from public.zad_inventory where id = 'e0000000-0000-0000-0000-000000000001') = public.zad_self_member(:'u1'), 'top-up kept the row member');

-- ٥) الهدف: member_id بيتغير لو اتبعت، ويفضل لو غاب.
select pg_temp.check((pg_temp.ci('goal.set', '{"title":"هدف جديد","member_id":"f0000000-0000-0000-0000-000000000001"}', 'm9') ->> 'ok')::boolean, 'goal re-set with member');
select pg_temp.check((select member_id from public.agent_goals where title = 'هدف جديد') = 'f0000000-0000-0000-0000-000000000001', 'goal member updated');
select pg_temp.check((pg_temp.ci('goal.set', '{"title":"هدف جديد","target_value":9}', 'm10') ->> 'ok')::boolean, 'goal re-set without member');
select pg_temp.check((select member_id from public.agent_goals where title = 'هدف جديد') = 'f0000000-0000-0000-0000-000000000001', 'goal member kept');

-- ٦) الـFK المركب: مفيش كتابة مباشرة بفرد بيت تاني.
do $$ begin
  insert into public.zad_inventory (user_id, member_id, item_name, quantity)
  values ('11111111-1111-1111-1111-111111111111', 'f0000000-0000-0000-0000-000000000003', 'x', 1);
  raise exception 'FAILED: cross-household member accepted';
exception when foreign_key_violation then null;
end $$;

-- ٧) مسح الحساب: صفوف المخزن (من غير FK على auth.users) مابتوقعش مسح الأفراد.
do $$ begin
  delete from auth.users where id = '22222222-2222-2222-2222-222222222222';
exception when others then raise exception 'FAILED: account delete blocked: %', sqlerrm;
end $$;
select pg_temp.check((select count(*) from public.zad_household_members where user_id = '22222222-2222-2222-2222-222222222222') = 0, 'members gone with the account');
select pg_temp.check((select count(*) from public.zad_inventory where user_id = '22222222-2222-2222-2222-222222222222') = 0, 'inventory gone with the account');

select 'member_id_required_test ok';
