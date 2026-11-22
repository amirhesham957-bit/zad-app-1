// سياسة التراجع (م١.٥): مين فيهم الفعل يتعرض عليه زرار «ارجع فيه»، ولمدة قد إيه، وإزاي الزرار
// يتكتب بنفس الشكل في الشات والتليجرام والإشعار والسجل. وكمان عبارات «ارجع في اللي عملته» بتتفهم
// كطلب تراجع عن آخر فعل قابل للتراجع، مش كطلب حذف.
// دالة نقية: مافيش I/O، ولا شبكة، ولا داتابيز، ولا Deno.env.
// التراجع الفعلي بيتم في zad_agent_undo (migration 20260809180000 + 20261011160000). الملف ده بيقرر بس
// هل نعرض الزرار ولا لأ، وبيترجم النتيجة لعربي.

/** القنوات اللي الزرار بيظهر فيها. الـpayload واحد على كله. */
export type Surface = "chat" | "telegram" | "push" | "log";

/** الشكل المختصر من agent_actions اللي الـpolicy محتاجاه بس. */
export type UndoableAction = {
  id: string;
  tool: string;
  status: string;
  createdAt: string;
  undoneAt?: string | null;
  kind?: string;
};

export type UndoReason = "expired" | "already_undone" | "not_reversible" | "unknown_status";

/** مدة الشباك اللي فيها التراجع مسموح: ٢٤ ساعة من وقت الفعل. الحد نفسه مسموح (<= الشباك). */
export const UNDO_WINDOW_MS = 24 * 60 * 60 * 1000;

/** الحالات اللي CHECK في agent_actions بيقبلها. أي حاجة غيرها = unknown_status. */
const KNOWN_STATUSES: ReadonlySet<string> = new Set(["applied", "rejected", "undone"]);

/**
 * أدوات مابتترجعش: إرسال أو إشعار اتبعت خلاص، ومفيش صف في الداتابيز يتعكس.
 * أي أداة جديدة من نوع إرسال لازم تتضاف هنا.
 */
export const NON_REVERSIBLE_TOOLS: ReadonlySet<string> = new Set([
  "send_message",
  "send_telegram",
  "send_push",
  "send_notification",
  "send_reminder",
  "notify_family",
]);

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CALLBACK_PREFIX = "undo:";
/** حد Telegram لـcallback_data بالبايت. */
const CALLBACK_MAX_BYTES = 64;
const UNDO_LABEL = "ارجع فيه";

const utf8 = new TextEncoder();

function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_RE.test(value);
}

/**
 * يقرر لو الفعل ينفع يتراجع عنه دلوقتي.
 * الترتيب: الحالة الغريبة الأول، بعدين «اتراجع قبل كده»، بعدين «مابيترجعش»، بعدين الشباك الزمني.
 * تاريخ مش قابل للقراءة = expired (نقفل لو مش متأكدين).
 */
export function isUndoable(
  action: UndoableAction,
  now: Date,
): { ok: boolean; reason?: UndoReason } {
  if (!KNOWN_STATUSES.has(action.status)) return { ok: false, reason: "unknown_status" };
  if (action.status === "undone" || (action.undoneAt ?? null) !== null) {
    return { ok: false, reason: "already_undone" };
  }
  if (action.status === "rejected" || NON_REVERSIBLE_TOOLS.has(action.tool)) {
    return { ok: false, reason: "not_reversible" };
  }
  const created = Date.parse(action.createdAt);
  if (Number.isNaN(created)) return { ok: false, reason: "expired" };
  // فعل بتاريخ في المستقبل (فرق ساعات بين السيرفر والجهاز) مابيتعدّش كـexpired.
  if (now.getTime() - created > UNDO_WINDOW_MS) return { ok: false, reason: "expired" };
  return { ok: true };
}

/** payload الزرار: `undo:<uuid>`. بيرمي لو الـid مش uuid، عشان مايتبعتش زرار مكسور. */
export function undoCallbackData(actionId: string): string {
  if (!isUuid(actionId)) throw new Error("undoCallbackData: actionId is not a uuid");
  return CALLBACK_PREFIX + actionId;
}

