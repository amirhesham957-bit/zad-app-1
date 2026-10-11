-- 20261011150000 — «هيخلص إمتى؟» والأمازون بيشوفوا البيت، مش الفرد (الموجة ٥، قرار المالك ٢٠٢٦-١٠-١١:
-- «العقل يتعامل مع البيت كوحدة استهلاك واحدة»).
--
-- بعد 20261011140000 القايمة بقت للبيت زي المخزن. دالتين كانوا لسه بيقروا بتاع الفرد بس:
--
--   _agent_predicted_shortage_for_user — كانت بتتوقع من مخزن العميل نفسه (i.user_id = p_user)،
--     وبتستبعد الصنف لو في قايمته هو بس (s.user_id = p_user). فلو الأب ضاف «لبن» للقايمة،
--     الأم كانت هتتسأل «أضيفه؟» عن حاجة متضافة، ولو اللبن في المخزن باسم الأب ماكانتش
--     هتتسأل عنه خالص.
--   zad_affiliate_matches — روابط أمازون للنواقص: نفس الحكاية مع القايمة والمخزن.
--
-- التعديل على النص الحي (ZAD_LIVING_BRAIN.md §١١ — الريبو والحي اختلفوا قبل كده): كل جملة
-- بتتلاقي بكلماتها بأي مسافات، ولازم تتلاقي مرة واحدة بالظبط، وإلا المايجريشن بتقف.
-- البيت = صفوف العميل + صفوف عيلته (family_members، عضوية واحدة).

do $migrate$
declare
  r record;
  v_def text;
  v_pat text;
  v_hits int;
begin
  for r in
    select * from (values
      ('_agent_predicted_shortage_for_user',
       'where i.user_id = p_user and coalesce(c.rate_known, false)',
       'where (i.user_id = p_user or i.family_id in (select m.family_id from public.family_members m where m.user_id = p_user)) and coalesce(c.rate_known, false)'),
      ('_agent_predicted_shortage_for_user',
       'where s.user_id = p_user and not coalesce(s.is_purchased, false)',
       'where (s.user_id = p_user or s.family_id in (select m.family_id from public.family_members m where m.user_id = p_user)) and not coalesce(s.is_purchased, false)'),
      ('zad_affiliate_matches',
       'FROM zad_shopping_list WHERE user_id = p_user AND NOT is_purchased',
       'FROM zad_shopping_list WHERE (user_id = p_user OR family_id IN (SELECT m.family_id FROM family_members m WHERE m.user_id = p_user)) AND NOT is_purchased'),
      ('zad_affiliate_matches',
       'WHERE i.user_id = p_user AND c.avg_daily_qty > 0',
       'WHERE (i.user_id = p_user OR i.family_id IN (SELECT m.family_id FROM family_members m WHERE m.user_id = p_user)) AND c.avg_daily_qty > 0')
    ) t(fn, old_words, new_text)
  loop
    select pg_get_functiondef(p.oid) into v_def
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = r.fn;
    if v_def is null then
      raise exception 'household list: % not found', r.fn;
    end if;

    -- Literal words, any spacing: escape the regex characters, then let every gap match
    -- any run of whitespace (the same recipe as 20261010130000).
    v_pat := regexp_replace(r.old_words, '([.*+?^${}()|\[\]\\])', '\\\1', 'g');
    v_pat := regexp_replace(v_pat, ' ', '\\s+', 'g');

    v_hits := regexp_count(v_def, v_pat);
    if v_hits <> 1 then
      raise exception 'household list: % has % matches for «%», expected 1', r.fn, v_hits, r.old_words;
    end if;

    execute regexp_replace(v_def, v_pat, r.new_text);
  end loop;
end
$migrate$;
