// رد الشات بصوت زاد: نص للتنفيذ والقوايم والأرقام، صوت للإحساس أو لو العميل بعت فويس.
import { assertEquals } from "jsr:@std/assert@1";
import { voiceReplyEmotion } from "./voiceReply.ts";

const say = (text: string, inboundVoice = false, transactional = false) => voiceReplyEmotion({ text, inboundVoice, transactional });

Deno.test("voice reply: encouragement and worry are said, plain answers stay text", () => {
  assertEquals(say("مبروك! وفرت الشهر ده أكتر من اللي فات 🎉"), "proud");
  assertEquals(say("خلي بالك، ميعاد الدكتور بكرة الصبح 🙏"), "caring");
  assertEquals(say("الجو حلو النهارده، تحب أقترح عليك حاجة؟"), null, "no clear feeling, typed message");
});

Deno.test("voice reply: a voice note gets a voice back, whatever the feeling", () => {
  assertEquals(say("الجو حلو النهارده، تحب أقترح عليك حاجة؟", true), "warm");
});

Deno.test("voice reply: receipts, lists, numbers and buttons stay text", () => {
  assertEquals(say("✅ تم تسجيل ٥٠ قهوة", true), null);
  assertEquals(say("ناقصك:\n- عيش\n- لبن", true), null);
  assertEquals(say("الكهربا 50 وShahid 300 ونتفليكس 300 والنت 400 — مبروك", true), null);
  assertEquals(say("مبروك! وفرت", true, true), null, "waiting on a confirm button");
  assertEquals(say("مبروك ".repeat(80), true), null, "too long to be a voice note");
  assertEquals(say("   ", true), null);
});
