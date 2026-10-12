import { assertEquals } from "jsr:@std/assert@1";
import { chatLane, freeDailyBudget, historyWindow, turnsPerMinute } from "./freeLane.ts";

Deno.test("a subscriber is always in the paid lane, whatever the day's load", () => {
  assertEquals(chatLane(true, 999_999, 1500), "paid");
  assertEquals(chatLane(true, null, 1500), "paid");
});

Deno.test("the free lane turns to Groq only past the day's budget", () => {
  assertEquals(chatLane(false, 1, 1500), "free");
  assertEquals(chatLane(false, 1500, 1500), "free", "the budget's last turn is still served");
  assertEquals(chatLane(false, 1501, 1500), "free_busy");
  assertEquals(chatLane(false, null, 1500), "free", "a failed count never blocks anyone");
  assertEquals(chatLane(false, 99_999, 0), "free", "0 means no budget");
});

Deno.test("the budget: 1500 by default, set by ZAD_FREE_DAILY_BUDGET", () => {
  assertEquals(freeDailyBudget(undefined), 1500);
  assertEquals(freeDailyBudget(""), 1500);
  assertEquals(freeDailyBudget("x"), 1500);
  assertEquals(freeDailyBudget("4000"), 4000);
  assertEquals(freeDailyBudget("0"), 0);
});

Deno.test("free gets half the conversation and a tighter rate", () => {
  assertEquals(historyWindow(true), 8);
  assertEquals(historyWindow(false), 4);
  assertEquals(turnsPerMinute(true) > turnsPerMinute(false), true);
});
