import { assert, assertEquals } from "jsr:@std/assert@1";
import { botDialectFor, localizeBotText } from "./botDialect.ts";

Deno.test("fixed bot messages speak the customer's dialect", () => {
  assertEquals(localizeBotText("تمام، ملغيته ✖️", "GULF"), "تمام، ألغيته ✖️");
  assertEquals(localizeBotText("مفيش تنبيهات معلقة دلوقتي 👍", "LEVANT"), "ما في تنبيهات معلقة هلق 👍");
  assertEquals(localizeBotText("حصلت مشكلة، جرب تاني.", "EN"), "Something went wrong, try again.");
  assertEquals(localizeBotText("تمام، ملغيته ✖️", "EG"), "تمام، ملغيته ✖️");
});

Deno.test("messages with names keep the name and only the fixed part changes", () => {
  assertEquals(localizeBotText("اتسجل ✅ ‏قهوة‏ — ‏50 ر.س‏", "GULF"), "انسجل ✅ ‏قهوة‏ — ‏50 ر.س‏");
  const med = localizeBotText("اتسجل ✅ بنادول — المواعيد: 08:00\nهتلاقي التذكير شغال في التطبيق بعد أول فتح.", "EN");
  assert(med.startsWith("Logged ✅ بنادول — times: 08:00"));
});

Deno.test("brain replies are never rewritten — only exact fixed messages match", () => {
  const brain = "أبشر، سجلت لك القهوة ومصروفك اليوم باقي ١٢٠ — ولا يهمك مش هتتحسب مرتين";
  assertEquals(localizeBotText(brain, "LEVANT"), brain);
});

Deno.test("dialect families map to the bot's variants", () => {
  assertEquals(botDialectFor("SA"), "GULF");
  assertEquals(botDialectFor("IQ"), "GULF");
  assertEquals(botDialectFor("LEVANT"), "LEVANT");
  assertEquals(botDialectFor("TN"), "MAGHREB");
  assertEquals(botDialectFor("TR"), "EN");
  assertEquals(botDialectFor("EG"), "EG");
});

Deno.test("every fixed ctx.reply message in index.ts has dialect variants (new ones must be added)", async () => {
  const src = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  const literals = [...src.matchAll(/ctx\.reply\("((?:[^"\\]|\\.)*)"/g)].map((m) => m[1]);
  const merged = [...src.matchAll(/ctx\.reply\(resolved\.already_resolved \? "([^"]+)" : "([^"]+)"\)/g)].flatMap((m) => [m[1], m[2]]);
  const missing = [...new Set([...literals, ...merged])].filter((t) => localizeBotText(t, "EN") === t);
  assertEquals(missing, []);
});
