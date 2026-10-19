// إضافة رسالة بنك حقيقية لـ bank_corpus.json بعد تنقيحها (ZAD_PLAN ٣.٧).
//
//   deno run -A testdata/add_bank_case.ts --id eg-cib-talabat --market EG --title CIB \
//     --expect money --amount 250 --direction out --merchant TALABAT < message.txt
//
// من غير --write بيطبع الحالة بس، عشان حد يبص على النص المنقّح و«الأسماء للمراجعة» الأول.
// --package الافتراضي تطبيق رسايل جوجل: رسايل البنك بتوصل من هناك (CLAUDE.md).
import { redactBankMessage } from "./redactBankMessage.ts";

const args: Record<string, string> = {};
for (let i = 0; i < Deno.args.length; i++) {
  const a = Deno.args[i];
  if (!a.startsWith("--")) continue;
  const next = Deno.args[i + 1];
  args[a.slice(2)] = next && !next.startsWith("--") ? (i++, next) : "true";
}
const need = (k: string) => {
  if (!args[k]) throw new Error(`--${k} is required`);
  return args[k];
};

const expect = need("expect");
if (!["money", "reminder", "ignore"].includes(expect)) throw new Error("--expect money|reminder|ignore");
const amount = args.amount ? Number(args.amount) : null;
const direction = args.direction ?? null;
if (expect === "money" && direction !== "out" && direction !== "in") throw new Error("--direction out|in for money");

const raw = (await new Response(Deno.stdin.readable).text()).trim();
if (!raw) throw new Error("the message text comes on stdin");
const { text, reviewNames } = redactBankMessage(raw, amount);

const title = need("title");
const entry = {
  id: need("id"),
  market: need("market"),
  origin: "real",
  package: args.package ?? "com.google.android.apps.messaging",
  title,
  text,
  expect,
  amount,
  direction: expect === "money" ? direction : null,
  merchant: args.merchant ?? null,
  currency: args.currency ?? (args.market === "SA" ? "SAR" : "EGP"),
  knownSender: args.known ? args.known === "true" : true,
};

console.log(JSON.stringify(entry, null, 2));
if (reviewNames.length) console.error(`⚠️ راجع الأسماء دي قبل الحفظ (تاجر يفضل، شخص يتغيّر): ${reviewNames.join(" | ")}`);

if (args.write === "true") {
  const file = new URL("./bank_corpus.json", import.meta.url);
  const corpus = JSON.parse(await Deno.readTextFile(file));
  if (corpus.cases.some((c: { id: string }) => c.id === entry.id)) throw new Error(`id ${entry.id} is taken`);
  corpus.cases.push(entry);
  await Deno.writeTextFile(file, JSON.stringify(corpus, null, 2) + "\n");
  console.error(`added — ${corpus.cases.length} cases`);
}
