// النية المؤجلة (purchaseIntent.ts، ZAD_PLAN ٥.٨ (٣)): «عايز أشتري جاكيت» بتتحفظ، والصبح بيدوّر لها على عرض.
import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { intentBought, notePurchaseIntent, openIntents, purchaseIntentFrom } from "./purchaseIntent.ts";
import { dealSource, loadTasteDeal } from "./tasteDeals.ts";
import { momentFallback } from "./voiceMoments.ts";

Deno.test("intent: the thing after «want to buy», in every dialect we serve, cut where the name ends", () => {
  assertEquals(purchaseIntentFrom("عايز أشتري جاكيت"), "جاكيت");
  assertEquals(purchaseIntentFrom("أنا عاوزة أشتري غسالة أطباق الشهر الجاي"), "غسالة أطباق");
  assertEquals(purchaseIntentFrom("ابغى اشتري جوال جديد"), "جوال");
  assertEquals(purchaseIntentFrom("ناوي أجيب مكنسة كهربا بكام تقريباً؟"), "مكنسة كهربا");
  assertEquals(purchaseIntentFrom("محتاجة اجيب شنطة للمدرسة عشان يوسف"), "شنطة للمدرسة");
  assertEquals(purchaseIntentFrom("عايز اشتري تكييف بـ15000"), "تكييف");
  assertEquals(purchaseIntentFrom("صباح الخير، نفسي أشتري عجلة"), "عجلة");
});

Deno.test("intent: not when negated, past, vague, or no buying at all", () => {
  assertEquals(purchaseIntentFrom("مش عايز اشتري جاكيت"), null);
  assertEquals(purchaseIntentFrom("اشتريت جاكيت امبارح"), null);
  assertEquals(purchaseIntentFrom("عايز أشتري حاجة"), null);
  assertEquals(purchaseIntentFrom("عايز اشتري ب500"), null);
  assertEquals(purchaseIntentFrom("عايز أعرف صرفت كام"), null);
  assertEquals(purchaseIntentFrom("سجل 50 جنيه قهوة"), null);
  assertEquals(purchaseIntentFrom(""), null);
  assertEquals(purchaseIntentFrom(null), null);
});

Deno.test("intent: bought when an expense or a pantry item by that name came after it was said", () => {
  const intent = { item: "جاكيت", said_at: "2026-10-01T10:00:00Z" };
  assertEquals(intentBought(intent, [{ name: "جاكيت جلد", at: "2026-10-05T10:00:00Z" }]), true);
  // قبل ما يقولها = مش هي.
  assertEquals(intentBought(intent, [{ name: "جاكيت", at: "2026-09-20T10:00:00Z" }]), false);
  assertEquals(intentBought(intent, [{ name: "قهوة", at: "2026-10-05T10:00:00Z" }, { name: null, at: null }]), false);
});

function fakeSb(tables: Record<string, unknown[]>, calls: Array<[string, unknown]> = []): SupabaseClient {
  const chain = (table: string, data: unknown): unknown =>
    new Proxy({}, {
      get(_t, prop) {
        if (prop === "then") return (res: (v: unknown) => unknown) => Promise.resolve({ data, error: null }).then(res);
        if (prop === "maybeSingle" || prop === "single") return () => chain(table, Array.isArray(data) ? data[0] ?? null : data);
        if (prop === "update") return (v: unknown) => { calls.push([`update:${table}`, v]); return chain(table, null); };
        return () => chain(table, data);
      },
    });
  return {
    from: (t: string) => chain(t, tables[t] ?? []),
    rpc: (fn: string, args: unknown) => { calls.push([fn, args]); return chain(fn, null); },
  } as unknown as SupabaseClient;
}

Deno.test("intent: noted through the one server function, nothing when there is none", async () => {
  const calls: Array<[string, unknown]> = [];
  assertEquals(await notePurchaseIntent(fakeSb({}, calls), "u", "عايز اشتري جاكيت"), "جاكيت");
  assertEquals(calls, [["zad_purchase_intent_note", { p_user: "u", p_item: "جاكيت", p_key: "جاكيت", p_days: 60 }]]);
  assertEquals(await notePurchaseIntent(fakeSb({}, calls), "u", "إزيك"), null);
  assertEquals(calls.length, 1);
});

