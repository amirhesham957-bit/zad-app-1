-- «لسه عندك؟» مابيتسألش على حاجة كميتها صفر (2026-11-01).
--
-- The owner: «بيسألني على حاجات خلصانة من شهرين». Measured that day over their last 21 days of
-- telegram_checkin_prompts: «مياه نستله بيور لايف» asked 3 times at quantity 0, «كرتونة ماية» 3
-- times at 0, «ماء بوفانا», «إزازة ماء», «عبوة مياه», «مياه إيلانو» twice each at 0 — none
-- answered. A zero is already known to be gone; it belongs on the shopping list, and asking again
-- is the nag. `_inventory_needs_checkin` (the live trigger, 20260813214630) and the bot's daily
-- `needsCheckIn` (`_shared/consumptionRate.ts`, same commit) now both say no at zero or below.

create or replace function public._inventory_needs_checkin(
  p_quantity numeric, p_threshold numeric, p_avg_daily_qty numeric, p_rate_known boolean)
 returns boolean
 language sql
 immutable
 set search_path = public
as $function$
    select p_quantity > 0
       and (p_quantity <= coalesce(p_threshold, 2)
            or (coalesce(p_avg_daily_qty, 0) > 0 and p_quantity / p_avg_daily_qty <= 2));
$function$;
