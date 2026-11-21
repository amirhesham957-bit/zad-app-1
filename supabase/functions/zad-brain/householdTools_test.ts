// The brain's pantry and list tools act on the household (owner, 2026-10-11): dad's
// «اشتريت لبن» tops up the milk mom added, his «اشتريت الجبنة» ticks her line, and his
// «ضيف لبن» adds to her open line instead of a second one. Before, each of these looked at
// dad's own rows only — a duplicate row, «مش موجود», or an update that matched nothing and
// still said «الكمية بقت…».
import { assert, assertEquals } from "jsr:@std/assert@1";
import { executeTool, runTool } from "./index.ts";
import { isDoorRefusal, refusalText } from "./commitIntent.ts";
import { freshContext } from "./validators.ts";

type Row = Record<string, unknown>;

/** A tiny PostgREST: eq / or (user_id, family_id) filters, select, update, insert. */
function fakeDb(tables: Record<string, Row[]>, names: Record<string, string> = {}) {
  const rpcs: Array<{ fn: string; args: Row }> = [];
  const writes: Array<{ table: string; op: string; id?: unknown; row: Row }> = [];
  let next = 1;
  const from = (table: string) => {
    const rows = (tables[table] ??= []);
    const filters: Array<(r: Row) => boolean> = [];
    let op: "select" | "update" | "insert" | "delete" = "select";
    let patch: Row = {};
    let inserted: Row[] = [];
    let single = false;
    const matching = () => rows.filter((r) => filters.every((f) => f(r)));
    const b: any = {
      select: () => b,
      limit: () => b,
      order: () => b,
      eq: (col: string, v: unknown) => (filters.push((r) => r[col] === v), b),
      neq: (col: string, v: unknown) => (filters.push((r) => r[col] !== v), b),
      is: (col: string, v: unknown) => (filters.push((r) => (r[col] ?? null) === v), b),
      or: (expr: string) => {
        const alts = expr.split(",").map((part) => {
          const [col, , val] = part.split(".");
          return (r: Row) => String(r[col]) === val;
        });
        filters.push((r) => alts.some((a) => a(r)));
        return b;
      },
      update: (p: Row) => ((op = "update"), (patch = p), b),
      delete: () => ((op = "delete"), b),
      insert: (r: Row | Row[]) => {
        op = "insert";
        inserted = (Array.isArray(r) ? r : [r]).map((x) => ({ id: `new${next++}`, ...x }));
        return b;
      },
      maybeSingle: () => ((single = true), b),
      single: () => ((single = true), b),
      then: (resolve: (v: unknown) => unknown) => {
        let data: Row[];
        if (op === "insert") {
          rows.push(...inserted);
          inserted.forEach((r) => writes.push({ table, op, row: r }));
          data = inserted;
        } else if (op === "update") {
          data = matching();
          data.forEach((r) => { Object.assign(r, patch); writes.push({ table, op, id: r.id, row: patch }); });
        } else if (op === "delete") {
          data = matching();
          data.forEach((r) => { rows.splice(rows.indexOf(r), 1); writes.push({ table, op, id: r.id, row: {} }); });
        } else {
          data = matching();
        }
        return Promise.resolve({ data: single ? data[0] ?? null : data, error: null }).then(resolve);
      },
    };
    return b;
  };
  // The one door (zad_commit_intent, M2.5): same writes as the SQL, same idempotency, refusals by reason.
  // It writes straight into the rows (not through from()), so `writes` shows the door's work as op "door:*".
  const seen = new Map<string, Row>();
  const door = (intent: Row): Row => {
    const key = `${intent.user_id}|${intent.client_event_id}`;
    const prior = seen.get(key);
    if (prior) return { ...prior, duplicate: true };
    if (doorRefuses) return { ok: false, reason: doorRefuses };
    const p = intent.payload as Row;
    const inv = (tables.zad_inventory ??= []);
    const row = p.item_id ? inv.find((r) => r.id === p.item_id) : undefined;
    if (p.item_id && !row) return { ok: false, reason: "item_not_found" };
    let out: Row;
    if (intent.kind === "inventory.added" && !row) {
      const fresh = { id: `new${next++}`, user_id: intent.user_id, item_name: p.item_name, quantity: p.quantity, unit: p.unit ?? "حبة", category: p.category, expiry_date: p.expiry_date ?? null };
      inv.push(fresh);
      writes.push({ table: "zad_inventory", op: "door:insert", id: fresh.id, row: fresh });
      out = { ok: true, duplicate: false, row_id: fresh.id, after: p.quantity };
    } else {
      const before = Number(row!.quantity ?? 0);
      const after = intent.kind === "inventory.added" ? Math.max(before, 0) + Number(p.quantity)
        : intent.kind === "inventory.consumed" ? Math.max(before - Number(p.amount), 0) : Number(p.quantity);
      row!.quantity = after;
      if (p.opened === true) row!.opened_at ??= new Date().toISOString();
      writes.push({ table: "zad_inventory", op: "door:update", id: row!.id, row: { quantity: after } });
      out = { ok: true, duplicate: false, row_id: row!.id, before, after };
    }
    seen.set(key, out);
    return out;
  };
  let doorRefuses: string | null = null;
  const rpc = (fn: string, args: Row) => {
    rpcs.push({ fn, args });
    if (fn === "zad_commit_intent") return Promise.resolve({ data: door(args.p_intent as Row), error: null });
    // zad_product_canonical: the household's chosen name, or the name as given.
    if (fn === "zad_product_canonical") {
      return Promise.resolve({ data: names[String(args.p_name)] ?? args.p_name, error: null });
    }
    return Promise.resolve({ data: { samples: 1, rate_known: false }, error: null });
  };
  return { sb: { from, rpc } as any, writes, rpcs, tables, refuse: (reason: string | null) => { doorRefuses = reason; } };
}

