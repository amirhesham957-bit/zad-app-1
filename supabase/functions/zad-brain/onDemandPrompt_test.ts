// م٤.٣ — eval حتمي (من غير موديل) لتحميل القواعد والأدوات عند الطلب. بيمشي على الـ٢٠٠ حالة في evals/cases.ts:
// الأداة المتوقعة لازم تفضل معروضة، وقاعدتها تفضل في البرومبت، وحجم السياق ينزل. الدقة الحقيقية (الموديل بيستجيب
// صح؟) بتتقاس بليلة الـeval الحية (acceptance probe) قبل ما ZAD_ONDEMAND_PROMPT يتفتح في الإنتاج.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildChatSystemPrompt, CHAT_TOOLS, INTENT_RULE_TOOLS, lazyToolsForCall, ruleToolsFor, toolsForCall } from "./index.ts";
import { intentToolHints, routeSpecialists, scopeToolsForSpecialist, specialistPromptBlock } from "./specialists.ts";
import type { SpecialistId } from "./specialists.ts";
import { soulBlock } from "./soul.ts";
import { EVAL_CASES } from "./evals/cases.ts";

const SNAP = { currency: "EGP", country: "EG", name_asked_in_conversation: true };

function withFlag<T>(on: boolean, f: () => T): T {
  const prev = Deno.env.get("ZAD_ONDEMAND_PROMPT");
  if (on) Deno.env.set("ZAD_ONDEMAND_PROMPT", "1"); else Deno.env.delete("ZAD_ONDEMAND_PROMPT");
  try { return f(); } finally { if (prev === undefined) Deno.env.delete("ZAD_ONDEMAND_PROMPT"); else Deno.env.set("ZAD_ONDEMAND_PROMPT", prev); }
}

function turn(message: string, on: boolean) {
  return withFlag(on, () => {
    const { primary, secondary } = routeSpecialists(message);
    const hinted = intentToolHints(message, "");
    const scoped = scopeToolsForSpecialist(CHAT_TOOLS, primary, secondary, hinted, message);
    const rules = ruleToolsFor(scoped, hinted, undefined, message);
    const chat = buildChatSystemPrompt(SNAP, false, rules);
    const tools = lazyToolsForCall(scoped, hinted, [], [], false) ?? toolsForCall(scoped, hinted, [], 0);
    const chars = JSON.stringify(tools).length + chat.length + soulBlock(undefined).length + (specialistPromptBlock(primary, secondary) ?? "").length;
    return { scoped, hinted, rules, chat, tools, tok: Math.round(chars / 3.5) };
  });
}

Deno.test("م٤.٣ on-demand: expected tools stay offered, rules for them stay, context shrinks", () => {
  const off: number[] = [], on: number[] = [];
  let lostRule = 0, leanExpected = 0, expectedTools = 0;
  for (const c of EVAL_CASES) {
    const a = turn(c.message, false), b = turn(c.message, true);
    off.push(a.tok); on.push(b.tok);
    const e = c.expect as { proposes?: string; executes?: string };
    const want = e.proposes ?? e.executes;
    if (!want) continue;
    expectedTools++;
    assert(b.scoped.some((t) => t.name === want), `${c.id}: ${want} not offered`);
    // الأداة موجودة دايماً في الاتنين؛ لو خفيفة فالـschema بأنواعها لسه موجود.
    const sent = b.tools.find((t) => t.name === want)!;
    assert(sent.input_schema, `${c.id}: ${want} lost its schema`);
    if (sent.description !== CHAT_TOOLS.find((t) => t.name === want)!.description) leanExpected++;
    if (INTENT_RULE_TOOLS.has(want) && a.scoped.some((t) => t.name === want) && !b.rules.has(want)) lostRule++;
  }
  off.sort((x, y) => x - y); on.sort((x, y) => x - y);
  const q = (r: number[], p: number) => r[Math.min(r.length - 1, Math.floor(r.length * p))];
  console.log(`[م٤.٣ ondemand] cases=${EVAL_CASES.length} expectedTool=${expectedTools} leanExpected=${leanExpected} lostRule=${lostRule}\n  off p50=${q(off, .5)} p90=${q(off, .9)}  on p50=${q(on, .5)} p90=${q(on, .9)} (tok, no snapshot)`);
  assertEquals(lostRule, 0);
  assert(q(on, .5) < q(off, .5), "on-demand must shrink the median turn");
  assert(q(on, .5) < 4600, `م٤.٣ج: per-turn p50 regressed above 4600 tok (${q(on, .5)})`);
});

