import { assertEquals } from "jsr:@std/assert@1";
import { keyOrder, laneFor, paidReservedCount, reservedCount } from "./keyLanes.ts";

Deno.test("scheduled analysis is background; reminders and chat are the customer's", () => {
  for (const a of ["run_daily_brain", "nightly_dream_reflection", "run_proactive_scan", "process_agent_tasks", "tools_probe"]) {
    assertEquals(laneFor(a), "background", a);
  }
  for (const a of ["process_voice_moments", "agent_turn_stream", "notification_ingest", undefined, 7]) {
    assertEquals(laneFor(a), "customer", String(a));
  }
});

Deno.test("a third of the pool is held back by default; a small pool is not split", () => {
  assertEquals(reservedCount(15), 5);
  assertEquals(reservedCount(10), 3);
  assertEquals(reservedCount(3), 1);
  assertEquals(reservedCount(2), 0);
  assertEquals(reservedCount(10, "4"), 4);
  assertEquals(reservedCount(10, "10"), 9, "the customer always keeps a key");
  assertEquals(reservedCount(10, "x"), 3);
  assertEquals(reservedCount(10, "0"), 0);
});

Deno.test("background never touches a customer key", () => {
  for (let c = 0; c < 12; c++) {
    const order = keyOrder("background", 15, 5, c);
    assertEquals(order.length, 5);
    assertEquals(order.every((k) => k >= 10), true);
  }
});

Deno.test("the customer tries their keys first, then borrows the background ones", () => {
  const order = keyOrder("customer", 15, 5, 3);
  assertEquals(order.length, 15);
  assertEquals(order.slice(0, 10).every((k) => k < 10), true);
  assertEquals(order.slice(10).every((k) => k >= 10), true);
  assertEquals(new Set(order).size, 15);
  assertEquals(order[0], 3, "rotated by the cursor");
});

Deno.test("an unsplit pool is the old round robin for everyone", () => {
  assertEquals(keyOrder("customer", 2, 0, 1), [1, 0]);
  assertEquals(keyOrder("background", 2, 0, 1), [1, 0]);
});

Deno.test("a paid key is held for paying customers; the free lane never draws on it", () => {
  // 5 keys: one for the cron, one for subscribers, three shared.
  assertEquals(paidReservedCount(5, 1), 1);
  assertEquals(paidReservedCount(4, 1), 0, "a small pool keeps every key shared");
  assertEquals(paidReservedCount(5, 1, "0"), 0);
  assertEquals(paidReservedCount(5, 1, "9"), 3, "the free lane always keeps a key");
  for (let c = 0; c < 10; c++) {
    const paid = keyOrder("paid", 5, 1, c, 1);
    assertEquals(paid[0], 3, "the paid key first");
    assertEquals(new Set(paid).size, 5);
    const free = keyOrder("free", 5, 1, c, 1);
    assertEquals(free.includes(3), false, "free never touches the paid key");
    assertEquals(free.length, 4);
    assertEquals(keyOrder("free_busy", 5, 1, c, 1).includes(3), false);
    assertEquals(keyOrder("background", 5, 1, c, 1), [4], "the cron keeps its own key");
    const customer = keyOrder("customer", 5, 1, c, 1);
    assertEquals(customer.slice(0, 3).every((k) => k < 3), true, "other customer calls: shared first");
    assertEquals(customer[3], 3);
  }
});

Deno.test("without a paid key the order is exactly what it was", () => {
  for (let c = 0; c < 6; c++) {
    assertEquals(keyOrder("customer", 15, 5, c, 0), keyOrder("customer", 15, 5, c));
    assertEquals(keyOrder("free", 15, 5, c, 0), keyOrder("customer", 15, 5, c));
    assertEquals(keyOrder("paid", 15, 5, c, 0), keyOrder("customer", 15, 5, c));
  }
});