Deno.test("intent: an open intent that was bought is closed and left out", async () => {
  const calls: Array<[string, unknown]> = [];
  const sb = fakeSb({
    zad_purchase_intents: [
      { id: "a", item: "جاكيت", said_at: "2026-10-01T10:00:00Z" },
      { id: "b", item: "مكنسة", said_at: "2026-10-01T10:00:00Z" },
    ],
  }, calls);
  const open = await openIntents(sb, "u", [{ name: "جاكيت", at: "2026-10-02T10:00:00Z" }]);
  assertEquals(open.map((i) => i.item), ["مكنسة"]);
  assertEquals(calls.map((c) => c[0]), ["update:zad_purchase_intents"]);
});

const TABLES = {
  zad_users: [{ id: "u", country: "EG", created_at: "2025-01-01T00:00:00Z" }],
  zad_shopping_list: [{ item_name: "زيت" }],
  zad_customer_profile: [{ interests: [] }],
  zad_transactions: Array(3).fill({ merchant_name: "كارفور", title: "بقالة", created_at: "2026-10-02T10:00:00Z" }),
  zad_purchase_intents: [{ id: "a", item: "جاكيت", said_at: "2026-10-01T10:00:00Z" }],
};
const DEALS = [
  { item: "زيت كريستال", store: "كارفور مصر", price: 90, discount_percent: 10 },
  { item: "جاكيت شتوي رجالي", store: "ديفاكتو", price: 600, discount_percent: 30 },
];

Deno.test("intent: the morning deal looks for what they said they want first, and says it in their word", async () => {
  dealSource.search = () => Promise.resolve({ deals: DEALS });
  const d = await loadTasteDeal(fakeSb(TABLES), "u");
  // محله المعتاد على حاجة من القايمة مابيغلبش حاجة هو قال إنه عايزها.
  assertEquals([d?.store, d?.intent], ["ديفاكتو", "جاكيت"]);
  const line = momentFallback("morning_greeting", { taste_deal: d }).text;
  assertStringIncludes(line, "قلتلي إنك ناوي تشتري جاكيت — لقيت عرض على جاكيت شتوي رجالي في ديفاكتو بخصم 30٪");

  // اتشرى ⇒ القايمة بس.
  const bought = await loadTasteDeal(fakeSb({
    ...TABLES,
    zad_transactions: [...TABLES.zad_transactions, { merchant_name: "ديفاكتو", title: "جاكيت", created_at: "2026-10-03T10:00:00Z" }],
  }), "u");
  assertEquals([bought?.store, bought?.intent], ["كارفور مصر", undefined]);

  // الفلوس ضيقة ⇒ مش وقت رغبات.
  const tight = await loadTasteDeal(fakeSb(TABLES), "u", Date.now(), { tight: true });
  assertEquals([tight?.store, tight?.intent], ["كارفور مصر", undefined]);
  dealSource.search = () => Promise.resolve(null);
});

import { searchIntentFrom } from "./purchaseIntent.ts";

Deno.test("5.9: a price, place or offer question is something he is thinking of buying", () => {
  const cases: Array<[string, string | null]> = [
    ["بكام اللابتوب ده؟", "لابتوب"],
    ["سعر التكييف كام دلوقتي", "تكييف"],
    ["فين ألاقي زيت زيتون", "زيت زيتون"],
    ["بدوّر على شنطة مدرسة", "شنطة مدرسة"],
    ["فيه عروض على الغسالات؟", "غسالات"],
    ["هو الآيفون ١٥ بكام؟", "الآيفون ١٥"],
    // Money itself, his own money, and health are never a product interest.
    ["الدولار بكام النهارده", null],
    ["الدهب عيار ٢١ بكام", null],
    ["صرفت كام الشهر ده", null],
    ["البنادول بكام", null],
    ["سعر علاج الضغط", null],
    ["مرحبا", null],
  ];
  for (const [m, want] of cases) assertEquals(searchIntentFrom(m), want, m);
});
