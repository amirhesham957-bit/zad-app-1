-- مفتاح «نداءات زادو» في الإعدادات (قرار المالك ٢٠٢٦-١١-٠٨): زرار الكتم اتشال من تليجرام، فالعميل لازم يقدر
-- يوقف النداءات من غير ما يحظر البوت ويضيع تحية الصبح والعروض.

alter table public.zad_users add column if not exists pet_calls_enabled boolean not null default true;

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

-- نداء مستني في الطابور وقت القفل مايتبعتش.
create or replace function public.zad_users_cancel_pet_calls()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  update agent_tasks set status = 'cancelled', result = 'pet_calls_off', updated_at = now()
    where user_id = new.id and kind = 'pet_call' and status = 'pending';
  return new;
end;
$fn$;
revoke all on function public.zad_users_cancel_pet_calls() from public, anon, authenticated;

drop trigger if exists zad_users_cancel_pet_calls on public.zad_users;
create trigger zad_users_cancel_pet_calls after update of pet_calls_enabled on public.zad_users
  for each row when (new.pet_calls_enabled is false and old.pet_calls_enabled is distinct from false)
  execute function public.zad_users_cancel_pet_calls();
