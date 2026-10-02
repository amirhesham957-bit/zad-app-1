// تشخيص زاد ٢.١: «مرحبا» مابتشيلش قواعد وأدوات مالهاش علاقة بيها.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildChatSystemPrompt, CHAT_TOOLS } from "./index.ts";
import { GENERAL_CORE_TOOLS, intentToolHints, scopeToolsForSpecialist } from "./specialists.ts";
import { soulBlock } from "./soul.ts";

const snap = { country: "EG", currency: "EGP", family: null, life_goals: [], broke_mode: null, savings_challenge: null, season: null };
const general = (message: string) => scopeToolsForSpecialist(CHAT_TOOLS, "general", null, intentToolHints(message));

Deno.test("a greeting carries only the core tools and their rules", () => {
  const tools = general("مرحبا");
  assertEquals(tools.map((t) => t.name).sort(), [...GENERAL_CORE_TOOLS].sort());
  const prompt = buildChatSystemPrompt(snap, false, new Set(tools.map((t) => t.name)));
  assert(!prompt.includes("شيف زاد"));
  assert(!prompt.includes("تحدي التوفير"));
  assert(!prompt.includes("وضع الطوارئ"));
  assert(!prompt.includes("المواسم (season)"));
  // From the cron and the probe (no offered set) every rule is there, as before.
  const all = buildChatSystemPrompt(snap);
  assert(all.includes("شيف زاد") && all.includes("وضع الطوارئ"));
});

Deno.test("a message that needs a moved tool gets it, and its rule", () => {
  const cases: Array<[string, string]> = [
    ["أنا مفلس خلاص", "set_broke_mode"],
    ["أطبخ إيه النهارده؟", "suggest_recipes"],
    ["فين أقرب سوبر ماركت؟", "find_nearby_stores"],
    ["عايز أكلم حد من الدعم، التطبيق بايظ", "open_support_ticket"],
    ["سعر الدهب عيار ٢١", "gold_price"],
    ["الدولار بكام النهارده؟", "fetch_current_exchange_rate"],
    ["فكّرني لما أوصل البيت آخد الغسيل", "add_place_reminder"],
  ];
  for (const [message, tool] of cases) {
    assert(general(message).some((t) => t.name === tool), `${message} ⇒ ${tool}`);
  }
  const broke = buildChatSystemPrompt(snap, false, new Set(general("أنا مفلس خلاص").map((t) => t.name)));
  assert(broke.includes("وضع الطوارئ"));
});

Deno.test("what a greeting sends, measured", () => {
  const tools = general("مرحبا");
  const prompt = soulBlock() + buildChatSystemPrompt(snap, false, new Set(tools.map((t) => t.name)));
  const before = soulBlock() + buildChatSystemPrompt(snap);
  const beforeTools = CHAT_TOOLS.filter((t) => [...GENERAL_CORE_TOOLS, "gold_price", "fetch_current_exchange_rate",
    "open_support_ticket", "add_place_reminder", "set_broke_mode", "suggest_recipes", "find_nearby_stores"].includes(t.name));
  const now = prompt.length + JSON.stringify(tools).length;
  const was = before.length + JSON.stringify(beforeTools).length;
  console.log(`greeting: ${now} chars (was ${was}); tools ${tools.length} (was ${beforeTools.length})`);
  assert(now < was - 3000, `saved only ${was - now} chars`);
});
