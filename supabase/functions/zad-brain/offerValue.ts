// م٦.١: قيمة العرض = التوفير × احتمال الاحتياج قبل ما العرض يخلص − الإزعاج.
// العمولة مش جوه الترتيب. لو منتج العمولة مش الأرخص بنقول كده. مفيش ترشيح شرا لو الميزانية في خطر.
export interface Offer {
  id: string;
  /** سعر العرض. */
  price: number;
  /** السعر المعتاد للبيت لنفس الصنف. */
  usualPrice: number;
  /** احتمال إن البيت يحتاج الصنف قبل ما العرض يخلص (٠–١)، من توقع المخزن. */
  needProb: number;
  /** تكلفة الإزعاج بالعملة (أعلى لو البيت وصله إشعارات كتير). */
  annoyance: number;
  /** منتج بعمولة؟ (للتنبيه بس، مابيدخلش الحساب). */
  commission?: boolean;
}

export interface RankedOffer {
  id: string;
  value: number;
  /** مرشّح للشرا: قيمة موجبة والميزانية مش في خطر. */
  recommend: boolean;
  /** منتج العمولة مش الأرخص بين البدايل. */
  commissionNotCheapest: boolean;
}

function check(n: number, name: string) {
  if (!Number.isFinite(n) || n < 0) throw new RangeError(`${name} must be finite and non-negative`);
}

export function offerValue(o: Offer): number {
  check(o.price, "price"); check(o.usualPrice, "usualPrice"); check(o.annoyance, "annoyance");
  if (!Number.isFinite(o.needProb) || o.needProb < 0 || o.needProb > 1) throw new RangeError("needProb must be in [0,1]");
  return Math.max(0, o.usualPrice - o.price) * o.needProb - o.annoyance;
}

export function rankOffers(offers: readonly Offer[], budgetAtRisk: boolean): RankedOffer[] {
  const cheapest = offers.length ? Math.min(...offers.map((o) => o.price)) : 0;
  return offers
    .map((o) => {
      const value = offerValue(o);
      return {
        id: o.id,
        value,
        recommend: value > 0 && !budgetAtRisk,
        commissionNotCheapest: !!o.commission && o.price > cheapest,
      };
    })
    .sort((a, b) => b.value - a.value || a.id.localeCompare(b.id));
}
