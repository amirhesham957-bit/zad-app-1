-- 20261116040000: the family head writes members' medicines through two RPCs; nobody else does.
-- Chain: scratch_scaffold, worlds_scaffold, 20261116040000, this file.
\set ON_ERROR_STOP on

insert into auth.users (id) values
  ('00000000-0000-4000-8000-0000000000d1'), ('00000000-0000-4000-8000-0000000000d2'), ('00000000-0000-4000-8000-0000000000d3'),
  ('00000000-0000-4000-8000-0000000000d4'), ('00000000-0000-4000-8000-0000000000d5');
insert into family_groups (id) values ('00000000-0000-4000-8000-00000000f001'), ('00000000-0000-4000-8000-00000000f002');
-- family 1: d1 head, d2 member, d3 second admin-less member. family 2: d4 head, d5 member.
insert into family_members (family_id, user_id, role) values
  ('00000000-0000-4000-8000-00000000f001', '00000000-0000-4000-8000-0000000000d1', 'admin'),
  ('00000000-0000-4000-8000-00000000f001', '00000000-0000-4000-8000-0000000000d2', 'member'),
  ('00000000-0000-4000-8000-00000000f001', '00000000-0000-4000-8000-0000000000d3', 'member'),
  ('00000000-0000-4000-8000-00000000f002', '00000000-0000-4000-8000-0000000000d4', 'admin'),
  ('00000000-0000-4000-8000-00000000f002', '00000000-0000-4000-8000-0000000000d5', 'member');
insert into zad_pharmacy_items (id, user_id, name, remaining_quantity, daily_dose_count, units_per_dose) values
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000d2', 'كونكور', 10, 1, 1),
  ('00000000-0000-4000-8000-0000000000e5', '00000000-0000-4000-8000-0000000000d5', 'بنادول', 10, 1, 1);

-- anon: refused outright.
set role anon;
do $$ begin
  begin perform zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d2', null, 'x'); raise exception 'anon save';
  exception when insufficient_privilege then null; end;
  begin perform zad_family_pharmacy_log_dose('00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000e2'); raise exception 'anon dose';
  exception when insufficient_privilege then null; end;
end $$;

-- d2 (plain member): cannot touch another member (or the head) — only own rows via the old policy.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d2","role":"authenticated"}', false);
do $$ begin
  begin perform zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d3', null, 'x'); raise exception 'member wrote for sibling';
  exception when sqlstate '42501' then null; end;
  begin perform zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d1', null, 'x'); raise exception 'member wrote for head';
  exception when sqlstate '42501' then null; end;
  begin perform zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d2', null, 'self via rpc'); raise exception 'non-admin self rpc';
  exception when sqlstate '42501' then null; end;
  begin perform zad_family_pharmacy_log_dose('00000000-0000-4000-8000-0000000000d3', '00000000-0000-4000-8000-0000000000e2'); raise exception 'member logged for sibling';
  exception when sqlstate '42501' then null; end;
  -- reads own, not the family's.
  if (select count(*) from zad_pharmacy_items) <> 1 then raise exception 'member reads wrong set'; end if;
  -- and no direct write on someone else's row (RLS: zero rows touched).
  insert into zad_pharmacy_items (user_id, name) values ('00000000-0000-4000-8000-0000000000d1', 'planted') on conflict do nothing;
exception when insufficient_privilege or check_violation then null;
end $$;
reset role;
do $$ begin
  if exists (select 1 from zad_pharmacy_items where name in ('x', 'planted', 'self via rpc')) then raise exception 'a forbidden write landed'; end if;
end $$;

