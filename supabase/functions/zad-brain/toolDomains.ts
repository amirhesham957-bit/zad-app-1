// م٤.٦ — جدول واحد: كل أداة في CHAT_TOOLS ليها مجال صاحبها. مابيغيّرش اللي الموديل بياخده (ده لسه
// SPECIALIST_TOOL_SCOPE وCROSS_DOMAIN_TOOLS وintentToolHints في specialists.ts)؛ التست في toolDomains_test.ts
// بيفشل لو أداة جديدة اتضافت من غير مجال، أو بقت من غير أي طريق توصل بيه للموديل.
export type ToolDomain = "finance" | "pantry" | "pharmacy" | "family" | "home" | "cross";

export const TOOL_DOMAIN: Record<string, ToolDomain> = {
  // الفلوس
  log_transaction: "finance", allocate_income: "finance", update_transaction: "finance", delete_transaction: "finance",
  set_monthly_limit: "finance", set_category_budget: "finance", add_debt: "finance", update_debt: "finance", delete_debt: "finance",
  add_obligation: "finance", update_obligation: "finance", delete_obligation: "finance",
  add_subscription: "finance", update_subscription: "finance", delete_subscription: "finance", mark_subscription_paid: "finance",
  forward_ledger: "finance", check_price_online: "finance", weekly_savings_plan: "finance",
  home_health_score: "finance", propose_next_month_budget: "finance", decision_impact: "finance", log_decision: "finance",
  household_resilience: "finance", confirm_life_shift: "finance", safe_daily_spend: "finance",
  start_savings_challenge: "finance", stop_savings_challenge: "finance", set_broke_mode: "finance",
  set_life_goal: "finance", add_goal_progress: "finance", gold_price: "finance", fetch_current_exchange_rate: "finance",
  // المخزن والتسوق والأكل
  add_inventory_item: "pantry", update_inventory_qty: "pantry", consume_item: "pantry", delete_inventory_item: "pantry",
  add_shopping_item: "pantry", complete_shopping_item: "pantry", delete_shopping_item: "pantry", add_shortages_to_shopping: "pantry",
  suggest_product: "pantry", find_nearby_stores: "pantry", where_to_buy: "pantry", suggest_recipes: "pantry", rate_recipe: "pantry",
  area_trends: "pantry", plan_gathering: "pantry", add_gathering_to_list: "pantry", plan_gathering_time: "pantry",
  answer_same_product: "pantry", restock_on_budget: "pantry", plan_menu: "pantry", set_item_preference: "pantry",
  find_deals: "pantry", get_nearby_deals: "pantry", check_price_trend: "pantry", report_price: "pantry",
  store_location: "pantry", clear_place_visits: "pantry",
  // الصيدلية
  add_pharmacy_item: "pharmacy", update_pharmacy_item: "pharmacy", delete_pharmacy_item: "pharmacy", log_pharmacy_dose: "pharmacy",
  snooze_pharmacy_dose: "pharmacy", medicine_price: "pharmacy", check_medicine_reorder: "pharmacy", emergency_card: "pharmacy",
  // العيلة
  schedule_task: "family", query_family: "family", family_digest: "family", family_mediation: "family", start_family_poll: "family",
  handover_card: "family", set_life_circumstance: "family", end_life_circumstance: "family", share_memory_with_family: "family",
  // البيت (صيانة، مستندات، إعدادات)
  add_maintenance_item: "home", update_maintenance_item: "home", delete_maintenance_item: "home",
  save_document: "home", delete_document: "home", save_trusted_technician: "home", set_sleep_window: "home",
  set_app_setting: "home", weather_forecast: "home", restore_deleted: "home", open_support_ticket: "home",
  // عابرة للمجالات (متاحة مع أي وكيل أو بالنية)
  remember: "cross", remember_occasion: "cross", delete_memory: "cross", learn_skill: "cross", web_search: "cross",
  set_market: "cross", set_transaction_category: "cross", update_emergency_fund_balance: "cross", app_command: "cross",
  update_customer_profile: "cross", read_house: "cross", dismiss_insight: "cross",
  add_appointment: "cross", update_appointment: "cross", delete_appointment: "cross", find_appointments: "cross",
  add_place_reminder: "cross", cancel_place_reminder: "cross",
};

/**
 * أدوات موجودة في CHAT_TOOLS ومافيش مسار بيعرضها على موديل الدردشة (مش في نطاق وكيل، ولا عابرة، ولا بنية رسالة،
 * ولا بحقن من index.ts). قياس ٢٢/١١: check_price_trend وget_nearby_deals اتبدّلوا بـwhere_to_buy (whereToBuy.ts)
 * وفضلوا معرّفين وبينفّذوا لو اتنادوا. ممنوع تزود هنا من غير قرار: الأداة الجديدة لازم يبقى ليها مسار.
 */
export const UNREACHABLE_TOOLS: readonly string[] = ["check_price_trend", "get_nearby_deals"];

/** أدوات بتتحقن من index.ts بحالة اللفة (مش بنية الرسالة)، مثلاً سؤال الصبح عن هدية. */
export const TURN_INJECTED_TOOLS: readonly string[] = ["set_life_goal"];
