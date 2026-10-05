-- Occasions in memory (migration 20261006000000): birthdays and anniversaries as
-- zad_memory notes with a yearly date. On a scratch database, in this order:
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/memory_scaffold.sql
--   psql < supabase/migrations/20261003100000_memory_entities_and_time.sql
--   psql < supabase/migrations/20261006000000_memory_occasions.sql
--   psql < supabase/sql/tests/memory_occasions_test.sql
-- U (b1) owns the occasions, O (b2) is another account. Raises on the first
-- failed check; every passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

insert into auth.users values ('00000000-0000-0000-0000-0000000000b1'), ('00000000-0000-0000-0000-0000000000b2') on conflict do nothing;
\set u1 '''00000000-0000-0000-0000-0000000000b1'''
\set u2 '''00000000-0000-0000-0000-0000000000b2'''
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond,false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
create or replace function pg_temp.refuses(stmt text, label text) returns void language plpgsql as $$
begin
  execute stmt;
  raise exception 'FAIL: % (accepted)', label;
exception when raise_exception or check_violation or insufficient_privilege then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'ok: %', label;
end $$;

-- 1. write, read back
select pg_temp.check(zad_memory_set_occasion(:u1, 'birthday', 'ماما', '03-12', 'عيد ميلاد ماما ١٢ مارس') is not null, 'birthday written');
select pg_temp.check((select count(*) from zad_memory_occasions(:u1)) = 1, 'one occasion listed');
select pg_temp.check((select occasion_md = '03-12' and occasion_for = 'ماما' and occasion = 'birthday' from zad_memory_occasions(:u1)), 'its fields read back');
select pg_temp.check((select note from zad_memory_live_notes(:u1, 20)) = 'عيد ميلاد ماما ١٢ مارس', 'it is an ordinary live note too');

-- 2. a correction moves the date on the same note
select pg_temp.check(
  zad_memory_set_occasion(:u1, 'birthday', ' ماما ', '03-15', 'عيد ميلاد ماما ١٥ مارس')
    = (select id from zad_memory where occasion = 'birthday' and occasion_for = 'ماما'),
  'same person, same kind: same note');
select pg_temp.check((select count(*) from zad_memory where user_id = :u1 and occasion is not null) = 1, 'no second note');
select pg_temp.check((select occasion_md from zad_memory where occasion_for = 'ماما') = '03-15', 'date corrected');
select pg_temp.check((select note from zad_memory where occasion_for = 'ماما') = 'عيد ميلاد ماما ١٥ مارس', 'sentence corrected');

-- 3. the customer's own, and an anniversary beside it
select pg_temp.check(zad_memory_set_occasion(:u1, 'birthday', null, '07-04', 'عيد ميلاد العميل ٤ يوليو') is not null, 'own birthday written');
select pg_temp.check(zad_memory_set_occasion(:u1, 'birthday', '', '07-05', 'عيد ميلاد العميل ٥ يوليو')
  = (select id from zad_memory where occasion = 'birthday' and occasion_for is null), 'empty name is the customer too');
select pg_temp.check(zad_memory_set_occasion(:u1, 'anniversary', null, '02-29', 'ذكرى الجواز ٢٩ فبراير') is not null, 'anniversary on 29 February');
select pg_temp.check((select count(*) from zad_memory_occasions(:u1)) = 3, 'three occasions');
select pg_temp.check((select array_agg(occasion_md order by occasion_md) from zad_memory_occasions(:u1)) = array['02-29', '03-15', '07-05'], 'listed by date');

