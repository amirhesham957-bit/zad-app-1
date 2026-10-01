-- الصيدلية: قاعدة واحدة للوحدة، أياً كان الطريق (تشخيص زاد ١.٧، ٢٠٢٦-١٠-٠١).
--
-- اتقاس على حساب المالك: نفس النوع بيتسجل «حبة» من الشات (الافتراضي في أداة
-- add_pharmacy_item)، و«قرص» من الفاتورة (countableUnit في التطبيق)، والاتنين من
-- الفورم (القايمة فيها الاتنين). وكريم البشرة اتسجل بـ٣ جرعات في اليوم وكل جرعة
-- خصمت «وحدة» كاملة، فبقت كميته صفر بعد يوم — أنبوبة كريم مش ٣ حبات.
--
-- القاعدة هنا في الداتابيز عشان تمسك كل الطرق مرة واحدة: الشات (zad-brain)،
-- الفورم والفاتورة (التطبيق)، وzad_pharmacy_restock. القيم بيانات بتتخزن وتتطابق
-- (CLAUDE.md، قسم i18n) — تفضل عربي.
--
--   حبة/حبات/حبوب/أقراص/قرص/tab  → قرص
--   كريم/مرهم/جل/جيل/دهان/لوشن     → دهان، والجرعة مابتخصمش من الكمية
--                                     (units_per_dose = 0: الكمية = عدد الأنابيب)

create or replace function public.zad_pharmacy_unit(p_unit text)
returns text
language sql
immutable
set search_path to 'public'
as $function$
  select case
    when p_unit is null or btrim(p_unit) = '' then p_unit
    when lower(btrim(p_unit)) ~ '^(حب|قرص|أقراص|اقراص|tab|pill)' then 'قرص'
    when lower(btrim(p_unit)) ~ '^(كريم|مرهم|جل|جيل|دهان|لوشن|cream|ointment|gel|lotion)' then 'دهان'
    when lower(btrim(p_unit)) ~ '^(كبسول|cap)' then 'كبسولة'
    when lower(btrim(p_unit)) ~ '^(نقط|نقطة|قطر)' then 'نقطة'
    else btrim(p_unit)
  end;
$function$;

create or replace function public.zad_pharmacy_items_normalize()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  new.unit := public.zad_pharmacy_unit(new.unit);
  -- دهان: الجرعة دهنة، مش أنبوبة. صفر = الدوز بيتسجل والكمية ماتتحركش
  -- (zad_log_pharmacy_dose_atomic بياخد greatest(units_per_dose, 0)).
  if new.unit = 'دهان' then
    new.units_per_dose := 0;
    new.dose_carry := 0;
  end if;
  return new;
end;
$function$;

drop trigger if exists zad_pharmacy_items_normalize on public.zad_pharmacy_items;
create trigger zad_pharmacy_items_normalize
  before insert or update of unit, units_per_dose on public.zad_pharmacy_items
  for each row execute function public.zad_pharmacy_items_normalize();

-- الصفوف الموجودة: نفس القاعدة. الكمية نفسها ماتتلمسش — مانعرفش العميل عنده
-- كام أنبوبة، والشاشة بتطلب منه يأكد العدد.
update public.zad_pharmacy_items
set unit = public.zad_pharmacy_unit(unit)
where unit is distinct from public.zad_pharmacy_unit(unit)
   or (public.zad_pharmacy_unit(unit) = 'دهان' and coalesce(units_per_dose, 1) <> 0);
