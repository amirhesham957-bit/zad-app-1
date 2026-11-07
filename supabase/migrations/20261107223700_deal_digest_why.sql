-- سبب كل عرض اتبعت في رسالة العروض (ZAD_PLAN ٥.٩، قياس الشريحة ٣): need / want / season / favorite / fire / top،
-- والأكواد code. من غيره مانقدرش نعرف العروض اللي جت من نية («بكام…؟») أو موسم بتتبعت قد إيه وبتتعمل بيها ولا لأ.
-- عمود جديد بس؛ الصفوف القديمة null (اتبعتت قبل ما السبب يتسجل). الكتابة من السيرفر بس زي الأول.

alter table public.zad_deal_digest_sent add column if not exists why text
  check (why is null or why in ('need', 'want', 'season', 'favorite', 'fire', 'top', 'code'));
