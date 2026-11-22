import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { detectSurges, poissonZ } from "./trendSurge.ts";

Deno.test("z: قفزة واضحة", () => {
  assertEquals(poissonZ(25, 16), 9 / 4);
  assertEquals(poissonZ(16, 16), 0);
});
Deno.test("z: معتاد صفري ماينفجرش", () => {
  assertEquals(Number.isFinite(poissonZ(5, 0)), true);
});
Deno.test("z: مدخلات غلط", () => {
  assertThrows(() => poissonZ(-1, 3), RangeError);
  assertThrows(() => poissonZ(1, NaN), RangeError);
});
Deno.test("أقل من ٥ بيوت مابيطلعش حتى لو القفزة ضخمة", () => {
  assertEquals(detectSurges([{ item: "رز", count: 100, houses: 4, baseline: 5 }]), []);
});
Deno.test("٥ بيوت وقفزة: بيطلع ومرتب، ومفيش توصية شرا", () => {
  const r = detectSurges([
    { item: "زيت", count: 30, houses: 6, baseline: 16 },
    { item: "سكر", count: 60, houses: 9, baseline: 16 },
    { item: "ملح", count: 17, houses: 9, baseline: 16 },
  ]);
  assertEquals(r.map((s) => s.item), ["سكر", "زيت"]);
  assertEquals(r.every((s) => s.recommendBuy === false), true);
});
