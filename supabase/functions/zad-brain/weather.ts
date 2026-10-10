// weather.ts — الطقس من Open-Meteo (الموجة ٤ من «خطة سد الفجوات»، قرار المالك ٢٠٢٦-١٠-١٠: مجاني ومن غير مفتاح).
//
// §١٠ كان رافض الطقس لأنه «مالوش مصدر موثوق»؛ Open-Meteo مصدر معروف (نماذج الأرصاد الوطنية)، والقرار اتاخد.
// المكان **تقريبي دايماً**: مدينة العميل من «ملفي» (zad_customer_profile.city) بالـgeocoding بتاع Open-Meteo جوه بلده،
// وإلا عاصمة بلده. مفيش لوكيشن موبايل هنا — الطقس مش محتاج أكتر من المدينة.
//
// كاش في `zad_weather_cache` بمفتاح المكان (مش العميل) ٣ ساعات: عملاء نفس المدينة بيقروا نفس الصف، والنداء
// الخارجي بيحصل مرة في ٣ ساعات للمدينة كلها. أي فشل (شبكة، رد غريب) = null، والعقل بيقول إنه مش عارف.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const WEATHER_TTL_MS = 3 * 3_600_000;
/** صف مدينة اتدورت ومالقيناهاش — مكانها العاصمة، ومايتدورش عليها تاني. */
const NOT_FOUND = "؟";
export const FORECAST_DAYS = 4;

/** عواصم البلاد اللي زاد شغال فيها — المكان لو المدينة مش معروفة أو مالقيناهاش. */
export const CAPITALS: Record<string, { name: string; lat: number; lon: number }> = {
  EG: { name: "القاهرة", lat: 30.0626, lon: 31.2497 },
  SA: { name: "الرياض", lat: 24.6877, lon: 46.7219 },
  AE: { name: "أبوظبي", lat: 24.4539, lon: 54.3773 },
  KW: { name: "الكويت", lat: 29.3759, lon: 47.9774 },
  QA: { name: "الدوحة", lat: 25.2854, lon: 51.531 },
  BH: { name: "المنامة", lat: 26.2285, lon: 50.586 },
  OM: { name: "مسقط", lat: 23.588, lon: 58.3829 },
  JO: { name: "عمّان", lat: 31.9539, lon: 35.9106 },
  LB: { name: "بيروت", lat: 33.8938, lon: 35.5018 },
  IQ: { name: "بغداد", lat: 33.3152, lon: 44.3661 },
  SY: { name: "دمشق", lat: 33.5138, lon: 36.2765 },
  YE: { name: "صنعاء", lat: 15.3694, lon: 44.191 },
  PS: { name: "رام الله", lat: 31.9038, lon: 35.2034 },
  LY: { name: "طرابلس", lat: 32.8872, lon: 13.1913 },
  SD: { name: "الخرطوم", lat: 15.5007, lon: 32.5599 },
  MA: { name: "الرباط", lat: 34.0209, lon: -6.8416 },
  TN: { name: "تونس", lat: 36.8065, lon: 10.1815 },
  DZ: { name: "الجزائر", lat: 36.7538, lon: 3.0588 },
  TR: { name: "إسطنبول", lat: 41.0082, lon: 28.9784 },
};

export interface DayWeather {
  date: string;
  code: number;
  label: string;
  max: number;
  min: number;
  rain_mm: number;
  wind_kmh: number;
}

export interface WeatherFacts {
  place: string;
  /** المكان اتعرف إزاي: مدينة الملف، ولا عاصمة البلد. */
  from: "city" | "capital";
  days: DayWeather[];
  fetched_at: string;
}

/** أكواد WMO (Open-Meteo) ⇒ وصف قصير بالعامية. */
export function wmoLabel(code: number): string {
  if (code === 0) return "صافي";
  if (code <= 2) return "صافي مع شوية سحاب";
  if (code === 3) return "غيم";
  if (code === 45 || code === 48) return "شبورة";
  if (code >= 51 && code <= 57) return "رذاذ";
  if (code >= 61 && code <= 67) return code >= 65 ? "مطر تقيل" : "مطر";
  if (code >= 71 && code <= 77) return "تلج";
  if (code >= 80 && code <= 82) return code === 82 ? "سيول مطر" : "زخات مطر";
  if (code === 85 || code === 86) return "تلج";
  if (code >= 95) return "عواصف رعدية";
  return "متقلب";
}

const num = (v: unknown): number | null => (typeof v === "number" && Number.isFinite(v) ? v : null);

