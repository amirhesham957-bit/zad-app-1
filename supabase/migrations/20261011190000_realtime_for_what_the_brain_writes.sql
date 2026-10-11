-- التحديث اللحظي لِلّي العقل بيكتبه في الخلفية (الموجة ٥، ٢٠٢٦-١٠-١١).
--
-- LiveSync في التطبيق (1e8a59bc) بيسمع على ٨ جداول. فحص ما قبل الإطلاق لقى إن مركز الإشعارات
-- (app_notifications — ١٩٠ صف على الحي) ورؤى العقل (zad_insights) والجرعات اللي بيعلّمها
-- (zad_pharmacy_doses) مش في supabase_realtime خالص، فاللي العقل بيكتبه مايبانش غير لما الشاشة
-- تتقفل وتتفتح. التطبيق بقى بيشترك فيهم (نفس الكومِت)؛ هنا بيتضافوا للنشر.
--
-- مرة واحدة لكل جدول: إضافة جدول موجود في النشر بتقع بخطأ، فبنتأكد الأول.
-- الـRLS بتاع كل جدول هو اللي بيقرر مين يوصله التغيير، زي باقي الجداول.

do $$
declare
  t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'supabase_realtime publication missing — nothing to do';
    return;
  end if;
  foreach t in array array['app_notifications', 'zad_insights', 'zad_pharmacy_doses'] loop
    if not exists (
      select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end
$$;
