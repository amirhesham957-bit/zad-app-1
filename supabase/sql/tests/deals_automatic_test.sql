-- العروض أوتوماتيك (migration 20261103210000), on a scratch database — after the deals, seed-stores and
-- deal-reports migrations (see the CI list). Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

-- 1. The Gulf shops are in the weekly search list.
select pg_temp.check((select count(*) from public.zad_deal_seed_stores where country = 'AE' and active) >= 5, 'UAE shops are searched');
select pg_temp.check((select count(*) from public.zad_deal_seed_stores where country = 'QA' and active) >= 5, 'Qatar shops are searched');
select pg_temp.check((select bool_and(currency = 'AED') from public.zad_deal_seed_stores where country = 'AE'), 'UAE in dirhams');

-- 2. A source pauses itself only past 10 shown and over 10% wrong, and «live» never does.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1') on conflict do nothing;
insert into public.zad_voice_moments (user_id, moment, facts)
select '00000000-0000-0000-0000-0000000000a1', 'morning_greeting',
       jsonb_build_object('taste_deal', jsonb_build_object('item', 'x' || g, 'source', jsonb_build_object('kind', k))
         || case when g <= w then '{"answer": "wrong"}'::jsonb else '{}'::jsonb end)
  from (values ('youtube', 10, 2), ('search', 10, 1), ('instagram', 9, 9)) as v(k, n, w), generate_series(1, v.n) g;
insert into public.zad_voice_moments (user_id, moment, facts)
select '00000000-0000-0000-0000-0000000000a1', 'morning_greeting', '{"taste_deal": {"item": "live", "answer": "wrong"}}'
  from generate_series(1, 12);
select pg_temp.check((select array_agg(source_kind order by source_kind) from public.zad_deal_paused_sources(14)) = array['youtube'],
  'only youtube pauses: 2 of 10 wrong; search at 1 of 10 and instagram under 10 shown stay; live never');

-- 3. Customers cannot read it.
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_deal_paused_sources(int)', 'execute'), 'customers cannot read the gate');
