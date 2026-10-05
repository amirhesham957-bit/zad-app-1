-- A card about a day stops showing after that day.
--
-- Measured 2026-10-05: a home card «تجديد نتفليكس بكرة» whose body said
-- «هيتجدد بكرة 3 أكتوبر» was written 2026-10-02 and was still `pending` on the
-- customer's home on 2026-10-05. zad_insights rows had no end at all: a card
-- stayed until the customer dismissed it, whatever date it was about.
--
-- emit_insight now sets expires_at — the end of the day the card is about
-- (`valid_until`), or 48 hours for an alert that named no day. Readers (the
-- app, the Telegram bot, the open-card budget) skip rows past it. Insights and
-- questions with no day stay open-ended, as before.

alter table public.zad_insights
  add column if not exists expires_at timestamptz;

comment on column public.zad_insights.expires_at is
  'After this instant the card is no longer shown. Null = open-ended.';

-- The alerts already waiting get the same 48 hours from when they were written,
-- which retires the stale renewal cards on the next read.
update public.zad_insights
   set expires_at = created_at + interval '48 hours'
 where kind = 'alert'
   and status = 'pending'
   and expires_at is null;
