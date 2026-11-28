-- بعد scratch_scaffold.sql و20261128170000_app_notifications_dedupe.sql.
\set ON_ERROR_STOP on

do $$
declare n int;
begin
  -- نفس اللحظة مرتين لنفس العميل = صف واحد.
  insert into public.app_notifications (user_id, title, message, dedupe_key)
    values ('00000000-0000-0000-0000-0000000000a1', 't', 'm', 'voice_moment:x')
    on conflict (user_id, dedupe_key) do nothing;
  insert into public.app_notifications (user_id, title, message, dedupe_key)
    values ('00000000-0000-0000-0000-0000000000a1', 't', 'm', 'voice_moment:x')
    on conflict (user_id, dedupe_key) do nothing;
  select count(*) into n from public.app_notifications where dedupe_key = 'voice_moment:x';
  assert n = 1, format('same moment twice: %s', n);

  -- نفس المفتاح لعميل تاني = صف تاني.
  insert into public.app_notifications (user_id, title, message, dedupe_key)
    values ('00000000-0000-0000-0000-0000000000a2', 't', 'm', 'voice_moment:x')
    on conflict (user_id, dedupe_key) do nothing;
  select count(*) into n from public.app_notifications where dedupe_key = 'voice_moment:x';
  assert n = 2, format('other user: %s', n);

  -- الكتّاب القدام من غير مفتاح مابيتأثروش.
  insert into public.app_notifications (user_id, title, message) values ('00000000-0000-0000-0000-0000000000a1', 't', 'old1');
  insert into public.app_notifications (user_id, title, message) values ('00000000-0000-0000-0000-0000000000a1', 't', 'old2');
  select count(*) into n from public.app_notifications where dedupe_key is null and user_id = '00000000-0000-0000-0000-0000000000a1';
  assert n = 2, format('null keys: %s', n);
end $$;
