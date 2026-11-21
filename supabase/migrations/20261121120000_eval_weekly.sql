-- التقييم يبقى أسبوعي بدل ليلي (ZAD_OR_PLAN م١.٥، المالك ٢١/١١).
--
-- المقاس ٢٠/١١: حساب الاختبار عمل ٣٬٣٦١ لفة شات من ٣٬٥١٥ في ١٤ يوم (٩٦٪)، بـ٧٩ مليون توكن. أغلبها eval-nightly:
-- ١١٧ لفة كل ليلة الساعة ٢ و٦٤ الساعة ٣ UTC (٢٠٠ حالة). التقييم بيشتغل على ZAD_EVAL_KEY لوحده، فهو مش بياكل كوتة
-- العملاء، بس المفتاح ده مدفوع، يعني كل ليلة فلوس. التغطية زي ما هي: نفس الـ٢٠٠ حالة، مرة في الأسبوع (الجمعة)،
-- ومعاها فحص القبول (٨ حالات) بعد كل نشر بيلمس العقل في CI. zad_eval_verdict(day) بيقرا يوم الجمعة.
-- الأمر نفسه زي ما هو في 20261025021500، والجدول بس اتغير.

do $cron$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    return;
  end if;
  perform cron.alter_job(
    job_id := (select jobid from cron.job where jobname = 'eval-nightly'),
    schedule := '*/3 2-3 * * 5'
  )
  where exists (select 1 from cron.job where jobname = 'eval-nightly');
end
$cron$;
