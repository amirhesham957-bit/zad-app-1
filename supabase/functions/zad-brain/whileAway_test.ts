// «فاتك إيه» (whileAway.ts): سطر بقواعد لما العميل يرجع بعد ٣ أيام أو أكتر.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { AWAY_DAYS, awayDays, awayLine, loadWhileAway, whileAwayBlock } from "./whileAway.ts";

const DAY = 86_400_000;
const NOW = Date.parse("2026-10-10T12:00:00Z");
const ago = (days: number) => new Date(NOW - days * DAY).toISOString();

Deno.test("away: three days without a word is a return; less, or no earlier turn, isn't", () => {
  assertEquals(AWAY_DAYS, 3);
  assertEquals(awayDays(ago(3), NOW), 3);
  assertEquals(awayDays(ago(5.5), NOW), 5);
  assertEquals(awayDays(ago(2.9), NOW), null);
  assertEquals(awayDays(null, NOW), null);
  assertEquals(awayDays("garbage", NOW), null);
  assertEquals(awayDays(new Date(NOW + DAY).toISOString(), NOW), null);
});

Deno.test("away: the line says only what happened, with the real numbers", () => {
  assertEquals(
    awayLine({ days: 5, expenses: { count: 7, total: 1230.4 }, currency: "EGP", awaiting: 2, appointments: ["دكتور الأسنان"] }),
    "من آخر مرة اتكلمنا (من 5 أيام): اتسجل 7 مصاريف بـ1,230 EGP، وفيه 2 معاملات بنك مستنية تأكيدك، وعدّى «دكتور الأسنان».",
  );
  assertEquals(
    awayLine({ days: 3, expenses: { count: 1, total: 50 }, currency: null, awaiting: 1, appointments: [] }),
    "من آخر مرة اتكلمنا (من 3 أيام): اتسجل مصروف واحد بـ50، وفيه معاملة بنك مستنية تأكيدك.",
  );
  // مافاتهوش حاجة ⇒ مفيش سطر خالص، مش «مافاتكش حاجة».
  assertEquals(awayLine({ days: 9, expenses: { count: 0, total: 0 }, currency: "EGP", awaiting: 0, appointments: [] }), null);
});

Deno.test("away: the prompt block carries the line as data to say first, and nothing without one", () => {
  assertEquals(whileAwayBlock(null), "");
  const block = whileAwayBlock("من آخر مرة اتكلمنا (من 4 أيام): اتسجل مصروف واحد بـ50.");
  assertStringIncludes(block, "=== فاتك إيه ===");
  assertStringIncludes(block, "ابدأ ردك بالسطر ده");
  assertStringIncludes(block, "نفس الأرقام بالظبط");
  assertStringIncludes(block, "وبعدين رد على رسالته هو");
});

function fakeSb(tables: Record<string, unknown[]>, failing: string | null = null): SupabaseClient {
  const chain = (table: string): unknown =>
    new Proxy({}, {
      get(_t, prop) {
        if (prop === "then") {
          return (res: (v: unknown) => unknown) =>
            Promise.resolve(table === failing ? { data: null, error: { message: "down" } } : { data: tables[table] ?? [], error: null }).then(res);
        }
        return () => chain(table);
      },
    });
  return { from: (table: string) => chain(table) } as unknown as SupabaseClient;
}

const TABLES = {
  zad_transactions: [{ amount: 100 }, { amount: "250.5" }, { amount: -30 }, { amount: null }],
  zad_transaction_proposals: [{ id: "p1" }],
  zad_appointments: [{ title: "دكتور الأسنان" }, { title: "اجتماع البنك" }, { title: "تالت" }],
};

Deno.test("away: read from the house since the last turn; any failed read means no line", async () => {
  assertEquals(
    await loadWhileAway(fakeSb(TABLES), "u", ago(4), "EGP", NOW),
    "من آخر مرة اتكلمنا (من 4 أيام): اتسجل 3 مصاريف بـ381 EGP، وفيه معاملة بنك مستنية تأكيدك، وعدّى «دكتور الأسنان» و«اجتماع البنك».",
  );
  // «غير معروف» (السناب شوت من غير عملة) مايتقالش كعملة.
  assert(!(await loadWhileAway(fakeSb(TABLES), "u", ago(4), "غير معروف", NOW))!.includes("غير معروف"));
  assertEquals(await loadWhileAway(fakeSb(TABLES), "u", ago(1), "EGP", NOW), null);
  for (const table of Object.keys(TABLES)) {
    assertEquals(await loadWhileAway(fakeSb(TABLES, table), "u", ago(4), "EGP", NOW), null, table);
  }
});
