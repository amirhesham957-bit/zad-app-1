// أمثلة تصحيح (م٨.٨): دالة نقية بتحوّل رفض الباب (zad_guard_events) وتعديل/تراجع العميل
// (agent_actions: previous_state/new_state) لأمثلة few-shot من غير بيانات شخصية، وبعدين
// المجموعة ماتتبنّاش إلا لو عدّت بوابة التقييم (modelGate، م٨.٤). مفيش I/O.

import { type DeployDecision, type ModelGateOptions, shouldDeploy } from "./modelGate.ts";

export type ExampleKind = "guard" | "edit" | "undo";

/** صف من zad_guard_events (الأعمدة: user_id, kind, reason, source, intent jsonb). */
export interface RawGuardEvent {
  user_id?: string;
  kind: string;
  reason: string;
  source?: string | null;
  intent: Record<string, unknown>;
}

/** صف من agent_actions: تعديل العميل (status=applied وفيه previous/new) أو تراجع (status=undone). */
export interface RawActionEdit {
  user_id?: string;
  tool_name: string;
  input?: Record<string, unknown> | null;
  previous_state?: Record<string, unknown> | null;
  new_state?: Record<string, unknown> | null;
  status?: string | null;
}

export interface CorrectionExample {
  kind: ExampleKind;
  tool: string;
  input: string;
  wrong: string;
  right: string;
  /** دايماً true: مفيش هوية فرد في المثال. */
  memberAgnostic: true;
}

export interface ScrubOptions {
  /** صاحب الحدث: أي member_id مختلف عنه = بيانات فرد تاني، المثال يترفض. */
  ownerMemberId?: string;
  /** أسماء/أرقام خاصة بأفراد تانيين: ظهورها في أي نص يرفض المثال. */
  otherMemberTerms?: readonly string[];
}

const IDENTITY_KEYS = new Set([
  "user_id", "member_id", "family_id", "owner_id", "created_by", "id", "row_id",
  "target_id", "client_event_id", "run_id", "email", "phone", "mobile",
]);
const NAME_KEYS = new Set(["name", "member_name", "full_name", "person", "contact", "patient", "doctor"]);
const AMOUNT_KEYS = new Set([
  "amount", "price", "total", "cost", "balance", "salary", "budget", "limit", "target", "paid", "value",
]);

const ARABIC_DIGITS = "٠١٢٣٤٥٦٧٨٩";
function latinDigits(s: string): string {
  return s.replace(/[٠-٩]/g, (d) => String(ARABIC_DIGITS.indexOf(d)));
}

export function bucketAmount(n: number): string {
  const a = Math.abs(n);
  if (!Number.isFinite(a)) return "<amount>";
  if (a < 10) return "<10";
  if (a < 100) return "10-100";
  if (a < 1000) return "100-1k";
  if (a < 10000) return "1k-10k";
  return ">10k";
}

function scrubString(s: string): string {
  return latinDigits(s)
    .replace(/[\w.+-]+@[\w-]+\.[\w.]+/g, "<email>")
    .replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, "<id>")
    .replace(/\+?\d[\d\s-]{6,}\d/g, "<phone>");
}

function scrubValue(v: unknown, key: string | null): unknown {
  if (v === null || v === undefined) return null;
  if (key !== null && NAME_KEYS.has(key)) return "<name>";
  if (typeof v === "number") return key !== null && AMOUNT_KEYS.has(key) ? bucketAmount(v) : v;
  if (typeof v === "string") {
    if (key !== null && AMOUNT_KEYS.has(key) && /^\s*-?[\d٠-٩.,]+\s*$/.test(v)) {
      return bucketAmount(Number(latinDigits(v).replace(/,/g, "")));
    }
    return scrubString(v);
  }
  if (Array.isArray(v)) return v.map((x) => scrubValue(x, null));
  if (typeof v === "object") return scrubObject(v as Record<string, unknown>);
  return v;
}

function scrubObject(o: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const k of Object.keys(o).sort()) {
    if (IDENTITY_KEYS.has(k)) continue;
    out[k] = scrubValue(o[k], k);
  }
  return out;
}

function stable(v: unknown): string {
  return JSON.stringify(v);
}

/** True لو الكائن فيه member_id (في أي عمق) غير صاحب الحدث. */
function hasForeignMember(v: unknown, owner: string | undefined): boolean {
  if (owner === undefined || v === null || typeof v !== "object") return false;
  if (Array.isArray(v)) return v.some((x) => hasForeignMember(x, owner));
  const o = v as Record<string, unknown>;
  if (typeof o.member_id === "string" && o.member_id !== owner) return true;
  return Object.values(o).some((x) => hasForeignMember(x, owner));
}

function mentionsOthers(texts: readonly string[], terms: readonly string[] | undefined): boolean {
  if (!terms) return false;
  return terms.some((t) => t.trim().length > 0 && texts.some((x) => x.includes(t)));
}

