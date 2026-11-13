-- ZAD_PLAN ١٠.٢(ج): طبقة العيلة في الذاكرة (قرار المالك ١٢/١١: العيلة بس، والجمهور يستنى ١٠.١٥).
--
-- اتقاس ١٢/١١ على الحي: ٣٣ ملاحظة حية، **صفر** ملاحظة اتشاركت مع عيلة في تاريخ الجدول كله — مع إن remember
-- فيها share_with_family من ٣٤.٢. يعني الطبقة موجودة ومحدش بيدخلها: الموديل مابيعرفش إمتى يشارك، والعميل
-- مابيتسألش. الحل في العقل (familyShare.ts): سؤال واحد في الأسبوع في تحية الصبح عن حقيقة تخص البيت كله، والمشاركة
-- بتحصل بـ«أيوه» من صاحب الملاحظة بس — من خلال الدالة دي.
--
-- واتلقت ثغرة في نفس الطبقة: الملاحظة المتشاركة بتتقري بـfamily_id بس. فرد ساب العيلة ⇒ ملاحظاته فضلت ظاهرة
-- لعيلته القديمة (سياسة family_shared_memory_select وقراية العقل الاتنين). الخروج = الموافقة خلصت، فـ:
--   - تريجر على family_members: اللي يخرج، ملاحظاته بترجع خاصة.
--   - السياسة بقت بتشترط إن كاتب الملاحظة لسه في نفس العيلة (لو التريجر اتخطّى بأي طريق).

/**
 * شارك ملاحظة مع العيلة أو رجّعها خاصة. صاحب الملاحظة بس (p_user = user_id)، وحية. المشاركة: العميل في عيلة فيها
 * فرد تاني على الأقل، ومش حساب طفل. الإلغاء مسموح دايماً — أي وقت صاحب الملاحظة يقول «خليها ليا».
 */
create or replace function public.zad_memory_share_with_family(p_user uuid, p_memory uuid, p_share boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_id uuid;
  v_family uuid;
  v_role text;
  v_size integer;
begin
  select id into v_id from public.zad_memory
   where id = p_memory and user_id = p_user and superseded_by is null;
  if v_id is null then
    return jsonb_build_object('ok', false, 'reason', 'unknown_note');
  end if;

  if p_share is not true then
    update public.zad_memory set family_id = null where id = p_memory and user_id = p_user;
    return jsonb_build_object('ok', true, 'shared', false);
  end if;

  select family_id, role into v_family, v_role from public.family_members where user_id = p_user limit 1;
  if v_family is null then
    return jsonb_build_object('ok', false, 'reason', 'no_family');
  end if;
  if v_role = 'child' then
    return jsonb_build_object('ok', false, 'reason', 'child');
  end if;
  select count(*) into v_size from public.family_members where family_id = v_family;
  if v_size < 2 then
    return jsonb_build_object('ok', false, 'reason', 'alone');
  end if;

  update public.zad_memory set family_id = v_family where id = p_memory and user_id = p_user;
  return jsonb_build_object('ok', true, 'shared', true);
end
$function$;

revoke all on function public.zad_memory_share_with_family(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.zad_memory_share_with_family(uuid, uuid, boolean) to service_role;

-- اللي يخرج من العيلة (أو يتشال)، ملاحظاته اللي كان شاركها معاها بترجع خاصة.
create or replace function public.zad_memory_unshare_on_leave()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
begin
  if tg_op = 'DELETE' or new.family_id is distinct from old.family_id or new.user_id is distinct from old.user_id then
    update public.zad_memory set family_id = null
     where user_id = old.user_id and family_id = old.family_id;
  end if;
  return null;
end
$function$;

revoke all on function public.zad_memory_unshare_on_leave() from public, anon, authenticated;

drop trigger if exists zad_memory_unshare_on_leave on public.family_members;
create trigger zad_memory_unshare_on_leave
  after delete or update of family_id, user_id on public.family_members
  for each row execute function public.zad_memory_unshare_on_leave();

-- اللي اتساب قبل التريجر ده.
update public.zad_memory m set family_id = null
 where m.family_id is not null
   and not exists (select 1 from public.family_members fm where fm.user_id = m.user_id and fm.family_id = m.family_id);

drop policy if exists "family_shared_memory_select" on public.zad_memory;
create policy "family_shared_memory_select"
  on public.zad_memory for select
  using (
    family_id in (select get_my_family_ids())
    and exists (
      select 1 from public.family_members fm
       where fm.user_id = zad_memory.user_id and fm.family_id = zad_memory.family_id
    )
  );
