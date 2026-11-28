-- P1.6b (مجموعة ٦، العيلة): أزرار العيلة في فلاتر بتكتب من الباب بدل insert/upsert/update مباشر على جداول العيلة.
--   * مجال جديد `family` (zad_intent_family): family.chore_added، family.chore_pref_set، family.goal_added،
--     family.spend_limits_set، family.fund_added، family.fund_contributed، family.challenge_added.
--   * الباب security definer فالـRLS مابتتطبقش جواه، فدالة المجال بتكرّر قواعدها صراحة بـp_uid (مش بـauth.uid()):
--     العضو في العيلة (family_id من العميل بيتتحقق منه، مش بيتصدق)، المكافأة والسقوف والتحدي = أدمن بس (زي تريجرات
--     zad_family_chores_guard وzad_family_challenges_guard وzad_family_members_guard_update)، وتفضيلات المهام للفرد لنفسه أو
--     لأدمن العيلة (زي zad_can_set_chore_prefs). تريجرات 20260921* لسه شغالة فوقها لما auth.uid() موجود.
--   * القاصر (P2.5، zad_is_minor_user): أهداف العيلة (family_goals) مقفولة عليه بـminor_blind_budget، فالباب بيرفض
--     family.goal_added بـminor_no_budget زي ما RLS كانت بتقفلها. باقي الأنواع نفس صلاحيات RLS القديمة للطفل.
--   * zad_commit_intent = نسخة 20261128150000 + 'family' في بادئات المجالات والتوزيع. zad_commit_my_intent = نسخة
--     20261129020000 + أنواع family.
--   * اللي فضل مباشر (مفيش نوع ليه): رسايل الشات (chat_messages: إرسال، تثبيت، ردود فعل، metadata) وختم آخر ظهور
--     (family_members.last_seen_at). كلهم تواصل أو نبض مش نية بيانات، والـRLS وتريجراتها هي الحارس.

