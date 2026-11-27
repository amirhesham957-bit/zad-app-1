import { assert, assertEquals } from "jsr:@std/assert@1";
import { guardHealthInference, HEALTH_SAFE_FALLBACK, isUndeclaredHealthInference } from "./healthInferenceGuard.ts";

Deno.test("blocks 'I think you are pregnant' inferred from purchases (ar + en)", () => {
  for (const t of [
    "أظن إنك حامل، بتشتري فيتامينات كتير.",
    "شكلك حامل بعد مشتريات الصيدلية دي",
    "عندك سكري على ما يبدو من كمية السكر اللي بتشتريها",
    "I think you might be pregnant based on your purchases.",
    "You probably have diabetes.",
  ]) {
    assert(isUndeclaredHealthInference(t, ""), t);
    assertEquals(guardHealthInference(t).text, HEALTH_SAFE_FALLBACK, t);
  }
});

Deno.test("allows the same sentence when the customer declared the condition", () => {
  assertEquals(isUndeclaredHealthInference("أظن إنك حامل", "أنا حامل في الشهر الرابع"), false);
  assertEquals(isUndeclaredHealthInference("You might have diabetes", "my diabetes is under control"), false);
  assertEquals(guardHealthInference("بما إنك حامل، خلّي بالك من الأكل النيّ.", "أنا حامل").removed.length, 0);
});

Deno.test("keeps the harmless sentences, drops only the inference", () => {
  const v = guardHealthInference("صرفت ٣٠٠ جنيه النهارده. أظن إنك حامل. تحب أسجّل المصروف؟");
  assertEquals(v.removed.length, 1);
  assert(!v.text.includes("حامل") && v.text.includes("٣٠٠"));
});

Deno.test("ordinary shopping and reminder text is untouched (sugar the product is not diabetes)", () => {
  for (const t of ["خلص السكر من المخزن", "اشتريت سكر وزيت بـ٦٠ جنيه", "عندك موعد قياس ضغط الدم بكرة", "Your pharmacy order arrived."]) {
    assertEquals(guardHealthInference(t).text, t);
  }
});

// السلك: الحارس لازم يكون موصّل في رد الشات والإشعارين. mutation check: شيل الاستدعاء ⇒ التست يقع.
Deno.test("guard is wired into the chat reply and both proactive push paths", () => {
  const brain = Deno.readTextFileSync(new URL("../../zad-brain/index.ts", import.meta.url));
  const push = Deno.readTextFileSync(new URL("../../zad-brain/push.ts", import.meta.url));
  assert(brain.includes("guardHealthInference(reply"), "chat reply");
  assertEquals(push.split("guardHealthInference(body)").length - 1, 2, "device + telegram");
  assertEquals(push.split("guardHealthInference(title)").length - 1, 2, "device + telegram titles");
});
