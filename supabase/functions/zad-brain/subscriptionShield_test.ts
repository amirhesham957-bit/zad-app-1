// درع الاشتراكات: اشتراكين في نفس النوع، أو الاشتراكات بقت تقيلة — سؤال، مش نصيحة إلغاء، والفواتير برّه.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { monthlyCost, type StaffInput, staffNotes } from "./staff.ts";

const NOW = new Date("2026-10-04T09:00:00Z");

function house(subscriptions: StaffInput["subscriptions"], monthlyLimit = 10000): StaffInput {
  return {
    pantry: [{ item_name: "رز", quantity: 2, low_stock_threshold: 1 }], shopping: [],
    pharmacy: [{ name: "فيتامين", remaining_quantity: 30, is_recurring: true, dose_times: "09:00", daily_dose_count: 1, units_per_dose: 1, expiry_date: null }],
    monthlyLimit, transactionDates: ["2026-10-03T10:00:00Z"], hasPushToken: true, hasTelegram: true,
    pendingShareRequests: [], familyMembers: null, myOpenChores: [], subscriptions,
  };
}

// The owner's subscriptions on the live project, 2026-10-04.
const owner: StaffInput["subscriptions"] = [
  { title: "Shahid", amount: 300, category: "ترفيه", type: "subscription", billing_cycle: "MONTHLY" },
  { title: "نتفليكس", amount: 300, category: "ترفيه", type: "subscription", billing_cycle: "MONTHLY" },
  { title: "فاتورة كهرباء", amount: 50, category: "فواتير", type: "utility", billing_cycle: "MONTHLY" },
];

const subjects = (input: StaffInput) => staffNotes(input, NOW).filter((n) => n.sender === "finance").map((n) => n.subject);

Deno.test("shield: two entertainment subscriptions are asked about, the electricity bill never", () => {
  const notes = staffNotes(house(owner), NOW).filter((n) => n.subject.startsWith("اشتراكات في نفس النوع"));
  assertEquals(notes.map((n) => n.subject), ["اشتراكات في نفس النوع «ترفيه»: Shahid، نتفليكس"]);
  assert(notes[0].detail.includes("بحوالي 600 في الشهر"));
  assert(notes[0].detail.includes("سؤال مش نصيحة إلغاء"));
  assertEquals(notes[0].detail.includes("كهرباء"), false);
});

Deno.test("shield: subscriptions over a tenth of the month's ceiling are named with the number", () => {
  assert(subjects(house(owner, 5000)).includes("الاشتراكات بقت ١٠٪ أو أكتر من مصروف الشهر"), "600 of 5000");
  assertEquals(subjects(house(owner, 13123)).includes("الاشتراكات بقت ١٠٪ أو أكتر من مصروف الشهر"), false, "600 of 13123");
});

Deno.test("shield: bills, obligations and a single subscription are left alone", () => {
  const bills: StaffInput["subscriptions"] = [
    { title: "كهربا", amount: 400, category: "فواتير", type: "utility", billing_cycle: "MONTHLY" },
    { title: "مية", amount: 100, category: "فواتير", type: null, billing_cycle: "MONTHLY" },
    { title: "قسط العربية", amount: 3000, category: "التزامات", type: "subscription", billing_cycle: "MONTHLY" },
    { title: "نتفليكس", amount: 300, category: "ترفيه", type: "subscription", billing_cycle: "MONTHLY" },
  ];
  assertEquals(subjects(house(bills, 100000)).filter((s) => s.includes("اشتراك")), []);
});

Deno.test("shield: a yearly subscription counts a twelfth a month", () => {
  assertEquals(monthlyCost({ amount: 1200, billing_cycle: "YEARLY" }), 100);
  assertEquals(monthlyCost({ amount: 300, billing_cycle: "MONTHLY" }), 300);
  assertEquals(monthlyCost({ amount: null, billing_cycle: null }), 0);
});
