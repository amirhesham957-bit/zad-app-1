import { assertEquals } from "jsr:@std/assert@1";
import { agentTaskPushData } from "./shared.ts";

Deno.test("the bank-stopped alert opens the repair route on the phone", () => {
  assertEquals(agentTaskPushData("listener_gap_alert"), { route: "bank_fix" });
  assertEquals(agentTaskPushData(" listener_gap_alert "), { route: "bank_fix" });
});

Deno.test("other tasks carry no route", () => {
  for (const k of ["reminder", "", null, undefined, "bill_reminder", "spending_ahead"]) {
    assertEquals(agentTaskPushData(k), undefined, String(k));
  }
});
