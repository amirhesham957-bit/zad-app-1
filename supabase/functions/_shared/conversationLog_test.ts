import { assertEquals } from "jsr:@std/assert@1";
import { isProactiveTurn, proactiveTurn, recordConversation, trimProactive } from "./conversationLog.ts";

Deno.test("a proactive message is marked as Zad's own, with its title once", () => {
  const t = proactiveTurn("🔔 زاد لاحظ إن إشعارات البنك وقفت", "مش بقدر أسمع إشعارات الدفع من ٣ أيام");
  assertEquals(isProactiveTurn(t), true);
  assertEquals(t.split("زاد لاحظ").length, 2);
  assertEquals(proactiveTurn("عنوان", "عنوان وكلام").endsWith("عنوان وكلام"), true);
});

Deno.test("a morning of alerts keeps only the last three in the window; the conversation stays whole", () => {
  const p = (n: number) => ({ role: "assistant", text: proactiveTurn(`تنبيه ${n}`, "") });
  const turns = [
    { role: "user", text: "الخميرة خلص كيس" }, { role: "assistant", text: "تمام" },
    p(1), p(2), p(3), p(4), p(5),
    { role: "user", text: "يعني إيه البنك؟" },
  ];
  const kept = trimProactive(turns);
  assertEquals(kept.length, 6);
  assertEquals(kept.filter((t) => isProactiveTurn(t.text)).map((t) => t.text.includes("تنبيه 3") || t.text.includes("تنبيه 4") || t.text.includes("تنبيه 5")), [true, true, true]);
  assertEquals(kept[0].text, "الخميرة خلص كيس");
});

Deno.test("turns are written in order, and a failed write never throws", async () => {
  const rows: string[] = [];
  const sb = { from: () => ({ insert: (r: { text: string }) => { rows.push(r.text); return Promise.resolve({ error: null }); } }) };
  await recordConversation(sb, "u", [{ role: "user", text: "[بعت صورة: فاتورة]" }, { role: "assistant", text: "اتزوّد ٣ أصناف" }, { role: "assistant", text: "  " }]);
  assertEquals(rows, ["[بعت صورة: فاتورة]", "اتزوّد ٣ أصناف"]);
  await recordConversation({ from: () => { throw new Error("down"); } }, "u", [{ role: "user", text: "x" }]);
});
