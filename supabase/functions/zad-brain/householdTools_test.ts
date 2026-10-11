// The brain's pantry and list tools act on the household (owner, 2026-10-11): dad's
// «اشتريت لبن» tops up the milk mom added, his «اشتريت الجبنة» ticks her line, and his
// «ضيف لبن» adds to her open line instead of a second one. Before, each of these looked at
// dad's own rows only — a duplicate row, «مش موجود», or an update that matched nothing and
// still said «الكمية بقت…».
import { assert, assertEquals } from "jsr:@std/assert@1";
import { executeTool } from "./index.ts";
import { freshContext } from "./validators.ts";

type Row = Record<string, unknown>;

/** A tiny PostgREST: eq / or (user_id, family_id) filters, select, update, insert. */
function fakeDb(tables: Record<string, Row[]>) {
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
  const rpc = (fn: string, args: Row) => {
    rpcs.push({ fn, args });
    return Promise.resolve({ data: { samples: 1, rate_known: false }, error: null });
  };
  return { sb: { from, rpc } as any, writes, rpcs, tables };
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
  assertEquals(writes.filter((w) => w.table === "zad_inventory").map((w) => w.op), ["update"]);
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
