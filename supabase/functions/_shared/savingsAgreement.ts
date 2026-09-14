// «افتكر إننا متفقين نوفّر» — هل فيه اتفاق توفير يستاهل تحذير عند دخول منطقة تسوق؟
// (store_arrival → shopping_zone_warning، ٢٠٢٦-٠٩-١٤)
//
// صافية عشان تتختبر: البيانات بتتقرا في zad-brain وبتتبعت هنا. الأولوية: وضع الطوارئ (أهم
// اتفاق)، بعده تحدي التوفير، بعده ميزانية في خطر حقيقي (DANGER/OVER). غير كده مفيش تحذير —
// زاد مابتنقّش على كل دخول محل.

export type AgreementReason = "broke" | "challenge" | "budget";

export interface SavingsAgreement {
  reason: AgreementReason;
  daily_cap: number | null;
  streak: number | null;
  currency: string | null;
}

export function savingsAgreementFrom(input: {
  brokeActive: boolean;
  brokeDailyCap: number | null;
  challenge: { daily_cap: number; streak: number } | null;
  threat: string | null;
  dailyAllowanceLeft: number | null;
  currency: string | null;
}): SavingsAgreement | null {
  if (input.brokeActive) {
    return { reason: "broke", daily_cap: input.brokeDailyCap, streak: null, currency: input.currency };
  }
  if (input.challenge) {
    return { reason: "challenge", daily_cap: Number(input.challenge.daily_cap), streak: Number(input.challenge.streak) || 0, currency: input.currency };
  }
  if (input.threat === "DANGER" || input.threat === "OVER") {
    const allowance = Number(input.dailyAllowanceLeft);
    return { reason: "budget", daily_cap: Number.isFinite(allowance) ? Math.max(0, Math.round(allowance)) : null, streak: null, currency: input.currency };
  }
  return null;
}
