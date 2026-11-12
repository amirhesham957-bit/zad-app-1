-- ZAD_PLAN ١٠.١ شريحة ٣: حد النقص على قد الكمية والوحدة، مش ٢ لكل حاجة.
--
-- اتقاس ١٢/١١ على الحي: ٤٠ صنف، ٢٩ منهم (٧٢٪) «منخفض». كل الصفوف عليها
-- low_stock_threshold = 2، ومفيش شاشة ولا دالة بتكتبه — ده default العمود. وأغلب
-- الحاجات بتتشترى واحدة («١ علبة»، «١ زجاجة») ⇒ أي صنف لسه داخل البيت كان «ناقص»
-- في التطبيق والبوت والإشعارات، والتنبيه اللي بيطلع على كل حاجة محدش بيبصله.
--
-- القاعدة (هي هي في الموبايل: inventory_item.dart defaultLowStockThreshold):
-- ربع الكمية اللي اتضافت، ومش أقل من حد أدنى حسب الوحدة —
--   كيلو/لتر: ٠٫٢٥ — جرام/ملّي: ١٠٠ — أي حاجة بتتعد (حبة، علبة، زجاجة…): نص.
-- يعني «١ علبة» مش ناقصة لحد ما تخلص أو يفضل نصها، و«٣٠ بيضة» ناقصة عند ٧.
--
-- كل اللي بيقرا الحد (`qty <= low_stock_threshold`: lowStock.ts، restockCycle.ts،
-- voiceMoments.ts، staff.ts، notify_telegram_on_low_stock، الملخص الأسبوعي) بيشتغل
-- صح من غير ما يتغير، لأن الصف نفسه بقى شايل الحد الصح.

create or replace function public.zad_default_low_stock_threshold(
  p_quantity numeric,
  p_unit text
) returns numeric
language sql
immutable
set search_path = ''
as $$
  select greatest(
    case
      when lower(btrim(coalesce(p_unit, ''))) in (
        'كجم', 'كيلو', 'كيلوجرام', 'كيلوغرام', 'كغ', 'kg',
        'لتر', 'l', 'liter', 'litre'
      ) then 0.25
      when lower(btrim(coalesce(p_unit, ''))) in (
        'جرام', 'جم', 'غرام', 'غ', 'g', 'gm', 'مل', 'ملي', 'ml'
      ) then 100
      else 0.5
    end,
    round(greatest(coalesce(p_quantity, 0), 0) * 0.25, 2)
  );
$$;

comment on function public.zad_default_low_stock_threshold(numeric, text) is
  'ZAD_PLAN 10.1: a quarter of what was added, never below 0.5 of a counted pack, 0.25 kg/l or 100 g/ml.';

-- أي إضافة من غير حد (الشات، تليجرام، الفاتورة، الموبايل القديم) تاخد الحد ده.
create or replace function public.zad_inventory_default_threshold()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.low_stock_threshold is null then
    new.low_stock_threshold :=
      public.zad_default_low_stock_threshold(new.quantity, new.unit);
  end if;
  return new;
end;
$$;

drop trigger if exists zad_inventory_default_threshold on public.zad_inventory;
create trigger zad_inventory_default_threshold
  before insert on public.zad_inventory
  for each row execute function public.zad_inventory_default_threshold();

alter table public.zad_inventory alter column low_stock_threshold drop default;

-- الصفوف اللي عليها ٢ أخدوها من الـdefault (مفيش حد كتبه)، فتتحسب من جديد. الحد
-- الجديد عمره ما بيعدّي الكمية الحالية إلا لو هي أصلاً تحت ٢ ⇒ مفيش صنف بيبقى
-- «ناقص» جديد من التحديث ده، فمفيش تنبيه بيطلع منه.
update public.zad_inventory
   set low_stock_threshold = public.zad_default_low_stock_threshold(quantity, unit)
 where low_stock_threshold = 2;
