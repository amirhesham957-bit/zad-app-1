import { assert, assertEquals } from "jsr:@std/assert@1";
import { describeReorder, parseReorderInput } from "./pharmacyReorderTool.ts";
import { guardEngineReply } from "./engineGuard.ts";
import { intentToolHints, scopeToolsForSpecialist } from "./specialists.ts";

const NOW = "2026-11-22T10:00:00Z"; // 12:00 in Cairo (UTC+2)
const med = { name: "بنادول", for_person: "ماما", remaining_quantity: 20, daily_dose_count: 2, units_per_dose: 2, dose_times: "08:00,20:00" };

Deno.test("parse: defaults and refusals", () => {
  const ok = parseReorderInput({ lead_time_days: 4, time_zone: "Africa/Cairo" });
  assert("value" in ok);
  assertEquals(ok.value.leadTimeDays, 4);
  for (const bad of [{ lead_time_days: -1 }, { lead_time_days: "x" }, { safety_days: 100 }, { time_zone: "Mars/Base" }]) {
    const p = parseReorderInput(bad);
    assert("error" in p);
    assert(p.error.startsWith("مرفوض"));
  }
});

Deno.test("describe: stock, reorder point, next dose in the given zone", () => {
  const p = parseReorderInput({ lead_time_days: 3 });
  assert("value" in p);
  const text = describeReorder([med], p.value, NOW, "Africa/Cairo");
  // 20 units, 4/day = 5 days; reorder point 4 * (3+2) = 20, so reorder now.
  assert(text.includes("باقي 20 وحدة"));
  assert(text.includes("يكفي 5 يوم"));
  assert(text.includes("نقطة الطلب 20 وحدة — اطلبه دلوقتي"));
  assert(text.includes("الجرعة الجاية 2026-11-22 20:00"));
});

Deno.test("describe: member time zone changes the next dose", () => {
  const p = parseReorderInput({ time_zone: "America/New_York" });
  assert("value" in p);
  // 10:00Z = 05:00 in New York, so 08:00 is next.
  assert(describeReorder([med], p.value, NOW, "Africa/Cairo").includes("الجرعة الجاية 2026-11-22 08:00"));
});

Deno.test("describe: longer lead time flips a comfortable stock to reorder", () => {
  const m = { ...med, remaining_quantity: 40 };
  const a = parseReorderInput({ lead_time_days: 3 });
  const b = parseReorderInput({ lead_time_days: 9 });
  assert("value" in a && "value" in b);
  assert(describeReorder([m], a.value, NOW, "UTC").includes("لسه بدري"));
  assert(describeReorder([m], b.value, NOW, "UTC").includes("اطلبه دلوقتي"));
});

Deno.test("describe: no stock, no schedule, unknown name", () => {
  const p = parseReorderInput({});
  assert("value" in p);
  assert(describeReorder([{ ...med, remaining_quantity: null }], p.value, NOW, "UTC").includes("مفيش رصيد متسجل"));
  assert(describeReorder([{ ...med, daily_dose_count: 0, dose_times: null }], p.value, NOW, "UTC").includes("مفيش جدول جرعات"));
  const n = parseReorderInput({ name: "اسبرين" });
  assert("value" in n);
  assert(describeReorder([med], n.value, NOW, "UTC").startsWith("مرفوض"));
});

Deno.test("guard: an invented number in the reply is replaced", () => {
  const p = parseReorderInput({});
  assert("value" in p);
  const content = describeReorder([med], p.value, NOW, "Africa/Cairo");
  const out = [{ tool: "check_medicine_reorder", content }];
  assertEquals(guardEngineReply("بنادول يكفي 9 يوم", "؟", out).replaced, true);
});

Deno.test("routing: pharmacy specialist has the tool, intent hints it", () => {
  const tools = scopeToolsForSpecialist([{ name: "check_medicine_reorder" } as never, { name: "log_transaction" } as never], "pharmacy", null, []);
  assert(tools.some((t: { name: string }) => t.name === "check_medicine_reorder"));
  assert(intentToolHints("الدوا هيخلص امتى؟").includes("check_medicine_reorder"));
});
