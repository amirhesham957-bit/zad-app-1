// كل عميل في سوقه (ZAD_PLAN ٣.١٣): برومبت حساب سعودي مافيهوش حاجة مصرية، والعكس.
//
// الشخصية (soul.ts) بتتبعت لكل عميل في كل لفة، وكان فيها مثال ثابت «كده هتخلص الشهر بـ٣٠٠ جنيه» — العميل
// السعودي كان بياخده كل مرة. التست ده بيبني برومبت الشات والتحليل لحساب SA وحساب EG ويدوّر على علامات
// السوق التاني. التعليمات اللي بتسمّي العملات عشان تمنع افتراضها مستثناة بالنص.
import { assertEquals } from "jsr:@std/assert@1";
import { buildChatSystemPrompt, buildSystemPrompt } from "./index.ts";
import { soulBlock } from "./soul.ts";

// «مصر» ككلمة لوحدها بس — «مصروف» و«مصاريف» مش علامة.
const EGYPT = /جنيه|جنية|EGP|InstaPay|إنستاباي|انستاباي|فودافون كاش|خير زمان|أولاد رجب|شم النسيم|القاهرة|(?<![\p{L}])مصر(?![\p{L}])/gu;
const SAUDI = /(?<![\p{L}])ريال|SAR\b|STC Pay|الراجحي|بنده|العثيم|الرياض|يوم التأسيس|اليوم الوطني|(?<![\p{L}])السعودية/gu;

/** تعليمات بتسمّي العملات عشان تمنع إن الموديل يفترض واحدة — مش محتوى لسوق. */
const INSTRUCTIONS = [
  "ممنوع تفترض ريال أو جنيه أو أي عملة من عندك",
];

function leaks(text: string, re: RegExp): string[] {
  let t = text;
  for (const s of INSTRUCTIONS) t = t.split(s).join("");
  return [...t.matchAll(re)].map((m) => t.slice(Math.max(0, m.index! - 40), m.index! + 30).replace(/\n/g, " "));
}

const SA = { country: "SA", currency: "SAR" };
const EG = { country: "EG", currency: "EGP" };

Deno.test("the persona every customer gets names no market", () => {
  assertEquals(leaks(soulBlock(), EGYPT).filter((l) => !l.includes("لو مصري")), []);
  assertEquals(leaks(soulBlock(), SAUDI), []);
});

Deno.test("a Saudi account's prompts carry nothing Egyptian", () => {
  assertEquals(leaks(soulBlock() + buildChatSystemPrompt(SA), EGYPT).filter((l) => !l.includes("لو مصري")), []);
  assertEquals(leaks(buildSystemPrompt(SA), EGYPT).filter((l) => !l.includes("لو مصري")), []);
});

Deno.test("an Egyptian account's prompts carry nothing Saudi", () => {
  assertEquals(leaks(soulBlock() + buildChatSystemPrompt(EG), SAUDI), []);
  assertEquals(leaks(buildSystemPrompt(EG), SAUDI), []);
});
