-- P2.5b (المرحلة ١): أعمدة الميزانية بتاعة zad_users في جدول لوحدها، والقاصر أعمى عنه.
-- المشكلة: RLS مابتفصلش أعمدة، فصف zad_users للطفل (monthly_limit، budget، emergency_fund_balance، cycle_*) كان مقروء له.
-- اللي في المرحلة دي: جدول zad_user_budget (صف لكل مستخدم) + باك-فيل + تريجر بيعكس أي كتابة على أعمدة الميزانية في zad_users
-- (الكتابة بتفضل على zad_users زي ما هي، فمفيش caller اتكسر) + RLS: صاحبه غير القاصر، وولي الأمر لقاصره (zad_i_guard). مفيش كتابة من العميل.
-- اللي لسه (مكتوب في ZAD_FAMILY_PLAN.md P2.5b): نقل القراية من zad_users للجدول الجديد (٧٧ ملف monthly_limit، ٢٤ سطر emergency_fund_balance،
-- cycle_* في Flutter والـedge functions)، وبعدين revoke select على الأعمدة دي من zad_users (أو شيلها) عشان تسريب صف الطفل يتقفل فعلاً.
-- ما دام الأعمدة لسه في zad_users، تسريب القاصر لنفسه لسه موجود هناك.
-- يعتمد على 20261128190000_visibility_matrix.sql (zad_i_am_minor, zad_i_guard).

create table if not exists public.zad_user_budget (
  user_id uuid primary key,
  budget double precision,
  monthly_limit numeric,
  emergency_fund_balance numeric not null default 0,
  cycle_anchor text,
  cycle_start_day int,
  limit_confirmed_at timestamptz,
  balance_anchored_at timestamptz,
  travel_budget numeric,
  updated_at timestamptz not null default now()
);
alter table public.zad_user_budget enable row level security;

drop policy if exists own_budget_read on public.zad_user_budget;
create policy own_budget_read on public.zad_user_budget for select to authenticated
  using (user_id = (select auth.uid()) or public.zad_i_guard(user_id));
-- القاصر أعمى (restrictive بتقيّد اللي فوق حتى لصفه هو).
drop policy if exists minor_blind_budget on public.zad_user_budget;
create policy minor_blind_budget on public.zad_user_budget as restrictive for select to authenticated
  using (not (select public.zad_i_am_minor()));
revoke all on public.zad_user_budget from public, anon, authenticated;
grant select on public.zad_user_budget to authenticated;
grant all on public.zad_user_budget to service_role;

create or replace function public.zad_user_budget_mirror()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.zad_user_budget as b (user_id, budget, monthly_limit, emergency_fund_balance, cycle_anchor, cycle_start_day,
                                           limit_confirmed_at, balance_anchored_at, travel_budget)
  values (new.id, new.budget, new.monthly_limit, coalesce(new.emergency_fund_balance, 0), new.cycle_anchor, new.cycle_start_day,
          new.limit_confirmed_at, new.balance_anchored_at, new.travel_budget)
  on conflict (user_id) do update set
    budget = excluded.budget, monthly_limit = excluded.monthly_limit, emergency_fund_balance = excluded.emergency_fund_balance,
    cycle_anchor = excluded.cycle_anchor, cycle_start_day = excluded.cycle_start_day, limit_confirmed_at = excluded.limit_confirmed_at,
    balance_anchored_at = excluded.balance_anchored_at, travel_budget = excluded.travel_budget, updated_at = now();
  return new;
end $$;
revoke all on function public.zad_user_budget_mirror() from public, anon, authenticated;

drop trigger if exists zad_user_budget_mirror on public.zad_users;
create trigger zad_user_budget_mirror
  after insert or update of budget, monthly_limit, emergency_fund_balance, cycle_anchor, cycle_start_day, limit_confirmed_at,
                            balance_anchored_at, travel_budget
  on public.zad_users for each row execute function public.zad_user_budget_mirror();

-- باك-فيل لمرة (آمن للإعادة: on conflict).
insert into public.zad_user_budget (user_id, budget, monthly_limit, emergency_fund_balance, cycle_anchor, cycle_start_day,
                                    limit_confirmed_at, balance_anchored_at, travel_budget)
select id, budget, monthly_limit, coalesce(emergency_fund_balance, 0), cycle_anchor, cycle_start_day, limit_confirmed_at,
       balance_anchored_at, travel_budget
  from public.zad_users
on conflict (user_id) do nothing;
