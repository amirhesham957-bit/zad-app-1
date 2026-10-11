-- «الحليب خلص — جهزتلك لينك أمازون» (صاحب التطبيق، ٢٠٢٦-١٠-١٠).
--
-- لما صنف في المخزون ينزل من كمية فعلية لصفر، بتتكتب مهمة استباقية restock_link بعد ربع
-- ساعة. الأصناف اللي تخلص في الربع ساعة دي (طبخة كبيرة، جرد بالإيد) بتتجمع في نفس المهمة —
-- رسالة واحدة مش خمسة. ورسالة واحدة في اليوم بالكتير.
--
-- التريجر بيكتب الأسماء بس، سطر لكل صنف. المنفّذ (zad-brain/restockLink.ts) هو اللي بيقرر:
-- الضروري بس، اللي لسه خالص وقت الإرسال، مش في وضع الطوارئ، وبيبني لينك أمازون بتاع بلد
-- العميل بتاجه. الأسماء نص من العميل: بتتنضف من «» والأسطر الجديدة وبتفضل بيانات.
--
-- التريجر مايقدرش يوقّع تعديل المخزون أبداً: أي خطأ بيتسجّل warning والتعديل بيكمّل.

create or replace function public._zad_restock_link_on_run_out()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_name text;
  v_task uuid;
begin
  if coalesce(old.quantity, 0) <= 0 or coalesce(new.quantity, 0) > 0 then
    return new;
  end if;
  v_name := left(btrim(regexp_replace(coalesce(new.item_name, ''), '[«»\r\n]', ' ', 'g')), 60);
  if v_name = '' then
    return new;
  end if;

  -- مهمة لسه مستنية: الصنف ينضم لها (مرة واحدة).
  select t.id into v_task
  from public.agent_tasks t
  where t.user_id = new.user_id and t.kind = 'restock_link' and t.status = 'pending'
  order by t.created_at desc
  limit 1
  for update skip locked;
  if v_task is not null then
    update public.agent_tasks
       set task_description = task_description || E'\n' || v_name,
           updated_at = now()
     where id = v_task
       and position(E'\n' || v_name || E'\n' in E'\n' || task_description || E'\n') = 0;
    return new;
  end if;

  -- رسالة في اليوم بالكتير. المهمة اللي اتلغت (مفيش صنف ضروري) ماتتحسبش.
  if exists (
    select 1 from public.agent_tasks t
    where t.user_id = new.user_id and t.kind = 'restock_link'
      and t.status in ('running', 'done')
      and t.created_at > now() - interval '20 hours'
  ) then
    return new;
  end if;

  insert into public.agent_tasks (user_id, kind, task_description, scheduled_for)
  values (new.user_id, 'restock_link', v_name, now() + interval '15 minutes');
  return new;
exception
  when others then
    raise warning '_zad_restock_link_on_run_out: user % item % failed: % (%)', new.user_id, new.item_name, sqlerrm, sqlstate;
    return new;
end;
$fn$;

comment on function public._zad_restock_link_on_run_out() is
  'صنف خلص (كمية → صفر): مهمة restock_link بعد ربع ساعة تجمع اللي يخلص معاه — رسالة لينك أمازون واحدة في اليوم بالكتير.';

revoke execute on function public._zad_restock_link_on_run_out() from public, anon, authenticated;

drop trigger if exists trigger_restock_link_on_run_out on public.zad_inventory;
create trigger trigger_restock_link_on_run_out
  after update of quantity on public.zad_inventory
  for each row execute function public._zad_restock_link_on_run_out();
