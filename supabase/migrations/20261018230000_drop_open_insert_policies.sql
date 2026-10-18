-- البند ٠.٧ (أمان سريع): سياستين insert بـ`with check (true)` لـpublic من 20260831140000.
-- اسمهم "server_write" بس service_role بيتخطى RLS ومش محتاجهم، فالأثر الوحيد إن أي حد معاه
-- الـanon key يقدر يدخّل توصيات أو إنجازات باسم أي مستخدم. التطبيق بيقرا الجدولين ويعدّل
-- التوصيات بس (سياسات owner موجودة)، ومفيش كاتب ليهم غير السيرفر. حارسه: _schema/policies_test.ts.
drop policy if exists "shopping_recommendations_server_write" on public.shopping_recommendations;
drop policy if exists "user_achievements_server_write" on public.user_achievements;
