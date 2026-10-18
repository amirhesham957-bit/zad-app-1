import { assertEquals } from "jsr:@std/assert@1";
import { heaviestKeys, promptSizes } from "./promptBudget.ts";

Deno.test("the heaviest snapshot keys come first, and empty ones are left out", () => {
  assertEquals(
    Object.keys(heaviestKeys({ small: "ab", big: "x".repeat(50), none: null, empty: [], mid: { a: "yyyy" } })),
    ["big", "mid", "small"],
  );
  assertEquals(Object.keys(heaviestKeys({ a: "aaaa", b: "bbbbb", c: "cccccc" }, 2)), ["c", "b"]);
});

Deno.test("every part is measured, and the total is what was sent", () => {
  const s = promptSizes({
    parts: { soul: "abc", lessons: "", chat: undefined, skills: "de" },
    snapshot: { pantry: ["rice"] },
    tools: [{ name: "t" }],
    history: [{ text: "hi" }, { text: "there" }],
  });
  assertEquals(s.parts, { soul: 3, skills: 2 });
  assertEquals(s.tools_count, 1);
  assertEquals(s.tools_chars, JSON.stringify([{ name: "t" }]).length);
  assertEquals(s.history_chars, 7);
  assertEquals(s.history_turns, 2);
  assertEquals(s.total_chars, 3 + 2 + s.tools_chars + 7);
});

Deno.test("a lean tool keeps its name, types, enums and required — not the explanations", async () => {
  const { leanTools } = await import("./promptBudget.ts");
  const tool = {
    name: "add_appointment",
    description: "سجّل ميعاد. احسب starts_at من now_local",
    input_schema: {
      type: "object",
      properties: { kind: { type: "string", enum: ["work", "other"], description: "نوعه" } },
      required: ["kind"],
    },
  };
  const [lean] = leanTools([tool], new Set());
  assertEquals(lean.description, "سجّل ميعاد");
  assertEquals(lean.input_schema as unknown, { type: "object", properties: { kind: { type: "string", enum: ["work", "other"] } }, required: ["kind"] });
  // اللي اتنادت أو عليها نية بتفضل كاملة.
  assertEquals(leanTools([tool], new Set(["add_appointment"]))[0], tool);
});

Deno.test("context diet 3b: Groq gets every specialist tool, lean, instead of dropping half", async () => {
  const { CHAT_TOOLS, groqSystemFor, groqToolsFor, toolsForCall } = await import("./index.ts");
  const { fitForGroq } = await import("./callModel.ts");
  const { intentToolHints, scopeToolsForSpecialist } = await import("./specialists.ts");
  const tools = scopeToolsForSpecialist(CHAT_TOOLS, "finance", null, intentToolHints("مرحبا"));
  const fitted = fitForGroq({
    system: groqSystemFor({ country: "EG", currency: "EGP" }, "مرحبا"),
    tools: groqToolsFor(tools, [], "مرحبا"),
    history: [{ role: "user", text: "مرحبا" }],
    maxTokens: 1200,
  });
  // Full definitions: finance reaches Groq with 22 of its 47 tools; lean, 42 of them
  // (measured after the specialists' cross tools came back, 2026-10-18).
  const full = fitForGroq({
    system: groqSystemFor({ country: "EG", currency: "EGP" }, "مرحبا"),
    tools, history: [{ role: "user", text: "مرحبا" }], maxTokens: 1200,
  });
  assertEquals(fitted.tools.length >= Math.floor(tools.length * 0.85), true, `${fitted.tools.length} of ${tools.length}`);
  assertEquals(fitted.tools.length >= full.tools.length + 15, true, `lean ${fitted.tools.length} vs full ${full.tools.length}`);
  const byName = new Map(groqToolsFor(tools, [], "مرحبا").map((t) => [t.name, t]));
  // أقسام read_house وفئات log_transaction جوه الوصف — كاملين دايماً.
  for (const n of ["read_house", "log_transaction"]) {
    assertEquals(byName.get(n), tools.find((t) => t.name === n));
  }

  // النداء الأول على Gemini: التلاتة بس خفاف، والباقي كامل.
  const first = toolsForCall(tools, [], [], 0);
  const changed = first.filter((t, i) => t !== tools[i]).map((t) => t.name).sort();
  assertEquals(changed, ["app_command", "remember", "update_appointment"].filter((n) => tools.some((t) => t.name === n)).sort());
  // عليهم نية ⇒ كاملين.
  assertEquals(toolsForCall(tools, ["remember"], [], 0).find((t) => t.name === "remember"), tools.find((t) => t.name === "remember"));
});
