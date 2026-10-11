-- «دول نفس الحاجة؟» — الإجابة (الموجة ٦، الشريحة ٢، ٢٠٢٦-١٠-١١).
--
-- بعد 20261011200000 الاسم اللي البيت بيختاره بيتكتب في كل حاجة جديدة. هنا اللي بيحصل لما
-- العميل يجاوب:
--
--   «أيوه، نفس الحاجة، سمّيها X» ⇒ zad_product_merge(X، Y):
--     ١. الإجابة تتسجل للبيت (zad_product_pairs، same، الاسم X).
--     ٢. المخزن: صفوف البيت بالاسمين، لكل وحدة صف واحد — الأحدث باسم X لو موجود وإلا الأحدث —
--        بمجموع الكميات (كل صف شرا حقيقي)، وفئة محددة أحسن من «عام/أخرى/البقالة»، وأقرب صلاحية
--        لصف فيه كمية، وأعلى حد. نفس قاعدة 20261010140000. الصفوف التانية بتتمسح بعد ما
--        صلاحيتها تتشال، عشان تريجر الهدر مايسجلش مخزون اتنقل كأنه اترمى.
--     ٣. القايمة: سطر مفتوح واحد باسم X بمجموع الكميات؛ المشترى بيتسمّى X (التاريخ).
--     ٤. الملاحظات بتاعة أفراد البيت بتتسمّى X، ومعدل الاستهلاك بيتحسب تاني تحت X — للي بيجاوب
--        (zad_recompute_consumption بتحسب للعميل نفسه بس من التطبيق؛ من العقل لكل البيت).
--   «لأ، حاجتين مختلفين» ⇒ zad_product_not_same(أ، ب): بتتسجل عشان مايتسألش تاني، ومفيش حاجة
--     بتتغير. لو كانوا «same» قبل كده، الأسماء الجاية بتتكتب زي ما هي (الدمج اللي حصل مابيترجعش).
--
-- النسختين: zad_product_merge / zad_product_not_same للتطبيق (auth.uid())، و…_for(p_user, …) للسيرفر
-- بس (العقل والبوت). الجسم واحد في private.

create schema if not exists private;

