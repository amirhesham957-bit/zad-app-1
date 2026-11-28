// receiptBankMatch.ts — صورة فاتورة في تليجرام تتربط بإشعار البنك بتاعها (P2.10b).
//
// نفس قاعدة bankMatchOf في zad_flutter/lib/shared/scan/domain/bank_twin.dart (قرار المالك، لازم
// الاتنين يتطابقوا): نافذة ±٢٤ ساعة، فرق المبلغ <= max(0.01، ٢٪ من إجمالي الفاتورة)، التحويل وسحب
// الكاش والدخل مش دفعة كارت، فاتورة الكاش مالهاش مقابل، الأقرب في الوقت يكسب، ولو تساووا فالأقرب مبلغاً.
// الدوال هنا نقية عشان تتختبر من غير بوت ولا داتابيز.

/** `zad_transactions.source_type` للمصروف اللي قناة البنك سجّلته. */
export const BANK_SOURCE_TYPE = "notification_listener";
export const BANK_TWIN_WINDOW_MS = 24 * 60 * 60 * 1000;
export const BANK_TWIN_TOLERANCE = 0.02;

const IGNORED_KINDS = new Set(["transfer", "cash_withdrawal", "income"]);
const OPEN_PROPOSAL = new Set(["awaiting_confirmation", "needs_classification"]);

export interface BankRow {
  id: string;
  amount: number;
  createdAt: Date;
  title: string;
  merchantName: string | null;
  sourceType: string | null;
  isExpense: boolean;
  txnKind: string | null;
}

export interface BankProposal {
  id: string;
  amount: number;
  createdAt: Date;
  title: string;
  merchantName: string | null;
  status: string;
  txnKind: string | null;
}

export interface BankMatch {
  kind: "transaction" | "proposal";
  id: string;
  amount: number;
  merchant: string;
  at: Date;
}

const shop = (merchant: string | null, title: string) => (merchant && merchant.trim() ? merchant : title);

function amountFits(bank: number, total: number): boolean {
  const tol = total * BANK_TWIN_TOLERANCE > 0.01 ? total * BANK_TWIN_TOLERANCE : 0.01;
  return Math.abs(bank - total) <= tol + 1e-9;
}

export function bankMatchOf(input: {
  total: number;
  spentAt: Date;
  rows: Iterable<BankRow>;
  proposals?: Iterable<BankProposal>;
  paidWith?: string | null;
}): BankMatch | null {
  const { total, spentAt } = input;
  if (!(total > 0) || input.paidWith === "cash") return null;
  let best: BankMatch | null = null;
  let bestGap = 0;
  let bestDiff = 0;

  const consider = (m: BankMatch) => {
    if (!amountFits(m.amount, total)) return;
    const gap = Math.abs(m.at.getTime() - spentAt.getTime());
    if (gap > BANK_TWIN_WINDOW_MS) return;
    const diff = Math.abs(m.amount - total);
    if (best === null || gap < bestGap || (gap === bestGap && diff < bestDiff)) {
      best = m;
      bestGap = gap;
      bestDiff = diff;
    }
  };

  for (const t of input.rows) {
    // تحويل (سحب ATM لكاش) is_expense فيه true، بس مش دفعة الكارت اللي الفاتورة ليها.
    if (t.sourceType !== BANK_SOURCE_TYPE || !t.isExpense || t.txnKind === "transfer") continue;
    consider({ kind: "transaction", id: t.id, amount: t.amount, merchant: shop(t.merchantName, t.title), at: t.createdAt });
  }
  for (const p of input.proposals ?? []) {
    if (!OPEN_PROPOSAL.has(p.status) || (p.txnKind !== null && IGNORED_KINDS.has(p.txnKind))) continue;
    consider({ kind: "proposal", id: p.id, amount: p.amount, merchant: shop(p.merchantName, p.title), at: p.createdAt });
  }
  return best;
}

/** uuid (٣٦ حرف) ← ٢٢ حرف base64url، عشان callback_data ياخد اتنين uuid تحت حد تليجرام (٦٤ بايت). */
export function packUuid(uuid: string): string {
  const hex = uuid.replace(/-/g, "");
  const bytes = Uint8Array.from(hex.match(/../g)!.map((h) => parseInt(h, 16)));
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function unpackUuid(packed: string): string | null {
  if (!/^[A-Za-z0-9_-]{22}$/.test(packed)) return null;
  const bin = atob(packed.replace(/-/g, "+").replace(/_/g, "/") + "==");
  const hex = Array.from(bin, (c) => c.charCodeAt(0).toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

/** "pk:<pending>:<p|t><target>" = اربطها بإشعار/عملية، "ps:<pending>" = سجّلها لوحدها. */
export function linkKeyboard(pendingId: string, match: BankMatch) {
  return [[
    { text: "🔗 اربطها (من غير خصم تاني)", callback_data: `pk:${packUuid(pendingId)}:${match.kind === "proposal" ? "p" : "t"}${packUuid(match.id)}` },
    { text: "🧾 سجّلها لوحدها", callback_data: `ps:${pendingId}` },
  ], [{ text: "✖️ لأ", callback_data: `c:${pendingId}` }]];
}

export function parseLinkCallback(data: string): { pendingId: string; targetKind: "proposal" | "transaction"; targetId: string } | null {
  const m = /^pk:([A-Za-z0-9_-]{22}):([pt])([A-Za-z0-9_-]{22})$/.exec(data);
  if (!m) return null;
  const pendingId = unpackUuid(m[1]);
  const targetId = unpackUuid(m[3]);
  if (!pendingId || !targetId) return null;
  return { pendingId, targetKind: m[2] === "p" ? "proposal" : "transaction", targetId };
}

export function parseSeparateCallback(data: string): string | null {
  const m = /^ps:([0-9a-fA-F-]{36})$/.exec(data);
  return m ? m[1] : null;
}

export function linkQuestion(match: BankMatch, amountText: string): string {
  return `لقيت إشعار فيزا بـ ${amountText} من ${match.merchant}. أربط الفاتورة بيه من غير خصم تاني؟`;
}
