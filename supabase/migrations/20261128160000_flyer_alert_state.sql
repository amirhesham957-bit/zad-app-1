-- تنبيه صحة النشرات بيتبعت لما الحالة تتغير مش كل ٢٤ ساعة: توقيع الحالة ('' = سليمة) محفوظ مع آخر إرسال.
alter table public.zad_admin_alert_log add column if not exists state text;
