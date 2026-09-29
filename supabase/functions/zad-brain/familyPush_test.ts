import { assertEquals } from "jsr:@std/assert@1";
import { familyPushText } from "./familyPush.ts";

Deno.test("an SOS says so in the title", () => {
  assertEquals(
    familyPushText({ message_type: "SOS", message: "الرجاء الانتباه، حالة طوارئ!", alias: "أحمد" }),
    { title: "🚨 استغاثة من أحمد", body: "الرجاء الانتباه، حالة طوارئ!" },
  );
});

Deno.test("a child's request says whether it is pocket money or a purchase", () => {
  assertEquals(
    familyPushText({ message_type: "PURCHASE_REQUEST", message: "محتاج مصروف 50", metadata: '{"kind":"allowance"}', alias: "سلمى" })?.title,
    "سلمى طالب مصروف",
  );
  assertEquals(
    familyPushText({ message_type: "PURCHASE_REQUEST", message: "أحتاج 100 لشراء لعبة", metadata: "not json", alias: "سلمى" })?.title,
    "سلمى عايز يشتري حاجة",
  );
});

Deno.test("Zad's own lines and empty messages push nothing; long ones are cut", () => {
  assertEquals(familyPushText({ message_type: "TEXT", message: "تمام", sender_id: "zad_ai", alias: "زاد" }), null);
  assertEquals(familyPushText({ message_type: "TEXT", message: "   ", alias: "أحمد" }), null);
  const long = familyPushText({ message_type: "TEXT", message: "ا".repeat(300), alias: "" })!;
  assertEquals(long.title, "حد من العيلة في شات العيلة");
  assertEquals(long.body.length, 158);
});
