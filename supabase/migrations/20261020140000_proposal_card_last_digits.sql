-- آخر أرقام الكارت/الحساب من إشعار البنك (٢٠٢٦-١٠-٢٠). بوابة الإشعارات في zad-brain بتقراها من النص
-- (notificationGate.ts) وبتتأكد إنها مكتوبة فيه فعلاً. ٢–٤ أرقام بس: أكتر من كده بيبقى رقم كارت، مش تمييز.
alter table public.zad_transaction_proposals
  add column if not exists card_last_digits text
    check (card_last_digits is null or card_last_digits ~ '^[0-9]{2,4}$');

comment on column public.zad_transaction_proposals.card_last_digits is
  'Last 2-4 digits of the card/account as printed in the bank notification; read by the notification gate and grounded in the text.';
