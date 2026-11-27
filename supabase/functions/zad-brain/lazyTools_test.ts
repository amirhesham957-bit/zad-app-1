// م٤.٣ج — أدوات بالطلب (ZAD_ONDEMAND_PROMPT=1): كل أداة متوقعة من الـ٢٠٠ حالة يا معروضة كاملة يا قابلة للطلب بـload_tools،
// والقفل = من غير تغيير، وقاعدة المواعيد بالنية. الدقة الحية (الموديل بينادي load_tools صح؟) لسه ما اتقاسّتش.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildChatSystemPrompt, CHAT_TOOLS, lazyToolsForCall, ruleToolsFor } from "./index.ts";
import { intentToolHints, routeSpecialists, scopeToolsForSpecialist } from "./specialists.ts";
import { EVAL_CASES } from "./evals/cases.ts";
import { LOAD_TOOLS_NAME, requestedTools } from "./lazyTools.ts";

const SNAP = { currency: "EGP", country: "EG", name_asked_in_conversation: true };
const M_APPT = "**المواعيد والتذكيرات (appointments + now_local)**";

function withFlag<T>(on: boolean, f: () => T): T {
  const prev = Deno.env.get("ZAD_ONDEMAND_PROMPT");
  if (on) Deno.env.set("ZAD_ONDEMAND_PROMPT", "1"); else Deno.env.delete("ZAD_ONDEMAND_PROMPT");
  try { return f(); } finally { if (prev === undefined) Deno.env.delete("ZAD_ONDEMAND_PROMPT"); else Deno.env.set("ZAD_ONDEMAND_PROMPT", prev); }
}
function lazyFor(message: string) {
  return withFlag(true, () => {
    const { primary, secondary } = routeSpecialists(message);
    const hinted = intentToolHints(message, "");
    const scoped = scopeToolsForSpecialist(CHAT_TOOLS, primary, secondary, hinted, message);
    return { scoped, tools: lazyToolsForCall(scoped, hinted, [], [], false)! };
  });
}
function promptFor(message: string, on: boolean) {
  return withFlag(on, () => {
    const { primary, secondary } = routeSpecialists(message);
    const hinted = intentToolHints(message, "");
    const scoped = scopeToolsForSpecialist(CHAT_TOOLS, primary, secondary, hinted, message);
    return buildChatSystemPrompt(SNAP, false, ruleToolsFor(scoped, hinted, undefined, message));
  });
}
const fullDesc = (n: string) => CHAT_TOOLS.find((t) => t.name === n)!.description;

Deno.test("م٤.٣ج lazy tools: every expected tool is full or requestable via load_tools", () => {
  let viaLoad = 0, expected = 0;
  for (const c of EVAL_CASES) {
    const { scoped, tools } = lazyFor(c.message);
    for (const n of ["log_transaction", "read_house"]) {
      if (scoped.some((t) => t.name === n)) assertEquals(tools.find((t) => t.name === n)?.description, fullDesc(n), `${c.id}: ${n} must stay full`);
    }
    const en = (tools.find((t) => t.name === LOAD_TOOLS_NAME)?.input_schema.properties.names.items.enum ?? []) as string[];
    for (const n of en) assert(scoped.some((t) => t.name === n) && !tools.some((t) => t.name === n), `${c.id}: ${n} in enum but offered or out of scope`);
    const e = c.expect as { proposes?: string; executes?: string };
    const want = e.proposes ?? e.executes;
    if (!want) continue;
    expected++;
    const sent = tools.find((t) => t.name === want);
    if (sent) { assertEquals(sent.description, fullDesc(want), `${c.id}: ${want} must be full`); continue; }
    assert(en.includes(want), `${c.id}: ${want} neither offered nor requestable`);
    viaLoad++;
  }
  console.log(`[م٤.٣ج lazy] expectedTool=${expected} full=${expected - viaLoad} viaLoad=${viaLoad}`);
});

Deno.test("م٤.٣ج lazy tools: closed flag untouched, a request loads the tool full from the next call", () => {
  assertEquals(withFlag(false, () => lazyToolsForCall(CHAT_TOOLS, [], [], [], false)), null);
  withFlag(true, () => {
    const scoped = scopeToolsForSpecialist(CHAT_TOOLS, "finance", null, [], "x");
    const hist = [{ role: "assistant", toolCalls: [{ id: "1", name: LOAD_TOOLS_NAME, input: { names: ["add_subscription", 7] } }] }];
    assertEquals(requestedTools(hist), ["add_subscription"]);
    const after = lazyToolsForCall(scoped, [], [], hist as never, false)!;
    assertEquals(after.find((t) => t.name === "add_subscription")?.description, fullDesc("add_subscription"));
    assert(!(after.find((t) => t.name === LOAD_TOOLS_NAME)!.input_schema.properties.names.items.enum as string[]).includes("add_subscription"));
  });
});

Deno.test("م٤.٣ج appointment rule: by intent or request, absent on a plain expense, kept when closed", () => {
  assert(promptFor("فكرني بكرة الساعة ٥ بميعاد الدكتور", true).includes(M_APPT));
  assert(!promptFor("صرفت ٥٠ على القهوة", true).includes(M_APPT));
  assert(promptFor("صرفت ٥٠ على القهوة", false).includes(M_APPT));
  withFlag(true, () => {
    const scoped = scopeToolsForSpecialist(CHAT_TOOLS, "finance", null, [], "x");
    assert(buildChatSystemPrompt(SNAP, false, ruleToolsFor(scoped, ["add_appointment"], true, "x")).includes(M_APPT));
    assert(!buildChatSystemPrompt(SNAP, false, ruleToolsFor(scoped, [], true, "x")).includes(M_APPT));
  });
  for (const c of EVAL_CASES) {
    const e = c.expect as { proposes?: string; executes?: string };
    if ((e.proposes ?? e.executes) === "add_appointment") assert(promptFor(c.message, true).includes(M_APPT), c.id);
  }
});
