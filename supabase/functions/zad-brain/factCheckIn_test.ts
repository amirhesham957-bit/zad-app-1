// P3.1: فلتر الهزار موصّل في البرومبت وحلقة الأدوات والمسار السريع، وسؤال الحقيقة مقفول افتراضياً وكل كتابته من الباب.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { buildChatSystemPrompt } from "./index.ts";
import { handleFactAnswer, learnFactsFromChat, runNightlyFactInference } from "./factCheckIn.ts";
import { JOKE_RULE } from "../_shared/or/jokeFilter.ts";

const on = (k: string) => (k === "ZAD_FACT_INFERENCE" ? "1" : undefined);
const off = (_k: string) => undefined;

Deno.test("قاعدة الهزار في برومبت الشات", () => {
  assertStringIncludes(buildChatSystemPrompt({}), JOKE_RULE.trim().slice(0, 60));
});

Deno.test("الهزار موصّل في index.ts: المسار السريع وحلقة الأدوات واستخلاص الحقائق", async () => {
  const src = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertStringIncludes(src, "const fast = jokeTurn ? null : parseFastPath(message);");
  assertStringIncludes(src, "if (jokeTurn && JOKE_BLOCKED_TOOLS.has(call.name))");
  assertStringIncludes(src, "if (!jokeTurn) afterResponse(\"chat facts\"");
});

/** عميل وهمي: أي نداء بيتسجل، والقراية بترجع [] أو الصف المحدد. */
function fakeSb(rows: Record<string, unknown[]> = {}) {
  const calls: string[] = [];
  const q = (table: string) => {
    const b: Record<string, unknown> = {};
    for (const m of ["select", "eq", "is", "in", "gte", "not", "order", "limit", "upsert", "insert", "update"]) b[m] = () => b;
    b.maybeSingle = () => Promise.resolve({ data: (rows[table] ?? [])[0] ?? null });
    b.then = (res: (v: unknown) => unknown) => res({ data: rows[table] ?? [], error: null });
    return b;
  };
  return {
    calls,
    from: (t: string) => { calls.push(`from:${t}`); return q(t); },
    rpc: (fn: string, args: Record<string, unknown>) => {
      calls.push(`rpc:${fn}`);
      if (fn === "zad_commit_intent") calls.push(`intent:${(args.p_intent as { kind: string }).kind}`);
      return Promise.resolve({ data: fn === "zad_commit_intent" ? { ok: true, duplicate: false } : false, error: null });
    },
  };
}

Deno.test("الفلاج مقفول: صفر قراية وصفر كتابة وصفر أسئلة", async () => {
  const sb = fakeSb();
  assertEquals(await runNightlyFactInference(sb as never, { get: off }), { users: 0, written: 0, asked: 0 });
  assertEquals(await handleFactAnswer(sb as never, "u", "آه", { get: off }), null);
  assertEquals(await learnFactsFromChat(sb as never, "u", "بحب الشاي", { source: "app_chat" }, off), 0);
  assertEquals(sb.calls, []);
});

Deno.test("«آه» على سؤال مفتوح ⇒ fact_set said من الباب، «لأ» ⇒ fact_deny", async () => {
  const asked = { id: "f1", user_id: "u", member_id: "m", key: "likes:الشاي", value: "بيحب الشاي", source: "inferred", confidence: 0.6, asked_at: new Date().toISOString(), denied_at: null, expires_at: null };
  const yes = fakeSb({ zad_member_facts: [asked] });
  assertEquals(await handleFactAnswer(yes as never, "u", "آه", { get: on }), "تمام، سجّلتها عندي 👍");
  assertEquals(yes.calls.filter((c) => c.startsWith("intent:")), ["intent:profile.fact_set"]);
  const no = fakeSb({ zad_member_facts: [asked] });
  assertEquals(await handleFactAnswer(no as never, "u", "لأ", { get: on }), "ماشي، مش هسألك عن ده تاني.");
  assertEquals(no.calls.filter((c) => c.startsWith("intent:")), ["intent:profile.fact_deny"]);
});

Deno.test("«آه» من غير سؤال مفتوح، أو رسالة عادية ⇒ null ومفيش كتابة", async () => {
  const none = fakeSb({ zad_member_facts: [] });
  assertEquals(await handleFactAnswer(none as never, "u", "آه", { get: on }), null);
  assertEquals(none.calls.filter((c) => c.startsWith("intent:")), []);
  const other = fakeSb();
  assertEquals(await handleFactAnswer(other as never, "u", "فاضل كام", { get: on }), null);
  assertEquals(other.calls, []);
});

Deno.test("الهزار مايتحولش لحقيقة حتى والفلاج مفتوح", async () => {
  const sb = fakeSb();
  assertEquals(await learnFactsFromChat(sb as never, "u", "بحب أشتري الدنيا كلها هههه بهزر", { source: "app_chat" }, on), 0);
  assertEquals(sb.calls, []);
});

Deno.test("كلام عادي ⇒ حقيقة مستنتجة بالباب (profile.fact_set)", async () => {
  const sb = fakeSb({ zad_household_members: [{ id: "m" }] });
  assertEquals(await learnFactsFromChat(sb as never, "u", "بحب الشاي من غير سكر", { source: "app_chat", runId: "r1" }, on), 1);
  assert(sb.calls.includes("intent:profile.fact_set"));
});

Deno.test("كل كتابة في factCheckIn.ts من الباب (مفيش insert/update/delete مباشر على zad_member_facts)", async () => {
  const src = await Deno.readTextFile(new URL("./factCheckIn.ts", import.meta.url));
  assert(!/from\("zad_member_facts"\)[\s\S]{0,80}\.(insert|update|upsert|delete)\(/.test(src));
});
