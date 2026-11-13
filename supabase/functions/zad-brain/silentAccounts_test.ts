// قرار المالك ١٣/١١ (٢ج): الحساب الساكت مايوصلوش أي لحظة اختيارية؛ الجرعات والمواعيد والأمان بيعدّوا.
import { assertEquals } from "jsr:@std/assert@1";
import { NEVER_HELD_MOMENTS, silentAccountHold } from "./voiceMoments.ts";
import { CHAT_VOICE_REPLY_MOMENT, TELEGRAM_WELCOME_MOMENT } from "../_shared/zadVoice.ts";

Deno.test("a silent account gets none of the optional moments", () => {
  for (const m of ["morning_greeting", "good_night", "close_day", "newcomer_question", "travel_arrived", "weekly_money", "pet_call"]) {
    assertEquals(silentAccountHold(m, true), "silent_account", m);
  }
});

Deno.test("doses, appointments, family alerts and the Telegram welcome still reach a silent account", () => {
  for (const m of [...NEVER_HELD_MOMENTS, TELEGRAM_WELCOME_MOMENT, CHAT_VOICE_REPLY_MOMENT]) {
    assertEquals(silentAccountHold(m, true), null, m);
  }
  assertEquals(NEVER_HELD_MOMENTS.has("appointment_soon"), true);
  assertEquals(NEVER_HELD_MOMENTS.has("family_dose_missed"), true);
});

Deno.test("an account that talked or has data is not held by this gate", () => {
  for (const m of ["morning_greeting", "good_night", "close_day"]) assertEquals(silentAccountHold(m, false), null, m);
});
