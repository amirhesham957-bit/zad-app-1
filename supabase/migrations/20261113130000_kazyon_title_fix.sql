-- ١٠.١٧ (owner's decision 13/11): the Kazyon purchase of 12/11 was recorded as
-- «دانوب» because the model's counterparty was trusted without checking it was
-- written in the bank message (fixed in code by #542). This corrects that one
-- row. Pinned to the id AND its current wrong values, so it is a no-op anywhere
-- the row is absent or was already edited by the customer.
update public.zad_transactions
   set title = 'KAZYON',
       merchant_name = 'KAZYON'
 where id = '3faecada-c0cc-4e6c-aa6c-34f523aaaf2c'
   and title = 'دانوب'
   and merchant_name = 'دانوب'
   and amount = 141.5;
