// ١٣/١١ (حساب المالك على تليجرام): ٥ من ٧ أدوية من فاتورتين اترفضت «التسجيل فشل» ٩ مرات — كلها وحدتها «شريط»،
// والتحقق كان بيقبل قايمة ثابتة. والـ٢ اللي عدّوا («علبة») اتسجلوا «قرص».
import { assertEquals } from "jsr:@std/assert@1";
import { validateAddPharmacyItem } from "./validators.ts";
import { pharmacyUnit } from "./index.ts";

const ctx = () => ({ counts: {} }) as never;
const pendingRow = (name: string, unit: string, quantity = 1) => ({
  name, dosage: null, daily_dose_count: 1, dose_times: null, unit, quantity, category: "عام",
});

Deno.test("the receipt rows that failed on 13/11 now pass validation", async () => {
  for (const [name, unit, q] of [
    ["Vonaspire 20 MG 30 Tab", "شريط", 1], ["Mucosta 100 Mg 20 Tabs سعر جديد", "شريط", 1],
    ["NeoCarbon Activated Charcoal 30 Cap", "شريط", 1], ["Geoprost 30 Tabs", "شريط", 1],
    ["Diosmin Plus 30 Tabs", "شريط", 2], ["Vitacid C 1 Gm 12 Eff Tabs", "علبة", 1], ["شراب كحة", "زجاجة", 1],
  ] as const) {
    assertEquals(await validateAddPharmacyItem(pendingRow(name, unit, q), {}, ctx()), { ok: true }, `${name} ${unit}`);
  }
});

Deno.test("a unit is still bounded", async () => {
  assertEquals((await validateAddPharmacyItem(pendingRow("بنادول", "x".repeat(31)), {}, ctx())).ok, false);
});

Deno.test("the unit follows zad_pharmacy_unit: known ones unify, the rest stay as written", () => {
  assertEquals(pharmacyUnit("شريط"), "شريط");
  assertEquals(pharmacyUnit("علبة"), "علبة");
  assertEquals(pharmacyUnit("زجاجة"), "زجاجة");
  assertEquals(pharmacyUnit("حبة"), "قرص");
  assertEquals(pharmacyUnit("أقراص"), "قرص");
  assertEquals(pharmacyUnit("Tabs"), "قرص");
  assertEquals(pharmacyUnit("كبسولات"), "كبسولة");
  assertEquals(pharmacyUnit("مرهم"), "دهان");
  assertEquals(pharmacyUnit("قطرة"), "نقطة");
  assertEquals(pharmacyUnit(""), "قرص");
  assertEquals(pharmacyUnit(undefined), "قرص");
});
