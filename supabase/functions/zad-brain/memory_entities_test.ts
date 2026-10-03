// الذاكرة بكيانات وزمن (20261003100000، docs/agent/ZAD_LIVING_BRAIN.md الشريحة ١).
import { assert, assertEquals } from "jsr:@std/assert@1";
import { entityRecallText, normalizeMemoryEntities, resolveValidUntil } from "./shared.ts";
import { memoryForSnapshot, parseFactSkillExtraction } from "./index.ts";
import { freshContext, validateRemember } from "./validators.ts";

// 2026-10-03 12:00 بتوقيت القاهرة (+03:00 صيفي).
const NOW = Date.parse("2026-10-03T09:00:00Z");
const CAIRO = "Africa/Cairo";

Deno.test("«أمي» و«ماما» كيان واحد، و«أنا» مش كيان", () => {
  const out = normalizeMemoryEntities([
    { kind: "person", name: "أمي" },
    { kind: "person", name: "ماما" },
    { kind: "person", name: "أنا" },
    { kind: "item", name: "قهوة" },
  ]);
  assertEquals(out, [
    { kind: "person", name: "ماما", key: "ماما" },
    { kind: "item", name: "قهوة", key: "قهوه" },
  ]);
});

Deno.test("نوع مش معروف بيتشال، والحد ٣", () => {
  const out = normalizeMemoryEntities([
    { kind: "pet", name: "بسبس" },
    { kind: "place", name: "مدرسة النيل" },
    { kind: "org", name: "البنك الأهلي" },
    { kind: "item", name: "شاي" },
    { kind: "person", name: "يوسف" },
  ]);
  assertEquals(out.map((e) => e.name), ["مدرسة النيل", "البنك الأهلي", "شاي"]);
  assertEquals(normalizeMemoryEntities("ماما"), []);
  assertEquals(normalizeMemoryEntities(undefined), []);
});

Deno.test("YYYY-MM-DD = لحد آخر اليوم ده بتوقيت العميل", () => {
  // آخر يوم ٩ أكتوبر في القاهرة = ١٠ أكتوبر ٠٠:٠٠ +03:00 = ٩ أكتوبر ٢١:٠٠ UTC.
  assertEquals(resolveValidUntil("2026-10-09", CAIRO, NOW), "2026-10-09T21:00:00.000Z");
  // النهارده نفسه لسه صحيح لحد آخره.
  assertEquals(resolveValidUntil("2026-10-03", CAIRO, NOW), "2026-10-03T21:00:00.000Z");
});

Deno.test("تاريخ فات، أو مش يوم، أو أبعد من سنتين = null", () => {
  assertEquals(resolveValidUntil("2026-10-02", CAIRO, NOW), null);
  assertEquals(resolveValidUntil("2026-02-30", CAIRO, NOW), null);
  assertEquals(resolveValidUntil("الجمعة", CAIRO, NOW), null);
  assertEquals(resolveValidUntil("2029-01-01", CAIRO, NOW), null);
  assertEquals(resolveValidUntil("", CAIRO, NOW), null);
  assertEquals(resolveValidUntil(undefined, CAIRO, NOW), null);
});

Deno.test("نص الاسترجاع: صلة القرابة متوحّدة، والحرف اللازق و«ال» بيتشالوا في النسخة التانية", () => {
  const t = entityRecallText("هي أمي عاملة إيه؟ وبالقهوة");
  const [base, variant] = t.split(" | ");
  assert(base.includes("امي"));
  assertEquals(variant.split(" ").includes("ماما"), true);
  assertEquals(variant.split(" ").includes("قهوه"), true);
  // عبارة من كلمتين تفضل متجاورة في النسخة الأولى.
  assert(entityRecallText("رحت كارفور المعادي").includes("كارفور المعادي"));
});

Deno.test("الاستخلاص بيقرا ABOUT وUNTIL", () => {
  const out = parseFactSkillExtraction(
    "FACT: أخو العميل أحمد قاعد عندهم في البيت\nSKILL: NONE\nABOUT: person:أحمد, place:البيت\nUNTIL: 2026-10-09",
  );
  assertEquals(out.fact, "أخو العميل أحمد قاعد عندهم في البيت");
  assertEquals(out.about.map((e) => `${e.kind}:${e.name}`), ["person:أحمد", "place:البيت"]);
  assertEquals(out.until, "2026-10-09");
});

Deno.test("الاستخلاص: NONE أو غياب السطرين = دائمة ومن غير كيانات، ومفيش كيانات من غير حقيقة", () => {
  const none = parseFactSkillExtraction("FACT: العميل بيحب القهوة من غير سكر\nSKILL: NONE\nABOUT: NONE\nUNTIL: NONE");
  assertEquals(none.about, []);
  assertEquals(none.until, null);
  const old = parseFactSkillExtraction("FACT: العميل بيحب القهوة من غير سكر\nSKILL: NONE");
  assertEquals(old.about, []);
  assertEquals(old.until, null);
  const noFact = parseFactSkillExtraction("FACT: NONE\nSKILL: NONE\nABOUT: person:ماما\nUNTIL: 2026-10-09");
  assertEquals(noFact.about, []);
  assertEquals(noFact.until, null);
});

Deno.test("الملاحظة في السناب شوت: until وabout بس لو ليهم قيمة", () => {
  const base = { id: "1", scope: "general", note: "ماما بتحب الشاي بالنعناع", confidence: 0.7, evidence_count: 2, last_seen: null };
  assertEquals("until" in memoryForSnapshot(base), false);
  assertEquals("about" in memoryForSnapshot({ ...base, about: [] }), false);
  const full = memoryForSnapshot({ ...base, valid_until: "2026-10-09T21:00:00+00:00", about: ["ماما"] });
  assertEquals(full.until, "2026-10-09");
  assertEquals(full.about, ["ماما"]);
});

Deno.test("remember بيرفض valid_until مش مفهوم أو فات، وبيقبل يوم جاي أو غيابه", async () => {
  const snap = { now_local: { time_zone: CAIRO, date: "2026-10-03" } };
  const note = "أخو العميل قاعد عندهم في البيت الأسبوع ده";
  const bad = await validateRemember({ note, valid_until: "الجمعة" }, snap, freshContext("u"));
  assertEquals(bad.ok, false);
  const past = await validateRemember({ note, valid_until: "2020-01-01" }, snap, freshContext("u"));
  assertEquals(past.ok, false);
  assertEquals((await validateRemember({ note, valid_until: "2099-01-01".replace("2099", String(new Date().getUTCFullYear() + 1)) }, snap, freshContext("u"))).ok, true);
  assertEquals((await validateRemember({ note }, snap, freshContext("u"))).ok, true);
  assertEquals((await validateRemember({ note, valid_until: "" }, snap, freshContext("u"))).ok, true);
});