const FAMILY = [
  { user_id: "mom", family_id: "f1" },
  { user_id: "dad", family_id: "f1" },
];

Deno.test("dad's «اشتريت لبن» tops up the household's milk, and the rate is learnt for its owner", async () => {
  const { sb, writes, rpcs, tables } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [{ id: "milk", user_id: "mom", family_id: "f1", item_name: "لبن", quantity: 1, unit: "علبة", created_at: "2026-10-10" }],
  });
  const out = await executeTool(sb, "dad", "add_inventory_item", { item_name: "لبن", quantity: 2 }, {}, freshContext("dad"), {} as any);
  assert(!out.startsWith("مرفوض"), out);
  assertEquals(tables.zad_inventory.length, 1, "a second milk row was added");
  assertEquals(tables.zad_inventory[0].quantity, 3);
  assertEquals(writes.filter((w) => w.table === "zad_inventory").map((w) => w.op), ["door:update"]);
  assertEquals(rpcs.find((r) => r.fn === "zad_record_observation")?.args.p_user, "mom");
});

Deno.test("dad's own row comes first when both parents have the item", async () => {
  const { sb, tables } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [
      { id: "m", user_id: "mom", family_id: "f1", item_name: "رز", quantity: 1, unit: null, created_at: "2026-10-10" },
      { id: "d", user_id: "dad", family_id: "f1", item_name: "رز", quantity: 1, unit: null, created_at: "2026-10-01" },
    ],
  });
  await executeTool(sb, "dad", "add_inventory_item", { item_name: "رز", quantity: 1 }, {}, freshContext("dad"), {} as any);
  assertEquals(tables.zad_inventory.find((r) => r.id === "d")?.quantity, 2);
  assertEquals(tables.zad_inventory.find((r) => r.id === "m")?.quantity, 1);
});

