-- ZAD_PLAN ١٠.١ شريحة ٣. بعد low_stock_threshold_scaffold.sql و20261112200000_low_stock_threshold_by_unit.sql.

\set ON_ERROR_STOP on

do $$
declare t numeric;
begin
  -- القاعدة: ربع الكمية، ومش أقل من نص علبة / ربع كيلو / ١٠٠ جرام.
  assert public.zad_default_low_stock_threshold(1, 'علبة') = 0.5, 'one box';
  assert public.zad_default_low_stock_threshold(30, 'حبة') = 7.5, 'thirty eggs';
  assert public.zad_default_low_stock_threshold(4, null) = 1, 'no unit counts';
  assert public.zad_default_low_stock_threshold(1, 'كيلو') = 0.25, 'one kilo';
  assert public.zad_default_low_stock_threshold(10, ' KG ') = 2.5, 'unit is trimmed and lowered';
  assert public.zad_default_low_stock_threshold(500, 'جرام') = 125, 'grams';
  assert public.zad_default_low_stock_threshold(200, 'مل') = 100, 'ml floor';
  assert public.zad_default_low_stock_threshold(-3, 'علبة') = 0.5, 'negative is zero';

  -- الصفوف القديمة اللي خدت ٢ من الـdefault اتحسبت من جديد؛ اللي اتكتب صريح فضل.
  select low_stock_threshold into t from public.zad_inventory where item_name = 'legacy-one-box';
  assert t = 0.5, format('legacy one box: %s', t);
  select low_stock_threshold into t from public.zad_inventory where item_name = 'legacy-eggs';
  assert t = 7.5, format('legacy eggs: %s', t);
  select low_stock_threshold into t from public.zad_inventory where item_name = 'legacy-chosen';
  assert t = 1, format('an explicit threshold is kept: %s', t);
  -- علبة واحدة لسه داخلة البيت مش «ناقصة»؛ اللي خلص ناقص.
  assert not exists (select 1 from public.zad_inventory
    where item_name = 'legacy-one-box' and quantity <= low_stock_threshold), 'one box is not low';
  assert exists (select 1 from public.zad_inventory
    where item_name = 'legacy-empty' and quantity <= low_stock_threshold), 'empty is low';

  -- إضافة جديدة من غير حد (الشات، تليجرام، الفاتورة) بتاخد القاعدة.
  insert into public.zad_inventory (item_name, quantity, unit) values ('new-bottle', 2, 'زجاجة');
  select low_stock_threshold into t from public.zad_inventory where item_name = 'new-bottle';
  assert t = 0.5, format('new bottle: %s', t);
  -- والحد اللي جاي مع الإضافة بيغلب.
  insert into public.zad_inventory (item_name, quantity, unit, low_stock_threshold)
    values ('new-chosen', 2, 'زجاجة', 1);
  select low_stock_threshold into t from public.zad_inventory where item_name = 'new-chosen';
  assert t = 1, format('explicit on insert: %s', t);
end $$;

select 'low_stock_threshold_test ok';
