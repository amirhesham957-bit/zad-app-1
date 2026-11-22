/** مكان ممكن الراجل يزوره في اليوم. `value` أهمية المكان (كل ما زاد كان أحسن)، `visitMin` مدة الزيارة بالدقيقة، `cost` تكلفة الزيارة. */
export interface Place {
  id: string;
  value: number;
  visitMin: number;
  cost: number;
  lat: number;
  lng: number;
}

export interface DayPlanInput {
  places: readonly Place[];
  start: { lat: number; lng: number };
  /** الدقايق المتاحة في اليوم (مشي + زيارات). */
  availableMin: number;
  budget: number;
  /** سرعة التنقل كم/س. */
  speedKmh: number;
}

export interface DayPlan {
  /** ترتيب الزيارة من نقطة البداية (مسار مفتوح، مفيش رجوع). */
  ids: string[];
  totalValue: number;
  /** التنقل + الزيارات. */
  minutes: number;
  cost: number;
}

const EARTH_KM = 6371;

function km(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const r = Math.PI / 180;
  const dLat = (b.lat - a.lat) * r;
  const dLng = (b.lng - a.lng) * r;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * r) * Math.cos(b.lat * r) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}

function validate(inp: DayPlanInput): void {
  if (!Number.isFinite(inp.availableMin) || inp.availableMin < 0) throw new RangeError("availableMin must be a non-negative number");
  if (!Number.isFinite(inp.budget) || inp.budget < 0) throw new RangeError("budget must be a non-negative number");
  if (!Number.isFinite(inp.speedKmh) || inp.speedKmh <= 0) throw new RangeError("speedKmh must be positive");
  if (!Number.isFinite(inp.start.lat) || !Number.isFinite(inp.start.lng)) throw new RangeError("bad start point");
  const ids = new Set<string>();
  for (const p of inp.places) {
    if (ids.has(p.id)) throw new RangeError(`duplicate place id: ${p.id}`);
    ids.add(p.id);
    if (!Number.isFinite(p.value) || p.value < 0) throw new RangeError(`bad value: ${p.id}`);
    if (!Number.isFinite(p.visitMin) || p.visitMin < 0) throw new RangeError(`bad visitMin: ${p.id}`);
    if (!Number.isFinite(p.cost) || p.cost < 0) throw new RangeError(`bad cost: ${p.id}`);
    if (!Number.isFinite(p.lat) || !Number.isFinite(p.lng)) throw new RangeError(`bad coordinates: ${p.id}`);
  }
}

/**
 * خطة يوم للمسافر: أكبر قيمة كلية جوه حدّين (وقت وميزانية). مسألة orienteering.
 * طمع بالإدراج: كل مرة نضيف المكان صاحب أعلى value/(وقت إضافي + تكلفة) في أرخص موضع،
 * وبعد كل إضافة نحسّن المسار بـ2-opt. حتمي: التعادل بيتفكّ بالـid.
 */
export function planTripDay(inp: DayPlanInput): DayPlan {
  validate(inp);
  const eps = 1e-9;
  const travel = (a: { lat: number; lng: number }, b: { lat: number; lng: number }) => (km(a, b) / inp.speedKmh) * 60;
  const pool = [...inp.places].sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));

  /** وقت المسار كله: تنقل من البداية + زيارات. */
  const routeMin = (r: readonly Place[]): number => {
    let t = 0;
    let prev: { lat: number; lng: number } = inp.start;
    for (const p of r) {
      t += travel(prev, p) + p.visitMin;
      prev = p;
    }
    return t;
  };

  /** 2-opt على مسار مفتوح: نعكس مقطع لو قلّل الوقت. */
  const twoOpt = (r: Place[]): Place[] => {
    let best = r;
    let bestT = routeMin(best);
    let improved = true;
    while (improved) {
      improved = false;
      for (let i = 0; i < best.length - 1; i++) {
        for (let j = i + 1; j < best.length; j++) {
          const cand = [...best.slice(0, i), ...best.slice(i, j + 1).reverse(), ...best.slice(j + 1)];
          const t = routeMin(cand);
          if (t < bestT - eps) {
            best = cand;
            bestT = t;
            improved = true;
          }
        }
      }
    }
    return best;
  };

  let route: Place[] = [];
  let spent = 0;
  const left = new Set(pool);

  for (;;) {
    const baseT = routeMin(route);
    let pick: { p: Place; at: number; ratio: number } | null = null;
    for (const p of pool) {
      if (!left.has(p)) continue;
      if (spent + p.cost > inp.budget + eps) continue;
      let bestAt = -1;
      let bestAdd = Infinity;
      for (let at = 0; at <= route.length; at++) {
        const add = routeMin([...route.slice(0, at), p, ...route.slice(at)]) - baseT;
        if (add < bestAdd - eps) {
          bestAdd = add;
          bestAt = at;
        }
      }
      if (baseT + bestAdd > inp.availableMin + eps) continue;
      const ratio = p.value / Math.max(bestAdd + p.cost, eps);
      if (!pick || ratio > pick.ratio + eps) pick = { p, at: bestAt, ratio };
    }
    if (!pick) break;
    left.delete(pick.p);
    spent += pick.p.cost;
    route = twoOpt([...route.slice(0, pick.at), pick.p, ...route.slice(pick.at)]);
  }

  return {
    ids: route.map((p) => p.id),
    totalValue: route.reduce((s, p) => s + p.value, 0),
    minutes: routeMin(route),
    cost: spent,
  };
}
