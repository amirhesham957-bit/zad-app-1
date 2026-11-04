import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { codeStoreKey, type CodeRow, dealCodeRows, pickDealCode, saidCodes } from "./dealCodes.ts";
import { codeLine } from "./voiceMoments.ts";

const NOW = Date.parse("2026-11-04T12:00:00Z");

function row(over: Partial<CodeRow>): CodeRow {
  return {
    store: "كيتا", store_key: "keeta", code: "KEETA30", discount_percent: 30, discount_amount: null, currency: "SAR",
    min_order: null, valid_until: null, source_kind: "instagram", source_url: "https://www.instagram.com/p/x/",
    found_at: "2026-11-03T00:00:00Z", ...over,
  };
}

Deno.test("Keeta in the bank and كيتا in the list are one store", () => {
  assertEquals(codeStoreKey("Keeta"), codeStoreKey("كيتا"));
  assertEquals(codeStoreKey("Ninja"), "ninja");
});

Deno.test("the code goes only to a household that orders from that app", () => {
  const rows = [row({}), row({ store: "نينجا", store_key: "ninja", code: "NINJA15" })];
  assertEquals(pickDealCode(rows, ["Ninja", "Keeta"], new Set())?.code, "NINJA15");
  assertEquals(pickDealCode(rows, ["هنقرستيشن"], new Set()), null);
  assertEquals(pickDealCode(rows, [], new Set()), null);
});

Deno.test("a code said this week is not said again; the newest code of the store comes first", () => {
  const rows = [row({ code: "OLD10", found_at: "2026-11-01T00:00:00Z" }), row({ code: "NEW20", found_at: "2026-11-04T00:00:00Z" })];
  assertEquals(pickDealCode(rows, ["Keeta"], new Set())?.code, "NEW20");
  assertEquals(pickDealCode(rows, ["Keeta"], new Set(["NEW20"]))?.code, "OLD10");
  const said = saidCodes([
    { facts: { deal_code: { code: "NEW20" } }, created_at: "2026-11-03T08:00:00Z" },
    { facts: { deal_code: { code: "OLD10" } }, created_at: "2026-10-20T08:00:00Z" },
  ], NOW);
  assertEquals([...said], ["NEW20"]);
});

Deno.test("rows for the table: the app's key, a week's life without a date, bad shapes dropped", () => {
  const rows = dealCodeRows({ country: "SA", store: "كيتا", currency: "SAR" }, [
    { code: "KEETA30", discount_percent: 30, source_url: "https://www.instagram.com/p/x/" },
    { code: "bad code", discount_percent: 30, source_url: "https://x" },
    { code: "NOOFF", source_url: "https://x" },
    { code: "LINK1", discount_percent: 10, source_url: "http://x" },
  ], "instagram", NOW);
  assertEquals(rows.length, 1);
  assertEquals(rows[0].store_key, "keeta");
  assertEquals(rows[0].expires_at, "2026-11-11T12:00:00.000Z");
  assertEquals(dealCodeRows({ country: "SA", store: "كيتا" }, null, "youtube", NOW), []);
});

Deno.test("the fallback line writes the code exactly and says where it came from", () => {
  const line = codeLine({ store: "كيتا", code: "KEETA30", discount_percent: 30, min_order: 50, until: "2026-11-10", source: "instagram" });
  assertStringIncludes(line, "KEETA30");
  assertStringIncludes(line, "30٪");
  assertStringIncludes(line, "50");
  assertStringIncludes(line, "بوست");
  assertStringIncludes(line, "ممكن يكون خلص");
  assertEquals(codeLine({ store: "كيتا", code: "X1Y" }), "");
  assertEquals(codeLine(null), "");
});
