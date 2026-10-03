-- =====================================================
-- زاد بيقرا شات العيلة — بموافقة كل كاتب على رسايله هو
-- (docs/agent/ZAD_LIVING_BRAIN.md، الشريحة ٣ — قرار المالك 2026-10-03).
--
-- «يتابع شات العيلة». أفراد العيلة كلهم شايفين الشات أصلاً؛ الجديد إن الرسايل تروح لموديل
-- ذكاء اصطناعي (Gemini) جوه عقل زاد. ده معالجة لمحتوى المستخدم ⇒ موافقة صاحب الرسالة هو:
--   - كل فرد بيختار «زاد يقرا رسايلي» لنفسه (zad_family_chat_consent)، وبيوقفها في أي وقت.
--   - العقل (لأي فرد في العيلة) بيشوف رسايل الموافقين بس؛ رسايل اللي ماوافقش ماتوصلش الموديل.
--   - أفراد العيلة شايفين مين موافق (شفافية: محدش يتفاجئ إن زاد قرا كلامه).
--
-- قبل ما العقل يصدّق إن الرسالة من صاحبها، اتقفلت ثغرتين في الشات نفسه:
--   - الإدراج كان بيتحقق من العيلة بس: أي فرد كان يقدر يبعت رسالة sender_id بتاعها فرد تاني.
--     دلوقتي: من غير السيرفر، الرسالة باسمك (صفك في family_members) أو باسم زاد ('zad_ai').
--   - التعديل كان مفتوح على أي عمود: أي فرد كان يقدر يغيّر نص رسالة فرد تاني. دلوقتي النص
--     والمرسل والعيلة والنوع مابيتغيروش من التطبيق؛ التثبيت والتفاعلات والتصويت زي ما هم.
-- =====================================================

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
  return new;
end;
$function$;

-- ── الموافقة ─────────────────────────────────────────────────────────────────

create table if not exists public.zad_family_chat_consent (
  user_id uuid primary key references auth.users(id) on delete cascade,
  family_id uuid not null references public.family_groups(id) on delete cascade,
  granted_at timestamptz not null default now()
);

-- Supabase بيدّي anon وauthenticated كل الصلاحيات على أي جدول جديد (ZAD_LIVING_BRAIN.md §٧).
alter table public.zad_family_chat_consent enable row level security;
revoke all on public.zad_family_chat_consent from anon, authenticated;
grant select on public.zad_family_chat_consent to authenticated;

-- العيلة كلها شايفة مين موافق: محدش يتفاجئ إن زاد قرا كلامه.
drop policy if exists "family_chat_consent: the family reads" on public.zad_family_chat_consent;
create policy "family_chat_consent: the family reads"
  on public.zad_family_chat_consent for select to authenticated
  using (family_id in (select public.get_my_family_ids()));

comment on table public.zad_family_chat_consent is
  'صف = الفرد ده موافق إن عقل زاد يقرا رسايله هو في شات العيلة. بيتكتب من zad_family_chat_consent_set بس. مسحه = وقف.';

/** «زاد يقرا رسايلي» — شغّل أو وقّف، للعيلة اللي العميل فيها دلوقتي. */
create or replace function public.zad_family_chat_consent_set(p_on boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_family uuid;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  select family_id into v_family from public.family_members where user_id = v_me limit 1;
  if v_family is null then return jsonb_build_object('ok', false, 'reason', 'not_in_family'); end if;
  if coalesce(p_on, false) then
    insert into public.zad_family_chat_consent (user_id, family_id)
    values (v_me, v_family)
    on conflict (user_id) do update set family_id = excluded.family_id, granted_at = now();
  else
    delete from public.zad_family_chat_consent where user_id = v_me;
  end if;
  return jsonb_build_object('ok', true, 'on', coalesce(p_on, false));
end $$;
revoke all on function public.zad_family_chat_consent_set(boolean) from public, anon;
grant execute on function public.zad_family_chat_consent_set(boolean) to authenticated;

/** للتطبيق: أنا موافق؟ ومين في عيلتي موافق (بالأسماء). */
create or replace function public.zad_family_chat_consent_view()
returns jsonb language sql stable security definer set search_path = public as $$
  select case when auth.uid() is null then jsonb_build_object('ok', false, 'reason', 'not_authenticated')
  else jsonb_build_object(
    'ok', true,
    'mine', exists (
      select 1 from public.zad_family_chat_consent c
        join public.family_members m on m.user_id = c.user_id and m.family_id = c.family_id
       where c.user_id = auth.uid()
    ),
    'readers', coalesce((
      select jsonb_agg(coalesce(nullif(btrim(m.alias), ''), 'فرد من العيلة') order by m.alias)
        from public.zad_family_chat_consent c
        join public.family_members m on m.user_id = c.user_id and m.family_id = c.family_id
       where c.family_id in (select public.get_my_family_ids())
    ), '[]'::jsonb)
  ) end;
$$;
revoke all on function public.zad_family_chat_consent_view() from public, anon;
grant execute on function public.zad_family_chat_consent_view() to authenticated;

/**
 * للعقل (service_role): آخر رسايل شات عيلة [p_viewer] من الموافقين بس، الأقدم الأول. رسايل
 * زاد نفسه مش منها. النص مقصوص — ده سياق، مش أرشيف.
 */
create or replace function public.zad_family_chat_for_brain(p_viewer uuid, p_hours integer default 24, p_limit integer default 15)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'who', x.who, 'mine', x.mine, 'type', x.message_type, 'text', x.body, 'at', x.created_at
    ) order by x.created_at), '[]'::jsonb)
    from (
      select coalesce(nullif(btrim(m.alias), ''), 'فرد من العيلة') as who,
             m.user_id = p_viewer as mine,
             c.message_type,
             left(c.message, 300) as body,
             c.created_at
        from public.chat_messages c
        join public.family_members m on m.id::text = c.sender_id and m.family_id = c.family_id
        join public.zad_family_chat_consent k on k.user_id = m.user_id and k.family_id = m.family_id
       where c.family_id = (select family_id from public.family_members where user_id = p_viewer limit 1)
         and c.created_at >= now() - make_interval(hours => greatest(1, least(coalesce(p_hours, 24), 168)))
         and coalesce(c.sender_id, '') <> 'zad_ai'
       order by c.created_at desc
       limit greatest(1, least(coalesce(p_limit, 15), 50))
    ) x;
$$;
revoke all on function public.zad_family_chat_for_brain(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.zad_family_chat_for_brain(uuid, integer, integer) to service_role;
