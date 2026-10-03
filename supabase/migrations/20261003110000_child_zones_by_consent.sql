-- =====================================================
-- نطاقات الأولاد بالموافقة (docs/agent/ZAD_LIVING_BRAIN.md، الشريحة ٢ — قرار المالك 2026-10-03).
--
-- «ينبهني الولد مش في المدرسة، خرج». بيتبني على شبكة العيلة بالموافقة (20261001130000):
-- نطاق جديد `location` في zad_family_shares — ولي الأمر بيطلب، والطفل بيوافق من موبايله،
-- وأي طرف يقدر يوقف.
--
-- حدود سياسة Google Play (Stalkerware، اتقرت 2026-10-03): المتابعة مسموحة **للأهل على
-- أولادهم بس**؛ تتبع أي بالغ — الزوج/الزوجة كمان — ممنوع حتى بموافقته. فالنطاق ده:
--   - بيتطلب ويتشاف بس لو صاحب البيانات دوره في العيلة `child`، والفحص في
--     zad_family_share_granted نفسها: لو الطفل كبر ودوره اتغير، المتابعة بتقف لوحدها.
--   - موبايل الطفل بيعرض إشعار دايم طول ما المشاركة شغالة (في التطبيق، مش هنا).
--
-- أقل بيانات ممكنة: مفيش تتبع مستمر ولا خط سير. ولي الأمر بيحدد نطاقات (المدرسة، النادي)
-- بمركز ونصف قطر، وموبايل الطفل بيسجّلها geofence (نفس بلج-إن zad_geofence) وبيبعت
-- **دخول/خروج بس**. الإحداثيات المتخزنة = مركز النطاق اللي ولي الأمر حدده، مش مكان الطفل.
--
-- التنبيه: خروج من نطاق جوه المواعيد اللي ولي الأمر حددها (أيام وساعات الدراسة) ⇒ لحظة
-- family_zone_exit لكل متابع موافَق عليه، بنفس مسار لحظات زاد (voiceMoments.ts: موبايل +
-- تليجرام). رجوع للنطاق بعد خروج اتنبّه عليه ⇒ family_zone_back. أي حاجة تانية بتتسجل من
-- غير تنبيه (بتبان في «عيلتي» كـ«جوه المدرسة من ٧:٤٥»).
-- =====================================================

-- ── النطاق الجديد في الموافقات ──────────────────────────────────────────────

alter table public.zad_family_shares drop constraint if exists zad_family_shares_scope_check;
alter table public.zad_family_shares
  add constraint zad_family_shares_scope_check
  check (scope in ('medicines', 'spending', 'tasks', 'location'));

-- مين يشوف إيه — نفس الدالة، بشرط زيادة للموقع: صاحب البيانات لسه `child`.
create or replace function public.zad_family_share_granted(p_viewer uuid, p_owner uuid, p_scope text)
returns boolean language sql stable security definer set search_path = public as $$
  select p_viewer = p_owner or exists (
    select 1
      from public.zad_family_shares s
      join public.family_members fo on fo.user_id = s.owner_id and fo.family_id = s.family_id
      join public.family_members fv on fv.user_id = s.viewer_id and fv.family_id = s.family_id
     where s.owner_id = p_owner and s.viewer_id = p_viewer
       and s.scope = p_scope and s.status = 'granted'
       and (s.scope <> 'location' or fo.role = 'child')
  );
$$;

create or replace function public.zad_family_scope_label(p_scope text, p_second_person boolean)
returns text language sql immutable set search_path = public as $$
  select case p_scope
    when 'medicines' then case when p_second_person then 'أدويتك' else 'أدويته' end
    when 'spending' then case when p_second_person then 'مصروفك' else 'مصروفه' end
    when 'location' then case when p_second_person then 'دخولك وخروجك من أماكن زي المدرسة'
                              else 'دخوله وخروجه من أماكن زي المدرسة' end
    else case when p_second_person then 'مهامك ومواعيدك' else 'مهامه ومواعيده' end
  end;
