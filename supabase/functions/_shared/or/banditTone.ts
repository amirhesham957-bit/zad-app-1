// م٨.٢/م٨.٥: Thompson sampling لاختيار قالب رسالة لكل فرد (member_id) من قوالب متوافق عليها.
// نقي: الـRNG بيتحقن (للاختبار). أقل من ١٨ سنة بره أي تجربة على العروض: الدالة بترجّع null.

export type Rng = () => number; // قيمة في [0,1)

export interface ArmStat {
  successes: number;
  failures: number;
}

/** member_id -> template id -> إحصاءات. */
export type Posteriors = Record<string, Record<string, ArmStat>>;

export interface Member {
  memberId: string;
  age?: number | null;
  isMinor?: boolean;
}

export function isMinor(m: Member): boolean {
  return m.isMinor === true || (typeof m.age === "number" && m.age < 18);
}

function normal(rng: Rng): number {
  const u = Math.max(rng(), Number.MIN_VALUE);
  const v = rng();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}

function gamma(shape: number, rng: Rng): number {
  if (shape < 1) {
    return gamma(shape + 1, rng) * Math.pow(Math.max(rng(), Number.MIN_VALUE), 1 / shape);
  }
  const d = shape - 1 / 3;
  const c = 1 / Math.sqrt(9 * d);
  for (;;) {
    const x = normal(rng);
    const t = 1 + c * x;
    if (t <= 0) continue;
    const v = t * t * t;
    const u = rng();
    if (Math.log(Math.max(u, Number.MIN_VALUE)) < 0.5 * x * x + d - d * v + d * Math.log(v)) {
      return d * v;
    }
  }
}

export function sampleBeta(a: number, b: number, rng: Rng): number {
  const x = gamma(a, rng);
  const y = gamma(b, rng);
  return x / (x + y);
}

/** يختار قالب من approved، أو null لو القاصر/مفيش قوالب. */
export function chooseArm(
  member: Member,
  approved: string[],
  posteriors: Posteriors,
  rng: Rng,
): string | null {
  if (isMinor(member) || approved.length === 0) return null;
  const mine = posteriors[member.memberId] ?? {};
  let best: string | null = null;
  let bestV = -1;
  for (const id of approved) {
    const s = mine[id] ?? { successes: 0, failures: 0 };
    const v = sampleBeta(1 + Math.max(0, s.successes), 1 + Math.max(0, s.failures), rng);
    if (v > bestV) {
      bestV = v;
      best = id;
    }
  }
  return best;
}

/** تحديث بعد النتيجة. بيتجاهل القاصر وأي قالب مش في approved. */
export function update(
  posteriors: Posteriors,
  member: Member,
  armId: string,
  approved: string[],
  success: boolean,
): Posteriors {
  if (isMinor(member) || !approved.includes(armId)) return posteriors;
  const mine = posteriors[member.memberId] ?? {};
  const s = mine[armId] ?? { successes: 0, failures: 0 };
  return {
    ...posteriors,
    [member.memberId]: {
      ...mine,
      [armId]: {
        successes: s.successes + (success ? 1 : 0),
        failures: s.failures + (success ? 0 : 1),
      },
    },
  };
}

/** mulberry32: RNG بالـseed للاختبار. */
export function seededRng(seed: number): Rng {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
