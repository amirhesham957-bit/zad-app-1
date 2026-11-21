// م٢.٥ e2e: الطريق الحقيقي من غير الموديل — runTool (المدقق + الأداة) ⇐ supabase-js ⇐ PostgREST ⇐ zad_commit_intent.
// التشغيل: run_commit_intent_e2e.sh (Postgres + PostgREST محليين). مش الحي أبداً.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { runTool } from "../../functions/zad-brain/index.ts";
import { freshContext } from "../../functions/zad-brain/validators.ts";

// PostgREST لوحده بيخدم من الجذر، وsupabase-js بيكلم /rest/v1.
const sb = createClient(Deno.env.get("E2E_URL")!, Deno.env.get("E2E_KEY")!, {
  auth: { persistSession: false },
  global: { fetch: (u: RequestInfo | URL, i?: RequestInit) => fetch(String(u).replace("/rest/v1", ""), i) },
});
const AMIR = "11111111-1111-1111-1111-111111111111";
const run1 = { source: "app_chat", runId: crypto.randomUUID() } as const;
let failed = 0;
const check = (ok: boolean, what: string, extra: unknown = "") => {
  console.log(`${ok ? "PASS" : "FAIL"}  ${what}`, extra === "" ? "" : JSON.stringify(extra));
  if (!ok) failed++;
};
const qty = async (name: string) =>
  ((await sb.from("zad_inventory").select("quantity").eq("user_id", AMIR).eq("item_name", name)).data ?? []).map((r) => Number(r.quantity));
const count = async (table: string, filter: Record<string, string>) => {
  let q = sb.from(table).select("*", { count: "exact", head: true });
  for (const [k, v] of Object.entries(filter)) q = q.eq(k, v);
  return (await q).count ?? -1;
};

// ١) إضافة: «اشتريت ٣ علب لبن».
const add = { item_name: "لبن", quantity: 3, unit: "علبة", category: "الألبان", expiry_date: "2027-01-01" };
const r1 = await runTool(sb, AMIR, "add_inventory_item", add, { stock: [] }, freshContext(AMIR), run1);
check(r1.includes("اتضاف"), "add: reply", r1);
check(JSON.stringify(await qty("لبن")) === "[3]", "add: one row, 3", await qty("لبن"));
check(await count("zad_events", { user_id: AMIR, kind: "inventory.added" }) === 1, "add: one event in zad_events");
check(await count("agent_actions", { user_id: AMIR, tool_name: "add_inventory_item" }) === 1, "add: undo log row");

// ٢) نفس الطلب تاني في نفس اللفة (الموديل كرر النداء): مفيش كتابة تانية.
const r2 = await runTool(sb, AMIR, "add_inventory_item", { ...add }, { stock: [] }, freshContext(AMIR), run1);
check(r2.includes("اتنفذ قبل كده"), "repeat: reply says already done", r2);
check(JSON.stringify(await qty("لبن")) === "[3]", "repeat: still one row, 3", await qty("لبن"));
check(await count("zad_events", { user_id: AMIR, kind: "inventory.added" }) === 1, "repeat: still one event");
check(await count("agent_actions", { user_id: AMIR, tool_name: "add_inventory_item" }) === 1, "repeat: no second undo row");

// ٣) لفة تانية: «اشتريت ٢ لبن كمان» = تزويد على نفس الصف.
const run2 = { source: "app_chat", runId: crypto.randomUUID() } as const;
const r3 = await runTool(sb, AMIR, "add_inventory_item", { item_name: "لبن", quantity: 2, unit: "علبة", category: "الألبان" }, { stock: [] }, freshContext(AMIR), run2);
check(r3.includes("بقى 5"), "top-up: reply", r3);
check(JSON.stringify(await qty("لبن")) === "[5]", "top-up: same row, 5", await qty("لبن"));

// ٤) استهلاك: «شربنا علبتين لبن».
const ctx4 = freshContext(AMIR);
ctx4.said = "شربنا علبتين لبن";
const r4 = await runTool(sb, AMIR, "consume_item", { item_name: "لبن", amount: 2, unit: "علبة" }, { stock: [] }, ctx4, run2);
check(!r4.startsWith("مرفوض"), "consume: reply", r4);
check(JSON.stringify(await qty("لبن")) === "[3]", "consume: 5 - 2 = 3", await qty("لبن"));
check(await count("zad_events", { user_id: AMIR, kind: "inventory.consumed" }) === 1, "consume: event");