$$;
revoke all on function public.zad_family_scope_label(text, boolean) from public, anon;
grant execute on function public.zad_family_scope_label(text, boolean) to authenticated, service_role;

create or replace function public.zad_family_request_share(p_owner uuid, p_scopes text[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_family uuid;
  v_alias text;
  v_owner_role text;
  v_scope text;
  v_asked int := 0;
  v_labels text[] := '{}';
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_owner is null or p_owner = v_me then
    return jsonb_build_object('ok', false, 'reason', 'self');
  end if;
  select fv.family_id, fv.alias, fo.role into v_family, v_alias, v_owner_role
    from public.family_members fv
    join public.family_members fo on fo.family_id = fv.family_id and fo.user_id = p_owner
   where fv.user_id = v_me and fv.role = 'admin'
   limit 1;
  if v_family is null then
    return jsonb_build_object('ok', false, 'reason', 'not_family_admin');
  end if;

  foreach v_scope in array coalesce(p_scopes, '{}') loop
    continue when v_scope not in ('medicines', 'spending', 'tasks', 'location');
    -- Play: متابعة مكان بالغ ممنوعة حتى بموافقته.
    continue when v_scope = 'location' and coalesce(v_owner_role, '') <> 'child';
    insert into public.zad_family_shares (family_id, owner_id, viewer_id, scope, status, requested_at, decided_at)
    values (v_family, p_owner, v_me, v_scope, 'pending', now(), null)
    on conflict (owner_id, viewer_id, scope) do update
      set status = 'pending', requested_at = now(), decided_at = null, family_id = excluded.family_id
      where public.zad_family_shares.status in ('declined', 'revoked');
    if found then
      v_asked := v_asked + 1;
      v_labels := v_labels || public.zad_family_scope_label(v_scope, true);
    end if;
  end loop;

  if v_asked > 0 then
    insert into public.app_notifications (user_id, title, message, is_read)
    values (
      p_owner,
      '👨‍👩‍👧 طلب متابعة من العيلة',
      coalesce(nullif(trim(v_alias), ''), 'حد من العيلة') || ' عايز يتابع ' || array_to_string(v_labels, ' و')
        || '. افتح «عيلتي» ووافق أو ارفض — وتقدر تلغي في أي وقت.',
      false
    );
  end if;
  return jsonb_build_object('ok', true, 'requested', v_asked);
end $$;
revoke all on function public.zad_family_request_share(uuid, text[]) from public, anon;
grant execute on function public.zad_family_request_share(uuid, text[]) to authenticated;

create or replace function public.zad_family_answer_share(p_share uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_row public.zad_family_shares%rowtype;
  v_alias text;
begin
  update public.zad_family_shares
     set status = case when p_accept then 'granted' else 'declined' end, decided_at = now()
   where id = p_share and owner_id = auth.uid() and status = 'pending'
  returning * into v_row;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_pending'); end if;

  select alias into v_alias from public.family_members
   where user_id = v_row.owner_id and family_id = v_row.family_id;
  insert into public.app_notifications (user_id, title, message, is_read)
  values (
    v_row.viewer_id,
    case when p_accept then '✅ وافق على المتابعة' else 'مش موافق على المتابعة' end,
    coalesce(nullif(trim(v_alias), ''), 'فرد من العيلة') || case when p_accept then ' وافق إنك تتابع ' else ' مش موافق إنك تتابع ' end
      || public.zad_family_scope_label(v_row.scope, false) || '.'
      || case when p_accept and v_row.scope = 'location'
              then ' حدّد النطاقات (المدرسة، النادي) من «عيلتي».' else '' end,
    false
  );
  return jsonb_build_object('ok', true, 'status', v_row.status);
end $$;
revoke all on function public.zad_family_answer_share(uuid, boolean) from public, anon;
grant execute on function public.zad_family_answer_share(uuid, boolean) to authenticated;

-- الإلغاء بقى بيقول للطرف التاني — طفل وقّف مشاركة المدرسة لازم ولي الأمر يعرف، مش يفضل
-- فاكر إن التنبيه هيوصله.
create or replace function public.zad_family_revoke_share(p_share uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_row public.zad_family_shares%rowtype;
  v_other uuid;
  v_alias text;
begin
  update public.zad_family_shares
     set status = 'revoked', decided_at = now()
   where id = p_share
     and (owner_id = auth.uid() or viewer_id = auth.uid())
     and status in ('pending', 'granted')
  returning * into v_row;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_active'); end if;

  v_other := case when v_row.owner_id = auth.uid() then v_row.viewer_id else v_row.owner_id end;
  select alias into v_alias from public.family_members
   where user_id = auth.uid() and family_id = v_row.family_id;
  insert into public.app_notifications (user_id, title, message, is_read)
  values (
    v_other,
    'اتلغت متابعة',
    coalesce(nullif(trim(v_alias), ''), 'فرد من العيلة')
      || case when v_row.owner_id = auth.uid()
              then ' وقّف مشاركة ' || public.zad_family_scope_label(v_row.scope, false) || ' معاك.'
              else ' وقّف متابعة ' || public.zad_family_scope_label(v_row.scope, true) || '.' end,
    false
  );
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.zad_family_revoke_share(uuid) from public, anon;
grant execute on function public.zad_family_revoke_share(uuid) to authenticated;

-- ── النطاقات ─────────────────────────────────────────────────────────────────

create table if not exists public.zad_family_zones (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.family_groups(id) on delete cascade,
  -- الطفل اللي النطاق بيخصّه (صاحب البيانات في zad_family_shares).
  member_id uuid not null references auth.users(id) on delete cascade,
  -- ولي الأمر اللي حدده.
  created_by uuid not null references auth.users(id) on delete cascade,
  label text not null check (char_length(btrim(label)) between 1 and 40),
  kind text not null default 'school' check (kind in ('school', 'home', 'club', 'other')),
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  -- أندرويد مابيوعدش بحاجة تحت ~١٠٠ م.
  radius_m integer not null default 150 check (radius_m between 100 and 1000),
  -- ساعات التنبيه بتوقيت سوق الطفل: أيام الأسبوع (extract(dow): الأحد = 0) ومن/لحد.
  -- بره الشباك ده الدخول والخروج بيتسجلوا من غير تنبيه. الافتراضي أسبوع الدراسة في مصر
  -- والخليج (الأحد–الخميس).
  alert_days smallint[] not null default '{0,1,2,3,4}',
  alert_from time,
  alert_to time,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint zad_family_zones_days check (
    cardinality(alert_days) between 1 and 7 and alert_days <@ '{0,1,2,3,4,5,6}'::smallint[]
  ),
  constraint zad_family_zones_window check (
    (alert_from is null and alert_to is null) or (alert_from is not null and alert_to is not null and alert_from < alert_to)
  )
);

create index if not exists zad_family_zones_member_idx on public.zad_family_zones (member_id) where active;

create table if not exists public.zad_family_zone_events (
  id uuid primary key default gen_random_uuid(),
  zone_id uuid not null references public.zad_family_zones(id) on delete cascade,
  member_id uuid not null references auth.users(id) on delete cascade,
  family_id uuid not null references public.family_groups(id) on delete cascade,
  transition text not null check (transition in ('enter', 'exit')),
  -- إمتى الموبايل شافه (ممكن يوصل متأخر لو كان أوفلاين).
  happened_at timestamptz not null,
  received_at timestamptz not null default now(),
  -- 'exit' / 'back' لو طلع منه تنبيه لولي الأمر، وإلا null.
  alerted text check (alerted is null or alerted in ('exit', 'back')),
  -- الموبايل بيعيد إرسال الحدث لو النداء فشل — نفس الحدث مايتسجلش مرتين.
  constraint zad_family_zone_events_once unique (zone_id, transition, happened_at)
);

create index if not exists zad_family_zone_events_zone_idx on public.zad_family_zone_events (zone_id, happened_at desc);

-- Supabase بيدّي anon وauthenticated كل الصلاحيات على أي جدول جديد (default privileges،
-- ZAD_LIVING_BRAIN.md §٧): نشيلها ونرجّع القراية بس. الكتابة من الدوال تحت بس.
alter table public.zad_family_zones enable row level security;
alter table public.zad_family_zone_events enable row level security;
revoke all on public.zad_family_zones from anon, authenticated;
revoke all on public.zad_family_zone_events from anon, authenticated;
grant select on public.zad_family_zones to authenticated;
grant select on public.zad_family_zone_events to authenticated;

-- الطفل بيشوف النطاقات اللي عليه (شفافية)، والمتابع بيشوفها طول ما الموافقة قايمة.
drop policy if exists "family_zones: the child and granted followers read" on public.zad_family_zones;
create policy "family_zones: the child and granted followers read"
  on public.zad_family_zones for select to authenticated
  using (member_id = (select auth.uid()) or public.zad_family_i_can_see(member_id, 'location'));

drop policy if exists "family_zone_events: the child and granted followers read" on public.zad_family_zone_events;
create policy "family_zone_events: the child and granted followers read"
  on public.zad_family_zone_events for select to authenticated
  using (member_id = (select auth.uid()) or public.zad_family_i_can_see(member_id, 'location'));

comment on table public.zad_family_zones is
  'نطاقات ولي الأمر لطفل وافق (zad_family_shares scope = location). بتتكتب من zad_family_zone_save/delete بس.';
comment on table public.zad_family_zone_events is
  'دخول/خروج من نطاق، من موبايل الطفل عبر zad_family_zone_event. مفيش إحداثيات للطفل هنا. بيتمسح بعد ٣٠ يوم.';

/** ولي الأمر بيضيف أو بيعدّل نطاق لطفل وافق على المتابعة. الطفل بيوصله إشعار بيه. */
create or replace function public.zad_family_zone_save(
  p_member uuid,
  p_label text,
  p_kind text,
  p_lat double precision,
  p_lng double precision,
  p_radius integer default 150,
  p_days integer[] default '{0,1,2,3,4}',
  p_from time default '07:00',
  p_to time default '15:00',
  p_zone uuid default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_family uuid;
  v_alias text;
  v_id uuid;
  v_label text := btrim(coalesce(p_label, ''));
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_member is null or p_member = v_me or not public.zad_family_share_granted(v_me, p_member, 'location') then
    return jsonb_build_object('ok', false, 'reason', 'not_granted');
  end if;
  if char_length(v_label) not between 1 and 40 then return jsonb_build_object('ok', false, 'reason', 'bad_label'); end if;
  if coalesce(p_kind, '') not in ('school', 'home', 'club', 'other') then return jsonb_build_object('ok', false, 'reason', 'bad_kind'); end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    return jsonb_build_object('ok', false, 'reason', 'bad_point');
  end if;
  if coalesce(p_radius, 0) not between 100 and 1000 then return jsonb_build_object('ok', false, 'reason', 'bad_radius'); end if;
  if p_days is null or cardinality(p_days) not between 1 and 7 or not (p_days <@ '{0,1,2,3,4,5,6}'::integer[]) then
    return jsonb_build_object('ok', false, 'reason', 'bad_days');
  end if;
  if (p_from is null) <> (p_to is null) or (p_from is not null and p_from >= p_to) then
    return jsonb_build_object('ok', false, 'reason', 'bad_window');
  end if;

  select fo.family_id into v_family
    from public.family_members fo
    join public.family_members fv on fv.family_id = fo.family_id and fv.user_id = v_me
   where fo.user_id = p_member limit 1;
  select alias into v_alias from public.family_members where user_id = v_me and family_id = v_family;

  if p_zone is null then
    if (select count(*) from public.zad_family_zones where member_id = p_member and active) >= 5 then
      return jsonb_build_object('ok', false, 'reason', 'too_many');
    end if;
    insert into public.zad_family_zones (family_id, member_id, created_by, label, kind, lat, lng, radius_m, alert_days, alert_from, alert_to)
    values (v_family, p_member, v_me, v_label, p_kind, p_lat, p_lng, p_radius, p_days::smallint[], p_from, p_to)
    returning id into v_id;
  else
    update public.zad_family_zones
       set label = v_label, kind = p_kind, lat = p_lat, lng = p_lng, radius_m = p_radius,
           alert_days = p_days::smallint[], alert_from = p_from, alert_to = p_to, updated_at = now()
     where id = p_zone and member_id = p_member and family_id = v_family and active
    returning id into v_id;
    if v_id is null then return jsonb_build_object('ok', false, 'reason', 'unknown_zone'); end if;
  end if;

  insert into public.app_notifications (user_id, title, message, is_read)
  values (
    p_member,
    '📍 نطاق جديد: ' || v_label,
    coalesce(nullif(trim(v_alias), ''), 'حد من العيلة') || ' حدّد «' || v_label
      || '». زاد هيقوله لما تخرج منه في المواعيد اللي حددها بس — مش مكانك طول الوقت. افتح زاد عشان يشتغل.',
    false
  );
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;
revoke all on function public.zad_family_zone_save(uuid, text, text, double precision, double precision, integer, integer[], time, time, uuid) from public, anon;
grant execute on function public.zad_family_zone_save(uuid, text, text, double precision, double precision, integer, integer[], time, time, uuid) to authenticated;

/** ولي الأمر بيشيل نطاق (الطفل بيوقف المشاركة كلها من «مين بيتابعك»). */
create or replace function public.zad_family_zone_delete(p_zone uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update public.zad_family_zones z
     set active = false, updated_at = now()
   where z.id = p_zone and z.active
     and auth.uid() is not null and auth.uid() <> z.member_id
     and public.zad_family_share_granted(auth.uid(), z.member_id, 'location');
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_allowed'); end if;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.zad_family_zone_delete(uuid) from public, anon;
grant execute on function public.zad_family_zone_delete(uuid) to authenticated;

/**
 * لموبايل الطفل: النطاقات اللي يسجّلها geofence، ومين بيتابع (للإشعار الدايم). فاضية لو
 * مفيش موافقة قايمة — والموبايل ساعتها بيشيل النطاقات والإشعار.
 */
create or replace function public.zad_family_my_zones()
returns jsonb language sql stable security definer set search_path = public as $$
  select case when auth.uid() is null then jsonb_build_object('ok', false, 'reason', 'not_authenticated')
  else jsonb_build_object(
    'ok', true,
    'zones', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', z.id, 'label', z.label, 'kind', z.kind,
          'lat', z.lat, 'lng', z.lng, 'radius_m', z.radius_m
        ) order by z.created_at)
        from public.zad_family_zones z
       where z.member_id = auth.uid() and z.active
         and public.zad_family_share_granted(z.created_by, auth.uid(), 'location')
    ), '[]'::jsonb),
    'watchers', coalesce((
      select jsonb_agg(distinct coalesce(nullif(btrim(fv.alias), ''), 'حد من العيلة'))
        from public.zad_family_shares s
        join public.family_members fv on fv.user_id = s.viewer_id and fv.family_id = s.family_id
       where s.owner_id = auth.uid() and s.scope = 'location' and s.status = 'granted'
         and public.zad_family_share_granted(s.viewer_id, auth.uid(), 'location')
    ), '[]'::jsonb)
  ) end;
$$;
revoke all on function public.zad_family_my_zones() from public, anon;
grant execute on function public.zad_family_my_zones() to authenticated;

/**
 * موبايل الطفل بيبلّغ دخول/خروج. القرار هنا كله (مش في التطبيق): يتسجل بس، ولا يطلّع تنبيه.
 *   - exit جوه شباك النطاق (أيام وساعات)، والحدث طازة (≤ ٣٠ دقيقة)، ومفيش تنبيه خروج لنفس
 *     النطاق آخر ساعة (GPS بيتهز على الحدود) ⇒ family_zone_exit.
 *   - enter بعد خروج اتنبّه عليه آخر ٣ ساعات ⇒ family_zone_back («رجع المدرسة»).
 * التنبيه لحظة في zad_voice_moments لكل متابع موافَق عليه (voiceMoments.ts بيصيغ ويوصّل)،
 * ونداء فوري لـzad-brain عشان مايستناش الكرون.
 */
create or replace function public.zad_family_zone_event(p_zone uuid, p_transition text, p_at timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_zone public.zad_family_zones%rowtype;
  v_tz text;
  v_local timestamp;
  v_event uuid;
  v_alert text;
  v_alias text;
  v_count int := 0;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_transition not in ('enter', 'exit') or p_at is null then
    return jsonb_build_object('ok', false, 'reason', 'bad_event');
  end if;
  -- مستقبل (ساعة الموبايل غلط) أو قديم أوي = مش حدث نصدّقه.
  if p_at > now() + interval '5 minutes' or p_at < now() - interval '7 days' then
    return jsonb_build_object('ok', false, 'reason', 'stale');
  end if;
  select * into v_zone from public.zad_family_zones where id = p_zone and member_id = v_me and active;
  if not found or not public.zad_family_share_granted(v_zone.created_by, v_me, 'location') then
    return jsonb_build_object('ok', false, 'reason', 'not_shared');
  end if;

  delete from public.zad_family_zone_events where member_id = v_me and happened_at < now() - interval '30 days';

  insert into public.zad_family_zone_events (zone_id, member_id, family_id, transition, happened_at)
  values (v_zone.id, v_me, v_zone.family_id, p_transition, p_at)
  on conflict on constraint zad_family_zone_events_once do nothing
  returning id into v_event;
  if v_event is null then return jsonb_build_object('ok', true, 'status', 'duplicate'); end if;

  select public.zad_market_timezone(u.country) into v_tz from public.zad_users u where u.id = v_me;
  v_tz := coalesce(v_tz, 'Africa/Cairo');
  v_local := p_at at time zone v_tz;

  if p_transition = 'exit'
     and p_at > now() - interval '30 minutes'
     and extract(dow from v_local)::smallint = any (v_zone.alert_days)
     and (v_zone.alert_from is null or (v_local::time >= v_zone.alert_from and v_local::time < v_zone.alert_to))
     and not exists (
       select 1 from public.zad_family_zone_events e
        where e.zone_id = v_zone.id and e.alerted = 'exit' and e.id <> v_event
          and e.happened_at > p_at - interval '60 minutes'
     ) then
    v_alert := 'exit';
  elsif p_transition = 'enter'
     and p_at > now() - interval '30 minutes'
     and exists (
       select 1 from public.zad_family_zone_events e
        where e.zone_id = v_zone.id and e.alerted = 'exit'
          and e.happened_at between p_at - interval '3 hours' and p_at
          and not exists (
            select 1 from public.zad_family_zone_events b
             where b.zone_id = v_zone.id and b.transition = 'enter' and b.id <> v_event
               and b.happened_at between e.happened_at and p_at
          )
     ) then
    v_alert := 'back';
  end if;

  if v_alert is null then
    return jsonb_build_object('ok', true, 'status', 'recorded');
  end if;

  update public.zad_family_zone_events set alerted = v_alert where id = v_event;
  select alias into v_alias from public.family_members where user_id = v_me and family_id = v_zone.family_id;

  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select s.viewer_id,
         case v_alert when 'exit' then 'family_zone_exit' else 'family_zone_back' end,
         jsonb_build_object(
           'member_id', v_me,
           'member_alias', coalesce(nullif(btrim(v_alias), ''), 'ابنك'),
           'zone_id', v_zone.id,
           'zone_label', v_zone.label,
           'zone_kind', v_zone.kind,
           'happened_at', p_at,
           'local_time', to_char(v_local, 'HH24:MI'),
           'time_zone', v_tz,
           'event_id', v_event
         ),
         'family_zone:' || v_event || ':' || s.viewer_id
    from public.zad_family_shares s
   where s.owner_id = v_me and s.scope = 'location' and s.status = 'granted'
     and public.zad_family_share_granted(s.viewer_id, v_me, 'location')
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;

  -- التوصيل فوراً بدل كرون الخمس دقايق. أي خطأ هنا بيتبلع: اللحظة اتسجلت والكرون هيوصّلها.
  if v_count > 0 then
    begin
      perform net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := jsonb_build_object('action', 'process_voice_moments'),
        timeout_milliseconds := 10000
      );
    exception when others then
      raise warning 'family zone alert not pushed now: %', sqlerrm;
    end;
  end if;

  return jsonb_build_object('ok', true, 'status', 'alerted', 'alert', v_alert, 'followers', v_count);
end $$;
revoke all on function public.zad_family_zone_event(uuid, text, timestamptz) from public, anon;
grant execute on function public.zad_family_zone_event(uuid, text, timestamptz) to authenticated;

/**
 * لكل نطاق لطفل وافق إن [p_viewer] يتابعه: آخر حدث. للعقل (service_role) وللتطبيق عبر
 * zad_family_member_view. «inside» = آخر حدث دخول، «left» = آخر حدث خروج، «unknown» = لسه.
 */
create or replace function public.zad_family_zone_status(p_viewer uuid, p_member uuid default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'member_id', z.member_id,
      'member_alias', coalesce(nullif(btrim(fm.alias), ''), 'ابنك'),
      'zone_id', z.id,
      'zone', z.label,
      'kind', z.kind,
      'radius_m', z.radius_m,
      'days', z.alert_days,
      'from', to_char(z.alert_from, 'HH24:MI'),
      'to', to_char(z.alert_to, 'HH24:MI'),
      'state', case e.transition when 'enter' then 'inside' when 'exit' then 'left' else 'unknown' end,
      'since', e.happened_at
    ) order by fm.alias, z.created_at), '[]'::jsonb)
    from public.zad_family_zones z
    join public.family_members fm on fm.user_id = z.member_id and fm.family_id = z.family_id
    left join lateral (
      select transition, happened_at from public.zad_family_zone_events
       where zone_id = z.id order by happened_at desc limit 1
    ) e on true
   where z.active
     and (p_member is null or z.member_id = p_member)
     and public.zad_family_share_granted(p_viewer, z.member_id, 'location')
     and z.member_id <> p_viewer;
