-- نداء زادو يحترم قرار الحارس (ZAD_PLAN ١٠.٦، متابعة #533).
--
-- المالك وافق ١٣/١١ على الترشيح #١ «سكّت pet_call عند الكل» (١٥٧ نداء في ٣٠ يوم، ٧٪ رد، ٣٪ اتعمل بيها حاجة).
-- الموافقة بتتقري من _agent_proactive_suppressed ⇐ private.zad_guardian_ignored، وده بيسأله الماسح الاستباقي
-- (agent_proactive_scan) بس. pet_call بيتعمل من كرون تاني (pet-calls-hourly ⇐ zad_enqueue_pet_calls) ومابيسألش،
-- فالموافقة كانت هتتسجّل والنداءات تفضل ماشية (~٢٠٠ مهمة في اليوم يوم ١٣/١١).
--
-- الإصلاح: نفس السؤال اللي كل مراحل الماسح بتسأله — موافقة الأدمن، أو كتم العميل، أو ٣ نداءات ورا بعض اتجاهلت
-- آخر ١٤ يوم. والنداءات اللي في الطابور وقت الموافقة بتتلغي هنا مرة واحدة.

create or replace function public.zad_enqueue_pet_calls()
returns integer
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_count integer;
begin
  with needy as (
    select c.user_id,
           case
             -- شبع أقل من الربع (الجوع بيخلص في ٢٠ ساعة، pet_care.dart).
             when c.fed_at < now() - interval '15 hours' then 'hungry'
             -- ريّ أقل من الربع (العطش بيخلص في ١٤ ساعة).
             when c.watered_at < now() - interval '630 minutes' then 'thirsty'
           end as need
    from zad_companion_care c
  )
  insert into agent_tasks (user_id, kind, task_description, scheduled_for)
  select n.user_id, 'pet_call', n.need, now()
  from needy n
  where n.need is not null
    -- العميل قفل النداءات من الإعدادات.
    and not exists (select 1 from zad_users u where u.id = n.user_id and u.pet_calls_enabled is false)
    -- الحارس: موافقة الأدمن على تسكيت النوع، أو كتم العميل، أو تجاهل ٣ ورا بعض (زي مراحل الماسح).
    and not public._agent_proactive_suppressed(n.user_id, 'pet_call')
    -- فاتح التطبيق النهارده: الرفيق على الرئيسية بيقول بنفسه.
    and not exists (
      select 1 from zad_product_events e
      where e.user_id = n.user_id and e.name = 'app_open' and e.at > now() - interval '12 hours')
    -- مرة في اليوم بالكتير؛ المهمة اللي اتلغت (اتأكل في النص) ماتتحسبش.
    and not exists (
      select 1 from agent_tasks t
      where t.user_id = n.user_id and t.kind = 'pet_call'
        and (t.status in ('pending', 'running') or (t.status = 'done' and t.created_at > now() - interval '20 hours')))
    -- قناة توصل: من غيرها المهمة هتفشل «no channel».
    and (
      exists (select 1 from telegram_bindings b where b.user_id = n.user_id and b.chat_id is not null)
      or exists (select 1 from zad_fcm_tokens f where f.user_id = n.user_id));
  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;
revoke all on function public.zad_enqueue_pet_calls() from public, anon, authenticated;
grant execute on function public.zad_enqueue_pet_calls() to service_role;

-- اللي في الطابور دلوقتي وعليه حارس مايتبعتش.
update public.agent_tasks t
   set status = 'cancelled', result = 'guardian_paused', updated_at = now()
 where t.kind = 'pet_call' and t.status = 'pending'
   and public._agent_proactive_suppressed(t.user_id, 'pet_call');
