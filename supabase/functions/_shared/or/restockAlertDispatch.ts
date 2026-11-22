// م٦.٢: قرار الإرسال اليومي لتنبيه الريستوك لبيت واحد. من غير شبكة: الـRPC (rankStoresForItem) بتتحقن.
// قواعد: موقع تقريبي بس، سقف ٣ تنبيهات في اليوم، مفيش في الكتم ووضع الطوارئ وساعات النوم.
// خصوصية: النص بيقول الصنف والمحل والمسافة بس. مفيش مين اشترى ولا المصدر.
import { normalizeItemName } from "../../zad-brain/lowStock.ts";
import { isQuietHourIn, localHourIn, quietWindowOf } from "../../zad-brain/shared.ts";
import { approxHome, type Rpc } from "./restockAvailabilityData.ts";
import { restockAlerts } from "./restockAlert.ts";

export const DAILY_ALERT_CAP = 3;

export interface Candidate {
  user_id: string;
  country: string;
  tz: string;
  lat: number | string;
  lng: number | string;
  sleep_bed: string | null;
  sleep_wake: string | null;
  muted: boolean;
  broke: boolean;
  sent_today: number;
  needed: string[];
}

export type Plan =
  | { send: false; reason: "muted" | "broke" | "quiet_hours" | "daily_cap" | "no_location" | "nothing" }
  | { send: true; title: string; body: string; itemKeys: string[] };

export async function planRestockAlert(sb: Rpc, c: Candidate, nowMs: number): Promise<Plan> {
  if (c.muted) return { send: false, reason: "muted" };
  if (c.broke) return { send: false, reason: "broke" };
  const room = DAILY_ALERT_CAP - (Number(c.sent_today) || 0);
  if (room <= 0) return { send: false, reason: "daily_cap" };
  if (isQuietHourIn(localHourIn(c.tz, nowMs), quietWindowOf(c.sleep_bed, c.sleep_wake))) {
    return { send: false, reason: "quiet_hours" };
  }
  const lat = Number(c.lat), lng = Number(c.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || !c.country) return { send: false, reason: "no_location" };

  const display = new Map<string, string>();
  for (const name of c.needed) {
    const key = normalizeItemName(name);
    if (key && !display.has(key)) display.set(key, name);
  }
  const alerts = await restockAlerts(sb, {
    country: c.country,
    home: approxHome({ lat, lng }),
    needed: [...display.keys()],
    max: room,
  });
  if (!alerts.length) return { send: false, reason: "nothing" };
  const lines = alerts.map((a) => a.text.replace(`«${a.item}»`, `«${display.get(a.item) ?? a.item}»`));
  return {
    send: true,
    title: "🛒 ناقصك حاجة وقريبة منك",
    body: lines.join("\n"),
    itemKeys: alerts.map((a) => (display.get(a.item) ?? a.item).toLowerCase().slice(0, 60)),
  };
}
