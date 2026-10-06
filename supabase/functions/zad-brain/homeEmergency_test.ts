import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { homeEmergencyRule, techniciansForSnapshot } from "./homeEmergency.ts";

Deno.test("the snapshot carries a name and a trade, never the phone or the note", () => {
  const lite = techniciansForSnapshot([
    { id: "1", name: " عم سيد ", trade: "plumber", phone: "01001234567", notes: "بييجي بالليل" },
    { id: "2", name: "", trade: "gas", phone: "01001234568" },
    { id: "3", name: "أبو محمد", trade: "unknown", phone: "01001234569" },
  ]);
  assertEquals(lite, [{ name: "عم سيد", trade: "سباك" }, { name: "أبو محمد", trade: "تاني" }]);
  assertEquals(JSON.stringify(lite).includes("0100"), false);
});

Deno.test("the rule puts gas safety first, names the technicians, and forbids inventing a number", () => {
  const rule = homeEmergencyRule({ trusted_technicians: [{ name: "عم سيد", trade: "سباك" }] });
  assertStringIncludes(rule, "ريحة غاز ⇒ أول جملة");
  assertStringIncludes(rule, "عم سيد (سباك)");
  assertStringIncludes(rule, "ماتألّفش رقم تليفون");
  assertStringIncludes(homeEmergencyRule({ trusted_technicians: [] }), "مالوش فنيين");
});
