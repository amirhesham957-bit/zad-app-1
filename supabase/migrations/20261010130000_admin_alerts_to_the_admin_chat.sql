-- System health alerts go to the private admin chat, never to a customer's chat (2026-10-10).
--
-- «العقل الاستباقي ساكت من ٣٧ ساعة…» reached the owner's customer chat in the bot. Three
-- functions sent their alert to every dashboard admin through that admin's own
-- `telegram_bindings` row — and an admin who also uses Zad has one chat for both, so the
-- diagnostics landed between the morning greeting and the shopping list.
--
-- Now they call `zad_notify_admin`, which posts to the bot's `admin_alert` job. The bot sends
-- to `ZAD_ADMIN_CHAT_ID` (a function secret: a Telegram group or channel the bot is in) and
-- nowhere else. With the secret unset the alert is logged and dropped; with it pointing at a
-- chat that is bound as a customer chat the bot refuses — that is the mistake being closed.
-- The rows in `zad_brain_health_alerts` are written exactly as before.
--
-- The three functions are edited on their live text, not retyped from older migrations
-- (`ZAD_LIVING_BRAIN.md` §١١ — the repo and the live functions have drifted before): each
-- admin loop is found by its words with any spacing, must be found exactly once, and is
-- replaced by one call. A function that does not match stops the migration.

create or replace function public.zad_notify_admin(p_title text, p_body text)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  perform net.http_post(
    url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=admin_alert',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')
    ),
    body := jsonb_build_object('title', p_title, 'body', p_body),
    timeout_milliseconds := 15000
  );
end;
$function$;

revoke all on function public.zad_notify_admin(text, text) from public, anon, authenticated;

do $migrate$
declare
  r record;
  v_def text;
  v_pat text;
  v_hits int;
begin
  for r in
    select * from (values
      ('zad_brain_health_check', '⚠️ صحة العقل', ''),
      ('zad_proactive_silence_check', '🔇 العقل ساكت', 'public.'),
      ('agent_proactive_scan', '🚨 الماسح الاستباقي', 'public.')
    ) t(fn, title, schema_prefix)
  loop
    select pg_get_functiondef(p.oid) into v_def
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = r.fn;
    if v_def is null then
      raise exception 'admin alerts: % not found', r.fn;
    end if;

    v_pat := 'for v_admin in select b.user_id from ' || r.schema_prefix || 'dashboard_admins a '
      || 'join ' || r.schema_prefix || 'telegram_bindings b on b.user_id = a.user_id and b.bound_at is not null '
      || 'loop perform net.http_post( '
      || 'url := ''https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=realtime_push'', '
      || 'headers := jsonb_build_object( ''Content-Type'', ''application/json'', '
      || '''X-Realtime-Push-Secret'', public.zad_cron_secret(''zad_realtime_push_secret'') ), '
      || 'body := jsonb_build_object(''user_id'', v_admin.user_id, '
      || '''title'', ''' || r.title || ''', ''body'', v_body), '
      || 'timeout_milliseconds := 15000 ); end loop;';
    -- Literal words, any spacing: escape the regex characters, then let every gap match any
    -- run of whitespace, and an opening/closing bracket sit with or without a space beside it.
    v_pat := regexp_replace(v_pat, '([.*+?^${}()|\[\]\\])', '\\\1', 'g');
    v_pat := regexp_replace(v_pat, '\\\( ', '\\(\\s*', 'g');
    v_pat := regexp_replace(v_pat, ' \\\)', '\\s*\\)', 'g');
    v_pat := regexp_replace(v_pat, ' ', '\\s+', 'g');

    v_hits := regexp_count(v_def, v_pat);
    if v_hits <> 1 then
      raise exception 'admin alerts: % has % admin loops matching, expected 1', r.fn, v_hits;
    end if;

    execute regexp_replace(v_def, v_pat,
      'perform public.zad_notify_admin(''' || r.title || ''', v_body);');
  end loop;
end
$migrate$;
