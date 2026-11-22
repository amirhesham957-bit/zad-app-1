-- ZAD_OR_PLAN م٢.٣: قيود SQL على المخزن والمعاملات.
--
-- الحدود دي من الكود الموجود، مش مخترعة:
--   zad_inventory.quantity >= 0            الكمية مش سالبة (inventory.consumed بيقف عند صفر).
--   zad_transactions.amount في [0, 10000000]  validators.ts (المبلغ >= 0)، وباب الشرا بيرفض فوق ١٠ مليون.
--
-- NOT VALID: القيد بيتطبق على الصفوف الجديدة والمعدّلة بس. الصفوف الموجودة ماتتفحصش، عشان مانقدرش نسأل
-- الداتابيز الحية قبل النشر. الـVALIDATE يتعمل في مايجريشن لوحده بعد ما نتأكد إن مفيش صف مخالف.
--
-- الصفوف المعدّلة بتتفحص كمان. لو صف قديم فيه قيمة مخالفة اتعدّل بعد النشر، التعديل هيترفض لحد ما القيمة تتصلّح.
--
-- مش متضاف هنا (محتاج قرار):
--   - تاريخ الصلاحية مش قبل تاريخ الشرا: zad_inventory مفيهوش عمود تاريخ شرا، و created_at مش نفس الحاجة.
--   - العملة من القايمة: القايمة اللي في zad_fx_rates (٢٠ عملة) مابتشملش EUR وGBP، واللي في bank_keywords بتشملهم.

alter table public.zad_inventory
  drop constraint if exists zad_inventory_quantity_nonnegative;
alter table public.zad_inventory
  add constraint zad_inventory_quantity_nonnegative check (quantity >= 0) not valid;

alter table public.zad_transactions
  drop constraint if exists zad_transactions_amount_range;
alter table public.zad_transactions
  add constraint zad_transactions_amount_range check (amount >= 0 and amount <= 10000000) not valid;