-- d1 (head): writes for d2 and d3; cannot reach family 2; cannot move another's item to the wrong target.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}', false);
do $$
declare r jsonb; v_item uuid;
begin
  r := zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d3', null, 'أوجمنتين', '1 قرص', 'قرص', 2, '08:00,20:00', 1, 14, null);
  if not (r ->> 'ok')::boolean or (r ->> 'user_id')::uuid <> '00000000-0000-4000-8000-0000000000d3' then raise exception 'add -> %', r; end if;
  v_item := (r ->> 'item_id')::uuid;

  -- edit it; only given fields change.
  r := zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d3', v_item, null, null, null, null, '09:00', null, 20, null);
  if (r ->> 'remaining_quantity')::int <> 20 then raise exception 'edit -> %', r; end if;
  if (select name || dose_times from zad_pharmacy_items where id = v_item) <> 'أوجمنتين09:00' then raise exception 'partial edit clobbered'; end if;

  -- edit the member's own existing medicine (d2's).
  r := zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000e2', null, null, null, null, null, null, 30, null);
  if (r ->> 'remaining_quantity')::int <> 30 then raise exception 'edit member item -> %', r; end if;

  -- duplicate name for the same person -> a clean refusal, not an exception.
  r := zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d3', null, 'أوجمنتين');
  if (r ->> 'ok')::boolean or r ->> 'reason' <> 'duplicate_name' then raise exception 'duplicate -> %', r; end if;

  -- bad dose time (24:00), bad name, bad quantity.
  begin perform zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d3', null, 'y', null, null, null, '24:00'); raise exception '24:00 accepted';
  exception when sqlstate '22023' then null; end;
  begin perform zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d3', null, ''); raise exception 'empty name accepted';
  exception when sqlstate '22023' then null; end;
  begin perform zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d3', null, 'z', null, null, null, null, null, -5); raise exception 'negative qty accepted';
  exception when sqlstate '22023' then null; end;

  -- family 2 is out of reach, add AND edit AND dose.
  begin perform zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d5', null, 'x'); raise exception 'head reached another family';
  exception when sqlstate '42501' then null; end;
  begin perform zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d5', '00000000-0000-4000-8000-0000000000e5', null, null, null, null, null, null, 999);
    raise exception 'head edited another family item'; exception when sqlstate '42501' then null; end;
  begin perform zad_family_pharmacy_log_dose('00000000-0000-4000-8000-0000000000d5', '00000000-0000-4000-8000-0000000000e5'); raise exception 'head dosed another family';
  exception when sqlstate '42501' then null; end;
  -- right family, wrong item (family 2's item under d2's id): not found, nothing changes.
  r := zad_family_pharmacy_save('00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000e5', null, null, null, null, null, null, 999);
  if r ->> 'reason' <> 'not_found' then raise exception 'cross item -> %', r; end if;
  r := zad_family_pharmacy_log_dose('00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000e5');
  if r ->> 'reason' <> 'not_found' then raise exception 'cross item dose -> %', r; end if;

  -- mark a dose for d2: 30 -> 29, the same slot again changes nothing, another slot -> 28.
  r := zad_family_pharmacy_log_dose('00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000e2', '2026-11-16 08:00+00');
  if (r ->> 'remaining_quantity')::int <> 29 or (r ->> 'duplicate')::boolean then raise exception 'dose -> %', r; end if;
  r := zad_family_pharmacy_log_dose('00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000e2', '2026-11-16 08:00+00');
  if (r ->> 'remaining_quantity')::int <> 29 or not (r ->> 'duplicate')::boolean then raise exception 'dose replay -> %', r; end if;
  r := zad_family_pharmacy_log_dose('00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000e2', '2026-11-16 20:00+00');
  if (r ->> 'remaining_quantity')::int <> 28 then raise exception 'second slot -> %', r; end if;

  -- the head still has no direct write path on a member's row.
  update zad_pharmacy_items set remaining_quantity = 1 where id = '00000000-0000-4000-8000-0000000000e2';
  if (select remaining_quantity from zad_pharmacy_items where id = '00000000-0000-4000-8000-0000000000e2') <> 28 then
    raise exception 'direct update by head landed'; end if;
end $$;
reset role;
do $$ begin
  if (select count(*) from zad_pharmacy_doses where user_id = '00000000-0000-4000-8000-0000000000d2') <> 2 then raise exception 'dose rows'; end if;
  if (select remaining_quantity from zad_pharmacy_items where id = '00000000-0000-4000-8000-0000000000e5') <> 10 then raise exception 'family 2 touched'; end if;
end $$;

-- d2 still reads and (RLS) owns their row; d3's new item is theirs to read.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d3","role":"authenticated"}', false);
do $$ begin
  if (select count(*) from zad_pharmacy_items where name = 'أوجمنتين') <> 1 then raise exception 'member cannot read own item'; end if;
end $$;
reset role;
select 'family_head_pharmacy_test OK' as result;
