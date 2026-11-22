// م٢.٧: دفعة واحدة من الفاتورة والفويس والروشتة → نيات للباب (zad_commit_intent). نقي: مفيش شبكة ولا داتابيز ولا Deno.env.
// الترتيب: أولاً حسب رتبة المجال (المخزن والشراء الأول، والفلوس آخر خالص)، وبعدين بالترتيب الأصلي في الدفعة. ده بيخلي الترتيب ثابت.
// المجال = أول جزء من الـkind قبل «.» أو «_» أو «:». المجال المش معروف بياخد رتبة وسط (قبل الديون والفلوس).
// client_event_id = `${batchId}:${index}:${hash(kind + JSON مرتب المفاتيح)}`، وبيتقصّ بحيث ماينفعش يعدّي ١٠٠ حرف. نفس الدفعة مرتين = نفس الـids.
// الروشتة: كل بند لازم member_id (الصحة بتاعة فرد، مش بتاعة الحساب كله).

export type Intent = {
  user_id: string;
  kind: string;
  client_event_id: string;
  source: "manual" | "receipt" | "bank" | "model" | "cron";
  payload: Record<string, unknown>;
  member_id?: string;
  confidence?: number;
  occurred_at?: string;
};

export type BatchSource = "receipt" | "voice" | "prescription";

export type BatchItem = {
  kind: string;
  payload: Record<string, unknown>;
  confidence?: number;
  memberId?: string;
  occurredAt?: string;
};

export type Rejection = { index: number; reason: string };

export const maxBatchSize = 40;
export const LOW_CONFIDENCE = 0.6;
export const MAX_CLIENT_EVENT_ID = 100;

// رتبة المجال: الأقل بيتنفذ الأول. الفلوس آخر حاجة في الدفعة.
export const DOMAIN_RANK: Record<string, number> = {
  inventory: 0,
  shopping: 1,
  pharmacy: 2,
  goal: 3,
  settings: 4,
  document: 5,
  appointment: 6,
  maintenance: 7,
  obligation: 8,
  subscription: 10,
  debt: 11,
  money: 12,
};
export const UNKNOWN_DOMAIN_RANK = 9;

// أنواع الفلوس: دايماً بتحتاج تأكيد، وبتتجمع في totalMoney.
export const MONEY_DOMAINS = new Set(["money", "debt", "subscription"]);

const SOURCE_FOR: Record<BatchSource, Intent["source"]> = {
  receipt: "receipt",
  voice: "model",
  prescription: "model",
};

const DOMAIN_LABEL: Record<string, string> = {
  inventory: "مخزن",
  shopping: "شراء",
  pharmacy: "صيدلية",
  goal: "هدف",
  settings: "إعدادات",
  document: "مستند",
  appointment: "موعد",
  maintenance: "صيانة",
  obligation: "التزام",
  subscription: "اشتراك",
  debt: "دين",
  money: "فلوس",
};

export function domainOf(kind: string): string {
  return kind.trim().split(/[._:]/)[0].toLowerCase();
}

export function domainRank(kind: string): number {
  const d = domainOf(kind);
  return Object.prototype.hasOwnProperty.call(DOMAIN_RANK, d) ? DOMAIN_RANK[d] : UNKNOWN_DOMAIN_RANK;
}

export function isMoneyKind(kind: string): boolean {
  return MONEY_DOMAINS.has(domainOf(kind));
}

// هاش FNV-1a 32 بت، بـ٨ حروف hex. دترمنستي وبسيط.
export function shortHash(s: string): string {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h.toString(16).padStart(8, "0");
}

// JSON بمفاتيح مرتبة، عشان ترتيب المفاتيح ماينفعش يغيّر الـid.
function stableStringify(v: unknown): string {
  if (v === null || typeof v !== "object") return JSON.stringify(v) ?? "null";
  if (Array.isArray(v)) return `[${v.map(stableStringify).join(",")}]`;
  const o = v as Record<string, unknown>;
  const keys = Object.keys(o).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(o[k])}`).join(",")}}`;
}