-- 4. what is refused
select pg_temp.refuses($q$select zad_memory_set_occasion('00000000-0000-0000-0000-0000000000b1', 'birthday', 'يوسف', '02-30', 'x')$q$, '30 February refused');
select pg_temp.refuses($q$select zad_memory_set_occasion('00000000-0000-0000-0000-0000000000b1', 'birthday', 'يوسف', '04-31', 'x')$q$, '31 April refused');
select pg_temp.refuses($q$select zad_memory_set_occasion('00000000-0000-0000-0000-0000000000b1', 'birthday', 'يوسف', '13-01', 'x')$q$, 'month 13 refused');
select pg_temp.refuses($q$select zad_memory_set_occasion('00000000-0000-0000-0000-0000000000b1', 'birthday', 'يوسف', '3-1', 'x')$q$, 'unpadded date refused');
select pg_temp.refuses($q$select zad_memory_set_occasion('00000000-0000-0000-0000-0000000000b1', 'graduation', 'يوسف', '03-01', 'x')$q$, 'unknown occasion refused');
select pg_temp.refuses($q$select zad_memory_set_occasion('00000000-0000-0000-0000-0000000000b1', 'birthday', 'يوسف', '03-01', '  ')$q$, 'empty note refused');
select pg_temp.refuses($q$insert into zad_memory(user_id, note, occasion) values ('00000000-0000-0000-0000-0000000000b1', 'x', 'birthday')$q$, 'occasion without a date refused by the table');
select pg_temp.refuses($q$insert into zad_memory(user_id, note, occasion_for) values ('00000000-0000-0000-0000-0000000000b1', 'x', 'ماما')$q$, 'a name without an occasion refused by the table');

-- 5. a closed occasion is history, not listed
update zad_memory set valid_until = now() - interval '1 minute', valid_from = now() - interval '1 day'
 where occasion = 'anniversary' and user_id = :u1;
select pg_temp.check((select count(*) from zad_memory_occasions(:u1)) = 2, 'expired occasion not listed');
select pg_temp.check(zad_memory_set_occasion(:u1, 'anniversary', null, '02-28', 'ذكرى الجواز ٢٨ فبراير')
  <> (select id from zad_memory where occasion = 'anniversary' and valid_until is not null), 'a new one does not revive the closed note');

-- 6. the merge leaves occasions alone
select pg_temp.check(zad_memory_upsert(:u1, 'general', 'عيد ميلاد ماما ٢٠ مارس', 0.5) = 'inserted', 'a near-identical plain note does not merge into the occasion');
select pg_temp.check((select note from zad_memory where occasion_for = 'ماما') = 'عيد ميلاد ماما ١٥ مارس', 'occasion sentence untouched by the merge');
select pg_temp.check(zad_memory_upsert(:u1, 'general', 'عيد ميلاد ماما ٢٠ مارس', 0.5) = 'strengthened', 'plain notes still merge with each other');

-- 7. pruning: occasions are outside the 60
insert into zad_memory(user_id, scope, note, confidence, evidence_count)
select :u1, 'general', 'ملاحظة قوية رقم ' || g, 1.0, 10 from generate_series(1, 70) g;
select zad_memory_prune();
select pg_temp.check((select count(*) from zad_memory where user_id = :u1 and occasion is null) = 60, 'plain notes pruned to 60');
select pg_temp.check((select count(*) from zad_memory_occasions(:u1)) = 3, 'every live occasion survives the prune');

-- 8. grants and the other account
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', false);
select pg_temp.check((select count(*) from zad_memory_occasions('00000000-0000-0000-0000-0000000000b1')) = 0, 'another account reads none');
select pg_temp.check((select count(*) from zad_memory_occasions('00000000-0000-0000-0000-0000000000b2')) = 0, 'own read works (empty)');
select pg_temp.refuses($q$select zad_memory_set_occasion('00000000-0000-0000-0000-0000000000b2', 'birthday', 'ماما', '03-12', 'x')$q$, 'the app cannot write occasions directly');
reset role;
set role anon;
select pg_temp.refuses($q$select zad_memory_occasions('00000000-0000-0000-0000-0000000000b1')$q$, 'anon cannot read occasions');
reset role;
select pg_temp.check(not has_function_privilege('anon', p.oid, 'EXECUTE'), 'anon cannot execute ' || p.proname)
  from pg_proc p where p.proname in ('zad_memory_set_occasion', 'zad_memory_occasions', 'zad_memory_upsert', 'zad_memory_prune');
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_memory_set_occasion(uuid, text, text, text, text)', 'EXECUTE'), 'set_occasion is server-only');
select pg_temp.check((select count(*) from pg_proc where proname = 'zad_memory_upsert') = 1, 'still exactly one upsert overload');
