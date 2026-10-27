import { assertEquals } from "jsr:@std/assert@1";
import { PENDING_TTL_MS, pendingAnswerable, sensitiveTopic } from "./sensitiveMemory.ts";

Deno.test("sensitiveTopic: الحاجات اللي تجرح لو اتفهمت غلط بتتمسك", () => {
  assertEquals(sensitiveTopic("مراته حامل في الشهر الرابع"), "pregnancy");
  assertEquals(sensitiveTopic("مامته عندها السرطان وبتاخد كيماوي"), "health");
  assertEquals(sensitiveTopic("بيروح لدكتور نفسي كل أسبوع"), "mental_health");
  assertEquals(sensitiveTopic("هو وجوزته منفصلين من شهرين"), "marriage");
  assertEquals(sensitiveTopic("أخوه مسجون ومصاريفه عليه"), "legal");
  assertEquals(sensitiveTopic("العيلة مسيحية وبيصوموا الصيام الكبير"), "religion");
  assertEquals(sensitiveTopic("ابنه عنده توحد وبيروح جلسات"), "health");
  assertEquals(sensitiveTopic("عنده سكري فبيقلل السكر"), "health");
});

Deno.test("sensitiveTopic: كلام البيت العادي مايتسألش عليه", () => {
  for (const note of [
    "عنده عيّلين في سن المدرسة (أحمد ونور)",
    "القبض يوم ٢٥ في الشهر",
    "ابنه عنده حساسية من الفول السوداني",
    "بيحب القهوة من غير سكر",
    "سني ٣٤ سنة وشغال مهندس",
    "جنسيته مصرية وعايش في الرياض",
    "عليه قسط عربية ٣٠٠٠ كل شهر",
    "بيشتري الحمل الأسبوعي من كارفور",
  ]) assertEquals(sensitiveTopic(note), null, note);
});

Deno.test("pendingAnswerable: التأكيد لازم ييجي في لفة بعد اللي اتركنت فيها", () => {
  const turn = Date.parse("2026-10-27T10:00:00Z");
  const before = { created_at: "2026-10-27T09:58:00Z", resolved_at: null };
  assertEquals(pendingAnswerable(before, turn, turn + 1000), "ok");
  assertEquals(pendingAnswerable({ created_at: "2026-10-27T10:00:01Z", resolved_at: null }, turn, turn + 2000), "same_turn");
  assertEquals(pendingAnswerable({ ...before, resolved_at: "2026-10-27T09:59:00Z" }, turn, turn), "resolved");
  assertEquals(pendingAnswerable(before, turn, Date.parse(before.created_at) + PENDING_TTL_MS + 1), "expired");
});
