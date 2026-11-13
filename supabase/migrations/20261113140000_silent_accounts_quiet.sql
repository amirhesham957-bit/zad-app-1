-- Owner's decision 13/11 (2ج): an account that has never talked to Zad and has no data gets no
-- optional message until its first word or first row — to save quota and keep the focus on the
-- customers who use the app.
--
-- Measured 13/11 on live: 18 of 25 accounts never chatted. 15 of them received 174 messages in
-- 7 days (morning greeting, good night, «اقفل يومك», newcomer and travel), and their daily
-- analysis spent 854k input tokens in the same week (63 runs, 14 accounts). Only one of the 18
-- had a transaction and one a pantry row.
--
-- zad_active_user_ids let them through because a refreshed push token (zad_fcm_tokens.updated_at)
-- counted as activity: every installed app was «active».
--
-- What is NOT silenced: doses, appointments, a family member's missed dose and school zones
-- (NEVER_HELD_MOMENTS in voiceMoments.ts) — those exist only because someone entered data anyway.
-- A brand-new account has 3 days of grace, so its welcome and first questions still reach it.

create or replace function public.zad_account_silent(p_user uuid, p_grace_days integer default 3)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (select 1 from zad_users u where u.id = p_user
                   and u.created_at <= now() - make_interval(days => greatest(0, coalesce(p_grace_days, 3))))
    -- talked
    and not exists (select 1 from zad_brain_runs r where r.user_id = p_user and r.trigger = 'chat')
    and not exists (select 1 from zad_chat_turns c where c.user_id = p_user and c.role = 'user')
    and not exists (select 1 from telegram_checkin_prompts k where k.user_id = p_user and k.answered_at is not null)
    -- entered data
    and not exists (select 1 from zad_transactions x where x.user_id = p_user)
    and not exists (select 1 from zad_inventory i where i.user_id = p_user)
    and not exists (select 1 from zad_pharmacy_items p where p.user_id = p_user)
    and not exists (select 1 from zad_appointments a where a.user_id = p_user)
    and not exists (select 1 from zad_shopping_list s where s.user_id = p_user)
    and not exists (select 1 from zad_obligations o where o.user_id = p_user)
    and not exists (select 1 from zad_subscriptions b where b.user_id = p_user)
    -- part of a household with someone else: the house's messages are theirs too
    and not exists (
      select 1 from family_members me join family_members other
        on other.family_id = me.family_id and other.user_id is distinct from me.user_id
       where me.user_id = p_user
    );
$$;

revoke all on function public.zad_account_silent(uuid, integer) from public, anon, authenticated;
grant execute on function public.zad_account_silent(uuid, integer) to service_role;

-- Same body as before, minus silent accounts. The push-token clause stays: a phone that is
-- alive AND has data or talk is active.
create or replace function public.zad_active_user_ids(p_days integer default 7)
returns setof uuid
language sql
stable
security definer
set search_path to 'public'
as $function$
  with since as (select now() - make_interval(days => greatest(1, coalesce(p_days, 7))) as t)
  select distinct u.id
    from zad_users u, since
   where u.id <> 'a11ce000-0000-4000-8000-00000000a11a'
     and not public.zad_account_silent(u.id)
     and (
       u.created_at > since.t
       or exists (select 1 from zad_chat_turns c where c.user_id = u.id and c.role = 'user' and c.created_at > since.t)
       or exists (select 1 from zad_transactions x where x.user_id = u.id and x.created_at > since.t)
       or exists (select 1 from zad_notification_ingest_events e where e.user_id = u.id and e.created_at > since.t)
       or exists (select 1 from agent_actions a where a.user_id = u.id and a.created_at > since.t)
       or exists (select 1 from zad_inventory i where i.user_id = u.id and i.created_at > since.t)
       or exists (select 1 from zad_pharmacy_items p where p.user_id = u.id and p.created_at > since.t)
       or exists (select 1 from telegram_checkin_prompts k where k.user_id = u.id and k.answered_at > since.t)
       or exists (select 1 from zad_fcm_tokens f where f.user_id = u.id and f.updated_at > since.t)
     );
$function$;
