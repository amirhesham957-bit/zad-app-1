-- «زاد | معاملة جديدة — مصروف: سحب كاش — bdc — 1000» (بلاغ المالك ٢/١١، صورة من تليجرام ٣٠/١٠).
--
-- السحب نفسه متسجل صح من ٣٠/١٠: txn_kind = transfer وtransfer_to = cash، فمابيدخلش في الصرف، والفواتير
-- الكاش بعده هي اللي بتتحسب. بس رسالة تليجرام كانت بتقرا is_expense (true على كل صف من الإشعار)، فالعميل
-- شاف «مصروف ١٠٠٠» وبعدها الفواتير، وفهم إن الفلوس اتخصمت مرتين. الرسالة بقت بتقرا txn_kind زي باقي التريجر.
--
-- تعديل على النص الحي (نفس طريقة 20261011160000): الجملة لازم تتلاقي مرة واحدة بالظبط.

do $migrate$
declare
  v_def text;
  v_pat text;
  v_new text := $new$(CASE WHEN NEW.txn_kind = 'transfer' AND NEW.transfer_to = 'cash' THEN 'سحب كاش (مش مصروف — اللي هتصرفه منه هو اللي بيتحسب): ' WHEN NEW.txn_kind = 'transfer' THEN 'تحويل: ' WHEN NEW.txn_kind = 'income' THEN 'دخل: ' ELSE 'مصروف: ' END)$new$;
  v_hits int;
begin
  select pg_get_functiondef('public.notify_telegram_on_transaction()'::regprocedure) into v_def;
  v_pat := $p$\(CASE\s+WHEN\s+NEW\.is_expense\s+THEN\s+'مصروف: '\s+ELSE\s+'دخل: '\s+END\)$p$;
  v_hits := regexp_count(v_def, v_pat);
  if v_hits <> 1 then
    raise exception 'withdrawal label: % matches, expected 1', v_hits;
  end if;
  execute regexp_replace(v_def, v_pat, replace(replace(v_new, '\', '\\'), '&', '\&'));
end
$migrate$;
