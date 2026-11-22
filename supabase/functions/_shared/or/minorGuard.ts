// حارس القاصرين (م٧.١٠): مافيش إعلانات موجّهة ولا توصيات عمولة لأي حد أقل من ١٨ سنة.
// دالة نقية: مافيش I/O. لو السن مش معروف، بنعامل العضو كقاصر (fail-safe).

export interface MemberAgeInfo {
  age?: number | null;
  birthDate?: string | null;
  isChild?: boolean;
}

export type OfferKind = "targeted_ad" | "affiliate" | "plain";

export interface Offer {
  id: string;
  kind: OfferKind;
}

const ADULT_AGE = 18;

/** Whole years between a YYYY-MM-DD birth date and `now` (UTC). Returns null if unparseable. */
function ageFromBirthDate(birthDate: string, now: Date): number | null {
  const ms = Date.parse(birthDate);
  if (Number.isNaN(ms)) return null;
  const birth = new Date(ms);
  let years = now.getUTCFullYear() - birth.getUTCFullYear();
  const beforeBirthday =
    now.getUTCMonth() < birth.getUTCMonth() ||
    (now.getUTCMonth() === birth.getUTCMonth() && now.getUTCDate() < birth.getUTCDate());
  if (beforeBirthday) years -= 1;
  return years;
}

/**
 * True if the member is a minor (or cannot be shown to be an adult).
 * Any signal of minority wins: isChild, a known age under 18, or a birth date giving under 18.
 */
export function isMinor(member: MemberAgeInfo, now: Date = new Date()): boolean {
  if (member.isChild === true) return true;

  let knownAge = false;

  if (typeof member.age === "number" && Number.isFinite(member.age)) {
    knownAge = true;
    if (member.age < ADULT_AGE) return true;
  }

  if (typeof member.birthDate === "string" && member.birthDate.length > 0) {
    const fromBirth = ageFromBirthDate(member.birthDate, now);
    if (fromBirth !== null) {
      knownAge = true;
      if (fromBirth < ADULT_AGE) return true;
    }
  }

  // No usable age information at all: fail-safe to minor.
  return !knownAge;
}

/** Drop targeted ads and affiliate (commission) offers for minors; adults get the list unchanged. */
export function filterOffersFor(member: MemberAgeInfo, offers: readonly Offer[], now: Date = new Date()): Offer[] {
  if (!isMinor(member, now)) return offers.slice();
  return offers.filter((offer) => offer.kind !== "targeted_ad" && offer.kind !== "affiliate");
}