// ٥) «فاضل كام»: «فاضل علبة واحدة».
const snap = { stock: [{ name: "لبن", qty: 3 }] };
const why = "العميل قال فاضل علبة واحدة";
const r5 = await runTool(sb, AMIR, "update_inventory_qty", { item_name: "لبن", new_qty: 1, reason: why }, snap, freshContext(AMIR), run2);
check(r5.includes("اتعدلت الكمية"), "set: reply", r5);
check(JSON.stringify(await qty("لبن")) === "[1]", "set: 1", await qty("لبن"));
check(await count("zad_events", { user_id: AMIR, kind: "inventory.quantity_set" }) === 1, "set: event");

// ٦) مدخل غلط يعدّي المدقق (لقطة قديمة فيها ٣٠) ويقف عند الباب (الصف الحقيقي فيه ١): «فاضل ٥٠٠ علبة».
const guardsBefore = await count("zad_guard_events", { user_id: AMIR });
const r6 = await runTool(sb, AMIR, "update_inventory_qty", { item_name: "لبن", new_qty: 500, reason: why }, { stock: [{ name: "لبن", qty: 30 }] }, freshContext(AMIR), run2);
check(r6.startsWith("مرفوض") && r6.includes("qty_too_large"), "refuse: model told why", r6);
check(JSON.stringify(await qty("لبن")) === "[1]", "refuse: nothing written", await qty("لبن"));
const { data: guard } = await sb.from("zad_guard_events").select("kind,reason,source,intent").eq("user_id", AMIR)
  .order("id", { ascending: false }).limit(1).single();
check(await count("zad_guard_events", { user_id: AMIR }) === guardsBefore + 1, "refuse: one row in zad_guard_events");
check(guard?.reason === "qty_too_large" && guard?.kind === "inventory.quantity_set" && guard?.source === "model", "refuse: guard row says what and why", guard);
check(await count("zad_events", { user_id: AMIR, kind: "inventory.quantity_set" }) === 1, "refuse: no event");

// ٧) تاريخ صلاحية فات: المدقق مابيعرفش، الباب بيرفض ويسجل.
const r7 = await runTool(sb, AMIR, "add_inventory_item", { item_name: "زبادي", quantity: 1, category: "الألبان", expiry_date: "2020-01-01" }, { stock: [] }, freshContext(AMIR), run2);
check(r7.startsWith("مرفوض") && r7.includes("expiry_before_purchase"), "refuse: expired add", r7);
check((await qty("زبادي")).length === 0, "refuse: no yoghurt row");
check(await count("zad_guard_events", { user_id: AMIR, reason: "expiry_before_purchase" }) === 1, "refuse: expiry guard row");

// ٨) مدخل غلط يقف عند المدقق قبل الباب (كمية بالسالب): مفيش كتابة، والرفض متسجل في zad_guard_events برضه.
const ctx8 = freshContext(AMIR);
const guards8 = await count("zad_guard_events", { user_id: AMIR });
const r8 = await runTool(sb, AMIR, "update_inventory_qty", { item_name: "لبن", new_qty: -1, reason: why }, snap, ctx8, run2);
check(r8.startsWith("مرفوض"), "validator refuse: reply", r8);
check(JSON.stringify(await qty("لبن")) === "[1]", "validator refuse: nothing written", await qty("لبن"));
check(await count("zad_guard_events", { user_id: AMIR }) === guards8 + 1, "validator refuse: one guard row");
const { data: g8 } = await sb.from("zad_guard_events").select("kind,source").eq("user_id", AMIR).order("id", { ascending: false }).limit(1).single();
check(g8?.kind === "validator:update_inventory_qty" && g8?.source === "model", "validator refuse: guard row names the validator", g8);

