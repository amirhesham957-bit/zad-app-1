import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1";
import {
  COOLDOWN_MS,
  commercialSuppression,
  criticalLane,
  detectDistress,
  isCommercialAllowed,
  laneFor,
  memoryPolicy,
  normalizeArabic,
  replyPolicy,
  scrubForMemory,
} from "./ventGuard.ts";

const lvl = (t: string) => detectDistress(t).level;
const NOW = new Date("2026-11-22T10:00:00.000Z");

Deno.test("empty and neutral text is none", () => {
  assertEquals(detectDistress(""), { level: "none", signals: [] });
  assertEquals(lvl("اشتريت لبن وعيش النهارده"), "none");
});
Deno.test("egyptian venting", () => {
  assertEquals(lvl("انا ضغطان اوي الأيام دي"), "venting");
  assertEquals(lvl("تعبان نفسياً"), "venting");
  assertEquals(lvl("مخنوق"), "venting");
  assertEquals(lvl("زهقت من كل حاجة"), "venting");
  assertEquals(lvl("مش قادر أكمل كده"), "venting");
});
Deno.test("gulf venting", () => {
  assertEquals(lvl("ضاق صدري واجد"), "venting");
  assertEquals(lvl("طفشت من الدوام"), "venting");
  assertEquals(lvl("مو قادر استحمل"), "venting");
});
Deno.test("msa venting", () => {
  assertEquals(lvl("اشعر بالضيق"), "venting");
  assertEquals(lvl("لم أعد أحتمل هذا الضغط"), "venting");
});
Deno.test("normalization: tashkeel, elongation, alef/yaa/taa", () => {
  assertEquals(lvl("مَخْنُوووق"), "venting");
  assertEquals(lvl("ضغطــــان"), "venting");
  assertEquals(lvl("تعبانة نفسيا"), "venting");
  assertEquals(normalizeArabic("أ إ آ ى ة"), "ا ا ا ي ه");
});
Deno.test("negation of venting", () => {
  assertEquals(lvl("مش مخنوق والله"), "none");
  assertEquals(lvl("مو زهقان"), "none");
});
Deno.test("quoted venting is ignored", () => {
  assertEquals(lvl('صاحبي قال "انا مخنوق" وانا بطمنه'), "none");
  assertEquals(lvl("كتب «ضغطان» على الصورة"), "none");
});
Deno.test("explicit risk phrases", () => {
  assertEquals(lvl("عايز انتحر"), "risk");
  assertEquals(lvl("نفسي اموت"), "risk");
  assertEquals(lvl("ابي اموت"), "risk");
  assertEquals(lvl("مش عايز اعيش"), "risk");
  assertEquals(lvl("أريد أن أنهي حياتي"), "risk");
  assertEquals(lvl("هاقتل نفسي"), "risk");
  assertEquals(lvl("عايز اوذي نفسي"), "risk");
});
Deno.test("risk wins over venting", () => {
  assertEquals(lvl("انا مخنوق ونفسي اموت"), "risk");
});
Deno.test("risk is conservative: idioms are not risk", () => {
  assertEquals(lvl("هموت من الضحك"), "none");
  assertEquals(lvl("نفسي اموت من الجوع"), "venting");
  assertEquals(lvl("مش عايز اموت"), "none");
});
Deno.test("suppression: any distress suppresses 24h immediately", () => {
  for (const l of ["venting", "risk"] as const) {
    const s = commercialSuppression(l, NOW);
    assert(s.suppress);
    assertEquals(s.until, new Date(NOW.getTime() + COOLDOWN_MS).toISOString());
    assert(s.reasons.includes("no_sales") && s.reasons.includes("no_affiliate") && s.reasons.includes("no_marketing"));
  }
});
Deno.test("suppression window: cooldown from lastDistressAt, then released", () => {
  const last = new Date(NOW.getTime() - 23 * 3600_000).toISOString();
  assertFalse(isCommercialAllowed({ lastDistressAt: last }, NOW));
  assertEquals(commercialSuppression("none", NOW, { lastDistressAt: last }).reasons[0], "cooldown_active");
  const old = new Date(NOW.getTime() - 25 * 3600_000).toISOString();
  assert(isCommercialAllowed({ lastDistressAt: old }, NOW));
  assert(isCommercialAllowed(undefined, NOW));
  assert(isCommercialAllowed({ lastDistressAt: "garbage" }, NOW));
  assertFalse(commercialSuppression("none", NOW).suppress);
});
Deno.test("replyPolicy: venting listens, no support lines, no offers", () => {
  const p = replyPolicy("venting", "EG");
  assertEquals(p.mode, "listen");
  assertEquals(p.supportLines, undefined);
  for (const f of ["diagnosis", "treatment", "medical_claim", "offers"]) assert(p.forbid.includes(f as never));
});
Deno.test("replyPolicy: risk gives table lines for EG/SA/AE", () => {
  for (const c of ["EG", "SA", "AE", "eg"]) {
    const p = replyPolicy("risk", c);
    assertEquals(p.mode, "listen_plus_support");
    assert((p.supportLines?.length ?? 0) > 0);
    assert(p.supportLines!.every((l) => /^\d{3}$/.test(l.number)));
  }
});
Deno.test("replyPolicy: unknown country gets no fabricated number", () => {
  for (const c of ["FR", "", "XX"]) {
    const p = replyPolicy("risk", c);
    assertEquals(p.supportLines, undefined);
    assertEquals(p.genericText, "اتصل بالطوارئ في بلدك");
    assertFalse(/\d/.test(JSON.stringify(p)));
  }
});
Deno.test("memory: never long-term, never detail, ever", () => {
  for (const l of ["none", "venting", "risk"] as const) {
    const m = memoryPolicy(l);
    assertEquals(m.storeLongTerm, false);
    assertEquals(m.storeDetail, false);
  }
  assertFalse(memoryPolicy("none").allowEventFlag);
  assert(memoryPolicy("venting").allowEventFlag && memoryPolicy("risk").allowEventFlag);
});
Deno.test("scrubForMemory blanks distress text only", () => {
  assertEquals(scrubForMemory("انا مخنوق"), "");
  assertEquals(scrubForMemory("عايز انتحر"), "");
  assertEquals(scrubForMemory("اشتريت ارز"), "اشتريت ارز");
  assertEquals(scrubForMemory("اي حاجة", "venting"), "");
});
Deno.test("critical lane only for risk", () => {
  assert(criticalLane("risk"));
  assertFalse(criticalLane("venting"));
  assertFalse(criticalLane("none"));
  assertEquals(laneFor("risk"), "critical");
  assertEquals(laneFor("venting"), "normal");
});
Deno.test("no output contains diagnosis words", () => {
  const banned = ["اكتئاب", "اضطراب", "مرض", "علاج", "تشخيص", "depress", "anxiety", "disorder", "bipolar"];
  const outs: unknown[] = [];
  for (const t of ["مخنوق", "عايز انتحر", "ضغطان", "مكتئب"]) {
    const d = detectDistress(t);
    outs.push(d, commercialSuppression(d.level, NOW));
    for (const c of ["EG", "SA", "AE", "FR"]) outs.push(replyPolicy(d.level, c));
    outs.push(memoryPolicy(d.level));
  }
  const s = JSON.stringify(outs).toLowerCase();
  for (const w of banned) assertFalse(s.includes(w), w);
});