/** رد /v1/forecast ⇒ أيام، أو null لو الشكل مش اللي متوقعينه (مايتبنيش على رد غريب). */
export function parseForecast(raw: unknown): DayWeather[] | null {
  const d = (raw as { daily?: Record<string, unknown[]> } | null)?.daily;
  if (!d || !Array.isArray(d.time)) return null;
  const days: DayWeather[] = [];
  for (let i = 0; i < d.time.length && i < FORECAST_DAYS; i++) {
    const date = String(d.time[i] ?? "");
    const code = num(d.weather_code?.[i]);
    const max = num(d.temperature_2m_max?.[i]);
    const min = num(d.temperature_2m_min?.[i]);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || code === null || max === null || min === null) return null;
    days.push({
      date, code, label: wmoLabel(code), max: Math.round(max), min: Math.round(min),
      rain_mm: Math.round((num(d.precipitation_sum?.[i]) ?? 0) * 10) / 10,
      wind_kmh: Math.round(num(d.wind_speed_10m_max?.[i]) ?? 0),
    });
  }
  return days.length ? days : null;
}

/** مفتاح الكاش: المكان مقرّب لـ٢ رقم عشري (~١ كم) — مش العميل. */
export function placeKey(lat: number, lon: number): string {
  return `${lat.toFixed(2)},${lon.toFixed(2)}`;
}

type Fetch = (input: string, init?: RequestInit) => Promise<Response>;

/** الشبكة اللي loadWeather بيستعملها لو ماتبعتلوش fetcher. التستات بتقفلها عشان مايكلموش Open-Meteo الحقيقي. */
export const weatherSource: { fetch: Fetch } = { fetch: (input, init) => fetch(input, init) };

/** مدينة الملف جوه بلده بس (اسم «المنصورة» موجود في ٥ بلاد). الأكبر سكاناً الأول. null = مالقيناهاش. */
export async function geocodeCity(city: string, country: string, fetcher: Fetch = weatherSource.fetch): Promise<{ name: string; lat: number; lon: number } | null> {
  const name = city.replace(/\s+/g, " ").trim().slice(0, 60);
  if (name.length < 2 || !/^[A-Z]{2}$/.test(country)) return null;
  const url = "https://geocoding-api.open-meteo.com/v1/search?" +
    new URLSearchParams({ name, count: "5", language: "ar", countryCode: country }).toString();
  const res = await fetcher(url, { signal: AbortSignal.timeout(6000) });
  if (!res.ok) return null;
  const body = await res.json() as { results?: Array<{ name?: string; latitude?: number; longitude?: number; country_code?: string; population?: number }> };
  const hit = (body.results ?? [])
    .filter((r) => r.country_code === country && num(r.latitude) !== null && num(r.longitude) !== null)
    .sort((a, b) => (b.population ?? 0) - (a.population ?? 0))[0];
  return hit ? { name: String(hit.name ?? name), lat: hit.latitude as number, lon: hit.longitude as number } : null;
}

export function forecastUrl(lat: number, lon: number, timeZone: string): string {
  return "https://api.open-meteo.com/v1/forecast?" + new URLSearchParams({
    latitude: lat.toFixed(4), longitude: lon.toFixed(4),
    daily: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max",
    timezone: timeZone || "auto", forecast_days: String(FORECAST_DAYS),
  }).toString();
}

/**
 * طقس مكان العميل: المدينة (لو معروفة واتلاقت) وإلا العاصمة، من الكاش لو أحدث من ٣ ساعات وإلا من Open-Meteo.
 * null = مفيش بلد معروفة، أو المصدر وقع ومفيش كاش.
 */
