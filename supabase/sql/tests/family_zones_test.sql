-- Children's school zones by consent (migration 20261003110000, docs/agent/ZAD_LIVING_BRAIN.md
-- slice 2), on a scratch database — see family_zones_scaffold.sql for the order.
-- P is the parent (admin), C a child, A an adult member (role member), O an outsider in
-- another family. Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'),('00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000d1'),('00000000-0000-0000-0000-0000000000f1') on conflict do nothing;
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000a1', 'EGP', 'EG'), ('00000000-0000-0000-0000-0000000000c1', 'EGP', 'EG'),
  ('00000000-0000-0000-0000-0000000000d1', 'EGP', 'EG'), ('00000000-0000-0000-0000-0000000000f1', 'EGP', 'EG')
  on conflict (id) do update set country = excluded.country;
insert into public.family_groups (id) values ('00000000-0000-0000-0000-00000000fa01'), ('00000000-0000-0000-0000-00000000fa02');
insert into public.family_members (family_id, user_id, role, alias) values
  ('00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-0000000000a1', 'admin', 'بابا'),
  ('00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-0000000000c1', 'child', 'يوسف'),
  ('00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-0000000000d1', 'member', 'ماما'),
  ('00000000-0000-0000-0000-00000000fa02', '00000000-0000-0000-0000-0000000000f1', 'admin', 'غريب');

create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', case p
    when 'P' then '00000000-0000-0000-0000-0000000000a1' when 'C' then '00000000-0000-0000-0000-0000000000c1'
    when 'A' then '00000000-0000-0000-0000-0000000000d1' when 'O' then '00000000-0000-0000-0000-0000000000f1' end,
    'role', 'authenticated')::text, false);
end $$;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
grant execute on function pg_temp.who(text) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
\set QUIET 0

set role authenticated;

-- 1. Play: an adult's location cannot even be asked for.
select pg_temp.who('P');
select pg_temp.check((zad_family_request_share('00000000-0000-0000-0000-0000000000d1', array['location']) ->> 'requested')::int = 0, 'location is not requestable for an adult (spouse included)');
select pg_temp.check((zad_family_member_view('00000000-0000-0000-0000-0000000000d1') ->> 'can_follow_location')::boolean = false, 'the adult view says location cannot be followed');
select pg_temp.check((zad_family_member_view('00000000-0000-0000-0000-0000000000c1') ->> 'can_follow_location')::boolean = true, 'the child view says it can');

-- 2. Nothing before the child's yes.
select pg_temp.check((zad_family_request_share('00000000-0000-0000-0000-0000000000c1', array['location']) ->> 'requested')::int = 1, 'parent asks the child');
select pg_temp.check((zad_family_zone_save('00000000-0000-0000-0000-0000000000c1', 'المدرسة', 'school', 30.0444, 31.2357) ->> 'reason') = 'not_granted', 'no zone before the yes');

select pg_temp.who('C');
select pg_temp.check((zad_family_answer_share((select id from zad_family_shares where scope = 'location'), true) ->> 'ok')::boolean, 'child agrees');

-- 3. Zones: the parent sets them, the child is told and sees them.
select pg_temp.who('P');
select pg_temp.check((zad_family_zone_save('00000000-0000-0000-0000-0000000000c1', 'المدرسة', 'school', 30.0444, 31.2357, 200, array[0,1,2,3,4,5,6], '00:00', '23:59') ->> 'ok')::boolean, 'parent saves the school zone');
select pg_temp.check((zad_family_zone_save('00000000-0000-0000-0000-0000000000c1', '', 'school', 30, 31) ->> 'reason') = 'bad_label', 'empty label refused');
select pg_temp.check((zad_family_zone_save('00000000-0000-0000-0000-0000000000c1', 'النادي', 'club', 30, 31, 50) ->> 'reason') = 'bad_radius', 'radius under 100 m refused');
select pg_temp.check((zad_family_zone_save('00000000-0000-0000-0000-0000000000c1', 'النادي', 'club', 30, 31, 150, array[0,1], '15:00', '09:00') ->> 'reason') = 'bad_window', 'inverted hours refused');

select pg_temp.who('C');
select pg_temp.check(exists (select 1 from app_notifications where user_id = '00000000-0000-0000-0000-0000000000c1' and title like '📍%'), 'child told about the new zone');
select pg_temp.check(jsonb_array_length(zad_family_my_zones() -> 'zones') = 1, 'child phone gets the zone');
select pg_temp.check((zad_family_my_zones() -> 'watchers' ->> 0) = 'بابا', 'and who watches, for the ongoing notification');
select pg_temp.check((select count(*) from zad_family_zones) = 1, 'child can read the zone about them');
do $$ begin
  insert into zad_family_zones (family_id, member_id, created_by, label, lat, lng)
  values ('00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c1', 'x', 0, 0);
  raise exception 'FAIL: client wrote a zone';
exception when insufficient_privilege then raise notice 'ok: no client writes on zones'; end $$;