Deno.test("dad ticks the line mom added", async () => {
  const { sb, tables } = fakeDb({
    family_members: FAMILY,
    zad_shopping_list: [{ id: "cheese", user_id: "mom", family_id: "f1", item_name: "جبنة", is_purchased: false, created_at: "2026-10-10" }],
  });
  const out = await executeTool(sb, "dad", "complete_shopping_item", { item_name: "جبنة" }, {}, freshContext("dad"), {} as any);
  assert(!out.startsWith("مرفوض"), out);
  assertEquals(tables.zad_shopping_list[0].is_purchased, true);
});

Deno.test("dad's «ضيف لبن» adds to mom's open line, not a second one", async () => {
  const { sb, tables } = fakeDb({
    family_members: FAMILY,
    zad_shopping_list: [{ id: "l1", user_id: "mom", family_id: "f1", item_name: "لبن", quantity: 1, is_purchased: false }],
  });
  const out = await executeTool(sb, "dad", "add_shopping_item", { item_name: "لبن", quantity: 1 }, {}, freshContext("dad"), {} as any);
  assert(out.includes("الكمية بقت 2"), out);
  assertEquals(tables.zad_shopping_list.length, 1);
  assertEquals(tables.zad_shopping_list[0].quantity, 2);
});

Deno.test("someone outside the family never touches its rows", async () => {
  const { sb, tables } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [{ id: "milk", user_id: "mom", family_id: "f1", item_name: "لبن", quantity: 1, unit: null }],
    zad_shopping_list: [{ id: "cheese", user_id: "mom", family_id: "f1", item_name: "جبنة", is_purchased: false }],
  });
  await executeTool(sb, "neighbour", "add_inventory_item", { item_name: "لبن", quantity: 1 }, {}, freshContext("neighbour"), {} as any);
  assertEquals(tables.zad_inventory.find((r) => r.id === "milk")?.quantity, 1);
  assertEquals(tables.zad_inventory.length, 2, "the neighbour's milk is its own row");
  const out = await executeTool(sb, "neighbour", "complete_shopping_item", { item_name: "جبنة" }, {}, freshContext("neighbour"), {} as any);
  assert(out.startsWith("مرفوض"), out);
  assertEquals(tables.zad_shopping_list[0].is_purchased, false);
});

Deno.test("a purchase ticks the household's open line for it, once, and says so", async () => {
  const { sb, tables, writes } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [],
    zad_shopping_list: [
      { id: "l-mom", user_id: "mom", family_id: "f1", item_name: "لبن", is_purchased: false, created_at: "2026-10-10" },
      { id: "l-bread", user_id: "mom", family_id: "f1", item_name: "عيش", is_purchased: false, created_at: "2026-10-10" },
    ],
  });
  const out = await executeTool(sb, "dad", "add_inventory_item", { item_name: "لبن", quantity: 1 }, {}, freshContext("dad"), {} as any);
  assert(out.includes("واتشطب \"لبن\" من قايمة التسوق"), out);
  assertEquals(tables.zad_shopping_list.find((l) => l.id === "l-mom")?.is_purchased, true);
  assertEquals(tables.zad_shopping_list.find((l) => l.id === "l-bread")?.is_purchased, false);
  // Its own entry in the action log, so «تراجع» can put the line back.
  assertEquals(writes.some((w) => w.table === "agent_actions" && w.row.target_id === "l-mom"), true);

  // Topping up an item already in the pantry ticks too; with no open line, nothing is said.
  const again = await executeTool(sb, "dad", "add_inventory_item", { item_name: "لبن", quantity: 1 }, {}, freshContext("dad"), {} as any);
  assert(!again.includes("اتشطب"), again);
});

