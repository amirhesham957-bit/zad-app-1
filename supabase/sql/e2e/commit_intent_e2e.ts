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

// ٨) مدخل غلط يقف عند المدقق قبل الباب (كمية بالسالب): مفيش كتابة، والرفض في ctx.rejections بس — مش في zad_guard_events.
const ctx8 = freshContext(AMIR);
const guards8 = await count("zad_guard_events", { user_id: AMIR });
const r8 = await runTool(sb, AMIR, "update_inventory_qty", { item_name: "لبن", new_qty: -1, reason: why }, snap, ctx8, run2);
check(r8.startsWith("مرفوض"), "validator refuse: reply", r8);
check(JSON.stringify(await qty("لبن")) === "[1]", "validator refuse: nothing written", await qty("لبن"));
console.log(`INFO  validator refusal reached zad_guard_events: ${(await count("zad_guard_events", { user_id: AMIR })) > guards8}`);

console.log(failed === 0 ? "e2e: all checks passed" : `e2e: ${failed} FAILED`);
Deno.exit(failed === 0 ? 0 : 1);
