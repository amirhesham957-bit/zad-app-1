-- شات العيلة يوصل والتطبيق مقفول — استغاثة الابن أولاً.
--
-- تطبيق كوتلن كان عنده خدمة في الخلفية (ChatNotificationService) بتسمع الشات وتطلع إشعار،
-- واستغاثة (SOS) بقناة لوحدها. نسخة فلاتر بتقرا الشات بس وهي مفتوحة على شاشة العيلة، فرسالة
-- «الرجاء الانتباه، حالة طوارئ!» كانت ممكن ماتوصلش لحد لحد ما حد يفتح الشاشة.
--
-- دلوقتي كل رسالة جديدة بتنادي zad-brain (family_message_push)، وده بيبعت FCM لكل فرد في
-- العيلة غير اللي كتب (familyPush.ts). بنفس سر الكرون اللي باقي نداءات zad-brain بتستخدمه.
--
-- الإشعار عمره ما يوقّع الرسالة: أي خطأ في النداء بيتبلع هنا والرسالة بتتحفظ عادي.
-- net.http_post غير متزامن أصلاً (pg_net)، فالإدخال مابيستناش الشبكة.

create or replace function public.zad_push_family_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.sender_id = 'zad_ai' then
    return new;
  end if;
  begin
    perform net.http_post(
      url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
      ),
      body := jsonb_build_object('action', 'family_message_push', 'message_id', new.id),
      timeout_milliseconds := 10000
    );
  exception when others then
    raise warning 'family chat push not queued: %', sqlerrm;
  end;
  return new;
end;
$$;

revoke all on function public.zad_push_family_message() from public, anon, authenticated;

drop trigger if exists chat_messages_push on public.chat_messages;
create trigger chat_messages_push
  after insert on public.chat_messages
  for each row execute function public.zad_push_family_message();
