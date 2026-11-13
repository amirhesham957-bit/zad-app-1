import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import {
  batchDoneMessage, batchMedicineKeyboard, batchMedicineMessage, captionPerson, NEW_MEDICINES_MAX, parseBatchCallback,
  routedMemberName, splitPhotoMedicines,
} from "./pharmacyPhoto.ts";

Deno.test("a medicine already in the pharmacy is topped up; a new one waits for the button", () => {
  const { known, fresh } = splitPhotoMedicines(
    [
      { name: " Panadol Extra ", quantity: 2, unit: "علبة" },
      { name: "أوجمنتين 1جم", quantity: 1.4, unit: null },
      { name: "", quantity: 1 },
      { name: "أوجمنتين 1جم", quantity: 1 },
    ],
    ["panadol extra"],
  );
  assertEquals(known, [{ name: "Panadol Extra", quantity: 2, unit: "علبة" }]);
  assertEquals(fresh, [{ name: "أوجمنتين 1جم", quantity: 1, unit: "قرص" }]);
});

Deno.test("«known» is the brain's own rule — a near spelling is new, so it is confirmed", () => {
  const { known, fresh } = splitPhotoMedicines([{ name: "اوجمنتين 1جم", quantity: 1 }], ["أوجمنتين 1جم"]);
  assertEquals([known.length, fresh.length], [0, 1]);
});

Deno.test("NEW_MEDICINES_MAX new medicines at most from one photo", () => {
  const items = Array.from({ length: 8 }, (_, i) => ({ name: `دوا ${i}`, quantity: 1 }));
  assertEquals(splitPhotoMedicines(items, []).fresh.length, NEW_MEDICINES_MAX);
});

// ── فاتورة صيدلية = تأكيد واحد، ولمين (قرار المالك ١٣/١١) ────────────────────────────────────────

Deno.test("captionPerson: the owner's two captions, kin with a stuck «ل», and what is not a person", () => {
  assertEquals(captionPerson("دا دوا مامتي"), { kind: "person", label: "مامتي" });
  assertEquals(captionPerson("دا دوايا"), { kind: "self" });
  assertEquals(captionPerson("دي أدويتي"), { kind: "self" });
  assertEquals(captionPerson("دوا لماما"), { kind: "person", label: "ماما" });
  assertEquals(captionPerson("لـ ماما"), { kind: "person", label: "ماما" });
  assertEquals(captionPerson("علاج لـ بابا"), { kind: "person", label: "بابا" });
  // «لينا» اسم — اللام بتتشال قدام صلة قرابة بس.
  assertEquals(captionPerson("دوا لينا"), { kind: "person", label: "لينا" });
  assertEquals(captionPerson("بتاع يوسف"), { kind: "person", label: "يوسف" });
  assertEquals(captionPerson("دا دوا الضغط"), null);
  assertEquals(captionPerson("فاتورة"), null);
  assertEquals(captionPerson(undefined), null);
});

const BATCH = "0b2f9ab5-7923-40e1-9280-ac56f7e5c794";
const meds = [{ name: "Vonaspire", quantity: 1, unit: "شريط" }, { name: "Mucosta", quantity: 2, unit: "شريط" }];

Deno.test("one message and one confirm for the whole receipt", () => {
  const msg = batchMedicineMessage(meds, { kind: "person", label: "مامتي" }, 1);
  assertStringIncludes(msg, "2 أدوية جديدة");
  assertStringIncludes(msg, "• Vonaspire — 1 شريط");
  assertStringIncludes(msg, "لـمامتي");
  assertStringIncludes(msg, "و1 موجودين");
  const kb = batchMedicineKeyboard(BATCH, { kind: "person", label: "مامتي" }, []);
  assertEquals(kb.flat().map((b) => b.callback_data), [`pb:${BATCH}:p`, `pb:${BATCH}:x`]);
  assertEquals(batchMedicineKeyboard(BATCH, { kind: "self" }, []).flat()[0].callback_data, `pb:${BATCH}:s`);
});

Deno.test("no caption: «mine», one button per consenting member (3 at most), and every callback fits 64 bytes", () => {
  const members = [1, 2, 3, 4].map((i) => ({ userId: `${i}${i}${i}${i}aaaa-0000-0000-0000-000000000000`, name: `فرد ${i}` }));
  const kb = batchMedicineKeyboard(BATCH, null, members);
  const data = kb.flat().map((b) => b.callback_data!);
  assertEquals(data, [`pb:${BATCH}:s`, `pb:${BATCH}:m1111aaaa`, `pb:${BATCH}:m2222aaaa`, `pb:${BATCH}:m3333aaaa`, `pb:${BATCH}:x`]);
  for (const d of data) assert(new TextEncoder().encode(d).length <= 64, d);
  assertStringIncludes(batchMedicineMessage(meds, null, 0), "دول لمين؟");
});

Deno.test("parseBatchCallback reads what the keyboard writes, and nothing else", () => {
  assertEquals(parseBatchCallback(`pb:${BATCH}:s`), { batchId: BATCH, choice: { kind: "self" } });
  assertEquals(parseBatchCallback(`pb:${BATCH}:p`), { batchId: BATCH, choice: { kind: "caption" } });
  assertEquals(parseBatchCallback(`pb:${BATCH}:x`), { batchId: BATCH, choice: { kind: "cancel" } });
  assertEquals(parseBatchCallback(`pb:${BATCH}:m0B2F9AB5`), { batchId: BATCH, choice: { kind: "member", prefix: "0b2f9ab5" } });
  assertEquals(parseBatchCallback(`pb:${BATCH}:mzz`), null);
  assertEquals(parseBatchCallback(`mx:${BATCH}`), null);
  assertEquals(parseBatchCallback(`pa:${BATCH}`), null);
});

Deno.test("routedMemberName reads the brain's reply for a new and for an already-saved medicine", () => {
  assertEquals(routedMemberName(`اتسجل "X" في صيدلية موني — التذكير هيروح لـموني`), "موني");
  assertEquals(routedMemberName(`"X" كان مسجل أصلاً في صيدلية أم أحمد — حدّثت بياناته`), "أم أحمد");
  assertEquals(routedMemberName(`"X" مسجل خلاص بنفس البيانات في صيدلية موني — مضفتش`), "موني");
  assertEquals(routedMemberName(`اتسجل "X" في الصيدلية`), null);
  assertEquals(routedMemberName(undefined), null);
});

Deno.test("the done message asks for the times once — or says the member was asked", () => {
  const mine = batchDoneMessage({ added: ["A", "B"], failed: [], memberName: null, forLabel: null });
  assertStringIncludes(mine, "اتسجل 2 أدوية ✅");
  assertEquals((mine.match(/الساعة كام/g) ?? []).length, 1);
  const hers = batchDoneMessage({ added: ["A", "B"], failed: ["C"], memberName: "موني", forLabel: "مامتي" });
  assertStringIncludes(hers, "في صيدلية موني");
  assertStringIncludes(hers, "التذكير هيروح لـموني");
  assert(!hers.includes("الساعة كام"), hers);
  assertStringIncludes(hers, "ماتسجلش: «C»");
  assertStringIncludes(batchDoneMessage({ added: ["A"], failed: [], memberName: null, forLabel: "تيتا" }), "اتسجل «A» لـتيتا ✅");
});
