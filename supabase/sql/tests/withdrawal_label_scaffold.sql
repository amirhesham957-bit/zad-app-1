-- The trigger function's head as it is live (2026-11-02), enough for the label migration to edit.
create or replace function public.notify_telegram_on_transaction() returns trigger language plpgsql as $$
declare push_body text;
begin
  IF NEW.amount != 0 THEN
        push_body := (CASE WHEN NEW.is_expense THEN 'مصروف: ' ELSE 'دخل: ' END)
            || NEW.title || ' — ' || NEW.amount::TEXT;
  END IF;
  return NEW;
end $$;
