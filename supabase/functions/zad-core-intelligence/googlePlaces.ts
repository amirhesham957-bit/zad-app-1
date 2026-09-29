// Google Places (New) Nearby Search — أول مصدر لـ nearby_pois (٢٠٢٦-٠٩-٢٨).
//
// المالك حط مفتاح جوجل ماب كسرّ على المشروع، واسم السر مش معروف من الريبو، فبنقرا أول اسم
// موجود من [GOOGLE_PLACES_KEY_NAMES] — provider_health بيطبع أي سر اسمه فيه MAPS/PLACES، فلو
// اتحط باسم تاني يبان هناك. المفتاح على السيرفر بس: الموبايل بيبعت نقطة تقريبية (٣ خانات) والرد
// بيتخزن لكل خلية، فالجيران بيشاركوا نداء واحد — Nearby Search بيتحاسب بعد حد شهري مجاني.
//
// null = فشل (مفتاح غلط، API مش مفعّل، شبكة) → nearby_pois بيكمّل على LocationIQ ثم Overpass.

export const GOOGLE_PLACES_KEY_NAMES = [
  "GOOGLE_MAPS_API_KEY",
  "GOOGLE_PLACES_API_KEY",
  "GOOGLE_MAPS_KEY",
  "MAPS_API_KEY",
  "GOOGLE_API_KEY",
];

export function googlePlacesKey(env: (name: string) => string | undefined): string | undefined {
  for (const name of GOOGLE_PLACES_KEY_NAMES) {
    const v = env(name)?.trim();
    if (v) return v;
  }
  return undefined;
}

/** أنواع جوجل لكل tag الكلاينت بيبعته — نفس tags بتاعة LocationIQ. */
export const PLACE_TYPES: Record<string, string[]> = {
  supermarket: ["supermarket", "grocery_store", "convenience_store"],
  pharmacy: ["pharmacy", "drugstore"],
};

export interface NearbyPlace {
  name: string;
  lat: number;
  lon: number;
  distance_meters: number;
}

function metres(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const r = 6_371_000;
  const rad = (d: number) => (d * Math.PI) / 180;
  const a = Math.sin(rad(lat2 - lat1) / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(rad(lon2 - lon1) / 2) ** 2;
  return Math.round(2 * r * Math.asin(Math.sqrt(a)));
}

/** صافية: رد searchNearby → محلات بأسماء وإحداثيات، الأقرب الأول. */
export function parseNearby(raw: unknown, lat: number, lon: number): NearbyPlace[] {
  const places = (raw as { places?: unknown })?.places;
  if (!Array.isArray(places)) return [];
  const out: NearbyPlace[] = [];
  for (const p of places) {
    const name = (p as { displayName?: { text?: unknown } })?.displayName?.text;
    const loc = (p as { location?: { latitude?: unknown; longitude?: unknown } })?.location;
    if (typeof name !== "string" || !name.trim()) continue;
    if (typeof loc?.latitude !== "number" || typeof loc?.longitude !== "number") continue;
    out.push({
      name: name.trim(),
      lat: loc.latitude,
      lon: loc.longitude,
      distance_meters: metres(lat, lon, loc.latitude, loc.longitude),
    });
  }
  return out.sort((a, b) => a.distance_meters - b.distance_meters);
}

export async function googleNearby(
  fetchImpl: typeof fetch,
  key: string,
  q: { lat: number; lon: number; tag: string; radius: number },
): Promise<NearbyPlace[] | null> {
  const types = PLACE_TYPES[q.tag];
  if (!types) return null;
  try {
    const res = await fetchImpl("https://places.googleapis.com/v1/places:searchNearby", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": key,
        // الحقلين دول بس — كل حقل زيادة بيرفع شريحة التسعير.
        "X-Goog-FieldMask": "places.displayName,places.location",
      },
      body: JSON.stringify({
        includedTypes: types,
        maxResultCount: 20,
        rankPreference: "DISTANCE",
        languageCode: "ar",
        locationRestriction: {
          circle: { center: { latitude: q.lat, longitude: q.lon }, radius: Math.min(Math.max(q.radius, 100), 50_000) },
        },
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) {
      console.error(`[CoreIntel] google places HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`);
      return null;
    }
    return parseNearby(await res.json(), q.lat, q.lon);
  } catch (e) {
    console.error("[CoreIntel] google places failed:", (e as Error).message);
    return null;
  }
}
