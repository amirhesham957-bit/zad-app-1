-- P2.4 — حزمة البلد: zad_locale_config مابقتش dedupe بس، بقت كل اللي بيتغير بين سوق وسوق
-- (المتاجر، المواسم، يوم القبض، الأكلات) كبيانات بدل ثوابت في الكود.
-- ماتخترعش أرقام مالية: مفيش مبالغ هنا. يوم القبض "افتراضي" بيتبدّل بأول دخل حقيقي للعميل.
-- idempotent: الأعمدة add if not exists، والبيانات بتتملي بس لو العمود لسه فاضي
-- (فاللي اتعدّل من الداشبورد ماينكتبش عليه).

alter table public.zad_locale_config
  add column if not exists common_stores text[] not null default '{}',
  add column if not exists seasons jsonb not null default '[]'::jsonb,
  add column if not exists default_payday smallint,
  add column if not exists common_dishes text[] not null default '{}';

do $$ begin
  alter table public.zad_locale_config
    add constraint zad_locale_config_default_payday_range check (default_payday is null or default_payday between 1 and 31);
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.zad_locale_config
    add constraint zad_locale_config_seasons_is_array check (jsonb_typeof(seasons) = 'array');
exception when duplicate_object then null; end $$;

comment on column public.zad_locale_config.common_stores is 'أشهر المتاجر في السوق، بالاسم اللي العميل بيكتبه.';
comment on column public.zad_locale_config.seasons is
  'مواسم السوق: [{"name","month" 1..12,"day" (اختياري),"hijri" (true = بتتحرك ~١١ يوم كل سنة، فالشهر تقريبي)}]. تقريب، مش موعد.';
comment on column public.zad_locale_config.default_payday is
  'يوم القبض الافتراضي (1..31) لحد ما أول دخل حقيقي للعميل يحدد يومه. تقدير للسوق، مش رقم من العميل.';
comment on column public.zad_locale_config.common_dishes is 'أكلات شائعة في السوق، لاقتراحات الوجبات والمخزن.';

-- بيانات البلاد الموجودة فعلاً (EG/SA/TR) وبس. مفيش insert لبلد جديد.
update public.zad_locale_config set
  common_stores = array['كارفور','سبينيس','هايبر وان','أولاد رجب','خير زمان','بنده'],
  common_dishes = array['كشري','فول وطعمية','ملوخية','محشي','فراخ ورز','مكرونة بشاميل'],
  default_payday = 1
where country = 'EG' and common_stores = '{}';
update public.zad_locale_config set
  seasons = '[
    {"name":"رمضان","month":3,"hijri":true},
    {"name":"عيد الفطر","month":4,"hijri":true},
    {"name":"عيد الأضحى","month":6,"hijri":true},
    {"name":"شم النسيم","month":4},
    {"name":"رأس السنة","month":1,"day":1},
    {"name":"بداية الدراسة","month":9}
  ]'::jsonb
where country = 'EG' and seasons = '[]'::jsonb;

update public.zad_locale_config set
  common_stores = array['بنده','العثيم','التميمي','الدانوب','كارفور','لولو'],
  common_dishes = array['كبسة','مندي','جريش','مطبق','سمبوسة','مرقوق'],
  default_payday = 27
where country = 'SA' and common_stores = '{}';
update public.zad_locale_config set
  seasons = '[
    {"name":"رمضان","month":3,"hijri":true},
    {"name":"عيد الفطر","month":4,"hijri":true},
    {"name":"الحج وعيد الأضحى","month":6,"hijri":true},
    {"name":"يوم التأسيس","month":2,"day":22},
    {"name":"اليوم الوطني","month":9,"day":23},
    {"name":"بداية الدراسة","month":8}
  ]'::jsonb
where country = 'SA' and seasons = '[]'::jsonb;

update public.zad_locale_config set
  common_stores = array['BİM','A101','ŞOK','Migros','CarrefourSA'],
  common_dishes = array['menemen','mercimek çorbası','kuru fasulye','pilav','lahmacun','börek'],
  default_payday = 15
where country = 'TR' and common_stores = '{}';
update public.zad_locale_config set
  seasons = '[
    {"name":"رمضان","month":3,"hijri":true},
    {"name":"عيد الفطر (Ramazan Bayramı)","month":4,"hijri":true},
    {"name":"عيد الأضحى (Kurban Bayramı)","month":6,"hijri":true},
    {"name":"عيد الجمهورية","month":10,"day":29},
    {"name":"بداية الدراسة","month":9}
  ]'::jsonb
where country = 'TR' and seasons = '[]'::jsonb;
