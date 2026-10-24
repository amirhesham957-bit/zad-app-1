// الحراس بيتكلموا (ZAD_PLAN ٣.٥): اللي اتمسك بيتقال بسببه، والعميل يقدر يسأل عليه.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { HOLD_REASON_AR, heldMessagesSummary } from "./shared.ts";
import { intentToolHints } from "./specialists.ts";

Deno.test("what was held reads as one line per kind and guard, newest first", () => {
  const text = heldMessagesSummary([
    { source: "task", kind: "spend_forecast", reason: "expired", action: "dropped", times: 3 },
    { source: "task", kind: "predicted_shortage", reason: "reply_hour", action: "waiting", times: 1 },
    { source: "task", kind: "spend_forecast", reason: "expired", action: "dropped", times: 1 },
    { source: "moment", kind: "good_night", reason: "quiet_hours", action: "dropped", times: 1 },
  ]);
  const lines = text.split("\n");
  assertEquals(lines.length, 3);
  assertEquals(lines[0], "• 📈 زاد بيتوقّع مصروف الأسبوع: ماقولتهاش (3 مرات) — كلامها قدم قبل ما ألاقي وقت مناسب");
  assertEquals(lines[1], "• 🥛 زاد شايف حاجات هتخلص قريب: لسه مستنية — استنيت الساعة اللي بترد فيها عادة");
  assert(lines[2].includes("good_night") && lines[2].includes("كان وقت نومك"));
});

Deno.test("nothing held says so, and an unknown reason is not hidden", () => {
  assert(heldMessagesSummary([]).includes("ماسكتّش"));
  assert(heldMessagesSummary([{ source: "task", kind: "habit_budget", reason: "weird", action: "postponed" }]).includes(HOLD_REASON_AR.other));
});

Deno.test("every guard the server writes has words", () => {
  for (const code of ["muted", "quiet_hours", "reply_hour", "pacing", "daily_cap", "busy_day", "circumstance", "duplicate", "expired", "not_relevant", "nothing_new"]) {
    assert(code in HOLD_REASON_AR, code);
  }
});

Deno.test("«what didn't you tell me?» reaches the tool", () => {
  for (const m of ["إيه اللي ماقولتليش عليه؟", "ليه مابعتليش حاجة امبارح", "انت سكت عن ايه الاسبوع ده", "ايه الحاجات اللي ماوصلتنيش"]) {
    assert(intentToolHints(m).includes("what_i_held_back"), m);
  }
  for (const m of ["قولتلي الميزانية كام؟", "سجل ٥٠ قهوة"]) {
    assert(!intentToolHints(m).includes("what_i_held_back"), m);
  }
});
