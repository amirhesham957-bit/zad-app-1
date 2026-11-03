-- الصوت المجاني ٦ في اليوم لكل عميل (قرار المالك ٣/١١: «خلي الرد الصوتي … ٦ لكل عميل فري»؛ كان ٣ من 20261028020000).
-- العدّاد واحد للتطبيق وتليجرام (zad_entitlement_consume 'voice')، وفويس نوت تليجرام بقى بيعدّي على نفس العدّاد بدل
-- رسالة الترقية. المدفوع زي ما هو من غير حد.
update public.zad_tiers set voice_daily = 6 where tier = 'free' and voice_daily is distinct from 6;
