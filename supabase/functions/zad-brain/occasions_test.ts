// المناسبات: الجملة، كام يوم فاضل، مين النهارده أو بعد ٣ أيام، ومبلغ الهدية.
import { assertEquals } from "jsr:@std/assert@1";
import { daysUntilOccasion, giftSuggestion, occasionDateLabel, occasionMd, occasionNote, upcomingOccasions } from "./occasions.ts";

Deno.test("a month and day become MM-DD only when the day exists", () => {
  assertEquals(occasionMd(3, 12), "03-12");
  assertEquals(occasionMd("7", "4"), "07-04");
  assertEquals(occasionMd(2, 29), "02-29");
  assertEquals(occasionMd(2, 30), null);
  assertEquals(occasionMd(4, 31), null);
  assertEquals(occasionMd(13, 1), null);
  assertEquals(occasionMd(0, 10), null);
  assertEquals(occasionMd(3.5, 1), null);
  assertEquals(occasionMd(undefined, 1), null);
});

Deno.test("the note reads like any other memory", () => {
  assertEquals(occasionDateLabel("03-12"), "12 مارس");
  assertEquals(occasionNote("birthday", "ماما", "03-12"), "عيد ميلاد ماما: 12 مارس");
  assertEquals(occasionNote("birthday", null, "07-04"), "عيد ميلاد العميل: 4 يوليو");
  assertEquals(occasionNote("anniversary", null, "12-01"), "ذكرى جواز العميل: 1 ديسمبر");
});

Deno.test("days until the next one, across the new year", () => {
  assertEquals(daysUntilOccasion("10-05", "2026-10-05"), 0);
  assertEquals(daysUntilOccasion("10-08", "2026-10-05"), 3);
  assertEquals(daysUntilOccasion("10-04", "2026-10-05"), 364);
  assertEquals(daysUntilOccasion("01-02", "2026-12-30"), 3);
  assertEquals(daysUntilOccasion("bad", "2026-10-05"), null);
});

Deno.test("29 February falls on the 28th in a common year, the 29th in a leap one", () => {
  assertEquals(daysUntilOccasion("02-29", "2027-02-28"), 0);
  assertEquals(daysUntilOccasion("02-29", "2027-02-25"), 3);
  assertEquals(daysUntilOccasion("02-29", "2028-02-28"), 1);
  assertEquals(daysUntilOccasion("02-29", "2028-02-29"), 0);
});

Deno.test("today and in three days only, nearest first, the customer before others", () => {
  const rows = [
    { occasion: "birthday", occasion_for: "يوسف", occasion_md: "10-08" },
    { occasion: "birthday", occasion_for: "ماما", occasion_md: "10-05" },
    { occasion: "birthday", occasion_for: null, occasion_md: "10-05" },
    { occasion: "anniversary", occasion_for: null, occasion_md: "10-06" },
    { occasion: "graduation", occasion_for: "x", occasion_md: "10-05" },
  ];
  assertEquals(upcomingOccasions(rows, "2026-10-05"), [
    { occasion: "birthday", for: null, md: "10-05", in_days: 0 },
    { occasion: "birthday", for: "ماما", md: "10-05", in_days: 0 },
    { occasion: "birthday", for: "يوسف", md: "10-08", in_days: 3 },
  ]);
  assertEquals(upcomingOccasions(rows, "2026-10-01"), []);
});

Deno.test("a gift amount from what is left, never for a house in the red", () => {
  assertEquals(giftSuggestion(6000), 300);
  assertEquals(giftSuggestion(30000), 1500);
  assertEquals(giftSuggestion(1000), 50);
  assertEquals(giftSuggestion(0), null);
  assertEquals(giftSuggestion(-400), null);
  assertEquals(giftSuggestion(null), null);
  assertEquals(giftSuggestion(50), null);
});
