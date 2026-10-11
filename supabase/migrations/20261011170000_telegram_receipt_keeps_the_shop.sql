-- صورة البون في تليجرام بتتسجل باسم المحل وبإنها فاتورة (الموجة ٥، ٢٠٢٦-١٠-١١).
--
-- فحص ما قبل الإطلاق: ولا مصروف من فاتورة على الحي عليه merchant_name، ومفيش أي مصروف غير البنك
-- عليه source_type. فاتورة التطبيق بقت بتكتب الاتنين (source_type = 'receipt')؛ البون في تليجرام
-- بيستنى ضغطة تأكيد في telegram_pending_writes، فالطلب بيشيلهم لحد التأكيد، وlog_transaction
-- بيكتبهم (provenance.ts). null = طلب من نص أو صوت، والسلوك زي الأول.

alter table public.telegram_pending_writes add column if not exists merchant_name text;
alter table public.telegram_pending_writes add column if not exists source_type text;
alter table public.telegram_pending_writes drop constraint if exists telegram_pending_writes_source_type_check;
alter table public.telegram_pending_writes add constraint telegram_pending_writes_source_type_check
  check (source_type is null or source_type = 'receipt');
alter table public.telegram_pending_writes drop constraint if exists telegram_pending_writes_merchant_name_check;
alter table public.telegram_pending_writes add constraint telegram_pending_writes_merchant_name_check
  check (merchant_name is null or char_length(merchant_name) <= 80);

comment on column public.telegram_pending_writes.merchant_name is
  'اسم المحل من البون (analyze_receipt.storeName)؛ بيتكتب في zad_transactions.merchant_name عند التأكيد.';
comment on column public.telegram_pending_writes.source_type is
  '''receipt'' لو الطلب من صورة بون؛ null = نص أو صوت.';