Deno.test("م٤.٣ on-demand: money tool and hinted tools stay full; flag off = unchanged", () => {
  const msg = "صرفت ٥٠ على القهوة";
  const on = turn(msg, true), off = turn(msg, false);
  const full = (r: ReturnType<typeof turn>, n: string) => r.tools.find((t) => t.name === n)?.description === CHAT_TOOLS.find((t) => t.name === n)?.description;
  assert(full(on, "log_transaction"));
  assert(!full(on, "add_inventory_item") || !on.scoped.some((t) => t.name === "add_inventory_item"));
  assert(full(off, "add_inventory_item") || !off.scoped.some((t) => t.name === "add_inventory_item"));
  const rec = turn("اطبخ ايه النهارده", true);
  assert(rec.chat.includes("suggest_recipes"), "recipe rule loads on recipe intent");
  assert(!turn("صرفت ٥٠ على القهوة", true).chat.includes("suggest_recipes"), "recipe rule absent without intent");
});

// م٤.٣ الخطوة ٢ — نطاق أضيق لكل تخصص: القفل = نفس الأدوات بالظبط (مع الرسالة وبدونها)، والفتح بيشيل أدوات التعديل
// والمسح بس لو مفيش فعل تعديل ولا نية، وفعل التعديل بيرجّعها.
Deno.test("م٤.٣ specialty scope: flag closed = identical tool set; open defers edit/delete until intent", () => {
  for (const c of EVAL_CASES) {
    const { primary, secondary } = routeSpecialists(c.message);
    const hinted = intentToolHints(c.message, "");
    const names = (msg?: string) => withFlag(false, () => scopeToolsForSpecialist(CHAT_TOOLS, primary, secondary, hinted, msg).map((t) => t.name));
    assertEquals(names(c.message), names(undefined), `${c.id}: closed flag must not change the tool set`);
    assertEquals(names(undefined), scopeToolsForSpecialist(CHAT_TOOLS, primary, secondary, hinted).map((t) => t.name), c.id);
  }
  const names = (msg: string) => withFlag(true, () => {
    const { primary, secondary } = routeSpecialists(msg);
    return scopeToolsForSpecialist(CHAT_TOOLS, primary, secondary, intentToolHints(msg, ""), msg).map((t) => t.name);
  });
  assert(!names("مصاريف الشهر ده كام وايه القسط الجاي").includes("delete_obligation"));
  assert(names("امسح القسط ده").includes("delete_obligation"), "edit verb brings delete back");
  assert(names("عدل القسط بتاعي").includes("update_obligation"));
  assert(withFlag(true, () => scopeToolsForSpecialist(CHAT_TOOLS, "finance", null, []).some((t) => t.name === "delete_obligation")), "no message = full scope");
});

