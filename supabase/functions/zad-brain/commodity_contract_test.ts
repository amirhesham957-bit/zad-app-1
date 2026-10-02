// قاعدة السلعة واحدة (تشخيص زاد ١.٥): العقل (lowStock.ts) والتطبيق (product_family.dart) لازم
// يجمّعوا نفس الصفوف تحت نفس السلعة — وإلا العقل يقول «عندك ٥ مية» والشاشة «١٣». الاختبار ده
// بيقرا جداول التطبيق من ملف الدارت ويقارنها بجداول هنا، ويجرّب نفس الأمثلة على الاتنين.
import { assertEquals } from "jsr:@std/assert@1";
import { productFamilyOf } from "./lowStock.ts";

const dart = await Deno.readTextFile(
  new URL("../../../zad_flutter/lib/shared/inventory/domain/product_family.dart", import.meta.url),
);
const ts = await Deno.readTextFile(new URL("./lowStock.ts", import.meta.url));

/** الكلمات جوه بلوك اسمه [name] في الملف (المفاتيح والقيم بين علامات تنصيص). */
function quoted(source: string, start: string, end: string): string[] {
  const from = source.indexOf(start);
  if (from < 0) throw new Error(`${start} not found`);
  const block = source.slice(from, source.indexOf(end, from + start.length))
    .split("\n").filter((l) => !l.trim().startsWith("//")).join("\n");
  return [...block.matchAll(/['"]([^'"\n]+)['"]/g)].map((m) => m[1]).sort();
}

Deno.test("the staples, packaging and water brands are the same in the app and the brain", () => {
  assertEquals(quoted(ts, "const STAPLES", "};"), quoted(dart, "const Map<String, String> _staples", "};"));
  assertEquals(quoted(ts, "const PACKAGING", "]);"), quoted(dart, "const Set<String> _packaging", "};"));
  assertEquals(quoted(ts, "const WATER_BRANDS", "]);"), quoted(dart, "const Set<String> _waterBrands", "};"));
});

Deno.test("the owner's ten water rows are one commodity on the server too", () => {
  for (const name of ["إزازة ماء", "صافي 1.5 لتر", "ماء صافى", "كرتونة ماية", "عبوة مياه", "إيلان", "إيلانو", "بوفانا", "داساني", "نستله"]) {
    assertEquals(productFamilyOf(name), "مياه", name);
  }
  assertEquals(productFamilyOf("نستله نيدو"), null);
  assertEquals(productFamilyOf("صافي لبن"), null);
});
