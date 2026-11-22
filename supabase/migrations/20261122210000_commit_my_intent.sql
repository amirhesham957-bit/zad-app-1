-- ZAD_OR_PLAN م٢.٤: غلاف الباب للموبايل، للمخزن بس (٣ أنواع).
--
-- zad_commit_intent للسيرفر (service_role) بس. الموبايل (authenticated) بينده الغلاف ده بدلها:
--   * المستخدم دايماً auth.uid() من الـJWT. الغلاف مابياخدش user_id خالص، فمفيش طريقة يتكتب بيها لحد تاني.
--   * المصدر دايماً 'manual'. العميل مايقدرش يقول 'model' أو 'bank'.
--   * الأنواع المسموحة: inventory.added / consumed / quantity_set. أي نوع تاني = unknown_kind (مجالات الموبايل
--     التانية بتتضاف بشرايح بعدها).
--   * التكرار: نفس client_event_id = duplicate:true من غير كتابة (الباب نفسه).
--   * occurred_at من العميل مسموح في الماضي (أوفلاين)، وبعد ساعة من دلوقتي مرفوض.
-- الباب نفسه ماتغيّرش، وصلاحيته لسه service_role بس.

create or replace function public.zad_commit_my_intent(
  p_kind text,
  p_client_event_id text,
  p_payload jsonb,
  p_occurred_at timestamptz default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_intent jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  end if;
  if p_kind is null or p_kind not in ('inventory.added', 'inventory.consumed', 'inventory.quantity_set') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;
  if p_occurred_at is not null and p_occurred_at > now() + interval '1 hour' then
    return jsonb_build_object('ok', false, 'reason', 'bad_shape');
  end if;

  -- مفيش user_id ولا member_id ولا confidence في النية: الباب بيجيب المستخدم من الـJWT والفرد «أنا».
  v_intent := jsonb_build_object(
    'kind', p_kind,
    'client_event_id', p_client_event_id,
    'source', 'manual',
    'payload', p_payload);
  if p_occurred_at is not null then
    v_intent := v_intent || jsonb_build_object('occurred_at', p_occurred_at);
  end if;
  return public.zad_commit_intent(v_intent);
end;
$fn$;

revoke all on function public.zad_commit_my_intent(text, text, jsonb, timestamptz) from public, anon;
grant execute on function public.zad_commit_my_intent(text, text, jsonb, timestamptz) to authenticated, service_role;