$$;
revoke all on function public.zad_family_zone_status(uuid, uuid) from public, anon, authenticated;
grant execute on function public.zad_family_zone_status(uuid, uuid) to service_role;

-- «عيلتي»: الموقع جوه نفس النداء — يتطلب بس لو الفرد طفل (can_follow_location)، والنطاقات
-- وآخر حدث لكل واحد بس لو موافَق عليه. باقي الدالة زي 20261001130000 بالظبط.
create or replace function public.zad_family_member_view(p_owner uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_family uuid;
  v_owner_role text;
  v_tz text;
  v_statuses jsonb;
  v_meds jsonb;
  v_spending jsonb;
  v_tasks jsonb;
  v_location jsonb;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  select fo.family_id, fo.role into v_family, v_owner_role
    from public.family_members fo
    join public.family_members fv on fv.family_id = fo.family_id and fv.user_id = v_me
   where fo.user_id = p_owner limit 1;
  if v_family is null then return jsonb_build_object('ok', false, 'reason', 'not_same_family'); end if;

  select coalesce(jsonb_object_agg(scope, jsonb_build_object('id', id, 'status', status)), '{}'::jsonb)
    into v_statuses
    from public.zad_family_shares
   where owner_id = p_owner and viewer_id = v_me and family_id = v_family;

  select public.zad_market_timezone(country) into v_tz from public.zad_users where id = p_owner;
  v_tz := coalesce(v_tz, 'UTC');

  if public.zad_family_share_granted(v_me, p_owner, 'medicines') then
    select coalesce(jsonb_agg(jsonb_build_object(
        'name', p.name,
        'for_person', p.for_person,
        'remaining', p.remaining_quantity,
        'today', coalesce((
          select jsonb_agg(jsonb_build_object(
              'time', t.hhmm,
              'state', case
                when d.status = 'taken' then 'taken'
                when d.status = 'skipped' then 'skipped'
                when t.slot > now() then 'upcoming'
                when t.slot + interval '3 hours' < now() then 'missed'
                else 'due' end
            ) order by t.slot)
            from (
              select trim(x) as hhmm,
                     ((to_char(now() at time zone v_tz, 'YYYY-MM-DD') || ' ' || trim(x))::timestamp at time zone v_tz) as slot
                from unnest(string_to_array(p.dose_times, ',')) as x
               where trim(x) ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
            ) t
            left join lateral (
              select status from public.zad_pharmacy_doses d
               where d.item_id = p.id
                 and d.scheduled_at between t.slot - interval '90 minutes' and t.slot + interval '90 minutes'
               order by abs(extract(epoch from d.scheduled_at - t.slot)) limit 1
            ) d on true
        ), '[]'::jsonb)
      ) order by p.name), '[]'::jsonb)
      into v_meds
      from public.zad_pharmacy_items p
     where p.user_id = p_owner
       and coalesce(p.remaining_quantity, 1) > 0;
  end if;

  if public.zad_family_share_granted(v_me, p_owner, 'spending') then
    select jsonb_build_object(
        'spent_30d', round(coalesce(sum(amount), 0)::numeric, 2),
        'top', coalesce((
          select jsonb_agg(jsonb_build_object('category', c.category, 'amount', round(c.total::numeric, 2)) order by c.total desc)
            from (
              select coalesce(category, 'أخرى') as category, sum(amount) as total
                from public.zad_transactions
               where user_id = p_owner and is_expense and created_at >= now() - interval '30 days'
               group by 1 order by 2 desc limit 3
            ) c
        ), '[]'::jsonb)
      )
      into v_spending
      from public.zad_transactions
     where user_id = p_owner and is_expense and created_at >= now() - interval '30 days';
  end if;

  if public.zad_family_share_granted(v_me, p_owner, 'tasks') then
    select jsonb_build_object(
        'appointments', coalesce((
          select jsonb_agg(jsonb_build_object('title', a.title, 'starts_at', a.starts_at) order by a.starts_at)
            from (
              select title, starts_at from public.zad_appointments
               where user_id = p_owner and status = 'upcoming' and starts_at >= now()
               order by starts_at limit 5
            ) a
        ), '[]'::jsonb),
        'chores_open', (
          select count(*) from public.family_chores
           where family_id = v_family and assigned_to = p_owner and not is_completed
        )
      ) into v_tasks;
  end if;

  if p_owner <> v_me and public.zad_family_share_granted(v_me, p_owner, 'location') then
    v_location := jsonb_build_object('zones', public.zad_family_zone_status(v_me, p_owner));
  end if;

  return jsonb_build_object(
    'ok', true,
    'shares', v_statuses,
    'can_follow_location', coalesce(v_owner_role, '') = 'child',
    'medicines', v_meds,
    'spending', v_spending,
    'tasks', v_tasks,
    'location', v_location
  );
end $$;
revoke all on function public.zad_family_member_view(uuid) from public, anon;
grant execute on function public.zad_family_member_view(uuid) to authenticated;
