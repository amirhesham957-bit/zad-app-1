/**
 * ZAD_PLAN ٢.٧(ب) — مفتاح الإرسال بتاع الجهاز.
 *
 * محرك الخلفية بتاع مستمع البنك مابيجددش الجلسة (١.٣)، فبعد ساعة من آخر فتحة مكانش
 * يقدر يبعت. التطبيق بيسجّل مفتاح عشوائي للجهاز وهو معاه جلسة صالحة، والسيرفر بيخزّن
 * الهاش بس (`zad_device_send_keys`). المفتاح ده بيفتح `notification_ingest` **بس**،
 * والحساب بييجي من صف المفتاح، عمره ما بييجي من `body.user_id`.
 */

/** الهيدر اللي محرك الخلفية بيبعت فيه المفتاح. */
export const DEVICE_KEY_HEADER = "x-zad-device-key";

/** الأكشنز اللي المفتاح يفتحها. واحد بس، عن قصد. */
export function deviceKeyAllows(action: unknown): boolean {
  return action === "notification_ingest";
}

/** المفتاح من الهيدر، أو null لو مش موجود أو شكله غلط (٣٢ بايت base64url = ٤٣ حرف). */
export function presentedDeviceKey(req: Request): string | null {
  const raw = (req.headers.get(DEVICE_KEY_HEADER) ?? "").trim();
  return /^[A-Za-z0-9_-]{40,128}$/.test(raw) ? raw : null;
}

/** SHA-256 بالهيكس — نفس اللي التطبيق بيسجّله. */
export async function hashDeviceKey(key: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(key));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export type DeviceKeyLookup = (keyHash: string) => Promise<string | null>;

/**
 * صاحب المفتاح، أو null. مابيتنادىش غير لما مفيش JWT صالح، وللأكشنز اللي
 * [deviceKeyAllows] بيسمح بيها.
 */
export async function resolveDeviceKeyUser(
  req: Request,
  action: unknown,
  lookup: DeviceKeyLookup,
): Promise<string | null> {
  if (!deviceKeyAllows(action)) return null;
  const key = presentedDeviceKey(req);
  if (!key) return null;
  try {
    return await lookup(await hashDeviceKey(key));
  } catch {
    return null;
  }
}
