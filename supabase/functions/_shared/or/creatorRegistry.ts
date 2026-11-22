// سجل الشيفات والمحلات (م٦.٧): قايمة منسّقة ومعتمدة من المالك، لكل بلد، بـ@handle.
// الكارت بيتعرض جوه التطبيق. الدالة دي بتاخد السجل كـ input، ومابتجيبش حاجة بنفسها.
// مفيش شبكة، ومفيش scraping، ومفيش Deno.env. أي مصدر لازم يكون قايمة منسّقة أو API رسمي.
// دالة نقية: مافيش I/O.

export type Platform = "youtube" | "instagram" | "tiktok";
export type CreatorKind = "chef" | "shop";
export type SourceKind = "curated_list" | "official_api" | "scrape";

export type Creator = {
  handle: string; // '@name'
  platform: Platform;
  country: string; // ISO-2
  kind: CreatorKind;
  displayName: string;
  approved: boolean;
  approvedBy?: string;
  approvedAt?: string;
};

export interface VideoInput {
  id: string;
  title: string;
  thumbnailUrl?: string;
}

export interface VideoCard {
  title: string;
  creator: Creator;
  embedUrl: string | null;
  watchUrl: string;
}

const PLATFORMS: readonly Platform[] = ["youtube", "instagram", "tiktok"];
const KINDS: readonly CreatorKind[] = ["chef", "shop"];
const HANDLE_BODY = /^[A-Za-z0-9._]+$/;
const HANDLE_MAX = 30;
const COUNTRY = /^[A-Z]{2}$/;
const YT_ID = /^[A-Za-z0-9_-]{6,20}$/;
const TITLE_MAX = 100;

/** يرجّع الـhandle بصيغة '@name' بحروف صغيرة، أو null لو مش صالح. */
export function normalizeHandle(s: string): string | null {
  if (typeof s !== "string") return null;
  let body = s.trim();
  if (body.startsWith("@")) body = body.slice(1);
  if (body.length === 0 || body.length > HANDLE_MAX) return null;
  if (!HANDLE_BODY.test(body)) return null;
  return "@" + body.toLowerCase();
}

/** يتأكد إن السجل صالح للاستخدام: معتمد من المالك، ومعاه اسم المعتمِد وتاريخ الاعتماد. */
export function validateCreator(c: Creator): { ok: boolean; errors: string[] } {
  const errors: string[] = [];
  const norm = normalizeHandle(c.handle);
  if (norm === null) errors.push("handle_invalid");
  else if (norm !== c.handle) errors.push("handle_not_normalized");
  if (!PLATFORMS.includes(c.platform)) errors.push("platform_invalid");
  if (!COUNTRY.test(c.country)) errors.push("country_invalid");
  if (!KINDS.includes(c.kind)) errors.push("kind_invalid");
  if (typeof c.displayName !== "string" || c.displayName.trim().length === 0) {
    errors.push("display_name_missing");
  }
  if (c.approved !== true) errors.push("not_approved");
  if (c.approved === true) {
    if (typeof c.approvedBy !== "string" || c.approvedBy.trim().length === 0) {
      errors.push("approved_by_missing");
    }
    if (typeof c.approvedAt !== "string" || Number.isNaN(Date.parse(c.approvedAt))) {
      errors.push("approved_at_invalid");
    }
  }
  return { ok: errors.length === 0, errors };
}

/** المعتمدين بس، لبلد معيّن (ونوع اختياري)، بدون تكرار platform+handle، مرتبين بالاسم عربي. */
export function listForCountry(registry: Creator[], country: string, kind?: CreatorKind): Creator[] {
  const wanted = country.trim().toUpperCase();
  const seen = new Set<string>();
  const out: Creator[] = [];
  for (const c of registry) {
    if (c.country !== wanted) continue;
    if (kind !== undefined && c.kind !== kind) continue;
    if (!validateCreator(c).ok) continue;
    const key = `${c.platform}|${c.handle}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(c);
  }
  return out.sort((a, b) => a.displayName.localeCompare(b.displayName, "ar"));
}

/**
 * كارت الفيديو. embedUrl بيتبني لليوتيوب بس (youtube-nocookie، من غير باراميترات تتبع).
 * الإنستجرام والتيكتوك: embedUrl = null، والـwatchUrl بيودّي لصفحة الصانع.
 * بيرمي خطأ لو id اليوتيوب مش صالح.
 */
export function videoCard(c: Creator, video: VideoInput): VideoCard {
  const title = video.title.length > TITLE_MAX ? video.title.slice(0, TITLE_MAX) : video.title;
  const name = c.handle.slice(1);
  if (c.platform === "youtube") {
    if (!YT_ID.test(video.id)) throw new Error("invalid_youtube_id");
    return {
      title,
      creator: c,
      embedUrl: `https://www.youtube-nocookie.com/embed/${video.id}`,
      watchUrl: `https://www.youtube.com/watch?v=${video.id}`,
    };
  }
  if (c.platform === "instagram") {
    return { title, creator: c, embedUrl: null, watchUrl: `https://www.instagram.com/${name}/` };
  }
  return { title, creator: c, embedUrl: null, watchUrl: `https://www.tiktok.com/@${name}` };
}

/** حارس السياسة: مسموح القوايم المنسّقة أو الـAPI الرسمي بس. الـscraping بيوقف بخطأ. */
export function assertNoScrape(sourceKind: SourceKind): void {
  if (sourceKind === "curated_list" || sourceKind === "official_api") return;
  throw new Error("scrape_forbidden");
}