export function clientEventId(batchId: string, index: number, kind: string, payload: Record<string, unknown>): string {
  const h = shortHash(kind + stableStringify(payload));
  const full = `${batchId}:${index}:${h}`;
  if (full.length <= MAX_CLIENT_EVENT_ID) return full;
  // الـbatchId طويل: بنختصره بهاش عشان الـid يفضل فريد وقصير.
  return `${shortHash(batchId)}:${index}:${h}`;
}

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function validate(item: BatchItem, source: BatchSource): string | null {
  if (typeof item.kind !== "string" || item.kind.trim() === "") return "empty_kind";
  if (!isPlainObject(item.payload)) return "bad_payload";
  if (item.confidence !== undefined) {
    const c = item.confidence;
    if (typeof c !== "number" || !Number.isFinite(c) || c < 0 || c > 1) return "bad_confidence";
  }
  if (source === "prescription" && (typeof item.memberId !== "string" || item.memberId.trim() === "")) {
    return "member_required";
  }
  return null;
}

export function splitIntoIntents(input: {
  batchId: string;
  userId: string;
  source: BatchSource;
  items: BatchItem[];
}): { intents: Intent[]; rejected: Rejection[] } {
  const { batchId, userId, source, items } = input;
  const rejected: Rejection[] = [];
  const valid: { index: number; rank: number; intent: Intent }[] = [];

  items.forEach((item, index) => {
    if (index >= maxBatchSize) {
      rejected.push({ index, reason: "batch_too_large" });
      return;
    }
    const reason = validate(item, source);
    if (reason) {
      rejected.push({ index, reason });
      return;
    }
    const intent: Intent = {
      user_id: userId,
      kind: item.kind,
      client_event_id: clientEventId(batchId, index, item.kind, item.payload),
      source: SOURCE_FOR[source],
      payload: item.payload,
    };
    if (item.memberId && item.memberId.trim() !== "") intent.member_id = item.memberId;
    if (item.confidence !== undefined) intent.confidence = item.confidence;
    if (item.occurredAt !== undefined) intent.occurred_at = item.occurredAt;
    valid.push({ index, rank: domainRank(item.kind), intent });
  });

  valid.sort((a, b) => a.rank - b.rank || a.index - b.index);
  return { intents: valid.map((v) => v.intent), rejected };
}

export type BatchPlan = { requiresConfirm: boolean; summary: string[]; totalMoney: number | null };

// تأكيد واحد للدفعة كلها. الفلوس دايماً بتتأكد، والتأكيد بيتطلب لأي دفعة فيها نية.
export function confirmBatchPlan(intents: Intent[]): BatchPlan {
  const summary = intents.map((it, i) => {
    const label = DOMAIN_LABEL[domainOf(it.kind)] ?? "حاجة";
    let line = `${i + 1}. ${label}: ${it.kind}`;
    if (isMoneyKind(it.kind)) {
      const amount = it.payload.amount;
      if (typeof amount === "number" && Number.isFinite(amount)) line += ` بمبلغ ${amount}`;
    }
    if (typeof it.confidence === "number" && it.confidence < LOW_CONFIDENCE) {
      line += " (ثقة قليلة، راجعها)";
    }
    return line;
  });

  let total = 0;
  let hasAmount = false;
  for (const it of intents) {
    const amount = it.payload.amount;
    if (isMoneyKind(it.kind) && typeof amount === "number" && Number.isFinite(amount)) {
      total += amount;
      hasAmount = true;
    }
  }

  return {
    requiresConfirm: intents.length > 0,
    summary,
    totalMoney: hasAmount ? total : null,
  };
}

export type BatchResult = { client_event_id: string; ok: boolean; duplicate?: boolean; reason?: string };
export type BatchOutcome = { applied: number; duplicates: number; failed: { id: string; reason: string }[]; allOk: boolean };

// التكرار = نجاح (الكتابة اتعملت قبل كده). applied = اتكتبت دلوقتي، duplicates = اتكتبت قبل كده.
export function applyBatchResults(results: BatchResult[]): BatchOutcome {
  let applied = 0;
  let duplicates = 0;
  const failed: { id: string; reason: string }[] = [];
  for (const r of results) {
    if (!r.ok) {
      failed.push({ id: r.client_event_id, reason: r.reason ?? "unknown" });
    } else if (r.duplicate) {
      duplicates++;
    } else {
      applied++;
    }
  }
  return { applied, duplicates, failed, allOk: failed.length === 0 };
}
