-- ZAD_OR_PLAN م٣.٢: نية inventory.rate_corrected (زرار «أسرع / أبطأ») بتحط معدل على الصنف، من الباب بس.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.ci(p text, cid text, u uuid default '11111111-1111-1111-1111-111111111111')
returns jsonb language sql as $$
  select zad_commit_intent(jsonb_build_object('user_id', u, 'kind', 'inventory.rate_corrected', 'client_event_id', cid, 'payload', p::jsonb)) $$;

\set u1 '11111111-1111-1111-1111-111111111111'
\set item 'e0000000-0000-0000-0000-000000000001'

select pg_temp.check((select count(*) from information_schema.columns where table_schema = 'public'
  and table_name = 'zad_inventory' and column_name = 'rate_override_per_day') = 1, 'column exists');
select pg_temp.check(((select rate_override_per_day from public.zad_inventory where id = :'item')) is null, 'no override by default');

-- ١) معدل صالح: الصف اتحدّث، والحدث شايل القديم والجديد.
select pg_temp.check((pg_temp.ci('{"item_id":"e0000000-0000-0000-0000-000000000001","rate_per_day":0.65}', 'r1') ->> 'ok')::boolean, 'rate set');
select pg_temp.check((select rate_override_per_day from public.zad_inventory where id = :'item') = 0.65, 'row has the rate');
select pg_temp.check((select payload ->> 'before' is null and (payload ->> 'after')::numeric = 0.65
  from public.zad_events where client_event_id = 'r1'), 'event before/after');
select pg_temp.check((pg_temp.ci('{"item_id":"e0000000-0000-0000-0000-000000000001","rate_per_day":0.5}', 'r2') ->> 'ok')::boolean, 'second correction');
select pg_temp.check((select (payload ->> 'before')::numeric = 0.65 from public.zad_events where client_event_id = 'r2'), 'event keeps the old rate');

-- ٢) معدل مش صالح: مرفوض ومتسجل، والصف زي ما هو.
select pg_temp.check(pg_temp.ci('{"item_id":"e0000000-0000-0000-0000-000000000001","rate_per_day":0}', 'r3') ->> 'reason' = 'rate_invalid', 'zero refused');
select pg_temp.check(pg_temp.ci('{"item_id":"e0000000-0000-0000-0000-000000000001","rate_per_day":-2}', 'r4') ->> 'reason' = 'rate_invalid', 'negative refused');
select pg_temp.check(pg_temp.ci('{"item_id":"e0000000-0000-0000-0000-000000000001","rate_per_day":"fast"}', 'r5') ->> 'reason' = 'rate_invalid', 'text refused');
select pg_temp.check(pg_temp.ci('{"item_id":"e0000000-0000-0000-0000-000000000001"}', 'r6') ->> 'reason' = 'rate_invalid', 'missing refused');
select pg_temp.check((select rate_override_per_day from public.zad_inventory where id = :'item') = 0.5, 'refusals left the row alone');

-- ٣) صنف مش بتاعي أو مش موجود.
select pg_temp.check(pg_temp.ci('{"item_id":"e0000000-0000-0000-0000-000000000001","rate_per_day":1}', 'r7', '22222222-2222-2222-2222-222222222222') ->> 'reason' = 'item_not_found', 'other home refused');
select pg_temp.check(pg_temp.ci('{"item_id":"not-a-uuid","rate_per_day":1}', 'r8') ->> 'reason' = 'item_not_found', 'bad id not found');

select 'rate_corrected: all checks passed';