function finish(
  kind: ExampleKind,
  tool: string,
  raw: { input: unknown; wrong: unknown; right: unknown },
  opts: ScrubOptions,
): CorrectionExample | null {
  if (hasForeignMember([raw.input, raw.wrong, raw.right], opts.ownerMemberId)) return null;
  // فحص الأسماء الخاصة قبل التنقية (التنقية بتشيل الاسم من مفاتيح الأسماء بس).
  const rawTexts = [stable(raw.input), stable(raw.wrong), stable(raw.right)];
  if (mentionsOthers(rawTexts, opts.otherMemberTerms)) return null;
  const sc = (x: unknown) => stable(scrubValue(x, null));
  const ex: CorrectionExample = {
    kind,
    tool,
    input: sc(raw.input),
    wrong: sc(raw.wrong),
    right: sc(raw.right),
    memberAgnostic: true,
  };
  if (ex.wrong === ex.right) return null;
  return ex;
}

/** رفض الباب: الغلط = النية المرفوضة، الصح = كود السبب (اللي المفروض الموديل يتفاداه). */
export function fromGuardEvent(e: RawGuardEvent, opts: ScrubOptions = {}): CorrectionExample | null {
  if (!e || typeof e.kind !== "string" || typeof e.reason !== "string" || !e.intent) return null;
  const payload = (e.intent as Record<string, unknown>).payload ?? {};
  return finish("guard", e.kind, {
    input: { kind: e.kind },
    wrong: payload,
    right: { refused: e.reason },
  }, opts);
}

/** تعديل العميل (previous→new) أو تراجع (الغلط = اللي اتطبّق، الصح = الحالة قبله). */
export function fromActionEdit(a: RawActionEdit, opts: ScrubOptions = {}): CorrectionExample | null {
  if (!a || typeof a.tool_name !== "string") return null;
  const prev = a.previous_state;
  const next = a.new_state;
  if (!prev || !next) return null;
  if (a.status === "undone") {
    return finish("undo", a.tool_name, { input: a.input ?? {}, wrong: next, right: prev }, opts);
  }
  return finish("edit", a.tool_name, { input: a.input ?? {}, wrong: prev, right: next }, opts);
}

/** تطبيع كل المدخلات الخام لمرشحين نظاف (المرفوض بيتشال). */
export function normaliseCandidates(
  guard: readonly RawGuardEvent[],
  edits: readonly RawActionEdit[],
  opts: ScrubOptions = {},
): CorrectionExample[] {
  const out: CorrectionExample[] = [];
  for (const g of guard) {
    const x = fromGuardEvent(g, opts);
    if (x) out.push(x);
  }
  for (const a of edits) {
    const x = fromActionEdit(a, opts);
    if (x) out.push(x);
  }
  return out;
}

export function exampleKey(e: CorrectionExample): string {
  return `${e.kind}|${e.tool}|${e.input}|${e.wrong}|${e.right}`;
}

export interface RankedExample {
  example: CorrectionExample;
  count: number;
}

/** دمج المكرر (العدد = التكرار) وحد أقصى لكل نوع؛ الترتيب حتمي. */
export function dedupeAndCap(
  candidates: readonly CorrectionExample[],
  capPerKind = 20,
): RankedExample[] {
  const map = new Map<string, RankedExample>();
  for (const c of candidates) {
    const k = exampleKey(c);
    const cur = map.get(k);
    if (cur) cur.count += 1;
    else map.set(k, { example: c, count: 1 });
  }
  const sorted = [...map.entries()].sort(([ka, a], [kb, b]) => b.count - a.count || ka.localeCompare(kb));
  const perKind: Record<string, number> = {};
  const out: RankedExample[] = [];
  for (const [, r] of sorted) {
    const used = perKind[r.example.kind] ?? 0;
    if (used >= capPerKind) continue;
    perKind[r.example.kind] = used + 1;
    out.push(r);
  }
  return out;
}

/** أعلى N مثال few-shot: الأكتر تكراراً ثم الأقصر ثم المفتاح. نفس المدخلات = نفس المخرجات. */
export function selectFewShot(
  candidates: readonly CorrectionExample[],
  n: number,
  capPerKind = 20,
): CorrectionExample[] {
  if (!Number.isFinite(n) || n <= 0) return [];
  const len = (e: CorrectionExample) => e.input.length + e.wrong.length + e.right.length;
  return dedupeAndCap(candidates, capPerKind)
    .sort((a, b) =>
      b.count - a.count || len(a.example) - len(b.example) ||
      exampleKey(a.example).localeCompare(exampleKey(b.example))
    )
    .slice(0, n)
    .map((r) => r.example);
}

export interface EvalScore {
  /** دقة بين 0 و1 على نفس عيّنة التقييم. */
  accuracy: number;
  n: number;
}

/**
 * بوابة اعتماد المجموعة: بتتحوّل لـshouldDeploy (MAE = 1 - accuracy)، يعني المجموعة
 * ماتتعتمدش إلا لو أدق بوضوح من الأساس وعيّنتها كفاية (minN الافتراضي ٣٠). التعادل = رفض.
 */
export function gateExamples(
  candidate: EvalScore,
  baseline: EvalScore,
  opts?: ModelGateOptions,
): DeployDecision {
  const toStats = (s: EvalScore, version: string) => {
    if (!Number.isFinite(s.accuracy) || s.accuracy < 0 || s.accuracy > 1) {
      throw new RangeError("accuracy must be within [0, 1]");
    }
    return { version, mae: 1 - s.accuracy, n: s.n };
  };
  return shouldDeploy(toStats(candidate, "with-examples"), toStats(baseline, "baseline"), opts);
}