export async function loadWeather(
  sb: SupabaseClient,
  input: { country: string | null | undefined; city?: string | null; timeZone: string; now?: number; fetcher?: Fetch },
): Promise<WeatherFacts | null> {
  const country = String(input.country ?? "").toUpperCase();
  const capital = CAPITALS[country];
  if (!capital) return null;
  const now = input.now ?? Date.now();
  const fetcher = input.fetcher ?? weatherSource.fetch;
  try {
    let place = { name: capital.name, lat: capital.lat, lon: capital.lon };
    let from: WeatherFacts["from"] = "capital";
    const city = (input.city ?? "").trim();
    if (city && city !== capital.name) {
      const cityKey = `city:${country}:${city.toLowerCase()}`;
      const { data: known } = await sb.from("zad_weather_cache").select("label,lat,lon").eq("place_key", cityKey).maybeSingle();
      const k = known as { label: string; lat: number; lon: number } | null;
      if (k && k.label !== NOT_FOUND) {
        place = { name: k.label, lat: k.lat, lon: k.lon };
        from = "city";
      } else if (!k) {
        const found = await geocodeCity(city, country, fetcher).catch(() => undefined);
        if (found) {
          place = found;
          from = "city";
        }
        // اسم المدينة ⇒ إحداثياتها (أو «مالقيناهاش») بيتحفظ مرة — مايتعملش geocoding في كل لفة.
        // فشل الشبكة (undefined) مابيتحفظش: المرة الجاية تتجرب تاني.
        if (found !== undefined) {
          await sb.from("zad_weather_cache").upsert({
            place_key: cityKey, label: found ? found.name : NOT_FOUND, lat: place.lat, lon: place.lon, days: [],
            fetched_at: new Date(0).toISOString(),
          }, { onConflict: "place_key" });
        }
      }
    } else if (city === capital.name) {
      from = "city";
    }
    const key = placeKey(place.lat, place.lon);
    const { data: cached } = await sb.from("zad_weather_cache").select("days,fetched_at").eq("place_key", key).maybeSingle();
    const c = cached as { days: DayWeather[]; fetched_at: string } | null;
    if (c && Array.isArray(c.days) && c.days.length && now - Date.parse(c.fetched_at) < WEATHER_TTL_MS) {
      return { place: place.name, from, days: c.days, fetched_at: c.fetched_at };
    }
    const res = await fetcher(forecastUrl(place.lat, place.lon, input.timeZone), { signal: AbortSignal.timeout(8000) });
    const days = res.ok ? parseForecast(await res.json()) : null;
    if (!days) {
      // المصدر وقع: كاش أقدم من ٣ ساعات أحسن من مفيش، بس من غير ما يتعدى يوم.
      return c && Array.isArray(c.days) && c.days.length && now - Date.parse(c.fetched_at) < 24 * 3_600_000
        ? { place: place.name, from, days: c.days, fetched_at: c.fetched_at }
        : null;
    }
    const fetchedAt = new Date(now).toISOString();
    await sb.from("zad_weather_cache").upsert(
      { place_key: key, label: place.name, lat: place.lat, lon: place.lon, days, fetched_at: fetchedAt },
      { onConflict: "place_key" },
    );
    return { place: place.name, from, days, fetched_at: fetchedAt };
  } catch (e) {
    console.warn("[weather] failed:", (e as Error)?.message);
    return null;
  }
}

/** شكل الطقس في السناب شوت: النهارده وبكرة وبعده، من غير الحقول الداخلية. */
export function weatherForSnapshot(w: WeatherFacts | null): Record<string, unknown> | null {
  if (!w) return null;
  return {
    place: w.place,
    source: "Open-Meteo",
    days: w.days.slice(0, 3).map((d) => ({ date: d.date, sky: d.label, max: d.max, min: d.min, rain_mm: d.rain_mm, wind_kmh: d.wind_kmh })),
  };
}

/** قاعدة البرومبت: الجو اللي في السناب شوت ومصدره، أو إنه مش معروف. */
export function weatherRule(snap: { weather?: { place?: string } | null } | null | undefined): string {
  const w = snap?.weather;
  if (!w) return "   - **الجو (weather)**: مش معروف دلوقتي — لو اتسألت عنه قول كده، وماتخمّنش درجات حرارة.\n";
  return `   - **الجو (weather)**: من Open-Meteo لـ${w.place} (تقريبي: مدينته أو عاصمة بلده). استخدمه لو الكلام عن خروج أو لبس ` +
    "أو غسيل أو سفر، وقول المدينة؛ الأرقام من days بس. مدينة تانية ⇒ weather_forecast.\n";
}

// ── حراس الطقس (الموجة ٤، الشريحة ٢) — قواعد على التوقعات، صفر توكنز ───────────────────────────────

export type WeatherAlertKind = "storm" | "heavy_rain" | "heat" | "cold" | "wind";

export interface WeatherAlert {
  kind: WeatherAlertKind;
  day: "today" | "tomorrow";
  date: string;
  /** الجملة نفسها بالأرقام، والنصيحة. */
  line: string;
}

/** حدود «أزمة جو»: عواصف رعدية، مطر ≥ ١٠ مم (أو مطر تقيل/سيول)، عظمى ≥ ٤٠، صغرى ≤ ٥، ريح ≥ ٥٠ كم/س. */
export const HEAVY_RAIN_MM = 10;
export const HEAT_C = 40;
export const COLD_C = 5;
export const WIND_KMH = 50;

