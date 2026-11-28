-- حزمة البلد (migration 20261128110000) على قاعدة سكراتش:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20260726080000_locale_config.sql
--   psql < supabase/migrations/20261128110000_locale_country_pack.sql
--   psql < supabase/sql/tests/locale_country_pack_test.sql

\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

-- كل بلد موجود اتملى، ومفيش بلد اتزاد
select pg_temp.check((select count(*) from public.zad_locale_config) = 3, 'no country was invented: still EG/SA/TR');
select pg_temp.check((select bool_and(cardinality(common_stores) > 0 and cardinality(common_dishes) > 0
  and jsonb_array_length(seasons) > 0 and default_payday between 1 and 31) from public.zad_locale_config), 'every existing country has a full pack');
select pg_temp.check((select 'كارفور' = any(common_stores) from public.zad_locale_config where country = 'EG'), 'EG stores include carrefour');
-- كل موسم له اسم وشهر 1..12
select pg_temp.check((select bool_and(s ->> 'name' is not null and (s ->> 'month')::int between 1 and 12)
  from public.zad_locale_config, jsonb_array_elements(seasons) s), 'every season has a name and a month 1..12');

-- idempotent: إعادة المايجريشن مابتكتبش على تعديل يدوي ومابتكررش حاجة
update public.zad_locale_config set common_stores = array['متجر معدّل'], default_payday = 5 where country = 'EG';
\i supabase/migrations/20261128110000_locale_country_pack.sql
select pg_temp.check((select common_stores = array['متجر معدّل'] from public.zad_locale_config where country = 'EG'), 're-run keeps a hand-edited pack');
select pg_temp.check((select jsonb_array_length(seasons) = 6 from public.zad_locale_config where country = 'EG'), 're-run does not duplicate seasons');

-- القيود
do $$ begin
  begin update public.zad_locale_config set default_payday = 0 where country = 'EG'; raise exception 'FAIL: payday 0 accepted';
  exception when check_violation then raise notice 'ok: payday 0 rejected'; end;
  begin update public.zad_locale_config set default_payday = 32 where country = 'EG'; raise exception 'FAIL: payday 32 accepted';
  exception when check_violation then raise notice 'ok: payday 32 rejected'; end;
  begin update public.zad_locale_config set seasons = '{"a":1}'::jsonb where country = 'EG'; raise exception 'FAIL: non-array seasons accepted';
  exception when check_violation then raise notice 'ok: non-array seasons rejected'; end;
end $$;

-- RLS: authenticated يقرا، anon لأ، ومفيش كتابة
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', false);
select pg_temp.check((select count(*) from public.zad_locale_config) = 3, 'authenticated reads the pack');
do $$ begin
  update public.zad_locale_config set default_payday = 9;
  if exists (select 1 from public.zad_locale_config where default_payday = 9) then raise exception 'FAIL: authenticated wrote'; end if;
  raise notice 'ok: authenticated cannot write';
exception when insufficient_privilege then raise notice 'ok: authenticated cannot write'; end $$;
reset role;
set role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', false);
select pg_temp.check((select count(*) from public.zad_locale_config) = 0, 'anon reads nothing');
reset role;

-- mutation: لو اتفرغت بيانات بلد، الفحص الأول لازم يفشل
do $$
declare ok boolean;
begin
  update public.zad_locale_config set common_stores = '{}' where country = 'SA';
  select bool_and(cardinality(common_stores) > 0) into ok from public.zad_locale_config;
  if ok then raise exception 'FAIL: mutation not caught (empty SA stores passed the pack check)'; end if;
  raise notice 'ok: mutation caught (emptied pack fails the completeness check)';
end $$;
