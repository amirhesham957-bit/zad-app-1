// التزام الدوا في الـsnapshot بيقرا الجدولين (٢٠٢٦-٠٩-٢٥). قبل كده العقل كان بيقرا
// zad_dose_log بس، فعميل بياخد دواه من زرار تليجرام كان باين له إنه مابياخدهوش.
import { assertEquals } from "jsr:@std/assert@1";
import { doseAdherence } from "./shared.ts";

// ٢٠٢٦-٠٩-٢٥ ١٥:٠٠ بتوقيت القاهرة (+03:00) = ١٢:٠٠ UTC.
const NOW = new Date("2026-09-25T12:00:00Z");

Deno.test("الجرعات المتسجلة في zad_pharmacy_doses بتتحسب — ده كان الغلط", () => {
  const items = [{ dose_times: "01:00,13:00", created_at: "2026-09-23T00:00:00Z" }];
  // خانات عدّت: ٢٣/٩ ١٣:٠٠، ٢٤/٩ ٠١:٠٠ و١٣:٠٠، ٢٥/٩ ٠١:٠٠ و١٣:٠٠ (١٠:٠٠Z) = ٥.
  const answered = [
    { status: "taken", scheduled_at: "2026-09-23T10:00:00Z" },
    { status: "taken", scheduled_at: "2026-09-23T22:00:00Z" },
    { status: "skipped", scheduled_at: "2026-09-24T10:00:00Z" },
  ];
  assertEquals(doseAdherence(items, answered, [], "+03:00", NOW), { scheduled: 5, taken: 2, skipped: 1 });
});

Deno.test("مع الجدول القديم بس (أدوية من غير dose_times) السلوك القديم فاضل", () => {
  const legacy = [
    { scheduled_at: "2026-09-24T08:00:00Z", taken_at: "2026-09-24T08:05:00Z" },
    { scheduled_at: "2026-09-25T08:00:00Z", taken_at: null },
    { scheduled_at: "2026-09-26T08:00:00Z", taken_at: null }, // لسه ماجاش
  ];
  assertEquals(doseAdherence([{ dose_times: null }], [], legacy, "+03:00", NOW), { scheduled: 2, taken: 1, skipped: 0 });
});

Deno.test("مفيش أدوية مجدولة = null، مش صفر من صفر", () => {
  assertEquals(doseAdherence([], [], [], "+03:00", NOW), null);
  assertEquals(doseAdherence([{ dose_times: "25:00" }], [], [], "+03:00", NOW), null);
});
