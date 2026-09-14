// تأكيد عمليات الفلوس في المكالمة الحية (٢٠٢٦-٠٩-١٥).
//
// شكوى من تجربة حقيقية: «زاد الصوتي مانفذش ولا طلب — خصم مبلغ، ضيف مبلغ». السبب في الكود: التأكيد
// كان بمطابقة توقيعة حرفية (اسم الأداة + JSON.stringify للبيانات). الموديل بعد ما العميل يقول «أيوه»
// نادراً ما بيعيد النداء بنفس البايتات بالظبط (عنوان متصاغ تاني، حقل category اتضاف، ترتيب مختلف)،
// فالتوقيعة ماتطابقش ⇒ يسأل تاني ⇒ لفة مابتخلصش والعملية مابتتنفذش أبداً.
//
// دلوقتي: الاقتراح المعلّق بيتحفظ بالبيانات اللي العميل سمعها. التأكيد ممكن بطريقتين:
//   ١. أداة صريحة confirm_pending_money_action (مفيش بيانات تتلخبط)
//   ٢. نفس الأداة تاني بنفس «جوهر» العملية (نفس النوع والمبلغ/المعرّف) — وبننفّذ البيانات المحفوظة،
//      مش الجديدة، عشان اللي يتسجل هو اللي اتقال للعميل.
// الاقتراح بيموت بعد ٥ دقايق، وأي اقتراح جديد مختلف بيحل محله.

export const PENDING_TTL_MS = 5 * 60 * 1000;

export interface PendingAction {
  tool: string;
  args: Record<string, unknown>;
  at: number;
}

const num = (v: unknown) => {
  const n = Number(v);
  return Number.isFinite(n) ? Math.round(n * 100) / 100 : null;
};

/** نفس العملية؟ الجوهر بس (النوع والمبلغ/المعرّف) — الصياغة والحقول الإضافية مش مهمة. */
export function sameMoneyAction(tool: string, a: Record<string, unknown>, b: Record<string, unknown>): boolean {
  switch (tool) {
    case "log_transaction":
      return num(a.amount) !== null && num(a.amount) === num(b.amount) && String(a.txn_kind ?? "") === String(b.txn_kind ?? "");
    case "update_transaction":
      return String(a.transaction_id ?? "") !== "" && a.transaction_id === b.transaction_id &&
        (a.amount === undefined || num(a.amount) === num(b.amount));
    case "delete_transaction":
      return String(a.transaction_id ?? "") !== "" && a.transaction_id === b.transaction_id;
    case "set_monthly_limit":
      return num(a.monthly_limit) !== null && num(a.monthly_limit) === num(b.monthly_limit);
    default:
      return false;
  }
}

export class PendingMoneyActions {
  private pending: PendingAction | null = null;
  constructor(private now: () => number = Date.now) {}

  private live(): PendingAction | null {
    if (this.pending && this.now() - this.pending.at > PENDING_TTL_MS) this.pending = null;
    return this.pending;
  }

  /**
   * نداء أداة فلوس. بيرجع `execute` بالبيانات اللي تتنفذ لو ده تأكيد لنفس العملية المعلّقة،
   * وإلا `ask` (والاقتراح بيتسجل/يتبدل).
   */
  onToolCall(tool: string, args: Record<string, unknown>): { action: "execute"; args: Record<string, unknown> } | { action: "ask" } {
    const p = this.live();
    if (p && p.tool === tool && sameMoneyAction(tool, p.args, args)) {
      this.pending = null;
      return { action: "execute", args: p.args };
    }
    this.pending = { tool, args, at: this.now() };
    return { action: "ask" };
  }

  /** العميل وافق صراحة. null = مفيش حاجة معلّقة (أو قدمت). */
  confirm(): PendingAction | null {
    const p = this.live();
    this.pending = null;
    return p;
  }

  cancel(): boolean {
    const had = this.live() !== null;
    this.pending = null;
    return had;
  }
}