Deno.test("once the family said «حليب» is «لبن», «اشتريت حليب» tops up the milk", async () => {
  const { sb, tables } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [{ id: "milk", user_id: "mom", family_id: "f1", item_name: "لبن", quantity: 1, unit: null, created_at: "2026-10-10" }],
    zad_shopping_list: [{ id: "l1", user_id: "mom", family_id: "f1", item_name: "لبن", is_purchased: false }],
  }, { "حليب": "لبن" });
  const out = await executeTool(sb, "dad", "add_inventory_item", { item_name: "حليب", quantity: 1 }, {}, freshContext("dad"), {} as any);
  assert(!out.startsWith("مرفوض"), out);
  assertEquals(tables.zad_inventory.length, 1, "a second row for the same product");
  assertEquals(tables.zad_inventory[0].quantity, 2);
  assertEquals(tables.zad_shopping_list[0].is_purchased, true, "the list line under the chosen name was not ticked");
});

// «شربنا ٣ مية» (pantry plan step 2, consumeItem.ts).
Deno.test("dad's «شربنا ٣ مية» takes half a 6-bottle pack from the household's water and teaches its owner's rate", async () => {
  const { sb, rpcs, tables } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [
      { id: "w", user_id: "mom", family_id: "f1", item_name: "زجاجة مياه بسعة 1.5 لتر من ايلانو 6 قطع ليتر", quantity: 2, unit: "قطعة", created_at: "2026-11-01" },
      { id: "t", user_id: "mom", family_id: "f1", item_name: "طماطم", quantity: 3, unit: "كيلو", created_at: "2026-11-01" },
    ],
  });
  const out = await executeTool(sb, "dad", "consume_item", { item_name: "مية", amount: 3 }, {}, freshContext("dad"), {} as any);
  assert(!out.startsWith("مرفوض"), out);
  assertEquals(tables.zad_inventory[0].quantity, 1.5);
  assertEquals(tables.zad_inventory[1].quantity, 3, "tomatoes untouched");
  const obs = rpcs.find((r) => r.fn === "zad_record_observation")!;
  assertEquals([obs.args.p_user, obs.args.p_qty, obs.args.p_source], ["mom", 1.5, "chat_consume"]);
});

Deno.test("consume_item never goes below zero and says the item ran out", async () => {
  const { sb, tables } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [{ id: "c", user_id: "dad", family_id: "f1", item_name: "جبنة رومي", quantity: 1, unit: "علبة", created_at: "2026-11-01" }],
  });
  const out = await executeTool(sb, "dad", "consume_item", { item_name: "جبنة رومي", amount: 2, unit: "علبة" }, {}, freshContext("dad"), {} as any);
  assertEquals(tables.zad_inventory[0].quantity, 0);
  assert(out.includes("خلص"), out);
});

Deno.test("consume_item refuses a name that points at two items, and one that is not in the pantry", async () => {
  const { sb, writes } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [
      { id: "a", user_id: "dad", family_id: "f1", item_name: "جبنة رومي", quantity: 1, unit: "علبة", created_at: "2026-11-01" },
      { id: "b", user_id: "dad", family_id: "f1", item_name: "جبنة بيضا", quantity: 1, unit: "علبة", created_at: "2026-11-02" },
    ],
  });
  const two = await executeTool(sb, "dad", "consume_item", { item_name: "جبنة", amount: 1 }, {}, freshContext("dad"), {} as any);
  assert(two.startsWith("مرفوض") && two.includes("جبنة رومي") && two.includes("جبنة بيضا"), two);
  const none = await executeTool(sb, "dad", "consume_item", { item_name: "زيتون", amount: 1 }, {}, freshContext("dad"), {} as any);
  assert(none.startsWith("مرفوض"), none);
  assertEquals(writes.length, 0);
});

Deno.test("someone outside the family cannot consume its pantry", async () => {
  const { sb, writes } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [{ id: "w", user_id: "mom", family_id: "f1", item_name: "مياه", quantity: 10, unit: "حبة", created_at: "2026-11-01" }],
  });
  const out = await executeTool(sb, "stranger", "consume_item", { item_name: "مياه", amount: 3 }, {}, freshContext("stranger"), {} as any);
  assert(out.startsWith("مرفوض"), out);
  assertEquals(writes.length, 0);
});

