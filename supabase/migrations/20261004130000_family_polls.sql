-- =====================================================
-- تصويت العيلة (docs/agent/ZAD_LIVING_BRAIN.md الشريحة ٢٤ — قرار المالك 2026-10-04: «ابدأ في تصويت العيلة لتطوير
-- نظام الاستفتاءات التفاعلية داخل شات الأسرة»).
--
-- التصويت كان موجود في الشات (رسالة POLL: سؤال واختيارات وأصوات في metadata) بس:
--   - **أي فرد كان يقدر يكتب أصوات غيره:** التطبيق بيبعت خريطة الأصوات كلها في metadata، وتريجر الحماية
--     كان قافل metadata على طلبات الشراء بس. استفتاء عائلي لازم يكون موثوق.
--   - مالوش نهاية ولا نتيجة: مفيش ميعاد قفل، ولا إعلان، ولا معنى لـ«العيلة اتفقت».
--
-- دلوقتي:
--   - الصوت من zad_family_poll_vote بس: الفرد بيصوّت لنفسه (صفه في family_members)، ويقدر يغيّر صوته لحد ما يتقفل.
--   - zad_family_poll_close: صاحب التصويت أو مسؤول العيلة (أو السيرفر لما الميعاد يخلص): العدّ، الاختيار الكسبان
--     (التعادل = مفيش كسبان)، و«توافق» = كل الكبار (غير الأطفال) اختاروا الكسبان. وزاد بيعلن النتيجة في الشات.
--   - zad_family_polls_close_due كل ساعة (pg_cron) للي ميعادها (closes_at) خلص.
--   - التريجر بيتحقق من شكل التصويت الجديد (سؤال ١–٢٠٠ حرف، ٢–٦ اختيارات، من غير أصوات ولا نتيجة جاهزة) ومن إن
--     metadata التصويت مابتتغيرش من التطبيق.
-- =====================================================

-- شكل تصويت جديد صحيح؟ (metadata نص JSON)
create or replace function public.zad_family_poll_shape_ok(p_metadata text)
returns boolean
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  v jsonb;
  v_opt jsonb;
  v_n int;
