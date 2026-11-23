-- البوت بيتكلم مع كل إشعار: أغلب العملاء مستنيين بوت تليجرام يبلّغهم، والإشعارات كانت بتوصل التطبيق بس.
-- النمط الموجود: تريجر على app_notifications بيندّه zad-telegram-bot (agent_task_telegram_delivery، ٢٠٢٦-٠٨-١٠). هنا
-- بيتعمم من غير مسار جديد: نفس الجدول، نفس السر (zad_realtime_push_secret)، نفس الربط (telegram_bindings).
--
-- مين بيتبعت: (١) الصف معلّم bot_push (تنبيه الريستوك اليومي)، (٢) عنوان «زاد خلّص مهمة كنت طلبتها» (زي ما كان)،
-- (٣) أي صف جاي من دالة/تريجر في الداتابيز أو من العميل نفسه (role مش service_role): تنبيهات العيلة والأهل والجرعات...
-- اللي بيكتبوا من service_role مباشرة (zad-brain: مبادرات، نداء الرفيق، رابط الريستوك، دوا العيلة) بيبعتوا تليجرام بنفسهم،
-- فمابنكررهمش. مفيش تغيير في zad-brain.
--
-- القرار الحقيقي (الكتم، ساعات النوم، السقف اليومي، التكرار) في zad-telegram-bot ?job=notification_push، بيحجز
-- الإشعار في zad_bot_notification_push بالـid، فإشعار واحد = رسالة واحدة حتى لو التريجر اتنده تاني.
-- النداء جوه begin/exception: تنبيه ضايع أهون من إشعار ماتسجّلش.

alter table public.app_notifications add column if not exists bot_push boolean not null default false;
comment on column public.app_notifications.bot_push is
  'الكاتب (service_role) عايز البوت يبعت الإشعار ده كمان. بيتعلّم من zad-restock-alerts. الباقي بيتحدد من التريجر.';

create table if not exists public.zad_bot_notification_push (
  notification_id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'skipped' check (status in ('sent', 'skipped')),
  reason text check (reason is null or length(reason) <= 40),
  created_at timestamptz not null default now()
);
create index if not exists zad_bot_notification_push_user on public.zad_bot_notification_push (user_id, created_at desc);
alter table public.zad_bot_notification_push enable row level security;
revoke all on public.zad_bot_notification_push from public, anon, authenticated;

create or replace function public.notify_telegram_on_app_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_role text;
begin
  if not exists (
    select 1 from public.telegram_bindings
     where user_id = new.user_id and bound_at is not null and chat_id is not null
  ) then
    return new;
  end if;

  v_role := coalesce(
    nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    'db'
  );
  if not (new.bot_push
          or new.title = 'زاد خلّص مهمة كنت طلبتها'
          or v_role <> 'service_role') then
    return new;
  end if;

  begin
    -- نتيجة مهمة العميل طلبها بنفسه: بتوصل زي ما كانت (realtime_push) من غير كتم ولا سقف.
    perform net.http_post(
      url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job='
             || case when new.title = 'زاد خلّص مهمة كنت طلبتها' then 'realtime_push' else 'notification_push' end,
      headers := jsonb_build_object('Content-Type', 'application/json',
                                    'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')),
      body := jsonb_build_object('notification_id', new.id, 'user_id', new.user_id, 'title', new.title, 'body', new.message),
      timeout_milliseconds := 15000
    );
  exception when others then
    raise warning 'notify_telegram_on_app_notification: push skipped (%)', sqlerrm;
  end;
  return new;
end;
$function$;
revoke all on function public.notify_telegram_on_app_notification() from public, anon, authenticated;

drop trigger if exists trigger_notify_telegram_on_agent_task_notification on public.app_notifications;
drop trigger if exists trigger_notify_telegram_on_app_notification on public.app_notifications;
create trigger trigger_notify_telegram_on_app_notification
after insert on public.app_notifications
for each row execute function public.notify_telegram_on_app_notification();

drop function if exists public.notify_telegram_on_agent_task_notification();
