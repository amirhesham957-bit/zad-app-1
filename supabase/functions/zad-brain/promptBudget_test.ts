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