Deno.test("«فتحنا علبة لبن» marks it opened without taking any off, and records no reading", async () => {
  const { sb, rpcs, tables } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [{ id: "m", user_id: "dad", family_id: "f1", item_name: "لبن", quantity: 3, unit: "علبة", created_at: "2026-11-01" }],
  });
  const out = await executeTool(sb, "dad", "consume_item", { item_name: "لبن", amount: 0, opened: true }, {}, freshContext("dad"), {} as any);
  assert(!out.startsWith("مرفوض"), out);
  assertEquals(tables.zad_inventory[0].quantity, 3);
  assert(typeof tables.zad_inventory[0].opened_at === "string", "opened_at set");
  assert(out.includes("اتفتح"), out);
  assertEquals(rpcs.filter((r) => r.fn === "zad_record_observation").length, 0);
});

// M2.5: the pantry tools write through zad_commit_intent only.
const RUN = { source: "app_chat", runId: "run-1" } as any;

Deno.test("M2.5: add, consume and set go through the door, never a direct pantry write", async () => {
  const { sb, writes, rpcs } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [{ id: "milk", user_id: "mom", family_id: "f1", item_name: "لبن", quantity: 1, unit: "علبة", created_at: "2026-10-10" }],
  });
  await executeTool(sb, "dad", "add_inventory_item", { item_name: "لبن", quantity: 2, category: "الألبان" }, {}, freshContext("dad"), RUN);
  await executeTool(sb, "dad", "add_inventory_item", { item_name: "زيت", quantity: 1, category: "البقالة" }, {}, freshContext("dad"), RUN);
  await executeTool(sb, "dad", "consume_item", { item_name: "لبن", amount: 1 }, {}, freshContext("dad"), RUN);
  await executeTool(sb, "dad", "update_inventory_qty", { item_name: "لبن", new_qty: 5 }, {}, freshContext("dad"), RUN);
  const pantry = writes.filter((w) => w.table === "zad_inventory").map((w) => w.op);
  assertEquals(pantry, ["door:update", "door:insert", "door:update", "door:update"]);
  const intents = rpcs.filter((r) => r.fn === "zad_commit_intent").map((r) => r.args.p_intent as Row);
  assertEquals(intents.map((i) => i.kind), ["inventory.added", "inventory.added", "inventory.consumed", "inventory.quantity_set"]);
  assertEquals(intents.map((i) => i.source), ["model", "model", "model", "model"]);
  assertEquals((intents[0].payload as Row).item_id, "milk", "the top-up names the household row");
});

Deno.test("M2.5: the same call twice in one turn writes once, and says so", async () => {
  const { sb, tables } = fakeDb({ family_members: FAMILY, zad_inventory: [] });
  const input = { item_name: "زيت", quantity: 2, category: "البقالة" };
  const first = await executeTool(sb, "dad", "add_inventory_item", input, {}, freshContext("dad"), RUN);
  const again = await executeTool(sb, "dad", "add_inventory_item", { ...input }, {}, freshContext("dad"), RUN);
  assert(first.includes("اتضاف"), first);
  assert(again.includes("اتنفذ قبل كده"), again);
  assertEquals(tables.zad_inventory.length, 1);
  assertEquals(tables.zad_inventory[0].quantity, 2);
  // Another turn is another request.
  await executeTool(sb, "dad", "consume_item", { item_name: "زيت", amount: 1 }, {}, freshContext("dad"), { source: "app_chat", runId: "run-2" } as any);
  await executeTool(sb, "dad", "consume_item", { item_name: "زيت", amount: 1 }, {}, freshContext("dad"), { source: "app_chat", runId: "run-3" } as any);
  assertEquals(tables.zad_inventory[0].quantity, 0);
});