// ٩) «اللبن ده على فترات» ثم «امسح اللبن»: الاتنين من الباب، والتكرار مابيعملش حاجة.
const r9 = await runTool(sb, AMIR, "update_inventory_qty", { item_name: "لبن", restock_mode: "occasional" }, snap, freshContext(AMIR), run2);
check(r9.includes("كل فترة"), "mode: reply", r9);
check((await sb.from("zad_inventory").select("restock_mode").eq("user_id", AMIR).eq("item_name", "لبن").single()).data?.restock_mode === "occasional", "mode: row marked");
check(await count("zad_events", { user_id: AMIR, kind: "inventory.restock_mode_set" }) === 1, "mode: event");
const r10 = await runTool(sb, AMIR, "delete_inventory_item", { item_name: "لبن" }, snap, freshContext(AMIR), run2);
check(r10.includes("اتحذف"), "delete: reply", r10);
check((await qty("لبن")).length === 0, "delete: row gone");
check(await count("zad_events", { user_id: AMIR, kind: "inventory.deleted" }) === 1, "delete: event with the row");
check(await count("agent_actions", { user_id: AMIR, tool_name: "delete_inventory_item" }) === 1, "delete: undo log row");
const r11 = await runTool(sb, AMIR, "delete_inventory_item", { item_name: "لبن" }, snap, freshContext(AMIR), run2);
check(r11.startsWith("مرفوض"), "delete again: nothing left to delete", r11);
check(await count("zad_events", { user_id: AMIR, kind: "inventory.deleted" }) === 1, "delete again: no second event");

// ١٠) القايمة: «ضيف ٢ عيش» مرتين في نفس اللفة، ثم «اشتريت عيش» (بيشطبه)، ثم «ضيف زيت» و«شيل الزيت».
const lines = async (name: string) =>
  ((await sb.from("zad_shopping_list").select("quantity,is_purchased").eq("user_id", AMIR).eq("item_name", name)).data ?? []);
const s1 = await runTool(sb, AMIR, "add_shopping_item", { item_name: "عيش", quantity: 2 }, { stock: [] }, freshContext(AMIR), run2);
check(s1.includes("اتضافت"), "list add: reply", s1);
const s2 = await runTool(sb, AMIR, "add_shopping_item", { item_name: "عيش", quantity: 2 }, { stock: [] }, freshContext(AMIR), run2);
check(s2.includes("اتنفذ قبل كده"), "list add again in the turn: duplicate", s2);
check(JSON.stringify(await lines("عيش")) === JSON.stringify([{ quantity: 2, is_purchased: false }]), "list: one line of 2", await lines("عيش"));
const run3 = { source: "app_chat", runId: crypto.randomUUID() } as const;
const s3 = await runTool(sb, AMIR, "add_inventory_item", { item_name: "عيش", quantity: 10, unit: "رغيف", category: "البقالة" }, { stock: [] }, freshContext(AMIR), run3);
check(s3.includes("اتشطب"), "bought: the list line is ticked", s3);
check((await lines("عيش"))[0]?.is_purchased === true, "bought: line marked purchased");
check(await count("zad_events", { user_id: AMIR, kind: "shopping.completed" }) === 1, "bought: tick event");
await runTool(sb, AMIR, "add_shopping_item", { item_name: "زيت", quantity: 1 }, { stock: [] }, freshContext(AMIR), run3);
const s4 = await runTool(sb, AMIR, "delete_shopping_item", { item_name: "زيت" }, { stock: [] }, freshContext(AMIR), run3);
check(s4.includes("اتحذف"), "list delete: reply", s4);
check((await lines("زيت")).length === 0, "list delete: line gone");
check(await count("zad_events", { user_id: AMIR, kind: "shopping.deleted" }) === 1, "list delete: event");
const g0 = await count("zad_guard_events", { user_id: AMIR });
const s5 = await runTool(sb, AMIR, "add_shopping_item", { item_name: "بيض", quantity: 500 }, { stock: [] }, freshContext(AMIR), run3);
check(s5.startsWith("مرفوض") && (await lines("بيض")).length === 0, "list refuse: 500 eggs not written", s5);
check(await count("zad_guard_events", { user_id: AMIR }) === g0 + 1, "list refuse: logged in zad_guard_events");

