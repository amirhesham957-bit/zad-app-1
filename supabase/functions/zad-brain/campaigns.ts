// campaigns.ts — العقل يشوف الحملة اللي على الرئيسية، وذوق العميل في الوصفات (الموجة ٣، §١١ح، ٢٠٢٦-١٠-١٠).
//
// الرئيسية بتعرض حملة موسمية (`app_campaigns`: الوايت فرايداي، رمضان، الخريف…) والعقل ماكانش شايفها — فممكن
// يناقض اللي العميل شايفه قدامه. الاختيار هنا نسخة من `pickCampaign` في التطبيق
// (`zad_flutter/lib/shared/campaigns/domain/campaign.dart`) بنفس الترتيب: أعلى أولوية، بعدها الموجهة لبلده،
// بعدها لهجته فاللهجة الجارة فالعامة. التطبيق كمان بيعرض الحملة الجاية بدري لو الفاصل قصير («bridged»)؛
// العقل بيشوف اللي شغالة النهارده بس.
//
// وتقييم الوصفات (`zad_recipe_feedback`): الشيف (`meal_suggestions`) بيقراه، بس العقل لما يقترح أكل في الشات
// ماكانش شايفه.

import { dialectForCountry } from "../_shared/dialect.ts";

export interface CampaignRow {
  id: string;
  event_key: string | null;
  event_name?: string | null;
  target_country?: string | null;
  dialect?: string | null;
  from_md?: string | null;
  to_md?: string | null;
  season_slug?: string | null;
  banner_title?: string | null;
  banner_body?: string | null;
  cta_text?: string | null;
  priority?: number | null;
  is_active?: boolean | null;
}

export interface SeasonWindowRow {
  slug: string;
  start_date: string;
  end_date: string;
}

export interface HomeCampaign {
  event: string;
  name: string | null;
  title: string;
  body: string;
  cta: string | null;
  /** آخر يوم ليها (YYYY-MM-DD). */
  until: string;
}

/** السعودي والخليجي بيقفوا مكان بعض قبل النسخة العامة — زي التطبيق. */
const NEAR_DIALECT: Record<string, string> = { SA: "GULF", GULF: "SA" };

function monthDay(raw: unknown): [number, number] | null {
  const m = /^(\d{2})-(\d{2})$/.exec(String(raw ?? "").trim());
  if (!m) return null;
  const [mo, d] = [Number(m[1]), Number(m[2])];
  return mo >= 1 && mo <= 12 && d >= 1 && d <= 31 ? [mo, d] : null;
}

