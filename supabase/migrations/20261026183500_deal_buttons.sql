-- ZAD_PLAN ٤.٢٠: عرض الصبح في تليجرام بزرارين — «🛒 ضيفه لقايمتي» و«🙅 مش مهتم».
--
-- الزرار بينادي zad_deal_answer_service زي «ده المرتب؟» (20261025001500): الملكية من اللحظة نفسها
-- (zad_voice_moments.user_id)، والجواب بيتكتب في facts.taste_deal.answer مرة واحدة. «ضيفه» بيضيف الصنف
-- لقايمة البيت لو مش موجود فيها مفتوح بنفس الاسم (zad_inventory_name_key)، و«مش مهتم» بيتقرا في
-- tasteDeals.ts: الاحتياج ده مايتعرضش عليه عرض ٣٠ يوم.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

create or replace function public.zad_deal_answer_service(p_user uuid, p_moment uuid, p_add boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_deal jsonb;
  v_item text;
  v_exists boolean;
begin
  select m.facts -> 'taste_deal' into v_deal
    from public.zad_voice_moments m
   where m.id = p_moment and m.user_id = p_user and m.moment = 'morning_greeting';
  v_item := nullif(btrim(coalesce(v_deal ->> 'item', '')), '');
  if v_item is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_deal ? 'answer' then
    return jsonb_build_object('ok', true, 'already', true, 'answer', v_deal ->> 'answer', 'item', v_item);
  end if;

  update public.zad_voice_moments
     set facts = jsonb_set(facts, '{taste_deal,answer}', to_jsonb(case when p_add then 'add' else 'no' end))
   where id = p_moment;

  if not p_add then
    return jsonb_build_object('ok', true, 'answer', 'no', 'item', v_item);
  end if;

  select exists (
    select 1 from public.zad_shopping_list s
     where coalesce(s.is_purchased, false) = false
       and public.zad_inventory_name_key(s.item_name) = public.zad_inventory_name_key(v_item)
       and (s.user_id = p_user
            or s.family_id in (select m.family_id from public.family_members m where m.user_id = p_user))
  ) into v_exists;
  if not v_exists then
    -- family_id بيتحط من التريجر (populate_family_inventory) زي أي إضافة من التطبيق أو العقل.
    insert into public.zad_shopping_list (user_id, item_name, is_purchased) values (p_user, v_item, false);
  end if;
  return jsonb_build_object('ok', true, 'answer', 'add', 'item', v_item, 'already_listed', v_exists);
end;
$function$;

revoke all on function public.zad_deal_answer_service(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.zad_deal_answer_service(uuid, uuid, boolean) to service_role;
