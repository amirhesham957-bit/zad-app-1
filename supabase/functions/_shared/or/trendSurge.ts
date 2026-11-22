// م٦.٣: قفزة عن المعتاد بـPoisson z-score على إشارات مجمّعة. الهايب لوحده مش سبب ترشيح.
export const MIN_HOUSES = 5;
export const Z_THRESHOLD = 3;

export interface SurgeInput {
  item: string;
  /** عدد الإشارات النهارده (مجمّعة على كل البيوت). */
  count: number;
  /** عدد البيوت المختلفة اللي طلعت منها الإشارات. */
  houses: number;
  /** المعتاد في نفس الفترة (متوسط تاريخي). */
  baseline: number;
}

export interface Surge {
  item: string;
  z: number;
  count: number;
  baseline: number;
  /** الهايب لوحده مش سبب ترشيح شرا: دايماً false. */
  recommendBuy: false;
}

/** z = (count - λ) / sqrt(λ)، مع λ أدنى ٠٫٥ عشان المعتاد الصفري ماينفجرش. */
export function poissonZ(count: number, baseline: number): number {
  if (!Number.isFinite(count) || !Number.isFinite(baseline) || count < 0 || baseline < 0) {
    throw new RangeError("count and baseline must be finite and non-negative");
  }
  const lambda = Math.max(baseline, 0.5);
  return (count - lambda) / Math.sqrt(lambda);
}

/** القفزات المعتبرة: z فوق الحد، وعلى الأقل ٥ بيوت (خصوصية). الأعلى الأول. */
export function detectSurges(inputs: readonly SurgeInput[]): Surge[] {
  const out: Surge[] = [];
  for (const i of inputs) {
    if (i.houses < MIN_HOUSES) continue;
    const z = poissonZ(i.count, i.baseline);
    if (z >= Z_THRESHOLD) out.push({ item: i.item, z, count: i.count, baseline: i.baseline, recommendBuy: false });
  }
  return out.sort((a, b) => b.z - a.z || a.item.localeCompare(b.item));
}
