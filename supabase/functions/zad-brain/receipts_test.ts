import { assertEquals } from "jsr:@std/assert@1";
import { isToolFailure, isWrite, silentWriteFallback, visibleReceipts } from "./receipts.ts";
import { identityOverwrites } from "../_shared/customerProfile.ts";

Deno.test("receipts: a read tool never becomes a receipt (web_search JSON used to reach Telegram)", () => {
  const hits = JSON.stringify("1. سعر الرز\nhttps://x.test\n...");
  assertEquals(isWrite("web_search", hits, false), false);
  assertEquals(isWrite("find_nearby_stores", "مفيش موقع محفوظ للعميل — قوله يفعّل …", false), false);
});

Deno.test("receipts: a write is a receipt; a failure is not, whatever its prefix", () => {
  assertEquals(isWrite("add_inventory_item", "اتضاف للمخزون", true), true);
  assertEquals(isWrite("add_shopping_item", "اتضافت لقائمة التسوق", false), true);
  assertEquals(isWrite("add_shopping_item", "فشل الإضافة: timeout", false), false);
  assertEquals(isToolFailure("مرفوض: الوقت مش مفهوم"), true);
  assertEquals(isToolFailure("تم — بدأ تحدي"), false);
});

Deno.test("receipts: the profile write stays out of what the customer sees", () => {
  const executed = [
    { tool: "update_customer_profile", ok: true, summary: "status=saved fields=preferred_name" },
    { tool: "add_inventory_item", ok: true, summary: "اتضاف للمخزون" },
  ];
  assertEquals(visibleReceipts(executed).map((e) => e.tool), ["add_inventory_item"]);
});

Deno.test("receipts: a silent write with no model text still answers, never an empty turn", () => {
  const silent = [{ tool: "update_customer_profile" }];
  assertEquals(silentWriteFallback("", silent, 0), "تمام 👍");
  assertEquals(silentWriteFallback("أهلاً يا مو!", silent, 0), "أهلاً يا مو!");
  assertEquals(silentWriteFallback("", [{ tool: "add_inventory_item" }], 0), "");
  assertEquals(silentWriteFallback("", [], 0), "");
});

Deno.test("profile: a joke name cannot overwrite the real one without confirmation", () => {
  assertEquals(identityOverwrites({ preferred_name: "مو شريف" }, { preferred_name: "بيتر باركر" }), ["preferred_name"]);
  assertEquals(identityOverwrites({ preferred_name: null }, { preferred_name: "مو شريف" }), []);
  assertEquals(identityOverwrites(null, { preferred_name: "مو" }), []);
  assertEquals(identityOverwrites({ preferred_name: "Mo" }, { preferred_name: "mo " }), []);
  assertEquals(identityOverwrites({ preferred_name: "مو" }, { preferred_name: null }), []);
  assertEquals(identityOverwrites({ gender: "male" }, { gender: "female" }), ["gender"]);
  assertEquals(identityOverwrites({ gender: "male" }, { city: "جدة" }), []);
});
