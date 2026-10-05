-- Bills in one home (migration 20261005235107, docs/agent/ZAD_LIVING_BRAIN.md §11 هـ) — see bills_one_home_scaffold.sql for
-- how to run it. Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
create or replace function pg_temp.ob(t text) returns public.zad_obligations language sql as $$
  select * from public.zad_obligations where title = t $$;
create or replace function pg_temp.sub_active(t text) returns boolean language sql as $$
  select is_active from public.zad_subscriptions where title = t $$;

-- 1. The one-time move: a bill subscription becomes a utility obligation, and the subscription is closed, not deleted.
select pg_temp.check((pg_temp.ob('كهربا')).kind = 'utility' and (pg_temp.ob('كهربا')).amount = 450, 'the electricity bill is an obligation');
select pg_temp.check((pg_temp.ob('كهربا')).due_day = 12, 'its due day comes from the renewal date');
select pg_temp.check((pg_temp.ob('كهربا')).provider = 'جنوب القاهرة', 'the provider moves with it');
select pg_temp.check((pg_temp.ob('كهربا')).confirmed and (pg_temp.ob('كهربا')).active, 'confirmed and active — the customer added it');
select pg_temp.check(pg_temp.sub_active('كهربا') = false, 'the subscription row is closed');
select pg_temp.check((select count(*) from zad_subscriptions where title = 'كهربا') = 1, 'and kept, not deleted');

-- 2. Already an obligation (same name, spaces and all) ⇒ no second one; the subscription still closes. This was the double count.
select pg_temp.check((select count(*) from zad_obligations where btrim(title) = 'مية') = 1, 'the water bill is not made twice');
select pg_temp.check(pg_temp.sub_active('مية') = false, 'its duplicate subscription closes');

-- 3. A category alone makes a bill (any spelling the canonical name folds), and yearly stays yearly.
select pg_temp.check((pg_temp.ob('رخصة العداد')).recurrence = 'yearly', 'فاتورة in the category is a bill; yearly stays yearly');

-- 4. What obligations cannot hold stays where it is: weekly, zero, and anything not a bill.
select pg_temp.check(pg_temp.sub_active('غاز') and pg_temp.ob('غاز') is null, 'a weekly bill stays a subscription');
select pg_temp.check(pg_temp.sub_active('نت قديم') and pg_temp.ob('نت قديم') is null, 'a zero bill stays');
select pg_temp.check(pg_temp.sub_active('نتفليكس') and pg_temp.ob('نتفليكس') is null, 'Netflix is a subscription');
select pg_temp.check(pg_temp.sub_active('تليفون أرضي') = false and pg_temp.ob('تليفون أرضي') is null, 'an inactive bill is left alone');

-- 5. A day the obligation cannot hold (40, or a date that is not one) moves without a day instead of failing the move.
select pg_temp.check((pg_temp.ob('عداد غريب')).due_day is null and pg_temp.sub_active('عداد غريب') = false, 'day 40 moves as no day');

-- 6. Any later writer — an old app, the bot — that adds a bill to subscriptions lands in obligations at once.
insert into zad_subscriptions (user_id, title, amount, renewal_date, category)
  values ('00000000-0000-0000-0000-0000000000a1', 'غاز طبيعي', 95, '2026-11-08', 'الفواتير');
select pg_temp.check((pg_temp.ob('غاز طبيعي')).due_day = 8 and pg_temp.sub_active('غاز طبيعي') = false, 'a new bill moves on insert');
insert into zad_subscriptions (user_id, title, amount, renewal_date, category)
  values ('00000000-0000-0000-0000-0000000000a1', 'شاهد', 100, '2026-11-08', 'الترفيه');
select pg_temp.check(pg_temp.sub_active('شاهد') and pg_temp.ob('شاهد') is null, 'a new subscription stays one');

-- 7. Nobody calls the movers directly.
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_subscription_to_obligation(public.zad_subscriptions)', 'execute'),
  'authenticated cannot run the mover');
select pg_temp.check(not has_function_privilege('anon', 'public.zad_subscriptions_bills_to_obligations()', 'execute'),
  'anon cannot run the trigger function');
