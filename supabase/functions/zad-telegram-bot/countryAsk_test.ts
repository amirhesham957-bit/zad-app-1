import { assert, assertEquals } from "jsr:@std/assert@1";
import { COUNTRY_CHOICES, countryKeyboard, parseCountryCallback, shouldAskCountry } from "./countryAsk.ts";

Deno.test("asks only an account with no country that was never asked", () => {
  assert(shouldAskCountry(null, null));
  assert(shouldAskCountry("  ", null));
  assert(!shouldAskCountry("EG", null));
  assert(!shouldAskCountry(null, "2026-10-01T10:00:00Z"));
});

Deno.test("every button parses back to its own country and fits Telegram's 64 bytes", () => {
  const buttons = countryKeyboard().flat();
  assertEquals(buttons.length, COUNTRY_CHOICES.length);
  for (const b of buttons) {
    assert(new TextEncoder().encode(b.callback_data!).length <= 64);
    const parsed = parseCountryCallback(b.callback_data);
    assertEquals(parsed?.label, b.text);
  }
});

Deno.test("a forged or foreign callback is not a country", () => {
  assertEquals(parseCountryCallback("cty:XX"), null);
  assertEquals(parseCountryCallback("cty:"), null);
  assertEquals(parseCountryCallback("b"), null);
  assertEquals(parseCountryCallback(undefined), null);
});

Deno.test("Saudi Arabia is saved with riyals", () => {
  assertEquals(parseCountryCallback("cty:SA"), { country: "SA", currency: "SAR", label: "🇸🇦 السعودية" });
});
