-- صورة البون في تليجرام بتتسجل بطريقة الدفع (الموجة ٣، بند ٧ — باقي من الموجة ٢، ٢٠٢٦-١٠-١٠).
--
-- الموجة ٢ (2b257ef5) خلّت analyze_receipt يقرا طريقة الدفع من الورقة (كاش/بطاقة/محفظة) والتطبيق يسجّل بيها.
-- البوت كان بيسجّل أي مصروف اتأكد من تليجرام «card» ثابتة، لأن telegram_pending_writes مالوش عمود يشيلها
-- لحد ما العميل يدوس تأكيد. دلوقتي الطلب بيشيل wallet (نفس قيم zad_transactions.wallet)؛ null = البون ماقالش،
-- والتأكيد بيكتب card زي الأول.

alter table public.telegram_pending_writes add column if not exists wallet text;
alter table public.telegram_pending_writes drop constraint if exists telegram_pending_writes_wallet_check;
alter table public.telegram_pending_writes add constraint telegram_pending_writes_wallet_check
  check (wallet is null or wallet in ('cash', 'card', 'bank'));

comment on column public.telegram_pending_writes.wallet is
  'طريقة الدفع اللي البون قالها (cash/card/bank — محفظة موبايل = bank زي التطبيق). null = ماقالش، والتأكيد بيكتب card.';
