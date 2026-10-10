// «هات اللوكيشن» في الشات (الموجة ٣): مهمة store_arrival شايلة رابط المحل، وstore_location بترجّعه.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { storeArrivalTask, storeLocationFrom, storeMapUrl } from "./storeFit.ts";
import { intentToolHints, scopeToolsForSpecialist } from "./specialists.ts";
import { MUTATING_TOOLS, VALIDATORS, freshContext } from "./validators.ts";
import { buildChatSystemPrompt, CHAT_TOOLS } from "./index.ts";

const CARREFOUR = "https://www.google.com/maps/search/?api=1&query=30.04442,31.23571";
const ATTAR = "https://www.google.com/maps/search/?api=1&query=30.05000,31.24000";
const ROWS = [
  { task_description: "وصول لـ«كارفور» (supermarket)", map_url: CARREFOUR, created_at: "2026-10-10T10:00:00Z" },
  { task_description: "وصول لـ«العطار» (spices)", map_url: ATTAR, created_at: "2026-10-10T12:00:00Z" },
  { task_description: "وصول لـ«بقالة» (supermarket)", map_url: null, created_at: "2026-10-10T13:00:00Z" },
];

Deno.test("store location: the latest store with a link, or the one named", () => {
  assertEquals(storeLocationFrom(ROWS), { store: "العطار", map_url: ATTAR, at: "2026-10-10T12:00:00Z" });
  assertEquals(storeLocationFrom(ROWS, "كارفور")?.map_url, CARREFOUR);
  // اسم أطول من المتسجل («كارفور مصر») بيلاقي «كارفور».
  assertEquals(storeLocationFrom(ROWS, "  كارفور مصر ")?.store, "كارفور");
  assertEquals(storeLocationFrom(ROWS, "سعودي"), null);
  assertEquals(storeLocationFrom([]), null);
  // رابط مش رابط خرايط (صف اتلعب فيه) مايترجعش.
  assertEquals(storeLocationFrom([{ task_description: "وصول لـ«x» (supermarket)", map_url: "javascript:alert(1)", created_at: "2026-10-10T12:00:00Z" }]), null);
});

Deno.test("store location: «هات اللوكيشن» brings the tool, a plain question doesn't", () => {
  for (const ask of ["هات اللوكيشن", "ابعتلي الموقع", "ابعتلي لوكيشن المحل ده", "فين المحل ده؟", "عايز مكان المحل", "وريني على الخريطة"]) {
    assert(intentToolHints(ask).includes("store_location"), ask);
  }
  for (const other of ["صرفت ٥٠ قهوة", "عامل إيه", "فين فلوسي راحت"]) {
    assert(!intentToolHints(other).includes("store_location"), other);
  }
  assert(scopeToolsForSpecialist(CHAT_TOOLS, "general", null, ["store_location"]).some((t) => t.name === "store_location"));
});

Deno.test("store location: a read, wired with its rule, never a write", () => {
  assert(CHAT_TOOLS.some((t) => t.name === "store_location"));
  assert(!MUTATING_TOOLS.includes("store_location"));
  const ctx = freshContext("u");
  assertEquals(VALIDATORS.store_location({}, {}, ctx), { ok: true });
  ctx.counts.store_location = 2;
  assertEquals((VALIDATORS.store_location({}, {}, ctx) as { ok: boolean }).ok, false);
  const prompt = buildChatSystemPrompt({}, false, new Set(["store_location"]));
  assert(prompt.includes("ماتسألوش هو في أنهي منطقة"));
  assert(!buildChatSystemPrompt({}, false, new Set([])).includes("لوكيشن المحل"));
});

Deno.test("store location: every link storeMapUrl makes fits the column's check (20261010180000)", async () => {
  const sql = await Deno.readTextFile(new URL("../../migrations/20261010180000_store_arrival_keeps_its_point.sql", import.meta.url));
  const pattern = /map_url ~ '([^']+)'/.exec(sql)?.[1];
  assert(pattern, "the migration's check pattern");
  const check = new RegExp(pattern);
  for (const [lat, lon] of [[30.0444196, 31.2357116], [-33.8688197, -151.2092955], [89.99999, 179.99999], [0.5, -0.5], [-9.1, 9.1]]) {
    const url = storeMapUrl(lat, lon);
    assert(url && check.test(url), `${lat},${lon} ⇒ ${url}`);
  }
  assert(!check.test(CARREFOUR + "&hl=ar"));
});

Deno.test("store arrival: the task row keeps the store's link, and only a valid one", () => {
  const row = storeArrivalTask("u", "وصول لـ«كارفور» (supermarket)", "body", 30.0444196, 31.2357116, "2026-10-10T10:00:00Z");
  assertEquals(row.map_url, CARREFOUR);
  assertEquals(row.kind, "store_arrival");
  assertEquals(storeLocationFrom([{ task_description: row.task_description as string, map_url: row.map_url ?? null, created_at: "2026-10-10T10:00:00Z" }])?.map_url, CARREFOUR);
  // من غير نقطة صالحة: نفس الصف من غير العمود (زي قبل الشريحة دي).
  assertEquals("map_url" in storeArrivalTask("u", "d", "b", 0, 0, "2026-10-10T10:00:00Z"), false);
  assertEquals("map_url" in storeArrivalTask("u", "d", "b", undefined, undefined, "2026-10-10T10:00:00Z"), false);
});
