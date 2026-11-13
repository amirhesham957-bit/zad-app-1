-- فاتورة صيدلية من تليجرام = تأكيد واحد مجمّع، ولمين (قرار المالك ١٣/١١/٢٠٢٦).
--
-- قبل كده كل دوا جديد في الصورة كان صف لوحده برسالة وزرار لوحدهم (٧ رسايل لفاتورة واحدة عند المالك)،
-- والكابشن «دا دوا مامتي» كان بيتبلع: الدوا بيتسجل على حساب اللي بعت.
--   batch_id   — صفوف الفاتورة الواحدة، بيتأكدوا أو يتلغوا مع بعض بزرار واحد.
--   for_person — اللي الكابشن قاله («مامتي»). العقل (add_pharmacy_item) هو اللي بيقرر: فرد في العيلة
--                وموافق ⇒ صيدليته هو، غير كده for_person على حساب اللي بعت.
-- الجدول نفسه والـRLS زي ما هم (20260808210000).
alter table public.telegram_pending_pharmacy
  add column if not exists batch_id uuid,
  add column if not exists for_person text check (for_person is null or char_length(for_person) <= 40);

create index if not exists idx_telegram_pending_pharmacy_batch
  on public.telegram_pending_pharmacy (batch_id) where batch_id is not null;
