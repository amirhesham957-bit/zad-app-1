-- ZAD_PLAN 5.8 (3) — النية المؤجلة: «عايز أشتري جاكيت» بتتحفظ بتاريخ (٦٠ يوم أو لما تتشرى)، وعرض الصبح بيدوّر لها.
-- الكاتب الوحيد السيرفر (zad-brain): الالتقاط بقواعد ثابتة على رسالة الشات، والقفل لما مصروف أو صنف مخزن بنفس الاسم
-- يظهر بعدها. العميل بيقرا نياته بس.

create table if not exists public.zad_purchase_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  item text not null check (char_length(item) between 2 and 40),
  item_key text not null check (char_length(item_key) between 2 and 40),
  said_at timestamptz not null default now(),
  expires_at timestamptz not null,
  status text not null default 'open' check (status in ('open', 'bought')),
  closed_at timestamptz,
  constraint zad_purchase_intents_closed check ((status = 'open') = (closed_at is null))
);

create unique index if not exists zad_purchase_intents_open_key
  on public.zad_purchase_intents (user_id, item_key) where status = 'open';

alter table public.zad_purchase_intents enable row level security;
revoke all on table public.zad_purchase_intents from anon, authenticated;
grant select on table public.zad_purchase_intents to authenticated;
grant all on table public.zad_purchase_intents to service_role;

drop policy if exists zad_purchase_intents_own on public.zad_purchase_intents;
create policy zad_purchase_intents_own on public.zad_purchase_intents for select to authenticated
  using (user_id = (select auth.uid()));

comment on table public.zad_purchase_intents is
  'ZAD_PLAN 5.8 (3) — things the customer said they mean to buy, kept 60 days or until bought, matched against deals. Written by the server only.';

/** نية جديدة، أو نفس الحاجة لسه مفتوحة ⇒ ميعادها يتجدد من النهارده. */
create or replace function public.zad_purchase_intent_note(p_user uuid, p_item text, p_key text, p_days int default 60)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  update public.zad_purchase_intents
     set said_at = now(), expires_at = now() + make_interval(days => p_days), item = p_item
   where user_id = p_user and item_key = p_key and status = 'open'
  returning id into v_id;
  if v_id is null then
    insert into public.zad_purchase_intents (user_id, item, item_key, expires_at)
    values (p_user, p_item, p_key, now() + make_interval(days => p_days))
    on conflict (user_id, item_key) where status = 'open' do nothing
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

revoke all on function public.zad_purchase_intent_note(uuid, text, text, int) from public, anon, authenticated;
grant execute on function public.zad_purchase_intent_note(uuid, text, text, int) to service_role;