create or replace function private.zad_product_merge_impl(p_user uuid, p_keep text, p_other text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_keep text := btrim(regexp_replace(coalesce(p_keep, ''), '\s+', ' ', 'g'));
  v_other text := btrim(regexp_replace(coalesce(p_other, ''), '\s+', ' ', 'g'));
  k1 text;
  k2 text;
  v_family uuid;
  v_members uuid[];
  g record;
  v_keep_id uuid;
  v_pantry int := 0;
  v_lines int := 0;
  v_obs int := 0;
  v_line_keep uuid;
  v_line_qty int;
  u uuid;
begin
  if p_user is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  k1 := public.zad_inventory_name_key(v_keep);
  k2 := public.zad_inventory_name_key(v_other);
  if k1 = '' or k2 = '' or k1 = k2 or char_length(v_keep) > 80 or char_length(v_other) > 80 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  select m.family_id into v_family from public.family_members m where m.user_id = p_user limit 1;
  v_members := array(
    select p_user
    union
    select m.user_id from public.family_members m
     where v_family is not null and m.family_id = v_family and m.user_id is not null
  );

  -- ١. الإجابة.
  insert into public.zad_product_pairs (user_id, family_id, a_key, b_key, verdict, canonical_name)
  values (p_user, v_family, least(k1, k2), greatest(k1, k2), 'same', v_keep)
  on conflict ((coalesce(family_id, user_id)), a_key, b_key)
  do update set verdict = 'same', canonical_name = excluded.canonical_name,
                user_id = excluded.user_id, created_at = now();

  -- ٢. المخزن، لكل وحدة.
  for g in
    select coalesce(nullif(btrim(i.unit), ''), '') as unit_key,
           count(*) as n,
           (array_agg(i.id order by (public.zad_inventory_name_key(i.item_name) = k1) desc,
                                    i.created_at desc nulls last, i.id desc))[1] as keep_id,
           sum(greatest(coalesce(i.quantity, 0), 0)) as total_qty,
           coalesce(
             (array_agg(i.category order by i.created_at desc)
               filter (where nullif(btrim(i.category), '') is not null
                         and i.category not in ('عام', 'أخرى', 'البقالة')))[1],
             (array_agg(i.category order by i.created_at desc)
               filter (where nullif(btrim(i.category), '') is not null))[1]
           ) as best_category,
           (array_agg(i.expiry_date order by public.zad_try_date(i.expiry_date))
             filter (where coalesce(i.quantity, 0) > 0 and public.zad_try_date(i.expiry_date) is not null))[1] as best_expiry,
           max(i.low_stock_threshold) as best_threshold
      from public.zad_inventory i
     where (i.user_id = p_user or (v_family is not null and i.family_id = v_family))
       and public.zad_inventory_name_key(i.item_name) in (k1, k2)
     group by 1
  loop
    v_keep_id := g.keep_id;
    -- التانيين الأول: صلاحيتهم تتشال (مش هدر — المخزون اتنقل)، وبعدين يتمسحوا.
    update public.zad_inventory set expiry_date = null
     where id <> v_keep_id
       and (user_id = p_user or (v_family is not null and family_id = v_family))
       and public.zad_inventory_name_key(item_name) in (k1, k2)
       and coalesce(nullif(btrim(unit), ''), '') = g.unit_key;
    delete from public.zad_inventory
     where id <> v_keep_id
       and (user_id = p_user or (v_family is not null and family_id = v_family))
       and public.zad_inventory_name_key(item_name) in (k1, k2)
       and coalesce(nullif(btrim(unit), ''), '') = g.unit_key;
    update public.zad_inventory
       set item_name = v_keep,
           quantity = g.total_qty,
           category = coalesce(g.best_category, category),
           expiry_date = coalesce(g.best_expiry, expiry_date),
           low_stock_threshold = coalesce(g.best_threshold, low_stock_threshold)
     where id = v_keep_id;
    v_pantry := v_pantry + g.n::int - 1;
  end loop;

  -- ٣. القايمة: سطر مفتوح واحد.
  select (array_agg(s.id order by (public.zad_inventory_name_key(s.item_name) = k1) desc,
                                  s.created_at desc nulls last, s.id desc))[1],
         sum(greatest(coalesce(s.quantity, 1), 1))::int, count(*)
    into v_line_keep, v_line_qty, v_lines
    from public.zad_shopping_list s
   where (s.user_id = p_user or (v_family is not null and s.family_id = v_family))
     and not coalesce(s.is_purchased, false)
     and public.zad_inventory_name_key(s.item_name) in (k1, k2);
  if v_line_keep is not null then
    delete from public.zad_shopping_list
     where id <> v_line_keep
       and (user_id = p_user or (v_family is not null and family_id = v_family))
       and not coalesce(is_purchased, false)
       and public.zad_inventory_name_key(item_name) in (k1, k2);
    update public.zad_shopping_list set item_name = v_keep, quantity = v_line_qty where id = v_line_keep;
    v_lines := v_lines - 1;
  else
    v_lines := 0;
  end if;
  update public.zad_shopping_list set item_name = v_keep
   where (user_id = p_user or (v_family is not null and family_id = v_family))
     and coalesce(is_purchased, false)
     and public.zad_inventory_name_key(item_name) in (k1, k2)
     and item_name <> v_keep;

  -- ٤. الملاحظات والمعدل.
  update public.zad_inventory_observations set item_name = v_keep
   where user_id = any(v_members)
     and public.zad_inventory_name_key(item_name) in (k1, k2)
     and item_name <> v_keep;
  get diagnostics v_obs = row_count;
  delete from public.zad_consumption
   where user_id = any(v_members)
     and public.zad_inventory_name_key(item_name) in (k1, k2)
     and item_name <> v_keep;
  foreach u in array v_members loop
    -- من التطبيق: المعدل بيتحسب للعميل نفسه بس (zad_recompute_consumption بتمنع غيره)؛
    -- الباقيين بيتحسبوا مع ملاحظتهم الجاية.
    if auth.uid() is null or auth.uid() = u then
      if exists (select 1 from public.zad_inventory_observations o
                  where o.user_id = u and o.item_name = v_keep) then
        perform public.zad_recompute_consumption(u, v_keep);
      end if;
    end if;
  end loop;

  return jsonb_build_object('ok', true, 'kept', v_keep,
    'pantry_rows_merged', v_pantry, 'list_lines_merged', v_lines, 'observations_renamed', v_obs);
end;
$$;

create or replace function private.zad_product_not_same_impl(p_user uuid, p_a text, p_b text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  k1 text := public.zad_inventory_name_key(p_a);
  k2 text := public.zad_inventory_name_key(p_b);
  v_family uuid;
begin
  if p_user is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if k1 = '' or k2 = '' or k1 = k2 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;
  select m.family_id into v_family from public.family_members m where m.user_id = p_user limit 1;
  insert into public.zad_product_pairs (user_id, family_id, a_key, b_key, verdict, canonical_name)
  values (p_user, v_family, least(k1, k2), greatest(k1, k2), 'different', null)
  on conflict ((coalesce(family_id, user_id)), a_key, b_key)
  do update set verdict = 'different', canonical_name = null, user_id = excluded.user_id, created_at = now();
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function private.zad_product_merge_impl(uuid, text, text) from public, anon, authenticated;
revoke all on function private.zad_product_not_same_impl(uuid, text, text) from public, anon, authenticated;

create or replace function public.zad_product_merge(p_keep text, p_other text)
returns jsonb language plpgsql security definer set search_path = public
as $$ begin return private.zad_product_merge_impl(auth.uid(), p_keep, p_other); end; $$;
create or replace function public.zad_product_not_same(p_a text, p_b text)
returns jsonb language plpgsql security definer set search_path = public
as $$ begin return private.zad_product_not_same_impl(auth.uid(), p_a, p_b); end; $$;
create or replace function public.zad_product_merge_for(p_user uuid, p_keep text, p_other text)
returns jsonb language plpgsql security definer set search_path = public
as $$ begin return private.zad_product_merge_impl(p_user, p_keep, p_other); end; $$;
create or replace function public.zad_product_not_same_for(p_user uuid, p_a text, p_b text)
returns jsonb language plpgsql security definer set search_path = public
as $$ begin return private.zad_product_not_same_impl(p_user, p_a, p_b); end; $$;

revoke all on function public.zad_product_merge(text, text) from public, anon;
revoke all on function public.zad_product_not_same(text, text) from public, anon;
grant execute on function public.zad_product_merge(text, text) to authenticated;
grant execute on function public.zad_product_not_same(text, text) to authenticated;
revoke all on function public.zad_product_merge_for(uuid, text, text) from public, anon, authenticated;
revoke all on function public.zad_product_not_same_for(uuid, text, text) from public, anon, authenticated;
grant execute on function public.zad_product_merge_for(uuid, text, text) to service_role;
grant execute on function public.zad_product_not_same_for(uuid, text, text) to service_role;
