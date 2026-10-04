// «لو اشتريت…» — الرصيد يوم بيوم بنفس معادلة zad_forward_ledger، والشراء بيتطرح من يومه لقدام.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { dailyBalances, type ForwardLedger, simulatePurchase } from "./whatIf.ts";

// رصيد ٣٠٠٠، صرف ١٠٠ في اليوم، قسط مدرسة ١٥٠٠ يوم ١٢ أكتوبر، والدورة بتخلص ١٥ أكتوبر.
const ledger: ForwardLedger = {
  as_of: "2026-10-04",
  horizon_days: 14,
  opening_balance: 3000,
  daily_burn: 100,
  cycle_end: "2026-10-15",
  currency: "EGP",
  event_days: [
    { date: "2026-10-12", balance: 700, events: [{ kind: "obligation", title: "قسط المدرسة", amount: -1500 }] },
  ],
};

Deno.test("what if: the day-by-day balances match the ledger's own formula and its event days", () => {
  const days = dailyBalances(ledger);
  assertEquals(days.length, 14);
  assertEquals(days[0], { date: "2026-10-05", balance: 2900 });
  // The ledger said 700 on the instalment day; rebuilt from the same inputs, so is this.
  assertEquals(days.find((d) => d.date === "2026-10-12")?.balance, 700);
  assertEquals(days.at(-1), { date: "2026-10-18", balance: 100 });
});

Deno.test("what if: a purchase that leaves the school instalment uncovered is «tight», naming it", () => {
  const w = simulatePurchase(ledger, 1000)!;
  assertEquals(w.verdict, "tight");
  assertEquals(w.on, "2026-10-05");
  assertEquals(w.balance_after_purchase, 1900);
  assertEquals(w.before.first_negative, null);
  assertEquals(w.after.first_negative, { date: "2026-10-12", balance: -300 });
  assertEquals(w.after.at_cycle_end, { date: "2026-10-15", balance: -600 });
  assertEquals(w.newly_uncovered, [{ date: "2026-10-12", kind: "obligation", title: "قسط المدرسة", amount: 1500, balance_after: -300 }]);
});

Deno.test("what if: a small purchase is «ok», with what is left at the end of the cycle", () => {
  const w = simulatePurchase(ledger, 200)!;
  assertEquals(w.verdict, "ok");
  assertEquals(w.after.first_negative, null);
  assertEquals(w.after.at_cycle_end?.balance, 200);
  assertEquals(w.newly_uncovered, []);
});

Deno.test("what if: a purchase after the instalment does not touch it", () => {
  const w = simulatePurchase(ledger, 600, "2026-10-13")!;
  assertEquals(w.on, "2026-10-13");
  assertEquals(w.newly_uncovered, []);
  assertEquals(w.after.first_negative?.date, "2026-10-14");
  assertEquals(w.verdict, "tight");
});

Deno.test("what if: already short before buying says so, and nonsense asks nothing", () => {
  const broke: ForwardLedger = { ...ledger, opening_balance: 1000 };
  assertEquals(simulatePurchase(broke, 50)?.verdict, "already_short");
  assertEquals(simulatePurchase(ledger, 0), null);
  assertEquals(simulatePurchase(ledger, -5), null);
  assertEquals(simulatePurchase(ledger, 100, "2027-01-01"), null, "beyond the horizon");
  assertEquals(simulatePurchase({ ...ledger, horizon_days: 0 }, 100), null);
  // «النهارده» (as_of) counts from the first projected day.
  assertEquals(simulatePurchase(ledger, 100, "2026-10-04")?.on, "2026-10-05");
});

Deno.test("what if: string numbers from Postgres numeric are read as numbers", () => {
  const w = simulatePurchase({ ...ledger, opening_balance: "3000.00", daily_burn: "100", event_days: [
    { date: "2026-10-12", events: [{ kind: "obligation", title: "قسط المدرسة", amount: "-1500" }] },
  ] }, 1000)!;
  assert(w.newly_uncovered.length === 1);
});
