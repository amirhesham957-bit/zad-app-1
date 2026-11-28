// P1.6a: ساندوتش الزرار. لكل معرّف في button_manifest.json: الزرار (نية من غير لفة، source=manual، مع trace_id) ⇐ zad_commit_intent
// ⇐ صف zad_events (النوع والمصدر والـtrace_id) ⇐ البوت (أداة شات حقيقية بتلاقي صف الزرار وتكتب حدث تاني).
// بيتشغّل من run_commit_intent_e2e.sh بعد commit_intent_e2e.ts، على نفس الداتابيز، بمستخدم تاني. الإشعار لسه مش مختبر (الـmanifest بيقول).
import { createClient } from "jsr:@supabase/supabase-js@2";
import { runTool } from "../../functions/zad-brain/index.ts";
import { freshContext } from "../../functions/zad-brain/validators.ts";

const sb = createClient(Deno.env.get("E2E_URL")!, Deno.env.get("E2E_KEY")!, {
  auth: { persistSession: false },
  global: { fetch: (u: RequestInfo | URL, i?: RequestInit) => fetch(String(u).replace("/rest/v1", ""), i) },
});
const BOB = "22222222-2222-2222-2222-222222222222";
const manifest = JSON.parse(await Deno.readTextFile(new URL("./button_manifest.json", import.meta.url))) as {
  actions: { id: string; status: string; intent_kind: string | null }[];
};
let failed = 0;
const check = (ok: boolean, what: string, extra: unknown = "") => {
  console.log(`${ok ? "PASS" : "FAIL"}  button: ${what}`, extra === "" ? "" : JSON.stringify(extra));
  if (!ok) failed++;
};
const bot = (tool: string, input: Record<string, unknown>, snap: Record<string, unknown> = { stock: [] }) =>
  runTool(sb, BOB, tool, input, snap, freshContext(BOB), { source: "app_chat", runId: crypto.randomUUID() });
const events = async (kind: string) =>
  (await sb.from("zad_events").select("id,kind,source,trace_id,client_event_id").eq("user_id", BOB).eq("kind", kind).order("recorded_at")).data ?? [];

/** الزرار: نية واحدة، وبعدها ضغطة تانية بنفس المفتاح (دبل تاب) ما تكتبش حاجة. */
async function press(id: string, kind: string, payload: Record<string, unknown>) {
  const trace = `e2e-trace-${id}`.slice(0, 40);
  const intent = { user_id: BOB, kind, client_event_id: `btn-${id}`, source: "manual", payload, trace_id: trace };
  const before = (await events(kind)).length;
  const { data, error } = await sb.rpc("zad_commit_intent", { p_intent: intent });
  check(!error && data?.ok === true && data?.duplicate !== true, `${id}: door accepted`, error ?? data);
  const ev = await events(kind);
  const last = ev[ev.length - 1];
  check(ev.length === before + 1 && last?.source === "manual" && last?.trace_id === trace, `${id}: zad_events row ${kind}, source manual, trace_id kept`, last);
  const again = await sb.rpc("zad_commit_intent", { p_intent: intent });
  check(again.data?.duplicate === true && (await events(kind)).length === before + 1, `${id}: double tap writes nothing`, again.data);
  return { rowId: String(data?.row_id ?? ""), data };
}

const today = new Date().toISOString().slice(0, 10);
const snapM = { stock: [], now_local: { date: today, utc_offset: "+00:00" } };
const stockOf = async (name: string) =>
  (await sb.from("zad_inventory").select("id,quantity").eq("user_id", BOB).eq("item_name", name)).data ?? [];