-- 4. Leaving inside the window alerts the parent once; a duplicate and a jitter do not.
select (now() - interval '1 minute')::text as left_at \gset
select pg_temp.check((zad_family_zone_event((select id from zad_family_zones), 'exit', :'left_at') ->> 'alert') = 'exit', 'leaving school alerts');
select pg_temp.check((zad_family_zone_event((select id from zad_family_zones), 'exit', :'left_at') ->> 'status') = 'duplicate', 'a re-sent event is not recorded twice');
select pg_temp.check((zad_family_zone_event((select id from zad_family_zones), 'enter', now() - interval '30 seconds') ->> 'alert') = 'back', 'coming back after an alerted exit says so');
select pg_temp.check((zad_family_zone_event((select id from zad_family_zones), 'exit', now() - interval '10 seconds') ->> 'status') = 'recorded', 'a second exit within the hour is recorded, not alerted');
select pg_temp.check((zad_family_zone_event((select id from zad_family_zones), 'exit', now() - interval '2 hours') ->> 'status') = 'recorded', 'a stale event is recorded, not alerted');
select pg_temp.check((zad_family_zone_event((select id from zad_family_zones), 'exit', now() + interval '1 hour') ->> 'reason') = 'stale', 'an event from the future is refused');
reset role;
select pg_temp.check((select count(*) from zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000a1' and moment = 'family_zone_exit') = 1, 'one exit moment for the parent');
select pg_temp.check((select count(*) from zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000a1' and moment = 'family_zone_back') = 1, 'one back moment for the parent');
select pg_temp.check((select facts ->> 'zone_label' = 'المدرسة' and facts ->> 'member_alias' = 'يوسف' from zad_voice_moments where moment = 'family_zone_exit'), 'the moment names the child and the zone');
select pg_temp.check(not exists (select 1 from zad_voice_moments where user_id <> '00000000-0000-0000-0000-0000000000a1'), 'nobody else is told');
set role authenticated;

-- 5. Outside the alert hours: recorded, not alerted.
select pg_temp.who('P');
select pg_temp.check((zad_family_zone_save('00000000-0000-0000-0000-0000000000c1', 'النادي', 'club', 30.05, 31.24, 150,
  array[(extract(dow from now() at time zone 'Africa/Cairo')::int + 1) % 7], '07:00', '08:00') ->> 'ok')::boolean, 'a zone watched only tomorrow');
select pg_temp.who('C');
select pg_temp.check((zad_family_zone_event((select id from zad_family_zones where label = 'النادي'), 'exit', now()) ->> 'status') = 'recorded', 'leaving outside its days is not an alert');

-- 6. What the parent sees, and what others do not.
select pg_temp.who('P');
select pg_temp.check((zad_family_member_view('00000000-0000-0000-0000-0000000000c1') -> 'location' -> 'zones' -> 0 ->> 'state') in ('inside', 'left'), 'parent sees the last state per zone');
select pg_temp.check((select count(*) from zad_family_zone_events) >= 5, 'parent reads the events');
select pg_temp.who('A');
select pg_temp.check((select count(*) from zad_family_zones) = 0, 'an adult who was not granted sees no zone');
select pg_temp.check((select count(*) from zad_family_zone_events) = 0, 'nor any event');
select pg_temp.check((zad_family_zone_save('00000000-0000-0000-0000-0000000000c1', 'x', 'other', 30, 31) ->> 'reason') = 'not_granted', 'nor can set one');
select pg_temp.who('O');
select pg_temp.check((select count(*) from zad_family_zones) = 0, 'an outsider sees nothing');
select pg_temp.check((zad_family_zone_event((select id from zad_family_zones limit 1), 'exit', now()) ->> 'reason') is not null, 'and cannot report for the child');

-- 7. The child stops it: the parent is told, the phone drops the zones, events are refused.
select pg_temp.who('C');
select pg_temp.check((zad_family_revoke_share((select id from zad_family_shares where scope = 'location')) ->> 'ok')::boolean, 'child stops sharing');
select pg_temp.check(jsonb_array_length(zad_family_my_zones() -> 'zones') = 0, 'phone gets no zones after the stop');
select pg_temp.check((zad_family_zone_event((select id from zad_family_zones where label = 'المدرسة'), 'exit', now()) ->> 'reason') = 'not_shared', 'events refused after the stop');
reset role;
select pg_temp.check(exists (select 1 from app_notifications where user_id = '00000000-0000-0000-0000-0000000000a1' and message like 'يوسف وقّف مشاركة%'), 'parent told it stopped');

-- 8. A child who grows up (role changed) is no longer followed, even with an old yes.
update zad_family_shares set status = 'granted' where scope = 'location';
select pg_temp.check(zad_family_share_granted('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', 'location'), 'granted again while a child');
update family_members set role = 'member' where alias = 'يوسف';
select pg_temp.check(not zad_family_share_granted('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', 'location'), 'an adult role ends location following');

-- 9. Grants: Supabase hands anon EXECUTE on new functions; none of these may keep it.
select pg_temp.check(not has_function_privilege('anon', p.oid, 'EXECUTE'), 'anon cannot execute ' || p.proname)
  from pg_proc p where p.proname in ('zad_family_zone_save', 'zad_family_zone_delete', 'zad_family_my_zones',
    'zad_family_zone_event', 'zad_family_zone_status', 'zad_family_scope_label');
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_family_zone_status(uuid, uuid)', 'EXECUTE'), 'zone status is server-only');
select pg_temp.check(not has_table_privilege('authenticated', 'public.zad_family_zone_events', 'INSERT,UPDATE,DELETE,TRUNCATE'), 'no client writes on events');
