import { assertEquals } from "jsr:@std/assert@1";
import { extractWeeklyPatterns, type PatternEvent } from "./weeklyPatterns.ts";

// 2026-11-20 جمعة. ١٠ص بالقاهرة (UTC+2) = 08:00Z.
function fridays(member: string, kind: string, n: number): PatternEvent[] {
  const out: PatternEvent[] = [];
  for (let i = 0; i < n; i++) {
    const d = new Date(Date.UTC(2026, 10, 20 + 7 * i, 8, 0));
    out.push({ memberId: member, kind, occurredAt: d.toISOString() });
  }
  return out;
}

Deno.test("٥ مرات بيطلع نمط، ٤ لأ", () => {
  const r5 = extractWeeklyPatterns(fridays("a", "inventory.consume", 5), "a");
  assertEquals(r5.length, 1);
  assertEquals([r5[0].weekday, r5[0].dayPart, r5[0].count], [5, "morning", 5]);
  assertEquals(extractWeeklyPatterns(fridays("a", "inventory.consume", 4), "a"), []);
});

Deno.test("خصوصية: أحداث فرد تاني مابتظهرش ولا بتكمّل عدّ فرد", () => {
  const ev = [...fridays("a", "k", 3), ...fridays("b", "k", 3), ...fridays("b", "other", 9)];
  assertEquals(extractWeeklyPatterns(ev, "a"), []);
  const b = extractWeeklyPatterns(ev, "b");
  assertEquals(b.every((p) => p.memberId === "b"), true);
  assertEquals(b.map((p) => p.kind), ["other"]);
  assertEquals(JSON.stringify(extractWeeklyPatterns(ev, "a")).includes('"b"'), false);
});

Deno.test("الوقت بمنطقة الحساب: 23:30Z خميس = جمعة ١:٣٠ بالقاهرة (ليل)", () => {
  const ev: PatternEvent[] = [];
  for (let i = 0; i < 5; i++) {
    ev.push({ memberId: "a", kind: "k", occurredAt: new Date(Date.UTC(2026, 10, 19 + 7 * i, 23, 30)).toISOString() });
  }
  const r = extractWeeklyPatterns(ev, "a");
  assertEquals([r[0].weekday, r[0].dayPart], [5, "night"]);
  const utc = extractWeeklyPatterns(ev, "a", { timeZone: "UTC" });
  assertEquals(utc[0].weekday, 4);
});

Deno.test("تواريخ بايظة بتتجاهل", () => {
  assertEquals(extractWeeklyPatterns([{ memberId: "a", kind: "k", occurredAt: "x" }], "a", { minOccurrences: 1 }), []);
});