/** يفك `undo:<uuid>`. أي حاجة غير مطابقة (نوع، طول، شكل) = null. */
export function parseUndoCallback(data: string): { actionId: string } | null {
  if (typeof data !== "string") return null;
  if (utf8.encode(data).byteLength > CALLBACK_MAX_BYTES) return null;
  if (!data.startsWith(CALLBACK_PREFIX)) return null;
  const actionId = data.slice(CALLBACK_PREFIX.length);
  if (!isUuid(actionId)) return null;
  return { actionId };
}

/**
 * الزرار بالشكل الموحّد. نفس الـlabel والـpayload على كل surface.
 * - null: الـid مش uuid، فمفيش payload يتبني.
 * - show=false: الفعل مش قابل للتراجع دلوقتي (الـpayload بيفضل موجود للتشخيص بس، ماتعرضوش).
 * في push الـpayload بيتحط كـdata بتاعة action button.
 */
export function undoButton(
  action: UndoableAction,
  surface: Surface,
  now: Date,
): { show: boolean; label: string; payload: string } | null {
  void surface; // مفيش فرق بين القنوات، عن قصد.
  if (!isUuid(action.id)) return null;
  return {
    show: isUndoable(action, now).ok,
    label: UNDO_LABEL,
    payload: undoCallbackData(action.id),
  };
}

// تطبيع عربي: شيل التشكيل والتطويل، وحّد الألف والياء والتاء المربوطة، وشيل علامات الترقيم.
function normalizeText(text: string): string {
  return text
    .normalize("NFKC")
    .replace(/[ً-ٰٟـ]/g, "")
    .replace(/[إأآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .toLowerCase()
    .replace(/[.,!?؟،;:"'«»()\-_]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

const UNDO_PHRASES: ReadonlySet<string> = new Set(
  [
    "ارجع في اللي عملته",
    "رجّع",
    "الغي ده",
    "تراجع",
    "undo",
  ].map(normalizeText),
);

/**
 * الرسالة كلها عبارة تراجع (بعد التطبيع). مش بتدور جوه جملة أطول.
 * العبارة دي معناها «ارجع عن آخر فعل»، مش «احذف». الدالة ماتطلعش أي اسم أداة.
 */
export function isUndoPhrase(text: string): boolean {
  if (typeof text !== "string") return false;
  return UNDO_PHRASES.has(normalizeText(text));
}

/**
 * آخر فعل قابل للتراجع (الأحدث createdAt). التعادل في الوقت = أول واحد في الـarray.
 * بيرجع نفس الـobject اللي في الـinput، ماينفعش يخترع أداة.
 */
export function pickTargetForPhrase(
  actions: readonly UndoableAction[],
  now: Date,
): UndoableAction | null {
  let best: UndoableAction | null = null;
  let bestTime = -Infinity;
  for (const action of actions) {
    if (!isUndoable(action, now).ok) continue;
    const t = Date.parse(action.createdAt);
    if (t > bestTime) {
      best = action;
      bestTime = t;
    }
  }
  return best;
}

/** نص الرد بعد محاولة التراجع. بالعامية المصرية، من غير أرقام. */
export function undoResultText(res: { ok: boolean; reason?: string }): string {
  if (res.ok) return "تمام، رجّعت الحاجة اللي عملتها زي ما كانت.";
  switch (res.reason) {
    case "expired":
      return "الفعل ده عدّى وقته المسموح، فمابقاش ينفع أرجّعه.";
    case "already_undone":
      return "الفعل ده اترجّع قبل كده.";
    case "not_reversible":
      return "الفعل ده ماينفعش يترجّع، لأنه إرسال أو إشعار اتبعت خلاص.";
    case "unknown_status":
      return "مش فاهم حالة الفعل ده، فمارجعتوش.";
    default:
      return "معرفتش أرجّع الفعل ده دلوقتي.";
  }
}
