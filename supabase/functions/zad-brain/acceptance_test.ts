import { assertEquals } from "jsr:@std/assert@1";
import { ACCEPTANCE_CASES } from "./acceptance.ts";

const byId = (id: string) => ACCEPTANCE_CASES.find((c) => c.id === id)!;
const run = (id: string, reply: string, executed: string[] = [], appointmentsCreated = 0) =>
  byId(id).check({ reply, executed: executed.map((tool) => ({ tool })), proposals: [] }, { appointmentsCreated });

Deno.test("the replies the owner got on 2026-10-01 fail their acceptance lines", () => {
  // 20:02, «مرحبا» by voice.
  assertEquals(run("4_hello_after_unanswered", "يا أمير معلش مش طالع قدامي سعر الذهب الموثوق دلوقتي في البحث"), "answered the old gold question");
  // 20:05, «سعر الدهب» on Telegram.
  assertEquals(run("1_gold", "يا أمير دورت لك في النت بس مش طالع قدامي سعر موثوق ومظبوط للذهب"), "no price in the first sentence");
  // 14:51 and 14:52: two wake-up appointments for one request.
  assertEquals(run("3_reminder_once", "تمام", ["add_appointment"], 2), "2 appointments saved");
});

Deno.test("the replies the owner asked for pass", () => {
  assertEquals(run("4_hello_after_unanswered", "أهلاً يا أمير! أخبارك إيه؟"), null);
  assertEquals(run("1_gold", "عيار 21 النهارده بـ 6,120 جنيه حسب بنكي (1 أكتوبر 5 العصر)."), null);
  assertEquals(run("2_dollar", "الدولار النهارده بحوالي 48.6 جنيه."), null);
  assertEquals(run("3_reminder_once", "تمام، هفكرك 5:12", ["add_appointment"], 1), null);
  assertEquals(run("8_general_question", "مانشستر سيتي كسب آخر كاس عالم للأندية بنظامها القديم، وتشيلسي كسب نسخة 2025."), null);
  assertEquals(run("8_general_question", "معرفش، تعالى نبص على ميزانيتك"), "said it could not find it");
});

Deno.test("internal text in a reply fails every case", async () => {
  const { internalLeak } = await import("./acceptance.ts");
  assertEquals(internalLeak("المساعد وعد بحاجة متنفذتش (تذكير شرب المية مش موجود في الأدوات المنفذة).\n\nولا يهمك، سجلتهالك 👌"), "internal reviewer text in the reply");
  assertEquals(internalLeak("تمام، نديت add_appointment"), "tool name in the reply: add_appointment");
  assertEquals(internalLeak("ولا يهمك، سجلتهالك 👌 هفكّرك تشرب مية كمان دقيقتين."), null);
});