function alertFor(d: DayWeather, place: string, when: string): Omit<WeatherAlert, "day" | "date"> | null {
  if (d.code >= 95) {
    return { kind: "storm", line: `${when} فيه عواصف رعدية في ${place} — خليك جوه لو تقدر، وابعد عن أعمدة الكهربا والشجر.` };
  }
  if (d.rain_mm >= HEAVY_RAIN_MM || d.code === 65 || d.code === 67 || d.code === 82) {
    return { kind: "heavy_rain", line: `${when} مطر تقيل في ${place}${d.rain_mm > 0 ? ` (حوالي ${d.rain_mm} مم)` : ""} — قفّل الشبابيك، وخلي بالك من الطريق.` };
  }
  if (d.max >= HEAT_C) {
    return { kind: "heat", line: `${when} حر شديد في ${place} (العظمى ${d.max}°) — مية كتير، وبلاش شمس الضهر خصوصاً للعيال والكبار.` };
  }
  if (d.min <= COLD_C) {
    return { kind: "cold", line: `${when} برد شديد في ${place} (الصغرى ${d.min}°) — دفّي العيال كويس بالليل.` };
  }
  if (d.wind_kmh >= WIND_KMH) {
    return { kind: "wind", line: `${when} ريح شديدة في ${place} (${d.wind_kmh} كم/س) — قفّل الشبابيك وشيل الحاجات الخفيفة من البلكونة.` };
  }
  return null;
}

/** أزمة جو النهارده، وإلا بكرة؛ null لو الجو عادي. [onlyTomorrow] لتصبح على خير. */
export function weatherAlert(w: Pick<WeatherFacts, "place" | "days"> | null, today: string, onlyTomorrow = false): WeatherAlert | null {
  if (!w) return null;
  const i = w.days.findIndex((d) => d.date === today);
  if (i < 0) return null;
  const candidates: Array<[DayWeather | undefined, "today" | "tomorrow", string]> = onlyTomorrow
    ? [[w.days[i + 1], "tomorrow", "بكرة"]]
    : [[w.days[i], "today", "النهارده"], [w.days[i + 1], "tomorrow", "بكرة"]];
  for (const [d, day, when] of candidates) {
    if (!d) continue;
    const a = alertFor(d, w.place, when);
    if (a) return { ...a, day, date: d.date };
  }
  return null;
}

export interface ClothingNudge {
  season: "winter" | "summer";
  /** مرة في الموسم: الشتا من يوليو لـيونيو اللي بعده، والصيف السنة نفسها. */
  key: string;
  line: string;
}

/** الصغرى ≤ ١٥ أو العظمى ≥ ٣٣ في يومين على الأقل من التلاتة الجايين ⇒ وقت تبديل هدوم الموسم. */
export const CLOTHES_COLD_MIN = 15;
export const CLOTHES_HOT_MAX = 33;

export function clothingNudge(w: Pick<WeatherFacts, "days"> | null, today: string): ClothingNudge | null {
  if (!w) return null;
  const i = w.days.findIndex((d) => d.date === today);
  if (i < 0) return null;
  const next = w.days.slice(i, i + 3);
  if (next.length < 2) return null;
  const [y, m] = today.split("-").map(Number);
  const cold = next.filter((d) => d.min <= CLOTHES_COLD_MIN);
  if (cold.length >= 2) {
    const low = Math.min(...cold.map((d) => d.min));
    return {
      season: "winter", key: `clothes:winter:${m >= 7 ? y : y - 1}`,
      line: `الليالي بدأت تبرد (الصغرى ${low}°) — وقت تطلّعوا البطاطين وهدوم الشتا؟`,
    };
  }
  const hot = next.filter((d) => d.max >= CLOTHES_HOT_MAX);
  if (hot.length >= 2) {
    const high = Math.max(...hot.map((d) => d.max));
    return {
      season: "summer", key: `clothes:summer:${y}`,
      line: `الحر بدأ (العظمى ${high}°) — وقت تطلّعوا هدوم الصيف وتشيلوا الشتوي؟`,
    };
  }
  return null;
}

/** مفاتيح تبديل الهدوم اللي اتقالت (facts.weather_clothes.key في تحيات الصبح). */
export function askedClothesKeys(rows: ReadonlyArray<{ facts?: unknown }> | null | undefined): Set<string> {
  const keys = new Set<string>();
  for (const r of rows ?? []) {
    const key = (r?.facts as { weather_clothes?: { key?: unknown } } | null)?.weather_clothes?.key;
    if (typeof key === "string" && key) keys.add(key);
  }
  return keys;
}
