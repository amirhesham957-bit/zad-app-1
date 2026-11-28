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

/**
 * أكشنز المكان اللي محرك الخلفية بيبعتها من غير جلسة (الجيوفنس: وصول محل، رجوع
 * البيت، ملخص المشوار). عليها حد معدّل لكل مفتاح.
 */
export const DEVICE_KEY_PLACE_ACTIONS: readonly string[] = ["store_arrival", "place_event", "commute_summary"];

/** الأكشنز اللي المفتاح يفتحها، وبس. أي أكشن تاني بيفضل ٤٠١. */
export const DEVICE_KEY_ACTIONS: readonly string[] = ["notification_ingest", ...DEVICE_KEY_PLACE_ACTIONS];

/** حد المكالمات لكل مفتاح في الساعة لأكشنز المكان. */
export const DEVICE_KEY_PLACE_HOURLY_LIMIT = 60;

export function deviceKeyAllows(action: unknown): boolean {
  return typeof action === "string" && DEVICE_KEY_ACTIONS.includes(action);
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

export type DeviceKeyCall =
  | { kind: "ok"; userId: string }
  | { kind: "none" }
  | { kind: "limited" };

/**
 * مكالمة بمفتاح جهاز: الحساب من صف المفتاح بس. أكشنز المكان بتعدّي على [hit]
 * (يرجّع false لو المفتاح عدّى الحد) — لو فشل العدّاد نرفض، مانفتحش من غير حد.
 */
export async function resolveDeviceKeyCall(
  req: Request,
  action: unknown,
  lookup: DeviceKeyLookup,
  hit: (keyHash: string) => Promise<boolean>,
): Promise<DeviceKeyCall> {
  if (!deviceKeyAllows(action)) return { kind: "none" };
  const key = presentedDeviceKey(req);
  if (!key) return { kind: "none" };
  try {
    const keyHash = await hashDeviceKey(key);
    const userId = await lookup(keyHash);
    if (!userId) return { kind: "none" };
    if (DEVICE_KEY_PLACE_ACTIONS.includes(String(action)) && !(await hit(keyHash))) return { kind: "limited" };
    return { kind: "ok", userId };
  } catch {
    return { kind: "none" };
  }
}
