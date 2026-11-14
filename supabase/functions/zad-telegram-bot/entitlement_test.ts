import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { mediaGate } from "./entitlement.ts";

function sbWith(responses: Record<string, unknown>) {
  return {
    rpc: (name: string) => Promise.resolve({ data: responses[name] ?? null, error: null }),
  };
}

Deno.test("المجاني: الصور والفويس من رصيد الساعتين بتاع التطبيق (قرار المالك ١٠/١١)", async () => {
  const sb = sbWith({
    zad_entitlement_status: { telegram_media: false, tier: "free" },
    zad_entitlement_consume: { allowed: true, reason: "quota", images_left: 1 },
  });
  assertEquals(await mediaGate(sb, "u1", "voice"), { allowed: true });
  assertEquals(await mediaGate(sb, "u1", "scan"), { allowed: true });
});

Deno.test("المجاني بعد الصورتين أو الـ٣ أسئلة صوتية بياخد رسالة «كل ساعتين» مش ترقية", async () => {
  const images = await mediaGate(sbWith({
    zad_entitlement_status: { telegram_media: false, tier: "free" },
    zad_entitlement_consume: { allowed: false, reason: "image_cycle_cap" },
  }), "u1", "scan");
  assertEquals(images.allowed, false);
  assertEquals(images.reply!.includes("٢ كل ساعتين"), true);

  const voice = await mediaGate(sbWith({
    zad_entitlement_status: { telegram_media: false, tier: "free" },
    zad_entitlement_consume: { allowed: false, reason: "voice_cycle_cap" },
  }), "u1", "voice");
  assertEquals(voice.allowed, false);
  assertEquals(voice.reply!.includes("٣ كل ساعتين"), true);
});

Deno.test("باقة من غير وسائط (مش مجانية) لسه الصور مقفولة برسالة ترقية", async () => {
  const photo = await mediaGate(sbWith({
    zad_entitlement_status: { telegram_media: false, tier: "legacy" },
    zad_entitlement_consume: { allowed: true, reason: "quota" },
  }), "u1", "scan");
  assertEquals(photo.allowed, false);
  assertEquals(photo.reply!.includes("الفواتير"), true);
});

Deno.test("المشترك اللي عنده رصيد بيعدي", async () => {
  const sb = sbWith({
    zad_entitlement_status: { telegram_media: true, tier: "plus" },
    zad_entitlement_consume: { allowed: true, reason: "quota", left: 99 },
  });
  assertEquals(await mediaGate(sb, "u1", "voice"), { allowed: true });
  assertEquals(await mediaGate(sb, "u1", "scan"), { allowed: true });
});

Deno.test("المشترك اللي رصيده خلص بياخد رسالة رصيد مش رسالة ترقية", async () => {
  const sb = sbWith({
    zad_entitlement_status: { telegram_media: true, tier: "starter" },
    zad_entitlement_consume: { allowed: false, reason: "quota_exhausted" },
  });
  const r = await mediaGate(sb, "u1", "voice");
  assertEquals(r.allowed, false);
  assertEquals(r.reply!.includes("خلص رصيد"), true);
});

// الفرق المقصود عن بوابة zad-brain: دي بتفشل مقفولة. لو الفحص وقع، الميزة المدفوعة
// ماتبقاش مجانية لأي حد بيجرب في اللحظة دي.
// voice_daily_cap بقى للباقات المدفوعة اللي ليها حد يومي بس؛ المجاني بياخد voice_cycle_cap (20261110210000).
Deno.test("الحد اليومي للصوت بياخد رسالة «بكرة» من غير ما يدّعي إنه المجاني", async () => {
  const sb = sbWith({
    zad_entitlement_status: { telegram_media: true, tier: "starter" },
    zad_entitlement_consume: { allowed: false, reason: "voice_daily_cap", voice_daily: 6 },
  });
  const r = await mediaGate(sb, "u1", "voice");
  assertEquals(r.allowed, false);
  assertEquals(r.reply!.includes("بكرة"), true);
  assertEquals(r.reply!.includes("المجانية"), false);
});

Deno.test("فشل الفحص بيقفل الوسائط، مش بيفتحها", async () => {
  const sbErr = { rpc: () => Promise.resolve({ data: null, error: { message: "boom" } }) };
  assertEquals((await mediaGate(sbErr, "u1", "voice")).allowed, false);

  const sbThrow = { rpc: () => Promise.reject(new Error("net")) };
  assertEquals((await mediaGate(sbThrow, "u1", "scan")).allowed, false);
});

Deno.test("رد ناقص من الـ RPC بيتعامل معاه كقفل", async () => {
  const sb = sbWith({ zad_entitlement_status: {} });
  assertEquals((await mediaGate(sb, "u1", "voice")).allowed, false);
});
