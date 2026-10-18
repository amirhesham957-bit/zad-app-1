-- المحادثة الواحدة (_shared/conversationLog.ts، ٢٠٢٦-١٠-١٨): مبادرات زاد ولحظاته الصوتية بقت بتتكتب في
-- zad_chat_turns كدور assistant. تحية الصبح وتصبح على خير كانوا بيعتبروا العميل «نشط» لو فيه أي لفة
-- في zad_chat_turns مؤخراً — يعني التحية نفسها كانت هتخلّيه مستحق تحية بكرة، للأبد، حتى لو بطّل.
-- الشرط بقى: العميل نفسه اتكلم (role = 'user').
--
-- نفس نمط 20260905150000: استبدال واحد على تعريف الدالة الحي بدل نقل جسمها بإيد، والاستبدال لازم
-- يكون حصل فعلاً وإلا الميجريشن تقع.

do $fix$
declare
  fn text;
  def text;
  fixed text;
  needle constant text := 'c.user_id = au.id and c.created_at > now()';
  repl constant text := 'c.user_id = au.id and c.role = ''user'' and c.created_at > now()';
begin
  foreach fn in array array['zad_enqueue_morning_fallback', 'zad_enqueue_good_night'] loop
    select pg_get_functiondef(p.oid) into def
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = fn;
    if def is null then
      raise exception 'function % not found', fn;
    end if;
    if position(repl in def) > 0 then
      continue; -- اتطبق قبل كده
    end if;
    fixed := replace(def, needle, repl);
    if fixed = def then
      raise exception 'function %: the zad_chat_turns condition was not found', fn;
    end if;
    execute fixed;
  end loop;
end
$fix$;
