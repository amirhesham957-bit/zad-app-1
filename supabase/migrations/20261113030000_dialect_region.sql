-- ZAD_PLAN ١٠.١٦ (قرار المالك ١٣/١١): العميل يختار منطقته في «ملفي» — حجازي، نجدي، شرقي، جنوبي، أو «عام».
-- قبل كده المنطقة كانت جاية من مدينة الملف بس، واتقاس ١٣/١١: ١ من ١١ حساب سعودي عنده مدينة. اختياره
-- بيكسب على المدينة (`resolveRegion` في `_shared/dialect.ts`)؛ «GENERAL» = سعودي عام حتى لو المدينة جدة؛
-- null = ماختارش ⇐ المدينة زي الأول. الجدول عليه RLS بالفعل (صاحب الصف بيقرا ويكتب صفه).
alter table public.zad_customer_profile
  add column if not exists dialect_region text
  check (dialect_region is null or dialect_region in ('SA_HIJAZ', 'SA_NAJD', 'SA_EAST', 'SA_SOUTH', 'GENERAL'));
