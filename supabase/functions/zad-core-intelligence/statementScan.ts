// statementScan.ts — كشف الحساب بالصورة أو PDF (ZAD_PLAN.md ٣.٣).
//
// الاستيراد كان CSV بس، والسبب مكتوب فوق statement_import.dart: «الرؤية بتغلط في جداول الفلوس
// المتعددة الصفحات». ده لسه صح، فالقراية هنا ليها حارسين في الكود مش في البرومبت:
//   - الموديل **بينقل** الصفوف زي ما هي (تاريخ، وصف، مبلغ، مدين/دائن، الرصيد بعدها لو مطبوع) —
//     مفيش صف بيتحسب ولا بيتخمّن، والإجماليات والرصيد المرحّل مش صفوف.
//   - **الرصيد بيراجع الأرقام:** لو الكشف فيه رصيد بعد كل صف، كل صف بيتحسب من اللي قبله
//     (balance_ok)، ولو فيه رصيد أول وآخر المدة، المجموع بيتطابق عليهم (check). التطبيق بيعرض
//     الصف اللي مش متطابق مش متعلّم، ومفيش حاجة بتتسجل من غير مراجعة العميل.

export const STATEMENT_PROMPT =
  "You read a bank or e-wallet account statement (a photo, a screenshot or a PDF) for a household finance app (ZAD) " +
  "used in Egypt and the Gulf. Statements are Arabic, English or both. TRANSCRIBE ONLY the transaction rows that are printed — " +
  "never compute, merge, split or invent a row. Skip headers, page totals, 'balance brought/carried forward' (رصيد مرحل/منقول), " +
  "summary boxes and blank lines. For each transaction row, in the order printed: " +
  "`date` as YYYY-MM-DD (statements print day first: 05/10/2026 is 5 October 2026; use the transaction/posting date, not the value date if both), " +
  "`description` exactly as written (merchant, transfer, fee…), " +
  "`amount` as a positive number exactly as printed (no currency, no thousands separators), " +
  "`direction`: \"debit\" for money out (withdrawal, purchase, مدين, سحب, خصم, Dr, a minus sign) or \"credit\" for money in " +
  "(deposit, salary, refund, دائن, إيداع, Cr) — take it from the column the amount sits in or its sign, " +
  "`balance` = the running balance printed on that row, or null if the row has none. " +
  "Also `opening_balance` and `closing_balance` if printed (else null), `currency` as a 3-letter ISO code if shown (else null), " +
  "and `bank` if printed (else null). A number you cannot read with confidence: leave that row out rather than guess it. " +
  "Return ONLY JSON: {\"bank\":null,\"currency\":null,\"opening_balance\":null,\"closing_balance\":null," +
  "\"rows\":[{\"date\":\"2026-10-05\",\"description\":\"\",\"amount\":0,\"direction\":\"debit\",\"balance\":null}]}";

/** أكبر كشف بنقبله في نداء واحد — أكتر من كده الموديل بيقطع والـJSON بيبوظ. */
export const MAX_STATEMENT_ROWS = 400;

/** الملفات اللي الأكشن بيقبلها: صورة أو PDF. Gemini بيقرا الاتنين inline. */
export function statementMimeOk(mime: unknown): mime is string {
  return typeof mime === "string" &&
    (mime === "application/pdf" || /^image\/(jpeg|png|webp|heic|heif)$/.test(mime));
}

export type Direction = "debit" | "credit";

export interface StatementRow {
  date: string;
  description: string | null;
  amount: number;
  direction: Direction;
  balance: number | null;
  /** الرصيد المطبوع بيتحسب من الصف اللي قبله؟ null لو مفيش رصيدين نقارن بيهم. */
  balance_ok: boolean | null;
}

export interface Statement {
  bank: string | null;
  currency: string | null;
  opening_balance: number | null;
  closing_balance: number | null;
  rows: StatementRow[];
  /** صفوف رجعت من الموديل واتشالت (تاريخ أو مبلغ مش مفهوم). */
  dropped: number;
  /**
   * balanced: أول المدة + الدائن − المدين = آخر المدة (أو كل الأرصدة الجارية متطابقة).
   * mismatch: في فرق — العميل يراجع كل صف. unknown: الكشف مفيهوش أرصدة نراجع بيها.
   */
  check: "balanced" | "mismatch" | "unknown";
}

const ARABIC_DIGITS = "٠١٢٣٤٥٦٧٨٩";
const PERSIAN_DIGITS = "۰۱۲۳۴۵۶۷۸۹";

/** رقم من رد الموديل: رقم، أو نص بأرقام عربية وفواصل آلاف وعملة. */
export function money(v: unknown): number | null {
  if (typeof v === "number") return Number.isFinite(v) ? v : null;
  if (typeof v !== "string") return null;
  let t = v.trim()
    .replace(/[٠-٩]/g, (d) => String(ARABIC_DIGITS.indexOf(d)))
    .replace(/[۰-۹]/g, (d) => String(PERSIAN_DIGITS.indexOf(d)))
    .replace(/٫/g, ".")
    .replace(/[٬,\s]/g, "");
  const negative = /^\(.*\)$/.test(t) || t.startsWith("-") || /-$/.test(t);
  t = t.replace(/[^0-9.]/g, "");
  if (!/^\d+(\.\d+)?$/.test(t)) return null;
  const n = Number(t);
  return negative ? -n : n;
}

