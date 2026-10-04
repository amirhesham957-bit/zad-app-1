// كارت الطوارئ: كل اللي العيلة محتاجاه في لحظة واحدة — من بياناتها هي، من غير تشخيص.
import { assertEquals } from "jsr:@std/assert@1";
import { AMBULANCE_NUMBERS, emergencyCard } from "./emergency.ts";

const NOW = Date.parse("2026-10-04T12:00:00Z");
const hoursAgo = (h: number) => new Date(NOW - h * 3_600_000).toISOString();

const medicines = [
  { id: "m1", name: "كونكور", dosage: "5mg", dose_times: "09:00", remaining_quantity: 20, for_person: "أمي" },
  { id: "m2", name: "فيتامين د", dosage: null, dose_times: null, remaining_quantity: 30, for_person: null },
  { id: "m3", name: "شراب كحة", dosage: "5ml", dose_times: "20:00", remaining_quantity: 1, for_person: "عمر" },
];
const doses = [
  { item_id: "m1", taken_at: hoursAgo(3), status: "taken" },
  { item_id: "m1", taken_at: hoursAgo(30), status: "taken" },
  { item_id: "m3", taken_at: hoursAgo(2), status: "taken" },
  { item_id: "m1", taken_at: null, status: "missed" },
];
const appointments = [
  { title: "دكتور القلب", starts_at: "2026-10-10T08:00:00Z", kind: "medical", for_person: "ماما" },
  { title: "اجتماع", starts_at: "2026-10-05T08:00:00Z", kind: "work", for_person: null },
];
const family = [
  { alias: "بابا", role: "admin", is_me: true },
  { alias: "ماما", role: "member", is_me: false },
  { alias: "سارة", role: "member", is_me: false },
];

Deno.test("emergency: mum's card gathers her medicines, today's doses and her doctor — «أمي» is «ماما»", () => {
  const card = emergencyCard({ person: "ماما", country: "EG", medicines, doses, appointments, notes: ["عندها حساسية من البنسلين"], family, now: NOW });
  assertEquals(card.ambulance, "123");
  assertEquals(card.medicines.map((m) => m.name), ["كونكور"]);
  assertEquals(card.doses_last_24h, [{ name: "كونكور", taken_at: hoursAgo(3) }]);
  assertEquals(card.medical_appointments, [{ title: "دكتور القلب", starts_at: "2026-10-10T08:00:00Z" }]);
  assertEquals(card.notes, ["عندها حساسية من البنسلين"]);
  assertEquals(card.family_to_call, ["ماما", "سارة"]);
});

Deno.test("emergency: the customer's own card holds only their own medicines", () => {
  const card = emergencyCard({ person: null, country: "SA", medicines, doses, appointments, notes: [], family: [], now: NOW });
  assertEquals(card.person, "العميل نفسه");
  assertEquals(card.ambulance, "997");
  assertEquals(card.medicines.map((m) => m.name), ["فيتامين د"]);
  assertEquals(card.doses_last_24h, []);
});

Deno.test("emergency: a country without a number we are sure of gets none, never a guess", () => {
  assertEquals(emergencyCard({ person: null, country: "LY", medicines: [], doses: [], appointments: [], notes: [], family: [], now: NOW }).ambulance, null);
  assertEquals(emergencyCard({ person: null, country: null, medicines: [], doses: [], appointments: [], notes: [], family: [], now: NOW }).ambulance, null);
  assertEquals(Object.keys(AMBULANCE_NUMBERS).sort(), ["AE", "EG", "JO", "KW", "QA", "SA", "TR"]);
});
