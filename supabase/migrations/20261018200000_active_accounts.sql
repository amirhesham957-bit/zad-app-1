-- المرحلة ٠.٤ (ZAD_DREAM_PLAN.md ع٦): التحليل اليومي كان بيشتغل على كل حساب في zad_users. المقاس ١٨/١٠:
-- ٣ من ٦ حسابات عمرهم ما بعتوا رسالة ولا سجلوا حركة، وحساب الاختبار — ~٤٦٨ ألف توكن في الأسبوع على
-- حسابات نايمة. «نشط» = عمل أي حاجة في آخر [p_days] يوم: كلّم زاد في أي قناة، حركة، إشعار بنك، فعل
-- اتسجل، صنف في المخزون أو الصيدلية، رد على سؤال المخزون، فتح التطبيق (توكن الإشعارات بيتحدث)،
-- أو حساب جديد. حساب الاختبار عمره ما بيدخل.

create or replace function public.zad_active_user_ids(p_days int default 7)
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  with since as (select now() - make_interval(days => greatest(1, coalesce(p_days, 7))) as t)
  select distinct u.id
    from zad_users u, since
   where u.id <> 'a11ce000-0000-4000-8000-00000000a11a'
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
$$;

revoke all on function public.zad_active_user_ids(int) from public, anon, authenticated;
grant execute on function public.zad_active_user_ids(int) to service_role;
