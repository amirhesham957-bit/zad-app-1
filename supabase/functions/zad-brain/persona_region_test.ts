import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { conversationProfile } from "./persona.ts";

Deno.test("conversationProfile refines Saudi by the profile's city (10.16)", () => {
  const jeddah = conversationProfile("SA", { city: "جدة" });
  assertEquals(jeddah.dialect, "SA");
  assertEquals(jeddah.region, "SA_HIJAZ");
  assertStringIncludes(jeddah.instruction, "حجازي");
  const riyadh = conversationProfile("SA", { city: "الرياض" });
  assertEquals(riyadh.region, "SA_NAJD");
  assertEquals(conversationProfile("SA").region, null);
  assertEquals(conversationProfile("EG", { city: "جدة" }).region, null);
});
