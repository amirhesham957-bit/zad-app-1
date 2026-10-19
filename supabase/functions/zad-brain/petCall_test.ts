// ZAD_PLAN ٥.٥ (ب): نداء الرفيق باسمه.
import { assertEquals } from "jsr:@std/assert@1";
import { dailyCapDecision, pacingPriority } from "./shared.ts";
import { deliverPetCall, petCallMessage, petNeedNow } from "./petCall.ts";

const NOW = Date.parse("2026-10-20T12:00:00Z");
const ago = (h: number) => new Date(NOW - h * 3_600_000).toISOString();

Deno.test("hunger before thirst, at the queue's own thresholds", () => {
  assertEquals(petNeedNow({ fed_at: ago(16), watered_at: ago(12) }, NOW), "hungry");
  assertEquals(petNeedNow({ fed_at: ago(3), watered_at: ago(11) }, NOW), "thirsty");
  assertEquals(petNeedNow({ fed_at: ago(3), watered_at: ago(3) }, NOW), null);
  assertEquals(petNeedNow(null, NOW), null);
});

Deno.test("the call speaks as the pet, by its name, and never of money", () => {
  for (const need of ["hungry", "thirsty"] as const) {
    const m = petCallMessage(need, "بسبوس");
    assertEquals(m.title.includes("بسبوس"), true);
    assertEquals(m.push.includes("بسبوس"), true);
    assertEquals(/جنيه|ريال|فلوس|ميزاني|صرف|مصروف/.test(m.body), false);
  }
  assertEquals(petCallMessage("hungry", "  ").push.startsWith("زادو"), true);
});

Deno.test("the pet's call is one of the day's two, and the last to go", () => {
  // Two house initiatives sent today: the pet waits for tomorrow, like any third.
  const sent = [{ kind: "bill_reminder", at: ago(5) }, { kind: "predicted_shortage", at: ago(2) }];
  assertEquals(dailyCapDecision("pet_call", sent, "Africa/Cairo", NOW).action, "postpone");
  assertEquals(dailyCapDecision("pet_call", sent.slice(0, 1), "Africa/Cairo", NOW).action, "deliver");
  assertEquals(pacingPriority("pet_call") > pacingPriority("warranty_reminder"), true);
});

function fakeDb(single: Record<string, unknown>) {
  const writes: Array<{ table: string; op: string; row: Record<string, unknown> }> = [];
  const db = {
    from(table: string) {
      const read: Record<string, unknown> = {
        select: () => read, eq: () => read,
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
  return { db: db as unknown as Parameters<typeof deliverPetCall>[0], writes };
}

function fakeDeps() {
  const device: unknown[][] = [];
  const telegram: unknown[][] = [];
  return {
    device, telegram,
    deps: {
      pushDevice: (...a: unknown[]) => (device.push(a), Promise.resolve("sent")),
      pushTelegram: (...a: unknown[]) => (telegram.push(a), Promise.resolve("delivered")),
      nowMs: NOW,
    },
  };
}

const task = { id: "t1", user_id: "u1", task_description: "hungry" };

Deno.test("a hungry pet calls on Telegram and the phone, in its own name", async () => {
  const { db, writes } = fakeDb({
    zad_companion_care: { fed_at: ago(18), watered_at: ago(1) },
    zad_companion: { persona: "basbous" },
    zad_companion_items: { name_ar: "بسبوس" },
  });
  const { deps, device, telegram } = fakeDeps();
  assertEquals(await deliverPetCall(db, task, deps), "sent");
  assertEquals(writes.some((w) => w.table === "agent_tasks" && w.row.status === "done"), true);
  assertEquals(writes.some((w) => w.table === "app_notifications" && w.op === "insert"), true);
  assertEquals(String(telegram[0][2]).includes("بسبوس جعان"), true);
  assertEquals(telegram[0][3], "t1");
  assertEquals(device[0][3], { route: "home" });
});

Deno.test("fed since it was queued: no call, and it does not count", async () => {
  const { db, writes } = fakeDb({ zad_companion_care: { fed_at: ago(1), watered_at: ago(1) } });
  const { deps, device, telegram } = fakeDeps();
  assertEquals(await deliverPetCall(db, task, deps), "skipped");
  assertEquals(writes.some((w) => w.table === "agent_tasks" && w.row.status === "cancelled"), true);
  assertEquals(device.length + telegram.length, 0);
});