Deno.test("M2.5: a refusal from the door reaches the model with its reason, and nothing is logged as done", async () => {
  const { sb, writes, refuse } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [{ id: "rice", user_id: "dad", family_id: "f1", item_name: "رز", quantity: 2, unit: "كيلو", created_at: "2026-11-01" }],
  });
  refuse("qty_too_large");
  const ctx = freshContext("dad");
  const out = await executeTool(sb, "dad", "update_inventory_qty", { item_name: "رز", new_qty: 900 }, {}, ctx, RUN);
  assert(out.startsWith("مرفوض") && out.includes("qty_too_large"), out);
  assertEquals(ctx.mutationCount, 0);
  assertEquals(writes.length, 0, "no audit row for a refused write");
});

// Every refusal lands in zad_guard_events, so «صحة العقل» sees them all — not only the door's.
const guards = (writes: Array<{ table: string; row: Row }>) => writes.filter((w) => w.table === "zad_guard_events").map((w) => w.row);

Deno.test("guards: a validator refusal is logged with the tool, the reason and the input", async () => {
  const { sb, writes } = fakeDb({ family_members: FAMILY, zad_inventory: [] });
  const out = await runTool(sb, "dad", "update_inventory_qty", { item_name: "لبن", new_qty: -1 }, { stock: [{ name: "لبن", qty: 1 }] }, freshContext("dad"), RUN);
  assert(out.startsWith("مرفوض"), out);
  const g = guards(writes);
  assertEquals(g.length, 1);
  assertEquals([g[0].user_id, g[0].kind, g[0].source], ["dad", "validator:update_inventory_qty", "model"]);
  assert(String(g[0].reason).includes("بالسالب") && !String(g[0].reason).startsWith("مرفوض"), String(g[0].reason));
  assertEquals((g[0].intent as Row).input, { item_name: "لبن", new_qty: -1 });
});

Deno.test("guards: a tool's own refusal is logged as tool:, a door refusal is not logged twice", async () => {
  const { sb, writes, refuse } = fakeDb({
    family_members: FAMILY,
    zad_inventory: [{ id: "rice", user_id: "dad", family_id: "f1", item_name: "رز", quantity: 2, unit: "كيلو", created_at: "2026-11-01" }],
  });
  const missing = await runTool(sb, "dad", "consume_item", { item_name: "زيتون", amount: 1 }, {}, freshContext("dad"), RUN);
  assert(missing.startsWith("مرفوض"), missing);
  assertEquals(guards(writes).map((g) => g.kind), ["tool:consume_item"]);
  refuse("amount_too_large");
  const door = await runTool(sb, "dad", "consume_item", { item_name: "رز", amount: 1 }, {}, freshContext("dad"), RUN);
  assert(isDoorRefusal(door), door);
  assertEquals(guards(writes).length, 1, "the door already logged its own refusal");
});

Deno.test("guards: the door's reply shape is recognised, nothing else is", () => {
  assert(isDoorRefusal(refusalText("qty_too_large")));
  assert(isDoorRefusal(refusalText("something_new")));
  assert(!isDoorRefusal("مرفوض: الكتابة اترفضت (rpc: timeout) — عدّل وحاول تاني."));
  assert(!isDoorRefusal("مرفوض: «زيتون» مش في مخزون البيت — اسأل العميل لو عايز يضيفه."));
});

Deno.test("guards: a failed log never changes the reply", async () => {
  const { sb } = fakeDb({ family_members: FAMILY, zad_inventory: [] });
  const broken = { ...sb, from: (t: string) => (t === "zad_guard_events" ? (() => { throw new Error("down"); })() : sb.from(t)) };
  const out = await runTool(broken as any, "dad", "update_inventory_qty", { item_name: "لبن", new_qty: -1 }, { stock: [{ name: "لبن", qty: 1 }] }, freshContext("dad"), RUN);
  assert(out.startsWith("مرفوض") && out.includes("بالسالب"), out);
});
