import { assertEquals } from "jsr:@std/assert@1";
import { familyView, type TripShareInput } from "./tripFamilyShare.ts";

Deno.test("مش موافق على المشاركة ⇒ null ومافيش ولا بيانات", () => {
  const input: TripShareInput = { consented: false, status: "في الطريق", city: "القاهرة" };
  assertEquals(familyView(input), null);
});

Deno.test("موافق ⇒ بس مفتاحين: status و city", () => {
  const out = familyView({ consented: true, status: "وصل", city: "أسوان" });
  assertEquals(out !== null, true);
  assertEquals(Object.keys(out!), ["status", "city"]);
  assertEquals(out, { status: "وصل", city: "أسوان" });
});

Deno.test("الإحداثيات (lat/lng) والحقول الزيادة بتتشال", () => {
  const out = familyView({
    consented: true,
    status: "في الطريق",
    city: "المنيا",
    lat: 27.18,
    lng: 31.18,
    userId: "u-1",
    notes: "secret",
  });
  assertEquals(out, { status: "في الطريق", city: "المنيا" });
  const json = JSON.stringify(out);
  assertEquals(json.includes("27.18"), false);
  assertEquals(json.includes("31.18"), false);
  assertEquals(json.includes("u-1"), false);
});

Deno.test("الموافقة من غير status ولا city ⇒ القيم بتبقى سلسلة فاضية", () => {
  assertEquals(familyView({ consented: true }), { status: "", city: "" });
  assertEquals(familyView({ consented: true, lat: 1, lng: 2 }), { status: "", city: "" });
});
