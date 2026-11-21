import { assertEquals } from "jsr:@std/assert@1";
import { checkNumbers, extractNumbers } from "./numberGuard.ts";

Deno.test("extracts Arabic-Indic digits, thousands, decimals, and percent", () => {
  assertEquals(extractNumbers("فاضلك ١٬٢٥٠٫٥ جنيه و٣٥٪ من الميزانية"), [1250.5, 35]);
});

Deno.test("extracts Western and Persian digits", () => {
  assertEquals(extractNumbers("spent 1,250 and ۴۰ today"), [1250, 40]);
});

Deno.test("identifiers glued to letters are not numbers", () => {
  assertEquals(extractNumbers("فيتامين B12 و iPhone15"), []);
});

Deno.test("a date gives three numbers", () => {
  assertEquals(extractNumbers("2026-11-22"), [2026, 11, 22]);
});

Deno.test("checkNumbers accepts allowed and free numbers and reports invented ones", () => {
  assertEquals(checkNumbers("١٢٥٠ و٣٥٪ و٧", [1250.5, 35]), { ok: true, unknown: [] });
  assertEquals(checkNumbers("١٢٥٠ و٣٥٪ و٩٩٩", [1250.5, 35]), { ok: false, unknown: [999] });
});

Deno.test("checkNumbers applies the default relative tolerance", () => {
  assertEquals(checkNumbers("1005", [1000]), { ok: true, unknown: [] });
  assertEquals(checkNumbers("1020", [1000]), { ok: false, unknown: [1020] });
});

Deno.test("a reply without numbers passes", () => {
  assertEquals(checkNumbers("لا توجد أرقام هنا", []), { ok: true, unknown: [] });
});