create or replace function public.zad_intent_family(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_family uuid;
  v_me public.family_members%rowtype;
  v_target public.family_members%rowtype;
  v_assignee uuid;
  v_title text;
  v_amount numeric;
  v_reward numeric;
  v_minutes int;
  v_due text;
  v_month text;
  v_text text;
  v_start timestamptz;
  v_end timestamptz;
  v_event uuid;
  v_date timestamptz;
  v_type text;
  v_season text;
  v_badge text;
  v_daily numeric;
  v_weekly numeric;
  v_dislikes text[];
  v_likes text[];
  v_row_id uuid;
  v_before jsonb;
  v_fund public.sinking_funds%rowtype;
  v_pref public.family_chore_preferences%rowtype;
begin
  if p_kind not in ('family.chore_added', 'family.chore_pref_set', 'family.goal_added', 'family.spend_limits_set',
                    'family.fund_added', 'family.fund_contributed', 'family.challenge_added') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  -- العيلة: من family_id في النية، أو (للنوعين اللي بيشاوروا على صف) من الصف نفسه. وبتتقفل على عضوية p_uid.
  if p_kind = 'family.spend_limits_set' then
    begin
      select * into v_target from public.family_members where id = (v_payload ->> 'member_id')::uuid;
    exception when others then
      v_target := null;
    end;
    v_family := v_target.family_id;
  elsif p_kind = 'family.fund_contributed' then
    begin
      select * into v_fund from public.sinking_funds where id = (v_payload ->> 'fund_id')::uuid for update;
    exception when others then
      v_fund := null;
    end;
    v_family := v_fund.family_id;
  else
    begin
      v_family := (v_payload ->> 'family_id')::uuid;
    exception when others then
      v_family := null;
    end;
  end if;
  if v_family is not null then
    select * into v_me from public.family_members where family_id = v_family and user_id = p_uid limit 1;
  end if;
  if v_me.id is null then
    -- عيلة غيري بتتقرا زي ما هي مش موجودة.
    return jsonb_build_object('ok', false, 'reason',
      case p_kind when 'family.fund_contributed' then 'fund_not_found'
                  when 'family.spend_limits_set' then 'member_not_found'
                  else 'not_in_family' end);
  end if;

  if p_kind = 'family.chore_added' then
    v_title := btrim(coalesce(v_payload ->> 'title', ''));
    if length(v_title) not between 1 and 200 then
      return jsonb_build_object('ok', false, 'reason', 'title_invalid');
    end if;
    begin
      v_reward := round(coalesce(nullif(v_payload ->> 'reward', ''), '0')::numeric, 2);
    exception when others then
      return jsonb_build_object('ok', false, 'reason', 'reward_invalid');
    end;
    if v_reward < 0 then
      return jsonb_build_object('ok', false, 'reason', 'negative_reward');
    elsif v_reward > 100000000 then
      return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
    elsif v_reward > 0 and v_me.role is distinct from 'admin' then
      return jsonb_build_object('ok', false, 'reason', 'only_admins_set_rewards');
    end if;
    if nullif(v_payload ->> 'minutes', '') is not null then
      begin
        v_minutes := (v_payload ->> 'minutes')::numeric::int;
      exception when others then
        v_minutes := null;
      end;
      if v_minutes is null or v_minutes not between 1 and 600 then
        return jsonb_build_object('ok', false, 'reason', 'minutes_invalid');
      end if;
    end if;
    v_due := nullif(btrim(coalesce(v_payload ->> 'due_date', '')), '');
    if length(coalesce(v_due, '')) > 40 then
      return jsonb_build_object('ok', false, 'reason', 'due_date_invalid');
    end if;
    begin
      v_assignee := (v_payload ->> 'assigned_to')::uuid;
    exception when others then
      return jsonb_build_object('ok', false, 'reason', 'assignee_not_in_family');
    end;
    if v_assignee is null or not exists (select 1 from public.family_members where id = v_assignee and family_id = v_family) then
      return jsonb_build_object('ok', false, 'reason', 'assignee_not_in_family');
    end if;
    insert into public.family_chores (family_id, assigned_to, title, due_date, reward_amount, minutes)
    values (v_family, v_assignee, v_title, v_due, v_reward, v_minutes)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null,
      'after', (select to_jsonb(c) from public.family_chores c where c.id = v_row_id));

  elsif p_kind = 'family.chore_pref_set' then
    begin
      select * into v_target from public.family_members
       where id = (v_payload ->> 'member_id')::uuid and family_id = v_family;
    exception when others then
      v_target := null;
    end;
    if v_target.id is null then
      return jsonb_build_object('ok', false, 'reason', 'member_not_found');
    elsif v_target.user_id is distinct from p_uid and v_me.role is distinct from 'admin' then
      return jsonb_build_object('ok', false, 'reason', 'not_allowed');
    end if;
    begin
      v_minutes := (v_payload ->> 'minutes_per_week')::numeric::int;
    exception when others then
      v_minutes := null;
    end;
    if v_minutes is null or v_minutes not between 0 and 2000 then
      return jsonb_build_object('ok', false, 'reason', 'minutes_invalid');
    end if;
    if jsonb_typeof(v_payload -> 'dislikes') is distinct from 'array' or jsonb_typeof(v_payload -> 'likes') is distinct from 'array'
       or jsonb_array_length(v_payload -> 'dislikes') > 20 or jsonb_array_length(v_payload -> 'likes') > 20
       or exists (select 1 from jsonb_array_elements(v_payload -> 'dislikes') e where jsonb_typeof(e) <> 'string' or length(e #>> '{}') > 80)
       or exists (select 1 from jsonb_array_elements(v_payload -> 'likes') e where jsonb_typeof(e) <> 'string' or length(e #>> '{}') > 80) then
      return jsonb_build_object('ok', false, 'reason', 'list_invalid');
    end if;
    select coalesce(array_agg(e #>> '{}'), '{}') into v_dislikes from jsonb_array_elements(v_payload -> 'dislikes') e;
    select coalesce(array_agg(e #>> '{}'), '{}') into v_likes from jsonb_array_elements(v_payload -> 'likes') e;
    select * into v_pref from public.family_chore_preferences where member_id = v_target.id for update;
    insert into public.family_chore_preferences (member_id, family_id, minutes_per_week, dislikes, likes, updated_at)
    values (v_target.id, v_family, v_minutes, v_dislikes, v_likes, now())
    on conflict (member_id) do update
      set minutes_per_week = excluded.minutes_per_week, dislikes = excluded.dislikes, likes = excluded.likes,
          updated_at = excluded.updated_at;
    v_row_id := v_target.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id,
      'before', case when v_pref.member_id is null then null else to_jsonb(v_pref) end,
      'after', (select to_jsonb(p) from public.family_chore_preferences p where p.member_id = v_target.id));

  elsif p_kind = 'family.goal_added' then
    -- أهداف العيلة مقفولة على القاصر (minor_blind_budget، P2.5): الباب بيرفض زي RLS.
    if public.zad_is_minor_user(p_uid) then
      return jsonb_build_object('ok', false, 'reason', 'minor_no_budget');
    end if;
    begin
      v_amount := round((v_payload ->> 'target_amount')::numeric, 2);
    exception when others then
      v_amount := null;
    end;
    if v_amount is null or v_amount <= 0 then
      return jsonb_build_object('ok', false, 'reason', 'amount_not_positive');
    elsif v_amount > 1000000000 then
      return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
    end if;
    v_month := coalesce(v_payload ->> 'month_year', '');
    if v_month !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
      return jsonb_build_object('ok', false, 'reason', 'month_invalid');
    end if;
    v_text := nullif(btrim(coalesce(v_payload ->> 'reward_suggestion', '')), '');
    if length(coalesce(v_text, '')) > 300 then
      return jsonb_build_object('ok', false, 'reason', 'reward_text_too_long');
    end if;
    insert into public.family_goals (family_id, target_amount, current_amount, month_year, reward_suggestion)
    values (v_family, v_amount, 0, v_month, v_text)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null,
      'after', (select to_jsonb(g) from public.family_goals g where g.id = v_row_id));

  elsif p_kind = 'family.spend_limits_set' then
    -- سقف الصرف تحكّم أبوي: أدمن عيلة العضو بس (zad_family_members_guard_update).
    if v_me.role is distinct from 'admin' then
      return jsonb_build_object('ok', false, 'reason', 'admins_only');
    end if;
    if not (v_payload ? 'daily' and v_payload ? 'weekly') then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end if;
    begin
      v_daily := round((v_payload ->> 'daily')::numeric, 2);
      v_weekly := round((v_payload ->> 'weekly')::numeric, 2);
    exception when others then
      return jsonb_build_object('ok', false, 'reason', 'limit_invalid');
    end;
    if v_daily < 0 or v_weekly < 0 then
      return jsonb_build_object('ok', false, 'reason', 'limit_invalid');
    elsif v_daily > 100000000 or v_weekly > 100000000 then
      return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
    end if;
    v_before := jsonb_build_object('daily_limit', v_target.daily_limit, 'weekly_limit', v_target.weekly_limit);
    update public.family_members set daily_limit = v_daily, weekly_limit = v_weekly where id = v_target.id;
    v_row_id := v_target.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_before,
      'after', jsonb_build_object('id', v_target.id, 'daily_limit', v_daily, 'weekly_limit', v_weekly));

  elsif p_kind = 'family.fund_added' then
    v_title := btrim(coalesce(v_payload ->> 'name', ''));
    if length(v_title) not between 1 and 120 then
      return jsonb_build_object('ok', false, 'reason', 'name_invalid');
    end if;
    begin
      v_amount := round((v_payload ->> 'target_amount')::numeric, 2);
    exception when others then
      v_amount := null;
    end;
    if v_amount is null or v_amount <= 0 then
      return jsonb_build_object('ok', false, 'reason', 'amount_not_positive');
    elsif v_amount > 1000000000 then
      return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
    end if;
    begin
      v_event := (v_payload ->> 'event_id')::uuid;
      v_date := (v_payload ->> 'target_date')::timestamptz;
    exception when others then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end;
    begin
      insert into public.sinking_funds (family_id, name, target_amount, event_id, target_date, created_by)
      values (v_family, v_title, v_amount, v_event, v_date, p_uid)
      returning id into v_row_id;
    exception when foreign_key_violation then
      return jsonb_build_object('ok', false, 'reason', 'event_not_found');
    end;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null,
      'after', (select to_jsonb(f) from public.sinking_funds f where f.id = v_row_id));

  elsif p_kind = 'family.fund_contributed' then
    begin
      v_amount := round((v_payload ->> 'amount')::numeric, 2);
    exception when others then
      v_amount := null;
    end;
    if v_amount is null or v_amount <= 0 then
      return jsonb_build_object('ok', false, 'reason', 'amount_not_positive');
    elsif v_amount > 1000000000 then
      return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
    end if;
    -- زيادة على الرصيد اللي في السيرفر (مش «الرصيد اللي العميل شافه + المبلغ»): مساهمتين مع بعض ماتضيعوش.
    update public.sinking_funds set current_amount = coalesce(current_amount, 0) + v_amount where id = v_fund.id;
    v_row_id := v_fund.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_fund),
      'after', (select to_jsonb(f) from public.sinking_funds f where f.id = v_row_id));

  else
    -- family.challenge_added
    v_type := coalesce(v_payload ->> 'challenge_type', '');
    if v_type not in ('weekly', 'monthly') then
      return jsonb_build_object('ok', false, 'reason', 'challenge_type_invalid');
    end if;
    v_title := btrim(coalesce(v_payload ->> 'title', ''));
    if length(v_title) not between 1 and 200 then
      return jsonb_build_object('ok', false, 'reason', 'title_invalid');
    end if;
    begin
      v_amount := round((v_payload ->> 'target_amount')::numeric, 2);
      v_reward := round(coalesce(nullif(v_payload ->> 'reward_amount', ''), '0')::numeric, 2);
      v_start := (v_payload ->> 'start_date')::timestamptz;
      v_end := (v_payload ->> 'end_date')::timestamptz;
    exception when others then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end;
    if v_amount is null or v_amount <= 0 then
      return jsonb_build_object('ok', false, 'reason', 'amount_not_positive');
    elsif v_reward < 0 then
      return jsonb_build_object('ok', false, 'reason', 'negative_amount');
    elsif v_amount > 1000000000 or v_reward > 1000000000 then
      return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
    elsif v_start is null or v_end is null or v_end <= v_start then
      return jsonb_build_object('ok', false, 'reason', 'dates_invalid');
    elsif v_reward > 0 and v_me.role is distinct from 'admin' then
      return jsonb_build_object('ok', false, 'reason', 'only_admins_set_rewards');
    end if;
    v_season := nullif(v_payload ->> 'season_key', '');
    v_badge := nullif(v_payload ->> 'badge', '');
    if v_season is not null and v_season !~ '^[a-z0-9_]{2,40}$' then
      return jsonb_build_object('ok', false, 'reason', 'season_invalid');
    elsif v_badge is not null and length(v_badge) not between 1 and 16 then
      return jsonb_build_object('ok', false, 'reason', 'badge_invalid');
    end if;
    insert into public.family_financial_challenges (family_id, challenge_type, title, target_amount, reward_amount,
                                                    start_date, end_date, is_active, season_key, badge)
    values (v_family, v_type, v_title, v_amount, v_reward, v_start, v_end, true, v_season, v_badge)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null,
      'after', (select to_jsonb(c) from public.family_financial_challenges c where c.id = v_row_id));
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_family(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;

create or replace function public.zad_commit_intent(p_intent jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_claims jsonb := coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
  v_uid uuid := auth.uid();
  v_kind text := p_intent ->> 'kind';
  v_cid text := p_intent ->> 'client_event_id';
  v_source text := coalesce(p_intent ->> 'source', 'model');
  v_payload jsonb := coalesce(p_intent -> 'payload', '{}'::jsonb);
  v_conf numeric;
  v_occurred timestamptz;
  v_member uuid;
  v_existing public.zad_events%rowtype;
  v_reason text;
  v_res jsonb;
  v_event_id uuid;
  v_trace text := nullif(btrim(coalesce(p_intent ->> 'trace_id', '')), '');
begin
  -- trace_id اختياري: لو شكله غلط بنتجاهله (التتبّع مايوقّفش كتابة).
  if v_trace is not null and length(v_trace) not between 8 and 64 then
    v_trace := null;
  end if;

  -- مين: JWT العميل لو موجود، وإلا (السيرفر) user_id اللي في النية. JWT عميل من غير sub = مرفوض.
  if v_uid is null then
    if v_claims ->> 'role' in ('authenticated', 'anon') then
      return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
    end if;
    begin
      v_uid := (p_intent ->> 'user_id')::uuid;
    exception when others then
      v_uid := null;
    end;
  end if;
  if v_uid is null or not exists (select 1 from auth.users where id = v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  end if;

  -- الشكل: النوع (بادئة مجال معروف — النوع نفسه بتراجعه دالة المجال)، مفتاح التكرار، المصدر، الثقة، الوقت، الفرد.
  if v_kind is null or split_part(v_kind, '.', 1) not in ('inventory', 'shopping', 'pharmacy', 'money', 'subscription', 'debt',
                                                           'obligation', 'maintenance', 'document', 'appointment', 'settings', 'goal', 'trait', 'profile', 'family') then
    v_reason := 'unknown_kind';
  elsif v_cid is null or length(v_cid) not between 1 and 100 then
    v_reason := 'bad_client_event_id';
  elsif v_source not in ('manual', 'receipt', 'bank', 'model', 'cron') then
    v_reason := 'bad_source';
  elsif jsonb_typeof(v_payload) <> 'object' then
    v_reason := 'bad_payload';
  end if;
  if v_reason is null then
    begin
      v_conf := (p_intent ->> 'confidence')::numeric;
      v_occurred := coalesce((p_intent ->> 'occurred_at')::timestamptz, now());
    exception when others then
      v_reason := 'bad_shape';
    end;
  end if;
  if v_reason is null and v_conf is not null and v_conf not between 0 and 1 then
    v_reason := 'bad_confidence';
  end if;
  if v_reason is null then
    if p_intent ? 'member_id' then
      begin
        v_member := (p_intent ->> 'member_id')::uuid;
      exception when others then
        v_member := null;
      end;
      if v_member is null or not exists (
        select 1 from public.zad_household_members where id = v_member and user_id = v_uid and archived_at is null
      ) then
        v_reason := 'member_not_in_household';
      end if;
    else
      v_member := public.zad_self_member(v_uid);
    end if;
  end if;
  if v_reason is not null then
    insert into public.zad_guard_events (user_id, kind, reason, source, intent)
    values (v_uid, coalesce(v_kind, '?'), v_reason, v_source, p_intent);
    return jsonb_build_object('ok', false, 'reason', v_reason);
  end if;

  -- تكرار: نفس النتيجة.
  select * into v_existing from public.zad_events where user_id = v_uid and client_event_id = v_cid;
  if found then
    return jsonb_build_object('ok', true, 'duplicate', true, 'event_id', v_existing.id, 'kind', v_existing.kind,
      'row_id', v_existing.payload ->> 'row_id');
  end if;

  -- القيود والكتابة في دالة المجال، والحدث معاها. لو نفس المفتاح اتكتب في نفس اللحظة من طلب تاني: الكتابة بتترجع
  -- ونرجّع نتيجته.
  begin
    -- if/elsif مش case: case بيحضّر كل النداءات مرة واحدة ويقع لو دالة مجال لسه مش موجودة.
    if split_part(v_kind, '.', 1) = 'inventory' then
      v_res := public.zad_intent_inventory(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'shopping' then
      v_res := public.zad_intent_shopping(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'pharmacy' then
      v_res := public.zad_intent_pharmacy(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'money' then
      v_res := public.zad_intent_money(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'subscription' then
      v_res := public.zad_intent_subscription(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'debt' then
      v_res := public.zad_intent_debt(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'obligation' then
      v_res := public.zad_intent_obligation(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'maintenance' then
      v_res := public.zad_intent_maintenance(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'document' then
      v_res := public.zad_intent_document(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'appointment' then
      v_res := public.zad_intent_appointment(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'settings' then
      v_res := public.zad_intent_settings(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'goal' then
      v_res := public.zad_intent_goal(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'trait' then
      v_res := public.zad_intent_trait(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'profile' then
      v_res := public.zad_intent_profile(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'family' then
      v_res := public.zad_intent_family(v_uid, v_kind, v_payload, v_occurred);
    end if;
    if (v_res ->> 'ok')::boolean is not true then
      v_reason := coalesce(v_res ->> 'reason', 'refused');
    else
      v_payload := v_res -> 'payload';
      insert into public.zad_events (user_id, member_id, client_event_id, kind, payload, occurred_at, source, confidence, trace_id)
      values (v_uid, v_member, v_cid, v_kind, v_payload, v_occurred, v_source, v_conf, v_trace)
      returning id into v_event_id;
    end if;
  exception when unique_violation then
    select * into v_existing from public.zad_events where user_id = v_uid and client_event_id = v_cid;
    if not found then
      raise;
    end if;
    return jsonb_build_object('ok', true, 'duplicate', true, 'event_id', v_existing.id, 'kind', v_existing.kind,
      'row_id', v_existing.payload ->> 'row_id');
  end;

  if v_reason is not null then
    insert into public.zad_guard_events (user_id, kind, reason, source, intent)
    values (v_uid, v_kind, v_reason, v_source, p_intent);
    return jsonb_build_object('ok', false, 'reason', v_reason, 'detail', v_res -> 'detail');
  end if;

  return jsonb_build_object('ok', true, 'duplicate', false, 'event_id', v_event_id, 'kind', v_kind,
    'row_id', v_res -> 'row_id', 'before', v_payload -> 'before', 'after', v_payload -> 'after', 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_commit_intent(jsonb) from public, anon, authenticated;
grant execute on function public.zad_commit_intent(jsonb) to service_role;

create or replace function public.zad_commit_my_intent(
  p_kind text,
  p_client_event_id text,
  p_payload jsonb,
  p_occurred_at timestamptz default null,
  p_trace_id text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $w$
declare
  v_uid uuid := auth.uid();
  v_intent jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  end if;
  if p_kind is null or p_kind not in ('inventory.added', 'inventory.consumed', 'inventory.quantity_set',
                                      'inventory.rate_corrected',
                                      'money.logged', 'money.updated', 'money.deleted', 'money.limit_set',
                                      'money.category_budget_set', 'settings.emergency_fund_set',
                                      'debt.added', 'debt.updated', 'debt.deleted',
                                      'obligation.added', 'obligation.updated', 'obligation.deleted',
                                      'subscription.added', 'subscription.updated', 'subscription.deleted',
                                      'settings.cycle_start_set', 'settings.market_set', 'settings.app_flag_set',
                                      'family.chore_added', 'family.chore_pref_set', 'family.goal_added',
                                      'family.spend_limits_set', 'family.fund_added', 'family.fund_contributed',
                                      'family.challenge_added') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;
  if p_occurred_at is not null and p_occurred_at > now() + interval '1 hour' then
    return jsonb_build_object('ok', false, 'reason', 'bad_shape');
  end if;

  v_intent := jsonb_build_object(
    'kind', p_kind,
    'client_event_id', p_client_event_id,
    'source', 'manual',
    'payload', p_payload);
  if p_occurred_at is not null then
    v_intent := v_intent || jsonb_build_object('occurred_at', p_occurred_at);
  end if;
  if nullif(btrim(coalesce(p_trace_id, '')), '') is not null then
    v_intent := v_intent || jsonb_build_object('trace_id', btrim(p_trace_id));
  end if;
  return public.zad_commit_intent(v_intent);
end;
$w$;

revoke all on function public.zad_commit_my_intent(text, text, jsonb, timestamptz, text) from public, anon;
grant execute on function public.zad_commit_my_intent(text, text, jsonb, timestamptz, text) to authenticated, service_role;
