-- 20261102090000: the Telegram line reads txn_kind. Scaffold: the function as it was, then the migration.
\set ON_ERROR_STOP on
do $$
declare d text := pg_get_functiondef('public.notify_telegram_on_transaction()'::regprocedure);
begin
  assert position('NEW.is_expense THEN' in d) = 0, 'still reads is_expense';
  assert position('سحب كاش (مش مصروف' in d) > 0;
end $$;
select 'withdrawal_label_test: ok' as result;