// ١١) الصيدلية: «سجل كونكور ٨ الصبح و٨ بالليل، معايا ٣٠» مرتين، «غيّر المواعيد»، «خدت الكونكور» مرتين، «امسحه».
const med = async () => (await sb.from("zad_pharmacy_items").select("dose_times,daily_dose_count,remaining_quantity").eq("user_id", AMIR).eq("name", "كونكور")).data ?? [];
const run4 = { source: "app_chat", runId: crypto.randomUUID() } as const;
const addMed = { name: "كونكور", dose_times: "08:00,20:00", quantity: 30, unit: "قرص", times_explicit: true };
const p1 = await runTool(sb, AMIR, "add_pharmacy_item", addMed, { stock: [] }, freshContext(AMIR), run4);
check(p1.includes("اتسجل"), "med add: reply", p1);
const p2 = await runTool(sb, AMIR, "add_pharmacy_item", { ...addMed }, { stock: [] }, freshContext(AMIR), run4);
check(p2.includes("اتنفذ قبل كده"), "med add again in the turn: duplicate", p2);
check(JSON.stringify(await med()) === JSON.stringify([{ dose_times: "08:00,20:00", daily_dose_count: 2, remaining_quantity: 30 }]), "med: one row, 2 doses, 30", await med());
const run5 = { source: "app_chat", runId: crypto.randomUUID() } as const;
const p3 = await runTool(sb, AMIR, "update_pharmacy_item", { name: "كونكور", dose_times: "09:00", times_explicit: true }, { stock: [] }, freshContext(AMIR), run5);
check(p3.includes("اتعدلت"), "med update: reply", p3);
check((await med())[0]?.dose_times === "09:00" && (await med())[0]?.daily_dose_count === 1, "med update: times and count", await med());
const p4 = await runTool(sb, AMIR, "log_pharmacy_dose", { name: "كونكور" }, { stock: [] }, freshContext(AMIR), run5);
check(p4.includes("اتسجلت") && (await med())[0]?.remaining_quantity === 29, "dose: 30 -> 29", [p4, await med()]);
const p5 = await runTool(sb, AMIR, "log_pharmacy_dose", { name: "كونكور" }, { stock: [] }, freshContext(AMIR), { source: "app_chat", runId: crypto.randomUUID() });
check(p5.includes("متسجلة قبل كده") && (await med())[0]?.remaining_quantity === 29, "dose twice in the window: once", [p5, await med()]);
check(await count("zad_guard_events", { user_id: AMIR, reason: "dose_already_logged" }) === 1, "dose twice: refusal logged");
const p6 = await runTool(sb, AMIR, "delete_pharmacy_item", { name: "كونكور" }, { stock: [] }, freshContext(AMIR), run5);
check(p6.includes("اتحذف") && (await med()).length === 0, "med delete", p6);
check(await count("zad_events", { user_id: AMIR, kind: "pharmacy.deleted" }) === 1, "med delete: event");