// م٤.٣ب — قواعد بالنية: كل قاعدة بتظهر لما رسالتها تطلبها وماتظهرش من غيرها، والمقفول = القواعد كلها زي ما كانت.
const FULL = { currency: "EGP", country: "EG", name_asked_in_conversation: true, family: { kids_places: [], polls: [], chat_recent: [] }, life_goals: [{ title: "عمرة" }] };
function rulesFor(message: string, on: boolean, snap: Record<string, unknown> = FULL, force?: SpecialistId) {
  return withFlag(on, () => {
    const routed = routeSpecialists(message);
    const primary = force ?? routed.primary, secondary = force ? null : routed.secondary;
    const hinted = intentToolHints(message, "");
    const scoped = scopeToolsForSpecialist(CHAT_TOOLS, primary, secondary, hinted, message);
    const p = buildChatSystemPrompt(snap, false, ruleToolsFor(scoped, hinted, undefined, message));
    return p.slice(0, p.lastIndexOf("=== SNAPSHOT ==="));
  });
}
const MARKERS: Record<string, string> = {
  decision: "**القرارات الكبيرة**", resilience: "**شهر صعب**", circumstance: "**حالة البيت (circumstance)**",
  occasion: "**المناسبات**", location: "**لوكيشن المحل**", channels: "**قدراتك في كل قناة**", ticket: "**شكوى أو مشكلة محتاجة إنسان**",
  goals: "**أهداف حياة العميل (life_goals)**", kids: "**family.kids_places**", polls: "**family.polls**",
};
Deno.test("م٤.٣ب rules by intent: each rule loads on its intent, absent otherwise, closed flag keeps all", () => {
  // الأدوات دي بتتعرض لوكيل المال (general مابيعرضهاش أصلاً، فمفيش قاعدة تتحمّل له في الحالتين).
  const FIN: Record<string, SpecialistId> = { decision: "finance", resilience: "finance", circumstance: "pharmacy" };
  const cases: Array<[string, string]> = [
    ["لو اشتريت عربية بـ٣٠٠ ألف ينفع؟", "decision"], ["الشهر ده تقيل ومش هنعدي", "resilience"],
    ["ابويا عيان في المستشفى هدي التنبيهات", "circumstance"], ["عيد ميلاد مراتي ١٢ مارس", "occasion"],
    ["هات اللوكيشن بتاع المحل", "location"], ["ترد عليا فويس في تليجرام؟", "channels"],
    ["عايز اكلم حد من الدعم", "ticket"], ["عايز اعدل هدف العمرة بتاعي", "goals"],
    ["ابني وصل المدرسة؟ فين عمر", "kids"], ["العيلة قالت ايه في التصويت", "polls"],
  ];
  for (const [msg, key] of cases) {
    assert(rulesFor(msg, true, FULL, FIN[key]).includes(MARKERS[key]), `${key} must load for: ${msg}`);
    assert(rulesFor(msg, false, FULL, FIN[key]).includes(MARKERS[key]), `closed flag keeps ${key}`);
    // نفس الوكيل بنفس القاعدة من غير النية = مش موجودة.
    if (FIN[key]) assert(!rulesFor("صرفت ٥٠ على القهوة", true, FULL, FIN[key]).includes(MARKERS[key]), `${key} absent without intent`);
  }
  const neutral = rulesFor("صرفت ٥٠ على القهوة", true, FULL, "finance");
  for (const [k, m] of Object.entries(MARKERS)) assert(!neutral.includes(m), `${k} must be absent on a plain expense`);
  // قواعد السلامة والتنفيذ ماتتشالش بأي نية.
  for (const m of ["ممنوع منعاً باتاً تذكر أو تقترح أو تجدول أي دوا", "**الدكتور أو الصيدلي**", "**متحكيش نتايج الأدوات", "**التنفيذ الفوري**", "**family.chat_recent**"]) {
    assert(neutral.includes(m), `safety rule kept: ${m}`);
  }
});

Deno.test("م٤.٣ب rules by intent: no eval case loses the rule of its expected tool, token estimate", () => {
  const off: number[] = [], on: number[] = [];
  for (const c of EVAL_CASES) {
    off.push(rulesFor(c.message, false).length); on.push(rulesFor(c.message, true).length);
    const e = c.expect as { proposes?: string; executes?: string };
    const want = e.proposes ?? e.executes;
    if (want === "decision_impact") assert(rulesFor(c.message, true).includes(MARKERS.decision), c.id);
    if (want === "store_location") assert(rulesFor(c.message, true).includes(MARKERS.location), c.id);
    if (want === "remember_occasion") assert(rulesFor(c.message, true).includes(MARKERS.occasion), c.id);
    if (want === "open_support_ticket") assert(rulesFor(c.message, true).includes(MARKERS.ticket), c.id);
  }
  const med = (r: number[]) => [...r].sort((a, b) => a - b)[Math.floor(r.length / 2)];
  console.log(`[م٤.٣ب rules] full-snapshot rules chars p50 off=${med(off)} (~${Math.round(med(off) / 3.5)} tok) on=${med(on)} (~${Math.round(med(on) / 3.5)} tok)`);
  assert(med(on) < med(off));
});
