// ZAD_PLAN 3.11: a correction becomes a nightly case.
import { assertEquals } from "jsr:@std/assert@1";
import { judgeEval } from "./judge.ts";
import { lessonCase } from "./lessons.ts";

Deno.test("a category correction replays as «log it» with the customer's category", () => {
  const c = lessonCase({ id: "5f0c2d1e-aaaa-4bbb-8ccc-0123456789ab", subject: "  كارفور   المعادي ", right_answer: "بقالة" })!;
  assertEquals(c.id, "lesson_5f0c2d1eaaaa");
  assertEquals(c.category, "lesson");
  assertEquals(c.message, "سجل 50 كارفور المعادي");
  const turn = (category: string) => ({
    reply: "أسجلها؟", executed: [], proposals: [{ tool: "log_transaction", input: { amount: 50, category } }],
  });
  assertEquals(judgeEval(c, turn("بقالة")), null);
  assertEquals(judgeEval(c, turn("مطاعم"))?.startsWith("log_transaction.category"), true);
});

Deno.test("a row missing its subject or answer is not a case", () => {
  assertEquals(lessonCase({ id: "x1", subject: "", right_answer: "بقالة" }), null);
  assertEquals(lessonCase({ id: "x1", subject: "كارفور", right_answer: " " }), null);
  assertEquals(lessonCase({ subject: "كارفور", right_answer: "بقالة" }), null);
});