// كل دالة هنا = جسم زرار واحد. مفتاحها معرّف الـmanifest بالظبط (الحارس بيتأكد).
const covered: Record<string, () => Promise<void>> = {
  "add_expense": async () => {
    const r = await press("add_expense", "money.logged", { amount: 40, title: "فطار زرار", txn_kind: "expense", wallet: "cash", category: "مطاعم", source_type: "manual" });
    const out = await bot("delete_transaction", { transaction_id: r.rowId }, { ...snapM, recent_transaction_ids: [r.rowId] });
    check(out.includes("اتحذفت") && (await events("money.deleted")).length >= 1, "add_expense: bot deletes the button's row", out);
  },
  "add_income": async () => {
    const r = await press("add_income", "money.logged", { amount: 5000, title: "مرتب زرار", txn_kind: "income", wallet: "card", source_type: "manual" });
    const out = await bot("delete_transaction", { transaction_id: r.rowId }, { ...snapM, recent_transaction_ids: [r.rowId] });
    check(out.includes("اتحذفت"), "add_income: bot deletes the button's income row", out);
  },
  "pay_debt": async () => {
    const d = await sb.from("zad_debts").insert({ user_id: BOB, name: "دين زرار", principal_amount: 1000, remaining_balance: 1000, minimum_payment: 50, is_active: true }).select("id").single();
    await press("pay_debt", "debt.updated", { item_id: d.data?.id, patch: { remaining_balance: 400 } });
    const out = await bot("update_debt", { name: "دين زرار", new_remaining_balance: 0 }, snapM);
    check(out.includes("خلص وقُفل") && (await events("debt.updated")).length === 2, "pay_debt: bot sees the debt and closes it", out);
  },
  "restock": async () => {
    await press("restock", "shopping.added", { item_name: "رز زرار", quantity: 2 });
    const out = await bot("delete_shopping_item", { item_name: "رز زرار" });
    check(out.includes("اتحذف") && (await events("shopping.deleted")).length >= 1, "restock: bot removes the button's line", out);
  },
  "use_expiring": async () => {
    await sb.from("zad_inventory").insert({ user_id: BOB, item_name: "جبنة زرار", quantity: 4, unit: "قطعة", category: "الألبان" });
    const row = (await stockOf("جبنة زرار"))[0];
    await press("use_expiring", "inventory.consumed", { item_id: row.id, amount: 1 });
    check(Number((await stockOf("جبنة زرار"))[0].quantity) === 3, "use_expiring: 4 -> 3");
    const out = await bot("update_inventory_qty", { item_name: "جبنة زرار", new_qty: 2, reason: "العميل قال فاضل ٢" }, { stock: [{ name: "جبنة زرار", qty: 3 }] });
    check(out.includes("اتعدلت الكمية") && Number((await stockOf("جبنة زرار"))[0].quantity) === 2, "use_expiring: bot reads 3 and sets 2", out);
  },
  "add_item": async () => {
    await press("add_item", "inventory.added", { item_name: "عدس زرار", quantity: 3, unit: "كيس", category: "البقالة" });
    check(Number((await stockOf("عدس زرار"))[0]?.quantity) === 3, "add_item: row with 3");
    const out = await bot("consume_item", { item_name: "عدس زرار", amount: 1, unit: "كيس" });
    check(!out.startsWith("مرفوض") && Number((await stockOf("عدس زرار"))[0]?.quantity) === 2, "add_item: bot consumes 1 of the button's row", out);
  },
  "add_pantry_item": async () => {
    await press("add_pantry_item", "inventory.added", { item_name: "سكر زرار", quantity: 5, unit: "كيلو", category: "البقالة" });
    const out = await bot("consume_item", { item_name: "سكر زرار", amount: 2, unit: "كيلو" });
    check(!out.startsWith("مرفوض") && Number((await stockOf("سكر زرار"))[0]?.quantity) === 3, "add_pantry_item: bot consumes 2 of 5", out);
  },
  "consume_pantry_item": async () => {
    await sb.from("zad_inventory").insert({ user_id: BOB, item_name: "ملح زرار", quantity: 6, unit: "كيس", category: "البقالة" });
    const row = (await stockOf("ملح زرار"))[0];
    await press("consume_pantry_item", "inventory.consumed", { item_id: row.id, amount: 2 });
    check(Number((await stockOf("ملح زرار"))[0].quantity) === 4, "consume_pantry_item: 6 -> 4");
    const out = await bot("update_inventory_qty", { item_name: "ملح زرار", new_qty: 3, reason: "العميل قال فاضل ٣" }, { stock: [{ name: "ملح زرار", qty: 4 }] });
    check(out.includes("اتعدلت الكمية"), "consume_pantry_item: bot reads 4 and sets 3", out);
  },
  "add_goal": async () => {
    await press("add_goal", "goal.set", { title: "هدف زرار", target_value: 3000, unit: "money", deadline_date: "2027-06-01" });
    const out = await bot("add_goal_progress", { goal_title: "هدف زرار", amount: 100 }, { ...snapM, life_goals: [{ title: "هدف زرار", kind: "amount" }] });
    check(out.includes("100") && (await events("goal.progress")).length >= 1, "add_goal: bot adds progress to the button's goal", out);
  },
  "add_pharmacy_item": async () => {
    await press("add_pharmacy_item", "pharmacy.added", { name: "دوا زرار", dose_times: "08:00", daily_dose_count: 1, remaining_quantity: 10, unit: "قرص", category: "عام" });
    const out = await bot("log_pharmacy_dose", { name: "دوا زرار" });
    check(out.includes("اتسجلت") && (await events("pharmacy.dose_taken")).length >= 1, "add_pharmacy_item: bot logs a dose on the button's medicine", out);
  },
  "log_dose": async () => {
    const m = await sb.from("zad_pharmacy_items").insert({ user_id: BOB, name: "دوا ٢ زرار", dose_times: "08:00,20:00", daily_dose_count: 2, remaining_quantity: 20 }).select("id").single();
    await press("log_dose", "pharmacy.dose_taken", { item_id: m.data?.id, taken_at: new Date().toISOString() });
    const left = (await sb.from("zad_pharmacy_items").select("remaining_quantity").eq("id", m.data?.id).single()).data?.remaining_quantity;
    check(Number(left) === 19, "log_dose: 20 -> 19", left);
    const out = await bot("log_pharmacy_dose", { name: "دوا ٢ زرار" });
    check(out.includes("متسجلة قبل كده"), "log_dose: bot sees the button's dose and refuses a repeat", out);
  },
  "set_budget_limit": async () => {
    await press("set_budget_limit", "money.limit_set", { amount: 7000 });
    const lim = (await sb.from("zad_users").select("monthly_limit,limit_confirmed_at").eq("id", BOB).single()).data;
    check(Number(lim?.monthly_limit) === 7000 && !!lim?.limit_confirmed_at, "set_budget_limit: zad_users.monthly_limit = 7000, confirmed", lim);
    const out = await bot("set_monthly_limit", { monthly_limit: 7000 }, snapM);
    check(!out.startsWith("مرفوض") && Number((await sb.from("zad_users").select("monthly_limit").eq("id", BOB).single()).data?.monthly_limit) === 7000, "set_budget_limit: bot re-sets the same value cleanly", out);
  },
};

for (const a of manifest.actions) {
  if (a.status === "covered") {
    const fn = covered[a.id];
    if (!fn) { check(false, `${a.id}: manifest says covered but button_e2e.ts has no body`); continue; }
    await fn();
  } else if (a.status === "read_only") {
    console.log(`READ  button: ${a.id}: read only, no door intent (nothing to write)`);
  } else {
    console.log(`SKIP  button: ${a.id}: ${a.status} (no door intent yet, see P1.6b)`);
  }
}
for (const id of Object.keys(covered)) {
  check(manifest.actions.some((a) => a.id === id && a.status === "covered"), `${id}: body has a covered manifest entry`);
}
console.log(failed === 0 ? "e2e: all checks passed" : `e2e: ${failed} FAILED`);
Deno.exit(failed === 0 ? 0 : 1);