const iso = (y: number, m: number, d: number) =>
  `${String(y).padStart(4, "0")}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;

/** شباك الحملة اللي فيه [day] (YYYY-MM-DD)، أو null. نفس `_windowOn` في التطبيق. */
export function campaignWindowOn(c: CampaignRow, day: string, seasons: readonly SeasonWindowRow[]): [string, string] | null {
  const slug = (c.season_slug ?? "").trim();
  const from = monthDay(c.from_md);
  const to = monthDay(c.to_md);
  // يا شباك بالتاريخ يا موسم هجري — مش الاتنين ومش ولا واحد (التطبيق بيرمي الصف ده).
  if ((from !== null && to !== null) === (slug !== "")) return null;
  if (slug) {
    const s = seasons.find((w) => w.slug === slug && w.start_date <= day && day <= w.end_date);
    return s ? [s.start_date, s.end_date] : null;
  }
  const [fm, fd] = from!;
  const [tm, td] = to!;
  const [y, m, d] = day.split("-").map(Number);
  const wraps = fm * 100 + fd > tm * 100 + td;
  // شباك بيلف السنة (12-28 → 01-03) بدأ السنة اللي فاتت لو النهارده في جزء يناير.
  const startYear = wraps && m * 100 + d <= tm * 100 + td ? y - 1 : y;
  const start = iso(startYear, fm, fd);
  const end = iso(wraps ? startYear + 1 : startYear, tm, td);
  return start <= day && day <= end ? [start, end] : null;
}

function text(raw: unknown, max: number): string | null {
  const v = typeof raw === "string" ? raw.replace(/\s+/g, " ").trim() : "";
  return v ? v.slice(0, max) : null;
}

/** حملة النهارده لعميل في [country] بيتكلم [dialect] (الملف، وإلا لهجة البلد)، أو null. */
export function pickHomeCampaign(
  rows: readonly CampaignRow[],
  seasons: readonly SeasonWindowRow[],
  day: string,
  country: string | null | undefined,
  dialect?: string | null,
): HomeCampaign | null {
  const place = country ? String(country).toUpperCase() : null;
  const speech = (dialect ? String(dialect).toUpperCase() : null) ?? dialectForCountry(place);
  let best: { rank: [number, number, number, string]; c: CampaignRow; end: string } | null = null;
  for (const c of rows) {
    if (c.is_active === false) continue;
    const title = text(c.banner_title, 120);
    const body = text(c.banner_body, 300);
    if (!c.id || !c.event_key || !title || !body) continue;
    const target = c.target_country ? c.target_country.toUpperCase() : null;
    if (target !== null && target !== place) continue;
    const cd = c.dialect ? c.dialect.toUpperCase() : null;
    let dialectRank: number;
    if (cd === null) dialectRank = 0;
    else if (cd === speech) dialectRank = 2;
    else if (speech !== null && NEAR_DIALECT[speech] === cd) dialectRank = 1;
    else continue;
    const window = campaignWindowOn(c, day, seasons);
    if (!window) continue;
    const rank: [number, number, number, string] = [c.priority ?? 0, target === null ? 0 : 1, dialectRank, c.id];
    if (!best || beats(rank, best.rank)) best = { rank, c, end: window[1] };
  }
  if (!best) return null;
  return {
    event: best.c.event_key as string,
    name: text(best.c.event_name, 60),
    title: text(best.c.banner_title, 120) as string,
    body: text(best.c.banner_body, 300) as string,
    cta: text(best.c.cta_text, 60),
    until: best.end,
  };
}

/** نفس `_beats` في التطبيق: الأعلى في كل خانة بالترتيب، وفي التعادل الـid الأصغر (نفس الاختيار على كل موبايل). */
function beats(a: [number, number, number, string], b: [number, number, number, string]): boolean {
  for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return (a[i] as number) > (b[i] as number);
  return a[3] < b[3];
}

/** آخر آراء العميل في الوصفات: اللي عجبه واللي ماعجبوش (الأحدث الأول، ٨ من كل واحد). */
export function recipeTaste(
  rows: ReadonlyArray<{ recipe_name: string | null; liked: boolean | null }>,
): { liked: string[]; disliked: string[] } | null {
  const liked: string[] = [];
  const disliked: string[] = [];
  for (const r of rows) {
    const name = text(r.recipe_name, 60);
    if (!name || typeof r.liked !== "boolean") continue;
    const list = r.liked ? liked : disliked;
    if (list.length < 8 && !list.includes(name)) list.push(name);
  }
  return liked.length || disliked.length ? { liked, disliked } : null;
}

/** قاعدة البرومبت: الحملة اللي العميل شايفها دلوقتي، وذوقه في الأكل. "" لو مفيش ولا واحدة. */
export function campaignAndTasteRules(
  snap: { home_campaign?: HomeCampaign | null; recipe_taste?: { liked: string[]; disliked: string[] } | null } | null | undefined,
): string {
  const lines: string[] = [];
  const c = snap?.home_campaign;
  if (c) {
    lines.push(
      `   - **الحملة اللي على الرئيسية دلوقتي (home_campaign)**: «${c.title}» لحد ${c.until}. ده اللي العميل شايفه قدامه — ` +
        "لو سأل عن المناسبة أو العرض اللي فوق، اتكلم عنها هي ومن نصها؛ ماتناقضهاش، وماتخترعش خصم أو سعر مش فيها.",
    );
  }
  const t = snap?.recipe_taste;
  if (t) {
    lines.push(
      "   - **ذوقه في الأكل (recipe_taste)**: لما تقترح أكل أو وصفة، فضّل اللي في liked وقريب منه، " +
        "وماتقترحش أي حاجة في disliked تاني إلا لو هو طلبها بالاسم.",
    );
  }
  return lines.length ? lines.join("\n") + "\n" : "";
}
