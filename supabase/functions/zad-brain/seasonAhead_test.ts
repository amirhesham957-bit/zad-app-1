// الموسم الجاي: تجهيز قبل ما الأسعار تعلى — رمضان وذي الحجة بأم القرى، بتوقيت العميل.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { upcomingSeason, upcomingSeasonInstruction } from "../_shared/season.ts";
import { type StaffInput, staffNotes } from "./staff.ts";
import { buildChatSystemPrompt } from "./index.ts";

const at = (d: string) => new Date(`${d}T09:00:00Z`);

Deno.test("season ahead: Ramadan 1448 (8 Feb 2027) shows three weeks out, not once it started", () => {
  assertEquals(upcomingSeason(at("2027-01-25"), "Africa/Cairo"), { kind: "ramadan", in_days: 14, hijri_year: 1448 });
  assertEquals(upcomingSeason(at("2027-02-10"), "Africa/Cairo"), null, "already Ramadan: seasonFor covers it");
  assertEquals(upcomingSeason(at("2026-10-04"), "Africa/Cairo"), null);
  assertEquals(upcomingSeason(at("2027-04-25"), "Africa/Cairo")?.kind, "dhul_hijjah");
});

Deno.test("season ahead: the line prepares, it does not push", () => {
  const line = upcomingSeasonInstruction({ kind: "ramadan", in_days: 14 });
  assert(line.includes("بعد حوالي 14 يوم"));
  assert(line.includes("من غير ضغط"));
  assert(upcomingSeasonInstruction({ kind: "dhul_hijjah", in_days: 12 }).includes("من غير افتراض"));
  assertEquals(upcomingSeasonInstruction(null), "");
});

Deno.test("season ahead: the pantry clerk notes it, and the chat rule appears only with one", () => {
  const house: StaffInput = {
    pantry: [{ item_name: "رز", quantity: 2, low_stock_threshold: 1 }], shopping: [],
    pharmacy: [{ name: "فيتامين", remaining_quantity: 30, is_recurring: true, dose_times: "09:00", daily_dose_count: 1, units_per_dose: 1, expiry_date: null }],
    monthlyLimit: 10000, transactionDates: ["2027-01-24T10:00:00Z"], hasPushToken: true, hasTelegram: true,
    pendingShareRequests: [], familyMembers: null, myOpenChores: [],
    seasonAhead: { kind: "ramadan", in_days: 14, hijri_year: 1448 },
  };
  const note = staffNotes(house, at("2027-01-25")).find((n) => n.subject === "رمضان 1448 جاي");
  assert(note && note.sender === "pantry");
  assert(buildChatSystemPrompt({ season_ahead: { kind: "ramadan", in_days: 14, instruction: "x" } }).includes("season_ahead"));
  assertEquals(buildChatSystemPrompt({}).includes("season_ahead"), false);
});
