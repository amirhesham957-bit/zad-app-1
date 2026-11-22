import { assertEquals } from "jsr:@std/assert@1";
import { filterOffersFor, isMinor, type Offer } from "./minorGuard.ts";

const NOW = new Date("2026-11-22T12:00:00Z");

Deno.test("age 17 is a minor and age 18 is an adult", () => {
  assertEquals(isMinor({ age: 17 }, NOW), true);
  assertEquals(isMinor({ age: 18 }, NOW), false);
  assertEquals(isMinor({ age: 30 }, NOW), false);
});

Deno.test("birthDate on the 18th birthday is adult, the day before is minor", () => {
  // Turns 18 exactly today.
  assertEquals(isMinor({ birthDate: "2008-11-22" }, NOW), false);
  // Turns 18 tomorrow.
  assertEquals(isMinor({ birthDate: "2008-11-23" }, NOW), true);
  // Turned 17 yesterday.
  assertEquals(isMinor({ birthDate: "2009-11-21" }, NOW), true);
  // Turned 18 yesterday.
  assertEquals(isMinor({ birthDate: "2008-11-21" }, NOW), false);
});

Deno.test("unknown age and birthDate fail safe to minor", () => {
  assertEquals(isMinor({}, NOW), true);
  assertEquals(isMinor({ age: null, birthDate: null }, NOW), true);
  assertEquals(isMinor({ age: undefined, birthDate: "not-a-date" }, NOW), true);
});

Deno.test("isChild forces minor even when age says adult", () => {
  assertEquals(isMinor({ isChild: true, age: 40 }, NOW), true);
  assertEquals(isMinor({ isChild: true, birthDate: "1980-01-01" }, NOW), true);
});

Deno.test("any minor signal wins over an adult signal", () => {
  assertEquals(isMinor({ age: 30, birthDate: "2015-06-01" }, NOW), true);
  assertEquals(isMinor({ age: 16, isChild: false }, NOW), true);
});

Deno.test("filterOffersFor removes targeted ads and affiliate offers for minors", () => {
  const offers: Offer[] = [
    { id: "a", kind: "targeted_ad" },
    { id: "b", kind: "affiliate" },
    { id: "c", kind: "plain" },
  ];
  assertEquals(filterOffersFor({ age: 16 }, offers, NOW), [{ id: "c", kind: "plain" }]);
  assertEquals(filterOffersFor({ isChild: true }, offers, NOW), [{ id: "c", kind: "plain" }]);
  assertEquals(filterOffersFor({}, offers, NOW), [{ id: "c", kind: "plain" }]);
});

Deno.test("filterOffersFor leaves offers unchanged for adults", () => {
  const offers: Offer[] = [
    { id: "a", kind: "targeted_ad" },
    { id: "b", kind: "affiliate" },
    { id: "c", kind: "plain" },
  ];
  assertEquals(filterOffersFor({ age: 18 }, offers, NOW), offers);
  assertEquals(filterOffersFor({ birthDate: "1990-05-05" }, offers, NOW), offers);
});
