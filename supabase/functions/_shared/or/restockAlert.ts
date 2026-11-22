// م٦.٢: تنبيه «محتاجه وقريب». البيت اللي صنف عنده ناقص + محل قريب غالباً فيه الصنف = سطر واحد.
// خصوصية: النص بيقول المحل والصنف بس، ومابيقولش مين أبلغ ولا من أي مصدر. المسافة من موقع البيت التقريبي.
import { type Home, type Rpc, rankStoresForItem } from "./restockAvailabilityData.ts";

export const ALERT_MIN_PROB = 0.7;
export const ALERT_MAX_KM = 5;

export interface RestockAlert {
  item: string;
  store: string;
  prob: number;
  km: number;
  text: string;
}

/** أحسن محل لكل صنف ناقص: احتمال ≥ ٠٫٧ وفي حدود ٥ كم (محل من غير موقع معروف مابيتنبّهش بيه). أقصى `max` تنبيهات. */
export async function restockAlerts(
  sb: Rpc,
  args: { country: string; home: Home; needed: string[]; max?: number },
): Promise<RestockAlert[]> {
  const out: RestockAlert[] = [];
  for (const item of [...new Set(args.needed)]) {
    const [best] = await rankStoresForItem(sb, { country: args.country, item, home: args.home, limit: 1 });
    if (!best || best.prob < ALERT_MIN_PROB || best.distanceKm > ALERT_MAX_KM) continue;
    const km = Math.round(best.distanceKm * 10) / 10;
    out.push({
      item,
      store: best.storeId,
      prob: Math.round(best.prob * 100) / 100,
      km,
      text: `«${item}» غالباً متوفر في ${best.storeId}، على بعد ${km} كم تقريباً.`,
    });
  }
  return out.sort((a, b) => b.prob - a.prob || a.km - b.km).slice(0, args.max ?? 3);
}
