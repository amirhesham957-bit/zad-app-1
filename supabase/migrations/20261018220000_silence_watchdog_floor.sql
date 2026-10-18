-- المرحلة ٠.٥ (ZAD_DREAM_PLAN.md ع٧): «العقل الاستباقي ساكت ٦٨ ساعة» يوم ١٦/١٠ كان إنذار كاذب.
-- المقاس: المالك كان كاتم أنواعه بـ«عرفت خلاص» (الصرف، البنك، التوقّع — كتم ٣ أيام بيتجدد)، والعميل
-- التاني ماكانش عنده شرط متحقق — مافيش فشل (ليه إنذار لوحده: proactive_scan_failure). الحارس بيحسب
-- «الطبيعي» من وسيط المسافة بين أيام المبادرات آخر ٦٠ يوم، والوسيط ده كان يوم واحد لأن «ملخص البيت
-- الأسبوعي» كان بيطلع كل يوم من ٢٩/٩ لـ٥/١٠ (عطل اتصلح) — فالأرضية ٣٦ ساعة كانت بتنذر على إيقاع
-- طبيعي لبيتين ببيانات قليلة. الأرضية بقت ٧٢ ساعة؛ الوسيط × ١٫٥ لسه بيرفعها لو الإيقاع أبطأ.
--
-- نفس نمط 20261018140000: استبدال واحد على تعريف الدالة الحي، ولازم يحصل مرة واحدة بالظبط.

do $fix$
declare
  def text;
  fixed text;
begin
  select pg_get_functiondef(p.oid) into def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'zad_proactive_silence_check';
  if def is null then
    raise exception 'zad_proactive_silence_check not found';
  end if;
  if position('greatest(72,' in def) > 0 then
    return; -- اتطبق قبل كده
  end if;
  fixed := replace(def, 'greatest(36,', 'greatest(72,');
  if fixed = def then
    raise exception 'zad_proactive_silence_check: the 36-hour floor was not found';
  end if;
  execute fixed;
end
$fix$;
