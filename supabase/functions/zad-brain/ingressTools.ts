/**
 * Deterministic ingress for trusted channel parsers (Telegram voice/receipt and
 * Android notification listeners).  It deliberately accepts only non-financial
 * household tools: money continues to require agent_confirm, so an OCR or speech
 * mistake can never create a financial entry without the user's confirmation.
 */
export const DIRECT_INGRESS_TOOLS = new Set([
  "add_inventory_item", "update_inventory_qty", "delete_inventory_item",
  "add_pharmacy_item", "update_pharmacy_item", "delete_pharmacy_item",
  "add_shopping_item", "complete_shopping_item", "delete_shopping_item",
  "answer_dose_reminder", "mute_checkin",
]);
// زرار في تليجرام مستني رد (ZAD_PLAN ٣.٤): الأدوات دي بتقرا اللي محتاجاه بنفسها، فمالهاش لقطة البيت كلها.
export const NO_SNAPSHOT_INGRESS_TOOLS = new Set(["answer_dose_reminder", "mute_checkin"]);
