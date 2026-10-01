import { assertEquals } from "jsr:@std/assert@1";
import { pickHistory, recordSharedTurn, SHARED_HISTORY_TURNS, toSharedHistory } from "./sharedConversation.ts";

Deno.test("rows come newest first; the brain reads them oldest first", () => {
  assertEquals(toSharedHistory([
    { role: "assistant", text: "سجلت ٥٠ جنيه قهوة" },
    { role: "user", text: "سجل ٥٠ جنيه قهوة" },
  ]), [
    { role: "user", text: "سجل ٥٠ جنيه قهوة" },
    { role: "assistant", text: "سجلت ٥٠ جنيه قهوة" },
  ]);
});

Deno.test("a turn said by voice or on Telegram is the history the app answers in", () => {
  const shared = [{ role: "user" as const, text: "من تليجرام" }];
  const client = [{ role: "user" as const, text: "من الموبايل" }];
  assertEquals(pickHistory(shared, client), shared);
});

Deno.test("nothing shared yet, or the read failed: the client's own history", () => {
  const client = [{ role: "user" as const, text: "من الموبايل" }];
  assertEquals(pickHistory([], client), client);
  assertEquals(pickHistory(null, client), client);
});

Deno.test("never more than the brain takes", () => {
  const many = Array.from({ length: 20 }, (_, i) => ({ role: "user" as const, text: `m${i}` }));
  assertEquals(pickHistory(many, []).length, SHARED_HISTORY_TURNS);
  assertEquals(pickHistory(many, [])[0].text, "m12");
});

Deno.test("an app turn is stored as the words, then the reply", async () => {
  const inserted: Array<{ role: string; text: string }> = [];
  const sb = {
    from: () => ({
      insert: (row: { role: string; text: string }) => {
        inserted.push(row);
        return Promise.resolve({ error: null });
      },
    }),
  } as unknown as Parameters<typeof recordSharedTurn>[0];
  await recordSharedTurn(sb, "u1", " فكرني بكرة ", "حاضر");
  assertEquals(inserted.map((r) => `${r.role}:${r.text}`), ["user:فكرني بكرة", "assistant:حاضر"]);
  inserted.length = 0;
  await recordSharedTurn(sb, "u1", "كلام", "  ");
  assertEquals(inserted, []);
});

import { markUnanswered, spokenRecord, UNANSWERED_MARK } from "./sharedConversation.ts";

Deno.test("an unanswered message is marked, so the next question does not carry it out again (2026-10-01)", () => {
  const history = markUnanswered([
    { role: "assistant", text: "تمام" },
    { role: "user", text: "ممكن تسجل في م عيدي اصحي كمان دقيقة و تنبهني" },
    { role: "user", text: "كم سعر زجاجة حليب فيفا في مصر" },
  ]);
  assertEquals(history[1].text?.endsWith(UNANSWERED_MARK), true);
  // The message being answered now is never marked; answered ones are left alone.
  assertEquals(history[2].text, "كم سعر زجاجة حليب فيفا في مصر");
  assertEquals(history[0].text, "تمام");
  // Marking twice does not stack.
  assertEquals(markUnanswered(history)[1].text, history[1].text);
});

Deno.test("spokenRecord keeps the receipts a turn answered with", () => {
  assertEquals(
    spokenRecord({ reply: "", executed: [{ tool: "add_appointment", summary: "تم تسجيل الميعاد «اصحى»" }], proposals: [] }),
    "✅ تم تسجيل الميعاد «اصحى»",
  );
  assertEquals(
    spokenRecord({ reply: "تمام", executed: [], proposals: [{ summary: "صرف ٥٠ قهوة" }] }),
    "تمام\n⏳ مستني تأكيد: صرف ٥٠ قهوة",
  );
  assertEquals(spokenRecord({ reply: "  " }), "");
});
