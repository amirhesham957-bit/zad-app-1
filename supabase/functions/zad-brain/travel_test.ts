// وضع السفر (20261003140000، docs/agent/ZAD_LIVING_BRAIN.md الشريحة ٦).
import { assert, assertEquals } from "jsr:@std/assert@1";
import { countryNameAr, travelContext, TRAVEL_STALE_DAYS } from "./shared.ts";
import { buildChatSystemPrompt, travelField } from "./index.ts";
import { momentFallback } from "./voiceMoments.ts";
import { emotionForMoment } from "../_shared/zadVoice.ts";

const NOW = Date.parse("2026-10-03T09:00:00Z");

Deno.test("برّه بلده: فين ومن إمتى وبلده", () => {
  const t = travelContext({ country: "EG", travel_country: "AE", travel_since: "2026-10-01T09:00:00Z" }, NOW);
  assertEquals(t, { in: "AE", country_name: "الإمارات", home: "EG", since: "2026-10-01T09:00:00.000Z", days: 2 });
});

Deno.test("في بلده، أو بلد الرحلة هو بلده، أو الرحلة قديمة، أو مش كود = مفيش سفر", () => {
  assertEquals(travelContext({ country: "EG", travel_country: null, travel_since: null }, NOW), null);
  assertEquals(travelContext({ country: "EG", travel_country: "EG", travel_since: "2026-10-01T09:00:00Z" }, NOW), null);
  const old = new Date(NOW - (TRAVEL_STALE_DAYS + 1) * 86_400_000).toISOString();
  assertEquals(travelContext({ country: "EG", travel_country: "AE", travel_since: old }, NOW), null);
  assertEquals(travelContext({ country: "EG", travel_country: "Dubai", travel_since: "2026-10-01T09:00:00Z" }, NOW), null);
  assertEquals(travelContext(null, NOW), null);
});

Deno.test("السناب شوت: travel بس لو مسافر", () => {
  assertEquals(travelField({ country: "EG", travel_country: null, travel_since: null }, NOW), {});
  assertEquals(travelField({ country: "SA", travel_country: "TR", travel_since: "2026-10-03T08:00:00Z" }, NOW).travel?.country_name, "تركيا");
});

Deno.test("اسم البلد بالعربي، والكود لو مش معروف", () => {
  assertEquals(countryNameAr("ae"), "الإمارات");
  assertEquals(countryNameAr("ZZ"), "ZZ");
});

Deno.test("ترحيب الوصول: باسم البلد، بعرض واحد، ومبسوطة", () => {
  const out = momentFallback("travel_arrived", { country: "TR", home_country: "EG" });
  assert(out.title.includes("تركيا"));
  assert(out.text.includes("أرشحلك"));
  assertEquals(emotionForMoment("travel_arrived"), "cheerful");
});

Deno.test("البرومبت: قاعدة السفر بس وهو مسافر، ومن غير ما يحوّل أرقامه", () => {
  const away = buildChatSystemPrompt({
    travel: { in: "AE", country_name: "الإمارات", home: "EG", since: "2026-10-01T09:00:00Z", days: 2 },
  });
  assert(away.includes("العميل مسافر (travel)"));
  assert(away.includes("ماتحوّلش أرقامه"));
  assertEquals(buildChatSystemPrompt({}).includes("العميل مسافر (travel)"), false);
});