// ١٢) الفلوس: «صرفت ٥٠ قهوة كاش» مرتين في نفس اللفة، ثم نفس المبلغ في لفة تانية (لازم يسأل)، ثم «أيوة دي تانية»،
// ثم تعديل وتصنيف وحذف، وتسوية الكاش، ووصف تخمين.
const txs = async (title: string) => ((await sb.from("zad_transactions").select("id,amount,category,wallet,is_expense,txn_kind").eq("user_id", AMIR).eq("title", title)).data ?? []);
const run6 = { source: "app_chat", runId: crypto.randomUUID() } as const;
const coffee = { amount: 50, title: "قهوة", txn_kind: "expense", wallet: "cash", category: "مطاعم" };
const snapM = { stock: [], now_local: { date: new Date().toISOString().slice(0, 10), utc_offset: "+00:00" } };
const t1 = await runTool(sb, AMIR, "log_transaction", coffee, snapM, freshContext(AMIR), run6);
check(t1.includes("اتسجلت المعاملة"), "money log: reply", t1);
const t2 = await runTool(sb, AMIR, "log_transaction", { ...coffee }, snapM, freshContext(AMIR), run6);
// نافذة الـ١٠ دقايق (قبل الباب، زي ما كانت) بتمسكه الأول وبتسأل؛ المهم إن مفيش صف تاني.
check(t2.startsWith("مرفوض") && (await txs("قهوة")).length === 1, "money log again in the turn: still one row", t2);
const run7 = { source: "app_chat", runId: crypto.randomUUID() } as const;
const t3 = await runTool(sb, AMIR, "log_transaction", { ...coffee, title: "قهوة تانية" }, snapM, freshContext(AMIR), run7);
check(t3.startsWith("مرفوض") && t3.includes("allow_duplicate"), "money: same amount within 10 min asks first", t3);
const t4 = await runTool(sb, AMIR, "log_transaction", { ...coffee, title: "قهوة تانية", allow_duplicate: true }, snapM, freshContext(AMIR), run7);
check(t4.includes("اتسجلت") && (await txs("قهوة تانية")).length === 1, "money: «it's another one» goes through", t4);
const row = (await txs("قهوة"))[0];
check(row?.is_expense === true && row?.wallet === "cash" && Number(row?.amount) === 50, "money: both columns and the wallet", row);
const idOf = String(row?.id);
const snapT = { ...snapM, recent_transaction_ids: [idOf], distinct_categories: ["مطاعم", "بقالة"] };
const t5 = await runTool(sb, AMIR, "update_transaction", { transaction_id: idOf, amount: 55 }, snapT, freshContext(AMIR), run7);
check(t5.includes("اتعدلت") && Number((await txs("قهوة"))[0]?.amount) === 55, "money update: 50 -> 55", t5);
const t6 = await runTool(sb, AMIR, "set_transaction_category", { transaction_id: idOf, category: "بقالة" }, snapT, freshContext(AMIR), run7);
check(t6.includes("اتصنفت") && (await txs("قهوة"))[0]?.category === "بقالة", "money category", t6);
const cashBefore = Number((await sb.rpc("zad_cash_balance", { p_user: AMIR })).data);
const t7 = await runTool(sb, AMIR, "reconcile_cash_balance", { reported_amount: cashBefore + 300 }, snapT, freshContext(AMIR), run7);
check(t7.includes("زيادة") && Number((await sb.rpc("zad_cash_balance", { p_user: AMIR })).data) === cashBefore + 300, "cash reconcile: +300", [t7, cashBefore]);
const t8 = await runTool(sb, AMIR, "delete_transaction", { transaction_id: idOf }, snapT, freshContext(AMIR), run7);
check(t8.includes("اتحذفت") && (await txs("قهوة")).length === 0, "money delete", t8);
check(await count("zad_events", { user_id: AMIR, kind: "money.deleted" }) === 1, "money delete: event");
const gM = await count("zad_guard_events", { user_id: AMIR });
const t9 = await runTool(sb, AMIR, "log_transaction", { amount: 100, title: "مصروف - مثلا صدقة؟", txn_kind: "expense" }, snapM, freshContext(AMIR), run7);
check(t9.startsWith("مرفوض") && (await txs("مصروف - مثلا صدقة؟")).length === 0, "money: guessed title refused", t9);
check(await count("zad_guard_events", { user_id: AMIR }) === gM + 1, "money: refusal logged");

// ١٣) الرصيد وسقف فئة.
const u1 = await runTool(sb, AMIR, "set_monthly_limit", { monthly_limit: 9000 }, snapM, freshContext(AMIR), run7);
const lim = (await sb.from("zad_users").select("monthly_limit,limit_confirmed_at").eq("id", AMIR).single()).data;
check(u1.includes("9000") && Number(lim?.monthly_limit) === 9000 && !!lim?.limit_confirmed_at, "balance set and confirmed", [u1, lim]);
const caps = async () => (await sb.from("zad_category_budgets").select("category,amount").eq("user_id", AMIR)).data ?? [];
const u2 = await runTool(sb, AMIR, "set_category_budget", { category: "مطاعم", amount: 1500 }, snapM, freshContext(AMIR), run7);
const u3 = await runTool(sb, AMIR, "set_category_budget", { category: "مطاعم", amount: 1200 }, snapM, freshContext(AMIR), { source: "app_chat", runId: crypto.randomUUID() });
check(u2.includes("1500") && u3.includes("1200") && JSON.stringify(await caps()) === JSON.stringify([{ category: "مطاعم", amount: 1200 }]), "cap set then changed, one row", await caps());
const u4 = await runTool(sb, AMIR, "set_category_budget", { category: "مطاعم", amount: 0 }, snapM, freshContext(AMIR), run7);
check(u4.includes("اتشال") && (await caps()).length === 0, "cap removed", u4);
check(await count("zad_events", { user_id: AMIR, kind: "money.category_budget_set" }) === 3, "cap events");

console.log(failed === 0 ? "e2e: all checks passed" : `e2e: ${failed} FAILED`);
Deno.exit(failed === 0 ? 0 : 1);
