// «تحب أساعدك في حاجة تانية؟» بيتشال — والفضول والعرض المحدد فاضلين. الأمثلة من ردود زاد الحقيقية.
import { assertEquals } from "jsr:@std/assert@1";
import { dropServiceCloser } from "./persona.ts";

Deno.test("a generic service question at the end is dropped, and only it", () => {
  assertEquals(
    dropServiceCloser("تمام يا ميرو، سجلت إن الدقيق بقى نصه.\n\nتحب أساعدك بحاجة تانية تخص البيت أو المصاريف؟"),
    "تمام يا ميرو، سجلت إن الدقيق بقى نصه.",
  );
  assertEquals(dropServiceCloser("ابشر، جهزتها لك. تامرني بشي ثاني يا بعد حيّي؟"), "ابشر، جهزتها لك.");
  assertEquals(
    dropServiceCloser("دي أحلى تلات حاجات عندي. حبّيت أنهي فيهم أكتر؟ ولا أضبطلك حاجة تانية؟ 😊"),
    "دي أحلى تلات حاجات عندي. حبّيت أنهي فيهم أكتر؟",
  );
  assertEquals(dropServiceCloser("ضفتهم. تحب أضيف لك حاجة تانية للمخزون أو قائمة الشراء؟"), "ضفتهم.");
});

Deno.test("curiosity and a specific offer stay", () => {
  for (const r of [
    "هههه طيب. قولي، روقت ولا لسه رايق؟ شطّبت تمرين الجيم ولا لسه قدامك؟",
    "خلص اللبن. تحب أضيفها لك في قائمة الشراء؟",
    "الدولار ٥٣٫٤٥ النهارده. تشرب إيه بقى على ما الساعات تلف؟ ☕️✨",
    "الكشف بكام؟",
    "تحب أساعدك بحاجة تانية؟",
  ]) {
    assertEquals(dropServiceCloser(r), r, r);
  }
});

Deno.test("the acceptance probe fails a reply that still ends like a call centre", async () => {
  const { machineCloser } = await import("./acceptance.ts");
  assertEquals(machineCloser("تمام. تحب أساعدك بحاجة تانية؟") !== null, true);
  assertEquals(machineCloser("تمام. شطّبت تمرين الجيم؟"), null);
});
