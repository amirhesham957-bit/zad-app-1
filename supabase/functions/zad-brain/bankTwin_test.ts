import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { bankTwinMergedReply } from "./bankTwin.ts";

Deno.test("the merged reply says it is the bank's own row, not a second one", () => {
  const now = Date.parse("2026-11-01T18:31:00Z");
  const r = bankTwinMergedReply("BDC", 3500, "إيجار شقة", "2026-11-01T18:13:00Z", now);
  assertStringIncludes(r, "اتسجلت المعاملة: إيجار شقة — 3500");
  assertStringIncludes(r, "«BDC» اللي وصلت من 18 دقيقة");
  assertEquals(r.startsWith("مرفوض"), false, "a merge is a success for every door");
  assertStringIncludes(bankTwinMergedReply("", 124.54, "عطارة", "2026-11-01T15:00:00Z", now), "من 4 ساعة");
});

Deno.test("log_transaction asks for the bank twin before the ten-minute guard", async () => {
  const src = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  const twin = src.indexOf('rpc("zad_bank_twin_service"');
  const guard = src.indexOf("const windowStart = new Date(Date.now() - 10 * 60 * 1000)");
  assertEquals(twin > 0 && twin < guard, true);
});
