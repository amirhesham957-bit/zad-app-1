import { assertEquals } from "jsr:@std/assert@1";
import { deliverRestockLink, isRestockEssential, restockItems, restockMessage } from "./restockLink.ts";

Deno.test("essentials are what runs out and gets ordered again, never fresh food", () => {
  for (const name of ["حليب جهينة", "اللبن", "قهوة تركي", "شاي ليبتون", "رز مصري", "زيت عباد الشمس", "شامبو هيد آند شولدرز",
    "مسحوق غسيل أريال", "سائل غسيل صحون", "ورق تواليت", "معجون اسنان", "مياه نستله", "إيلان", "حفاضات بامبرز"]) {
    assertEquals(isRestockEssential(name), true, name);
  }
  for (const name of ["طماطم", "فراخ", "عيش بلدي", "بيض", "تفاح", "ايس كريم", "بسكويت", "زيتون", "لحمة مفرومة", ""]) {
    assertEquals(isRestockEssential(name), false, name);
  }
  // Cleaning and personal care are ordered whatever the name says.
  assertEquals(isRestockEssential("بريل", "منظفات"), true);
  assertEquals(isRestockEssential("نيفيا", "العناية"), true);
  assertEquals(isRestockEssential("كوسة", "خضار"), false);
});

Deno.test("only items still out, essential, each once, three at most", () => {
  const pantry = [
    { item_name: "حليب", quantity: 0 },
    { item_name: "قهوة", quantity: 0 },
    { item_name: "شامبو", quantity: 2 }, // restocked before the message went out
    { item_name: "طماطم", quantity: 0 }, // fresh
    { item_name: "بريل", quantity: 0, category: "منظفات" },
    { item_name: "سكر", quantity: 0 },
    { item_name: "رز", quantity: 0 },
    { item_name: "رز", quantity: 1 }, // another row of the same item still has some
  ];
  assertEquals(
    restockItems(["حليب", "شامبو", "طماطم", "حليب", "رز", "مش في المخزن", "قهوة", "بريل", "سكر"], pantry),
    ["حليب", "قهوة", "بريل"],
  );
  assertEquals(restockItems(["طماطم"], pantry), []);
});

Deno.test("the message reads like a friend's, with the link as is", () => {
  const one = restockMessage([{ name: "الشامبو", url: "https://www.amazon.eg/s?k=x&tag=zad04-21" }]);
  assertEquals(one.title, "🛒 الشامبو خلص");
  assertEquals(one.body.endsWith("\n• الشامبو: https://www.amazon.eg/s?k=x&tag=zad04-21"), true);
  assertEquals(one.plain.includes("http"), false);
  assertEquals(/عرض|اشتري الآن|خصم/.test(one.body), false);
  const two = restockMessage([{ name: "حليب", url: "https://a/1" }, { name: "قهوة", url: "https://a/2" }]);
  assertEquals(two.body.includes("• حليب: https://a/1\n• قهوة: https://a/2"), true);
  assertEquals(two.push.includes("http"), false);
});

// A stand-in for the few calls deliverRestockLink makes: reads answer from `tables`,
// writes are recorded.
function fakeDb(tables: Record<string, unknown[]>, single: Record<string, unknown>) {
  const writes: Array<{ table: string; op: string; row: Record<string, unknown> }> = [];
  const db = {
    from(table: string) {
      const read = {
        select: () => read, eq: () => read, limit: () => Promise.resolve({ data: tables[table] ?? [], error: null }),
        maybeSingle: () => Promise.resolve({ data: single[table] ?? null, error: null }),
      };
      return {
        ...read,
        update: (row: Record<string, unknown>) => {
          writes.push({ table, op: "update", row });
          return { eq: () => Promise.resolve({ error: null }) };
        },
        insert: (row: Record<string, unknown>) => {
          writes.push({ table, op: "insert", row });
          return Promise.resolve({ error: null });
        },
      };
    },
  };
  return { db: db as unknown as Parameters<typeof deliverRestockLink>[0], writes };
}

function fakeDeps() {
  const device: unknown[][] = [];
  const telegram: unknown[][] = [];
  return {
    device, telegram,
    deps: {
      pushDevice: (...a: unknown[]) => (device.push(a), Promise.resolve("sent")),
      pushTelegram: (...a: unknown[]) => (telegram.push(a), Promise.resolve("delivered")),
      env: () => undefined,
      nowMs: Date.parse("2026-10-10T12:00:00Z"),
    },
  };
}

const task = { id: "t1", user_id: "u1", task_description: "حليب\nطماطم" };

Deno.test("an Egyptian customer gets amazon.eg links with the Egyptian tag, everywhere Zad talks", async () => {
  const { db, writes } = fakeDb(
    { zad_inventory: [{ item_name: "حليب", quantity: 0, category: "الألبان" }, { item_name: "طماطم", quantity: 0 }] },
    { zad_users: { country: "EG" } },
  );
  const { deps, device, telegram } = fakeDeps();
  assertEquals(await deliverRestockLink(db, task, deps), "sent");
  const done = writes.find((w) => w.table === "agent_tasks" && w.row.status === "done");
  assertEquals(String(done?.row.result).includes("https://www.amazon.eg/s?k=%D8%AD%D9%84%D9%8A%D8%A8&tag=zad04-21"), true);
  assertEquals(String(done?.row.result).includes("طماطم"), false);
  assertEquals(writes.some((w) => w.table === "app_notifications" && w.op === "insert"), true);
  assertEquals(writes.some((w) => w.table === "zad_chat_turns" && w.row.role === "assistant"), true);
  assertEquals(device[0][3], { route: "home" });
  assertEquals(telegram[0][3], "t1");
  assertEquals(String(telegram[0][2]).includes("http"), false);
  assertEquals(telegram[0][4], [{ name: "حليب", url: "https://www.amazon.eg/s?k=%D8%AD%D9%84%D9%8A%D8%A8&tag=zad04-21" }]);
});

Deno.test("any other country gets amazon.sa", async () => {
  const { db, writes } = fakeDb({ zad_inventory: [{ item_name: "حليب", quantity: 0 }] }, { zad_users: { country: "AE" } });
  await deliverRestockLink(db, task, fakeDeps().deps);
  const done = writes.find((w) => w.row.status === "done");
  assertEquals(String(done?.row.result).includes("https://www.amazon.sa/s?k=%D8%AD%D9%84%D9%8A%D8%A8&tag=zad0b-21"), true);
});

Deno.test("nothing is sent in وضع الطوارئ, or when nothing essential is still out", async () => {
  for (const [inventory, broke] of [
    [[{ item_name: "حليب", quantity: 0 }], { ends_at: "2026-10-20T00:00:00Z", ended_at: null }],
    [[{ item_name: "حليب", quantity: 1 }, { item_name: "طماطم", quantity: 0 }], null],
  ] as const) {
    const { db, writes } = fakeDb({ zad_inventory: [...inventory] }, { zad_users: { country: "EG" }, zad_broke_mode: broke });
    const { deps, device, telegram } = fakeDeps();
    assertEquals(await deliverRestockLink(db, task, deps), "skipped");
    assertEquals(writes.some((w) => w.row.status === "cancelled"), true);
    assertEquals(writes.some((w) => w.table === "app_notifications" || w.table === "zad_chat_turns"), false);
    assertEquals(device.length + telegram.length, 0);
  }
});
