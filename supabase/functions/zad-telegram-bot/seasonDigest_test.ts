import { assert, assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { digestButtons, digestCaption, digestCodesMessage, digestHeader, digestPhoto } from "./telegram.ts";

Deno.test("a card says the item, store, price, saving and why — from the facts only", () => {
  const caption = digestCaption({ item: "زيت عافية", store: "كارفور", price: 30, price_before: 40, currency: "EGP", saving: 25, why: "need", until: "2026-11-10" });
  assertStringIncludes(caption, "زيت عافية — كارفور");
  assertStringIncludes(caption, "30 EGP بدل 40 (−25٪)");
  assertStringIncludes(caption, "قرّب يخلص");
  assertStringIncludes(caption, "لحد 2026-11-10");
});

Deno.test("the link is a button; a picture is only a YouTube thumbnail", () => {
  assertEquals(digestButtons({ url: "https://www.youtube.com/watch?v=abc123XYZ", source: "youtube" }), [[{ text: "▶️ الفيديو", url: "https://www.youtube.com/watch?v=abc123XYZ" }]]);
  assertEquals(digestButtons({ url: "javascript:alert(1)" }), []);
  assertEquals(digestPhoto({ photo: "https://i.ytimg.com/vi/abc123XYZ/hqdefault.jpg" }), "https://i.ytimg.com/vi/abc123XYZ/hqdefault.jpg");
  assertEquals(digestPhoto({ photo: "https://evil.example/x.jpg" }), null);
});

Deno.test("codes are written letter for letter with their source; junk codes are dropped", () => {
  const msg = digestCodesMessage([
    { store: "كيتا", code: "KEETA30", discount_percent: 30, min_order: 50, source_kind: "instagram", source_url: "https://www.instagram.com/p/x/" },
    { store: "نينجا", code: "bad code", discount_percent: 10 },
    { store: "جاهز", code: "JAHEZ5", source_url: "https://x.example/" },
  ]);
  assert(msg);
  assertEquals(msg.count, 1);
  assertStringIncludes(msg.text, "KEETA30 — خصم 30٪ على طلب 50 أو أكتر");
  assertEquals(msg.rows.length, 1);
  assertEquals(digestCodesMessage([]), null);
});

Deno.test("the header names the season and what was found", () => {
  assertStringIncludes(digestHeader("الجمعة البيضاء", 3, 1), "الجمعة البيضاء: لقيتلك 3 عروض على حاجات بيتك و1 كود خصم لتطبيقاتك");
});

Deno.test("a top-deals message says so, not «على حاجات بيتك»", () => {
  assertStringIncludes(digestHeader("الجمعة البيضاء", 3, 0, true), "3 عروض من أقوى خصومات الموسم في بلدك");
});
