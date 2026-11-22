// حارس وضع الأطفال (م٧.١٠): الطفل = حساب الأب فعّل عليه وضع الأطفال (family_members.role = 'child'، ٦–١٠ سنين).
// أي حد غيره بيتعامل كبالغ وياخد كل ميزات التطبيق، حتى لو سنه أقل من ١٨. السن مش معيار.
// دالة نقية: مافيش I/O.

export interface MemberAgeInfo {
  isChild?: boolean;
}

export type OfferKind = "targeted_ad" | "affiliate" | "plain";

export interface Offer {
  id: string;
  kind: OfferKind;
}

/** True فقط لو وضع الأطفال متفعّل على الحساب. */
export function isMinor(member: MemberAgeInfo): boolean {
  return member.isChild === true;
}

/** وضع الأطفال: نشيل الإعلانات الموجهة وعروض العمولة. الباقي بيرجع زي ما هو. */
export function filterOffersFor(member: MemberAgeInfo, offers: readonly Offer[]): Offer[] {
  if (!isMinor(member)) return offers.slice();
  return offers.filter((offer) => offer.kind !== "targeted_ad" && offer.kind !== "affiliate");
}
