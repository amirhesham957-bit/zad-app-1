// م٤.٦ — كل أداة ليها مجال، ولا أداة اتسابت من غير طريق للموديل، والمجال الصاحب بيعرض أداته.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { CHAT_TOOLS } from "./index.ts";
import { CROSS_DOMAIN_TOOLS, GENERAL_CORE_TOOLS, intentToolHints, scopeToolsForSpecialist, SPECIALIST_TOOL_SCOPE } from "./specialists.ts";
import { TOOL_DOMAIN, TURN_INJECTED_TOOLS, UNREACHABLE_TOOLS } from "./toolDomains.ts";

const names = CHAT_TOOLS.map((t) => t.name);
const hintSrc = intentToolHints.toString();
const inAnyScope = (n: string) => Object.values(SPECIALIST_TOOL_SCOPE).some((v) => v.includes(n));

Deno.test("م٤.٦ every chat tool has exactly one domain, and the table has no stale names", () => {
  assertEquals(names.filter((n) => !(n in TOOL_DOMAIN)), []);
  assertEquals(Object.keys(TOOL_DOMAIN).filter((n) => !names.includes(n)), []);
  assertEquals(new Set(names).size, names.length, "duplicate tool names");
});

Deno.test("م٤.٦ no tool is left behind: each is reachable by scope, core, cross-domain, intent or turn injection", () => {
  const orphans = names.filter((n) =>
    !inAnyScope(n) && !GENERAL_CORE_TOOLS.includes(n) && !CROSS_DOMAIN_TOOLS.includes(n) &&
    !hintSrc.includes(`"${n}"`) && !TURN_INJECTED_TOOLS.includes(n)
  );
  assertEquals([...orphans].sort(), [...UNREACHABLE_TOOLS].sort(), "unreachable list must match exactly");
});

Deno.test("م٤.٦ a specialist domain's own tools are offered to that specialist, and cross tools to all", () => {
  for (const sp of Object.keys(SPECIALIST_TOOL_SCOPE) as (keyof typeof SPECIALIST_TOOL_SCOPE)[]) {
    const offered = new Set(scopeToolsForSpecialist(CHAT_TOOLS, sp).map((t) => t.name));
    for (const [tool, dom] of Object.entries(TOOL_DOMAIN)) {
      if (dom === sp && inAnyScope(tool)) assert(offered.has(tool), `${sp} should offer its own tool ${tool}`);
    }
    for (const n of CROSS_DOMAIN_TOOLS) if (names.includes(n)) assert(offered.has(n), `${sp} missing cross tool ${n}`);
    // مفيش أداة مجال تاني بتتسرّب من غير ما تكون في نطاقه أو عابرة.
    for (const n of offered) {
      assert(SPECIALIST_TOOL_SCOPE[sp].includes(n) || CROSS_DOMAIN_TOOLS.includes(n), `${sp} leaked ${n}`);
    }
  }
});