const cents = (n: number) => Math.round(n * 100) / 100;

const text = (v: unknown, max: number): string | null => {
  if (typeof v !== "string") return null;
  const t = v.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim();
  return t ? t.slice(0, max) : null;
};

/** تاريخ الصف: حقيقي، مش في المستقبل (يوم سماح للتوقيت)، ومش أقدم من سنتين. */
export function statementDate(raw: unknown, now: Date = new Date()): string | null {
  if (typeof raw !== "string") return null;
  const m = raw.trim().match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!m) return null;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const at = new Date(Date.UTC(y, mo - 1, d));
  if (at.getUTCFullYear() !== y || at.getUTCMonth() !== mo - 1 || at.getUTCDate() !== d) return null;
  const day = 24 * 60 * 60 * 1000;
  if (at.getTime() > now.getTime() + day) return null;
  if (at.getTime() < now.getTime() - 731 * day) return null;
  return m[0];
}

function direction(v: unknown, signed: number | null): Direction | null {
  const t = typeof v === "string" ? v.trim().toLowerCase() : "";
  if (t === "debit" || t === "dr" || t === "out") return "debit";
  if (t === "credit" || t === "cr" || t === "in") return "credit";
  // الموديل نسي الاتجاه بس كتب المبلغ بإشارة: السالب خارج.
  if (signed != null && signed < 0) return "debit";
  return null;
}

/** الفرق المسموح بين الرصيد المحسوب والمطبوع (تقريب القروش). */
const TOLERANCE = 0.011;

export function normalizeStatement(raw: unknown, now: Date = new Date()): Statement {
  const o = raw && typeof raw === "object" ? raw as Record<string, unknown> : {};
  const list = Array.isArray(o.rows) ? o.rows.slice(0, MAX_STATEMENT_ROWS) : [];
  const rows: StatementRow[] = [];
  let dropped = Array.isArray(o.rows) ? Math.max(0, o.rows.length - MAX_STATEMENT_ROWS) : 0;
  for (const item of list) {
    const r = item && typeof item === "object" ? item as Record<string, unknown> : {};
    const date = statementDate(r.date, now);
    const signed = money(r.amount);
    const dir = direction(r.direction, signed);
    const amount = signed == null ? null : cents(Math.abs(signed));
    if (!date || amount == null || amount <= 0 || amount >= 100_000_000 || !dir) {
      dropped++;
      continue;
    }
    const balance = money(r.balance);
    rows.push({
      date,
      description: text(r.description, 140),
      amount,
      direction: dir,
      balance: balance == null ? null : cents(balance),
      balance_ok: null,
    });
  }

  const opening = money(o.opening_balance);
  const closing = money(o.closing_balance);

  // الرصيد الجاري: كل صف له رصيد، والصف اللي قبله له رصيد ⇒ اللي قبله ± المبلغ = ده.
  // أول صف بيتقارن برصيد أول المدة لو مطبوع. الكشوف اللي الأحدث فيها فوق بتتراجع بالعكس.
  const fits = (prev: number, row: StatementRow) =>
    Math.abs(prev + (row.direction === "credit" ? row.amount : -row.amount) - (row.balance as number)) < TOLERANCE;
  const chain = (ordered: StatementRow[], start: number | null) => {
    let ok = 0, bad = 0;
    const marks: (boolean | null)[] = [];
    let prev: number | null = start;
    for (const row of ordered) {
      if (row.balance == null) {
        marks.push(null);
        prev = null;
        continue;
      }
      if (prev == null) {
        marks.push(null);
      } else if (fits(prev, row)) {
        marks.push(true);
        ok++;
      } else {
        marks.push(false);
        bad++;
      }
      prev = row.balance;
    }
    return { ok, bad, marks };
  };
  const forward = chain(rows, opening);
  const reversed = [...rows].reverse();
  const backward = chain(reversed, opening);
  const useBackward = backward.ok > forward.ok;
  const marks = useBackward ? backward.marks.reverse() : forward.marks;
  rows.forEach((row, i) => row.balance_ok = marks[i]);

  let check: Statement["check"] = "unknown";
  if (opening != null && closing != null && rows.length > 0) {
    const net = rows.reduce((s, r) => s + (r.direction === "credit" ? r.amount : -r.amount), 0);
    check = Math.abs(opening + net - closing) < TOLERANCE * Math.max(1, rows.length) ? "balanced" : "mismatch";
  } else {
    const { ok, bad } = useBackward ? backward : forward;
    if (ok + bad > 0) check = bad === 0 && ok >= Math.max(1, rows.length - 1) ? "balanced" : bad > 0 ? "mismatch" : "unknown";
  }
  if (dropped > 0 && check === "balanced") check = "mismatch";

  const currency = typeof o.currency === "string" && /^[A-Za-z]{3}$/.test(o.currency.trim())
    ? o.currency.trim().toUpperCase()
    : null;
  return {
    bank: text(o.bank, 80),
    currency,
    opening_balance: opening == null ? null : cents(opening),
    closing_balance: closing == null ? null : cents(closing),
    rows,
    dropped,
    check,
  };
}
