-- 20261011160000 — «تراجع» بيعرف البيت (الموجة ٥).
--
-- المخزن والقايمة للبيت كله (20261011140000، ce5b28db): العقل بيشطب صنف الأم لما الأب يقول
-- «اشتريته»، وبيعدّل كمية صنف في مخزن البيت أياً كان اللي ضافه. لكن zad_agent_undo كانت بتلاقي
-- الصف بـuser_id = اللي بيتراجع بس، فالتراجع عن تعديل على صف فرد تاني كان بيرجع
-- target_row_missing — والسجل بيقول «اتعمل» ومافيش «تراجع». ده كان حاصل من قبل كده مع
-- update_inventory_qty (بيعدّل صفوف العيلة من Task 30).
--
-- دلوقتي، للجدولين دول بس (zad_inventory وzad_shopping_list): الصف لازم يبقى بتاع اللي بيتراجع
-- أو بتاع عيلته — نفس RLS بتاعهم. باقي الجداول (معاملات، أدوية، التزامات، البروفايل) زي ما
-- هي: صاحبها بس.
--
-- اللي فاضل زي ما هو عن قصد: «فيه فعل أحدث على نفس الصف؟» بيعدّ أفعال اللي بيتراجع بس؛ لو
-- الفرد التاني عدّل نفس الصف بعده، التراجع بيرجّع الحالة اللي قبل فعل الأول. نادر، واتكتب هنا.
--
-- التعديل على النص الحي (md5 قبل: 48c6047a…): كل جملة بكلماتها بأي مسافات، مرة واحدة بالظبط.

do $migrate$
declare
  r record;
  v_def text;
  v_pat text;
  v_hits int;
begin
  for r in
    select * from (values
      (1, 'v_newer int;',
          'v_newer int;
  v_scope text;'),
      (2, 'return jsonb_build_object(''ok'', false, ''error'', ''table_not_undoable'', ''table'', v_act.target_table); end if;',
          'return jsonb_build_object(''ok'', false, ''error'', ''table_not_undoable'', ''table'', v_act.target_table);
  end if;

  -- المخزن والقايمة للبيت (20261011160000): الصف بتاع اللي بيتراجع أو بتاع عيلته، زي RLS بتاعهم.
  v_scope := case when v_act.target_table in (''zad_inventory'', ''zad_shopping_list'')
    then format(''(t.%1$I = $2 or t.family_id in (select m.family_id from public.family_members m where m.user_id = $2))'', v_owner_col)
    else format(''t.%I = $2'', v_owner_col)
  end;'),
      (3, 'execute format(''delete from public.%I where id = $1 and %I = $2'', v_act.target_table, v_owner_col)',
          'execute format(''delete from public.%I t where t.id = $1 and '', v_act.target_table) || v_scope'),
      (4, 'if (v_act.previous_state ->> v_owner_col)::uuid is distinct from v_uid then',
          'if (v_act.previous_state ->> v_owner_col)::uuid is distinct from v_uid
       and not (v_act.target_table in (''zad_inventory'', ''zad_shopping_list'')
                and (v_act.previous_state ->> ''family_id'')::uuid in
                    (select m.family_id from public.family_members m where m.user_id = v_uid)) then'),
      (5, 'where t.id = $1 and t.%I = $2'', v_act.target_table, v_set, v_act.target_table, v_owner_col',
          'where t.id = $1 and '' || v_scope, v_act.target_table, v_set, v_act.target_table')
    ) t(n, old_words, new_text)
    order by n
  loop
    select pg_get_functiondef('public.zad_agent_undo(uuid)'::regprocedure) into v_def;

    -- Literal words, any spacing (the recipe of 20261010130000).
    v_pat := regexp_replace(r.old_words, '([.*+?^${}()|\[\]\\])', '\\\1', 'g');
    v_pat := regexp_replace(v_pat, ' ', '\\s+', 'g');

    v_hits := regexp_count(v_def, v_pat);
    if v_hits <> 1 then
      raise exception 'undo household: phrase % has % matches, expected 1', r.n, v_hits;
    end if;

    -- The replacement is literal: escape what regexp_replace reads as back-references.
    execute regexp_replace(v_def, v_pat, replace(replace(r.new_text, '\', '\\'), '&', '\&'));
  end loop;
end
$migrate$;