begin
  begin
    v := p_metadata::jsonb;
  exception when others then
    return false;
  end;
  if jsonb_typeof(v) is distinct from 'object' then return false; end if;
  if char_length(btrim(coalesce(v ->> 'question', ''))) not between 1 and 200 then return false; end if;
  if jsonb_typeof(v -> 'options') is distinct from 'array' then return false; end if;
  v_n := jsonb_array_length(v -> 'options');
  if v_n not between 2 and 6 then return false; end if;
  for v_opt in select * from jsonb_array_elements(v -> 'options') loop
    if jsonb_typeof(v_opt) is distinct from 'string'
       or char_length(btrim(v_opt #>> '{}')) not between 1 and 60 then
      return false;
    end if;
  end loop;
  if coalesce(v -> 'votes', '{}'::jsonb) <> '{}'::jsonb then return false; end if;
  if v ? 'closed' or v ? 'result' then return false; end if;
  if v ? 'closes_at' then
    begin
      if (v ->> 'closes_at')::timestamptz <= now()
         or (v ->> 'closes_at')::timestamptz > now() + interval '31 days' then
        return false;
      end if;
    exception when others then
      return false;
    end;
  end if;
  return true;
end
$function$;

create or replace function public.zad_chat_messages_guard()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_meta jsonb;
begin
  if auth.uid() is null or public.zad_family_ledger_open() then return new; end if;

  if tg_op = 'INSERT' then
    -- باسمك أو باسم زاد بس (ZAD_LIVING_BRAIN.md الشريحة ٣): العقل بيقرا الرسالة على إنها من
    -- صاحب sender_id، وموافقته هو اللي بتسمح.
    if coalesce(new.sender_id, '') <> 'zad_ai' and not exists (
      select 1 from public.family_members
       where id::text = new.sender_id and user_id = auth.uid()
         and family_id = new.family_id
    ) then
      raise exception 'message_in_own_name_only' using errcode = '42501';
    end if;
    if new.message_type = 'PURCHASE_REQUEST' then
      -- In the sender's own name: approval debits the sender.
      if not exists (
        select 1 from public.family_members
        where id::text = new.sender_id and user_id = auth.uid()
          and family_id = new.family_id
      ) then
        raise exception 'request_in_own_name_only' using errcode = '42501';
      end if;
      begin
        v_meta := new.metadata::jsonb;
      exception when others then
        raise exception 'invalid_request' using errcode = '22023';
      end;
      if coalesce(v_meta ->> 'status', '') <> 'PENDING'
         or coalesce((v_meta ->> 'amount')::numeric, 0) <= 0 then
        raise exception 'invalid_request' using errcode = '22023';
      end if;
    end if;
    -- تصويت العيلة (20261004130000): سؤال واختيارات بحدود، ومن غير أصوات جاهزة ولا نتيجة جاهزة.
    if new.message_type = 'POLL' then
      if not public.zad_family_poll_shape_ok(new.metadata) then
        raise exception 'invalid_poll' using errcode = '22023';
      end if;
    end if;
    return new;
  end if;

  -- What a message says, and who it is from, never change from the app.
  if new.message is distinct from old.message
     or new.sender_id is distinct from old.sender_id
     or new.family_id is distinct from old.family_id
     or new.message_type is distinct from old.message_type then
    raise exception 'messages_are_not_edited' using errcode = '42501';
  end if;

  -- Pins and reactions stay open; what a request says is decided on the server.
  if (old.message_type = 'PURCHASE_REQUEST' or new.message_type = 'PURCHASE_REQUEST')
     and new.metadata is distinct from old.metadata then
    raise exception 'requests_are_decided_on_the_server' using errcode = '42501';
  end if;
  -- A poll's votes and result too (20261004130000): each member votes for themself through
  -- zad_family_poll_vote; nobody rewrites another member's vote, the question or the options.
  if (old.message_type = 'POLL' or new.message_type = 'POLL')
     and new.metadata is distinct from old.metadata then
    raise exception 'polls_change_on_the_server' using errcode = '42501';
  end if;
  return new;
end;
$function$;

-- الصوت: لنفسك بس، وتقدر تغيّره لحد ما التصويت يتقفل.
create or replace function public.zad_family_poll_vote(p_message uuid, p_option integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_msg record;
  v_member uuid;
  v_meta jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  select id, family_id, message_type, metadata into v_msg from public.chat_messages where id = p_message;
  if not found or v_msg.message_type is distinct from 'POLL' then
    return jsonb_build_object('ok', false, 'reason', 'not_a_poll');
  end if;
  select id into v_member from public.family_members where user_id = v_uid and family_id = v_msg.family_id;
  if v_member is null then
    return jsonb_build_object('ok', false, 'reason', 'not_in_family');
  end if;
  begin
    v_meta := v_msg.metadata::jsonb;
  exception when others then
    return jsonb_build_object('ok', false, 'reason', 'not_a_poll');
  end;
  if coalesce((v_meta ->> 'closed')::boolean, false)
     or (v_meta ? 'closes_at' and (v_meta ->> 'closes_at')::timestamptz <= now()) then
    return jsonb_build_object('ok', false, 'reason', 'closed');
  end if;
  if p_option is null or p_option < 0 or p_option >= jsonb_array_length(coalesce(v_meta -> 'options', '[]'::jsonb)) then
    return jsonb_build_object('ok', false, 'reason', 'bad_option');
  end if;
  v_meta := jsonb_set(v_meta, '{votes}',
    coalesce(v_meta -> 'votes', '{}'::jsonb) || jsonb_build_object(v_member::text, p_option));
  perform set_config('zad.family_ledger', 'on', true);
  update public.chat_messages set metadata = v_meta::text where id = p_message;
  perform set_config('zad.family_ledger', 'off', true);
  return jsonb_build_object('ok', true, 'votes', (select count(*) from jsonb_object_keys(v_meta -> 'votes')));
end
$function$;

-- القفل والنتيجة. p_by_server = الكرون (من غير auth.uid())؛ غير كده صاحب التصويت أو مسؤول العيلة.
create or replace function public.zad_family_poll_close(p_message uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_msg record;
  v_meta jsonb;
  v_n int;
  v_counts int[];
  v_vote record;
  v_max int := 0;
  v_winner int := null;
  v_ties int := 0;
  v_voters int := 0;
  v_adults int;
  v_adults_with_winner int;
  v_consensus boolean;
  v_question text;
  v_text text;
  i int;
begin
  select id, family_id, sender_id, message_type, metadata into v_msg from public.chat_messages where id = p_message;
  if not found or v_msg.message_type is distinct from 'POLL' then
    return jsonb_build_object('ok', false, 'reason', 'not_a_poll');
  end if;
  if v_uid is not null and not exists (
    select 1 from public.family_members
     where user_id = v_uid and family_id = v_msg.family_id
       and (id::text = v_msg.sender_id or role = 'admin')
  ) then
    return jsonb_build_object('ok', false, 'reason', 'not_allowed');
  end if;
  begin
    v_meta := v_msg.metadata::jsonb;
  exception when others then
    return jsonb_build_object('ok', false, 'reason', 'not_a_poll');
  end;
  if coalesce((v_meta ->> 'closed')::boolean, false) then
    return jsonb_build_object('ok', true, 'already', true, 'result', v_meta -> 'result');
  end if;

  v_n := jsonb_array_length(coalesce(v_meta -> 'options', '[]'::jsonb));
  v_counts := array_fill(0, array[greatest(v_n, 1)]);
  for v_vote in select key, value from jsonb_each_text(coalesce(v_meta -> 'votes', '{}'::jsonb)) loop
    begin
      i := v_vote.value::int;
    exception when others then
      continue;
    end;
    continue when i < 0 or i >= v_n;
    -- صوت من حد مابقاش في العيلة مابيتحسبش.
    continue when not exists (select 1 from public.family_members where id::text = v_vote.key and family_id = v_msg.family_id);
    v_counts[i + 1] := v_counts[i + 1] + 1;
    v_voters := v_voters + 1;
  end loop;
  for i in 1..v_n loop
    if v_counts[i] > v_max then
      v_max := v_counts[i]; v_winner := i - 1; v_ties := 1;
    elsif v_counts[i] = v_max and v_max > 0 then
      v_ties := v_ties + 1;
    end if;
  end loop;
  if v_max = 0 or v_ties > 1 then v_winner := null; end if;

  select count(*) into v_adults from public.family_members
   where family_id = v_msg.family_id and coalesce(role, 'member') <> 'child';
  select count(*) into v_adults_with_winner
    from jsonb_each_text(coalesce(v_meta -> 'votes', '{}'::jsonb)) v
    join public.family_members m on m.id::text = v.key and m.family_id = v_msg.family_id
   where coalesce(m.role, 'member') <> 'child' and v_winner is not null and v.value = v_winner::text;
  v_consensus := v_winner is not null and v_adults > 0 and v_adults_with_winner = v_adults;

  v_meta := v_meta
    || jsonb_build_object('closed', true, 'closed_at', now())
    || jsonb_build_object('result', jsonb_build_object(
         'counts', to_jsonb(v_counts), 'winner', v_winner, 'voters', v_voters, 'consensus', v_consensus));
  perform set_config('zad.family_ledger', 'on', true);
  update public.chat_messages set metadata = v_meta::text where id = p_message;

  v_question := btrim(coalesce(v_meta ->> 'question', ''));
  v_text := case
    when v_voters = 0 then format('📊 التصويت «%s» اتقفل من غير أصوات.', v_question)
    when v_winner is null then format('📊 التصويت «%s» خلص بالتعادل — محتاجين تتكلموا فيه.', v_question)
    else format('📊 نتيجة «%s»: %s (%s من %s صوت)%s', v_question, v_meta -> 'options' ->> v_winner,
      v_max, v_voters, case when v_consensus then ' — الكبار كلهم متفقين ✅' else '' end)
  end;
  insert into public.chat_messages (family_id, sender_id, message, message_type, metadata)
  values (v_msg.family_id, 'zad_ai', v_text, 'TEXT',
    jsonb_build_object('kind', 'poll_result', 'poll', p_message)::text);
  perform set_config('zad.family_ledger', 'off', true);
  return jsonb_build_object('ok', true, 'result', v_meta -> 'result');
end
$function$;

-- كل اللي ميعادها خلص. للكرون بس.
create or replace function public.zad_family_polls_close_due()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_id uuid;
  v_n int := 0;
begin
  for v_id in
    select id from public.chat_messages
     where message_type = 'POLL'
       and created_at > now() - interval '60 days'
       and metadata ~ '"closes_at"'
       and coalesce((metadata::jsonb ->> 'closed')::boolean, false) = false
       and (metadata::jsonb ->> 'closes_at')::timestamptz <= now()
  loop
    perform public.zad_family_poll_close(v_id);
    v_n := v_n + 1;
  end loop;
  return v_n;
end
$function$;

revoke all on function public.zad_family_poll_shape_ok(text) from public, anon, authenticated;
revoke all on function public.zad_family_poll_vote(uuid, integer) from public, anon;
grant execute on function public.zad_family_poll_vote(uuid, integer) to authenticated;
revoke all on function public.zad_family_poll_close(uuid) from public, anon;
grant execute on function public.zad_family_poll_close(uuid) to authenticated;
revoke all on function public.zad_family_polls_close_due() from public, anon, authenticated;

-- كل ساعة عند الدقيقة ٢٣. من غير pg_cron (قاعدة تجربة) بيتخطى.
do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('family-polls-close-due') where exists (select 1 from cron.job where jobname = 'family-polls-close-due');
    perform cron.schedule('family-polls-close-due', '23 * * * *', 'select public.zad_family_polls_close_due()');
  end if;
end
$cron$;
