-- متابعة العيلة: أي فرد كبير يطلب، والطفل يتابعه رب الأسرة من غير موافقة (قرار المالك، ٢٠٢٦-١١-٢١).
--
-- «الدوا يتقسم حسب المنضم في الأسرة لو أدّى موافقة مشاركة … وفي أطفال … ويدّي تقرير للأب، وينبّهوا بعض، أو
-- المسؤول عن الأسرة: ابن وأبوه وأمه وإخواته حسب وضعه.» أسئلة الاختيار اتجاوبت:
--   • مين يتابع: أي فرد كبير (role <> 'child')، مش الأدمن بس. صاحب البيانات بيوافق، وأي واحد من الاتنين يلغي.
--   • الدوا: متابعة بس، مش مشاركة للعيلة كلها (الرؤية بتفضل زوجية في zad_family_shares).
--   • الأطفال: رب الأسرة (admin) بيتابع الطفل (role = 'child') في الأدوية والمصروف والمهام من غير موافقة —
--     مسموح في سياسة جوجل للقُصّر. المكان (location) بيفضل بموافقة الطفل زي ما هو (20261003110000)، ومتابعة
--     مكان بالغ ممنوعة حتى بموافقته (Play، ZAD_LIVING_BRAIN).
--   • التنبيهات: الفوري (جرعة فاتت) شغال من 20261001140000 لأي متابع موافَق عليه، فبيشمل المتابعين الجداد من غير تعديل.
--
-- الطفل نفسه مايطلبش يتابع حد. والرد زي ما هو، وفيه status لكل نطاق اتعمل عشان الشاشة تعرف إنه granted على طول.

create or replace function public.zad_family_request_share(p_owner uuid, p_scopes text[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_family uuid;
  v_alias text;
  v_my_role text;
  v_owner_role text;
  v_scope text;
  v_auto boolean;
  v_asked int := 0;
  v_granted int := 0;
  v_ask_labels text[] := '{}';
  v_auto_labels text[] := '{}';
  v_statuses jsonb := '{}'::jsonb;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_owner is null or p_owner = v_me then
    return jsonb_build_object('ok', false, 'reason', 'self');
  end if;
  select fv.family_id, fv.alias, coalesce(fv.role, 'member'), coalesce(fo.role, 'member')
    into v_family, v_alias, v_my_role, v_owner_role
    from public.family_members fv
    join public.family_members fo on fo.family_id = fv.family_id and fo.user_id = p_owner
   where fv.user_id = v_me
   limit 1;
  if v_family is null then
    return jsonb_build_object('ok', false, 'reason', 'not_same_family');
  end if;
  if v_my_role = 'child' then
    return jsonb_build_object('ok', false, 'reason', 'child_cannot_follow');
  end if;

  foreach v_scope in array coalesce(p_scopes, '{}') loop
    continue when v_scope not in ('medicines', 'spending', 'tasks', 'location');
    -- Play: متابعة مكان بالغ ممنوعة حتى بموافقته.
    continue when v_scope = 'location' and v_owner_role <> 'child';
    -- رب الأسرة على طفل: متابعة على طول، إلا المكان.
    v_auto := v_my_role = 'admin' and v_owner_role = 'child' and v_scope <> 'location';

    if v_auto then
      insert into public.zad_family_shares (family_id, owner_id, viewer_id, scope, status, requested_at, decided_at)
      values (v_family, p_owner, v_me, v_scope, 'granted', now(), now())
      on conflict (owner_id, viewer_id, scope) do update
        set status = 'granted', requested_at = now(), decided_at = now(), family_id = excluded.family_id
        where public.zad_family_shares.status <> 'granted';
      if found then
        v_granted := v_granted + 1;
        v_auto_labels := v_auto_labels || public.zad_family_scope_label(v_scope, true);
      end if;
      v_statuses := v_statuses || jsonb_build_object(v_scope, 'granted');
    else
      insert into public.zad_family_shares (family_id, owner_id, viewer_id, scope, status, requested_at, decided_at)
      values (v_family, p_owner, v_me, v_scope, 'pending', now(), null)
      on conflict (owner_id, viewer_id, scope) do update
        set status = 'pending', requested_at = now(), decided_at = null, family_id = excluded.family_id
        where public.zad_family_shares.status in ('declined', 'revoked');
      if found then
        v_asked := v_asked + 1;
        v_ask_labels := v_ask_labels || public.zad_family_scope_label(v_scope, true);
      end if;
      v_statuses := v_statuses || jsonb_build_object(v_scope,
        (select status from public.zad_family_shares
          where owner_id = p_owner and viewer_id = v_me and scope = v_scope));
    end if;
  end loop;

  if v_asked > 0 then
    insert into public.app_notifications (user_id, title, message, is_read)
    values (
      p_owner,
      'طلب متابعة من العيلة',
      coalesce(nullif(trim(v_alias), ''), 'حد من العيلة') || ' عايز يتابع ' || array_to_string(v_ask_labels, ' و')
        || '. افتح «عيلتي» ووافق أو ارفض — وتقدر تلغي في أي وقت.',
      false
    );
  end if;
  -- الطفل بيعرف إن فيه متابعة، حتى لو مااتسألش.
  if v_granted > 0 then
    insert into public.app_notifications (user_id, title, message, is_read)
    values (
      p_owner,
      'العيلة معاك',
      coalesce(nullif(trim(v_alias), ''), 'رب الأسرة') || ' بقى يتابع ' || array_to_string(v_auto_labels, ' و')
        || ' عشان يطمّن عليك.',
      false
    );
  end if;
  return jsonb_build_object('ok', true, 'requested', v_asked, 'granted', v_granted, 'statuses', v_statuses);
end $$;
revoke all on function public.zad_family_request_share(uuid, text[]) from public, anon;
grant execute on function public.zad_family_request_share(uuid, text[]) to authenticated;

-- الطفل مايقدرش يلغي متابعة رب الأسرة لأدويته ومصروفه ومهامه (قرار المالك)؛ المكان بيفضل في إيده.
-- رب الأسرة نفسه يقدر يلغي، والكبير يلغي أي متابعة عليه. الباقي زي 20261003110000 بالظبط (إشعار للطرف التاني).
create or replace function public.zad_family_revoke_share(p_share uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_row public.zad_family_shares%rowtype;
  v_other uuid;
  v_alias text;
begin
  update public.zad_family_shares s
     set status = 'revoked', decided_at = now()
   where s.id = p_share
     and (s.viewer_id = auth.uid()
          or (s.owner_id = auth.uid()
              and not (s.scope <> 'location'
                       and exists (select 1 from public.family_members fo
                                    where fo.user_id = s.owner_id and fo.family_id = s.family_id
                                      and fo.role = 'child')
                       and exists (select 1 from public.family_members fv
                                    where fv.user_id = s.viewer_id and fv.family_id = s.family_id
                                      and fv.role = 'admin'))))
     and s.status in ('pending', 'granted')
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
