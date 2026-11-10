/**
 * ترشيحات تيك توك وإنستجرام من غير سعر (طلب المالك ١٠/١١: «يرشحهم عادي بدون رقم طالما حديث ومحقق مشاهدات»).
 *
 * قبل كده الفيديو أو البوست كان بيتقري وبيترمي لو مفيهوش صنف بسعر مكتوب، لأن zad_deals مابيقبلش سعر صفر: النهارده
 * ١٢ تشغيلة تيك توك وإنستجرام قرت فيديوهات وطلّعت `put: 0`. الترشيح هو اللي يستاهل يتقال للعميل حتى من غير رقم: عرض
 * بنسبة أو كود، وصفة تريند، فكرة، مطعم، سوبرماركت، تطبيق توصيل. بيتخزن في zad_social_picks برابطه، والبوت بيعرضه.
 *
 * «العينين»: إنستجرام بيتقري بصورة البوست (أو غلاف الريل). تيك توك بنص محرك البحث بس: oEmbed الرسمي بيرجّع iframe
 * من غير وصف ولا صورة (اتقاس تاني ١٠/١١). الفيديو نفسه مابيتنزلش (شروط المنصتين، وقاعدة المصادر القانونية في ZAD_PLAN).
 */

export const PICK_KINDS = ["offer", "recipe", "idea", "restaurant", "supermarket", "delivery"] as const;
export type PickKind = typeof PICK_KINDS[number];

/** بيتحط في برومبت القراية جنب العروض والأكواد. */
export const PICK_RULE =
  "pick = ترشيح واحد لو المحتوى يستاهل يتقال لعميل بيدوّر على توفير أو أكل، حتى لو مفيهوش سعر: " +
  "kind واحد من offer (عرض أو خصم بنسبة أو كود) أو recipe (وصفة) أو idea (فكرة توفير أو تنظيم بيت) أو restaurant أو supermarket أو delivery (تطبيق توصيل)، " +
  "title عنوان قصير بالعربي (٦٠ حرف بالكتير)، summary جملة أو اتنين باللي مكتوب أو ظاهر في الصورة بس (٢٠٠ حرف بالكتير)، " +
  "discount_percent = نسبة الخصم لو مكتوبة وإلا null. مسابقة، رأي، إعلان وظيفة، أو محتوى مش متعلق ⇒ pick = null. ";

/** أقدم ترشيح بيتقبل: الترند اللي عدّى عليه أسبوعين مابقاش ترند. */
export const PICK_MAX_AGE_DAYS = 14;
/** إنستجرام: أقل لايكات لترشيح من هاشتاج (أكونت المحل نفسه بيعدّي من غير شرط، المتابعين اتفحصوا قبل كده). */
export const PICK_MIN_LIKES = 50;

export interface SocialPick {
  kind: PickKind;
  title: string;
  summary: string;
  discount_percent: number | null;
  source_url: string;
  posted_at: string | null;
  likes: number | null;
}

const clean = (v: unknown, max: number) =>
  typeof v === "string" ? v.replace(/[\n\r=]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max) : "";

/** الترشيح من رد الموديل، أو null. نقي. */
export function readSocialPick(
  parsed: unknown, sourceUrl: string, postedAt: string | null, likes: number | null = null,
): SocialPick | null {
  const p = (parsed as { pick?: Record<string, unknown> | null } | null)?.pick;
  if (!p || typeof p !== "object") return null;
  const kind = String(p.kind ?? "") as PickKind;
  if (!PICK_KINDS.includes(kind)) return null;
  const title = clean(p.title, 60);
  const summary = clean(p.summary, 200);
  if (title.length < 3) return null;
  const pct = Number(p.discount_percent);
  return {
    kind, title, summary,
    discount_percent: Number.isFinite(pct) && pct > 0 && pct <= 90 ? Math.round(pct) : null,
    source_url: sourceUrl, posted_at: postedAt, likes,
  };
}

/** حديث كفاية؟ تاريخ مش معروف = مقبول (البحث نفسه بيرتّب الأحدث). نقي. */
export function isFreshPick(postedAt: string | null, now = Date.now()): boolean {
  if (!postedAt) return true;
  const at = Date.parse(postedAt);
  return !Number.isFinite(at) || now - at <= PICK_MAX_AGE_DAYS * 86_400_000;
}

/** وقت نشر فيديو تيك توك من رقمه: أول ٣٢ بت هي ثواني يونكس. null لو الرابط مش فيديو. نقي. */
export function tiktokPostedAt(url: string): string | null {
  const id = /\/video\/(\d{15,22})/.exec(url)?.[1];
  if (!id) return null;
  try {
    const seconds = Number(BigInt(id) >> 32n);
    // ٢٠١٦ (أول تيك توك) لحد بكرة: غير كده الرقم مش بالشكل ده.
    if (seconds < 1_451_606_400 || seconds > Date.now() / 1000 + 86_400) return null;
    return new Date(seconds * 1000).toISOString();
  } catch {
    return null;
  }
}
