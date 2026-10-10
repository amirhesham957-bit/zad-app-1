-- A receipt saved first, then the bank's notification for the same card payment, is one
-- payment (2026-10-10).
--
-- Confirming a bank notification already asks «نفس المعاملة؟» when an expense with the same
-- amount sits within 15 minutes of the notification (20260913213000). A receipt is rarely
-- that close: it carries the printed day, not a time, and is often photographed the next
-- morning — so «receipt, then the bank» confirmed into two expenses for one payment. (The
-- other order — bank first — is handled on the phone: the receipt sheet finds the bank's row
-- and completes it, `bank_twin.dart`.)
--
-- For a receipt-style row — a shop name, no channel of its own (`source_type` null), not
-- cash — the window is now 36 hours either side. Nothing is merged by this: the proposal is
-- marked a suspected duplicate and the customer answers «نفس المعاملة» or «عملية تانية»,
-- exactly as before. A wrong match costs one question, never an expense.
--
-- Edited on the live text of `private.zad_resolve_transaction_proposal_impl` (13 KB): the one
-- clause is matched by its words with any spacing and must match exactly once — checked
-- read-only on production the same day.

do $migrate$
declare
  v_def text;
  v_pat text;
  v_hits int;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private' and p.proname = 'zad_resolve_transaction_proposal_impl';
  if v_def is null then
    raise exception 'receipt twin: private.zad_resolve_transaction_proposal_impl not found';
  end if;

  v_pat := 'and t.created_at between v_proposal.created_at - interval ''15 minutes'' '
        || 'and v_proposal.created_at + interval ''15 minutes''';
  v_pat := regexp_replace(v_pat, '([.*+?^${}()|\[\]\\])', '\\\1', 'g');
  v_pat := regexp_replace(v_pat, ' ', '\\s+', 'g');

  v_hits := regexp_count(v_def, v_pat);
  if v_hits <> 1 then
    raise exception 'receipt twin: % matches of the transaction window, expected 1', v_hits;
  end if;

  execute regexp_replace(v_def, v_pat,
    'and (t.created_at between v_proposal.created_at - interval ''15 minutes'''
    || ' and v_proposal.created_at + interval ''15 minutes'''
    || ' or (t.source_type is null and t.merchant_name is not null'
    || ' and t.wallet is distinct from ''cash'''
    || ' and t.created_at between v_proposal.created_at - interval ''36 hours'''
    || ' and v_proposal.created_at + interval ''36 hours''))');
end
$migrate$;
