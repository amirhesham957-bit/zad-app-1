-- العروض من غير ولا خطوة يدوية (قرار المالك ٣/١١: «مش هبعت ولا أرفع نشرات بإيدي؛ العروض كلها أوتوماتيك بالذكاء
-- والكرون»). المقاس قبلها: ٠ من ٣٦ تحية صبح في يومين فيها عرض، وعملاء في الإمارات وقطر من غير ولا عرض لأن قايمة
-- محلات البحث كانت السعودية ومصر بس.
--
-- ١. محلات البحث الأسبوعي للإمارات وقطر (فيهم عملاء): نفس الكرونات (بحث، يوتيوب، إنستجرام) بتلفّ عليهم لوحدها.
-- ٢. `zad_deal_paused_sources`: بوابة الدقة (٤.١٩) أوتوماتيك بدل المراجعة اليدوية — مصدر اتعرض منه ١٠ عروض أو أكتر
--    آخر ١٤ يوم والعملاء قالوا على أكتر من ١٠٪ منهم «العرض ده غلط» بيقف عن تحية الصبح لوحده، ويرجع لما النسبة تنزل.

insert into public.zad_deal_seed_stores (country, store, currency, kind) values
  ('AE', 'كارفور الإمارات', 'AED', 'grocery'),
  ('AE', 'لولو', 'AED', 'grocery'),
  ('AE', 'يونيون كوب', 'AED', 'grocery'),
  ('AE', 'سبينيس', 'AED', 'grocery'),
  ('AE', 'طلبات', 'AED', 'delivery'),
  ('AE', 'نون', 'AED', 'marketplace'),
  ('AE', 'أمازون الإمارات', 'AED', 'marketplace'),
  ('QA', 'لولو', 'QAR', 'grocery'),
  ('QA', 'كارفور قطر', 'QAR', 'grocery'),
  ('QA', 'الميرة', 'QAR', 'grocery'),
  ('QA', 'مونوبري', 'QAR', 'grocery'),
  ('QA', 'طلبات', 'QAR', 'delivery'),
  ('QA', 'سنونو', 'QAR', 'delivery')
on conflict (country, store) do nothing;

create or replace function public.zad_deal_paused_sources(p_days int default 14)
returns table (source_kind text, shown bigint, wrong bigint)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select a.source_kind, a.shown, a.wrong
    from public.zad_deal_accuracy(p_days) a
   where a.source_kind <> 'live'
     and a.shown >= 10
     and a.wrong * 10 > a.shown;
$function$;

revoke all on function public.zad_deal_paused_sources(int) from public, anon, authenticated;
grant execute on function public.zad_deal_paused_sources(int) to service_role;
