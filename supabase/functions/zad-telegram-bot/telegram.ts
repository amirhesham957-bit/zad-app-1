// Pure helpers — no grammY, no Supabase, no network. Framework-agnostic on purpose so
// they stay testable without spinning up a Bot instance (grammY's Bot needs a live
// token to construct in some code paths); index.ts is the only place that touches
// grammY or Supabase.

/**
 * زر إما بـcallback_data (بيرجع للبوت) أو بـurl (بيفتح رابط عند العميل).
 *
 * ⚠️ تليجرام بيقبل http/https/tg:// في url وبيرفض أي مخطط مخصص — يعني
 * `zad://rewards` مش هيتبعت أصلاً. عشان كده رابط الشحن https://zad.app/rewards
 * وفيه intent-filter مقابل في المانيفست.
 */
export interface InlineKeyboardButton {
  text: string;
  callback_data?: string;
  url?: string;
}

/** زر "اشحن رصيدك" لرسالة نفاد الرصيد. */
export function adCreditKeyboard(): InlineKeyboardButton[][] {
  return [[{ text: "🎬 اشحن رصيدك من التطبيق", url: "https://zad.app/rewards" }]];
}

export function mainMenuKeyboard(): InlineKeyboardButton[][] {
  return [
    [{ text: "الرصيد المتبقي", callback_data: "b" }],
    [{ text: "آخر المعاملات", callback_data: "t" }],
    [{ text: "التنبيهات المعلقة", callback_data: "i" }],
  ];
}

/** dismiss_reason الأقصر ممكن — Telegram callback_data محدود بـ٦٤ بايت، ومحتاج نضم insight id كمان */
const DISMISS_REASON_CODES: Record<string, string> = { n: "not_relevant", w: "wrong_data", t: "timing" };
const DISMISS_REASON_LABELS: Record<string, string> = { n: "مش مهم", w: "الرقم غلط", t: "عرفت خلاص" };

export function reasonForCode(code: string): string | null {
  return DISMISS_REASON_CODES[code] ?? null;
}

export function dismissKeyboard(insightId: string): InlineKeyboardButton[][] {
  return [Object.keys(DISMISS_REASON_LABELS).map((code) => ({
    text: DISMISS_REASON_LABELS[code],
    callback_data: `d:${insightId}:${code}`,
  }))];
}

/**
 * أزرار الرفض تحت رسالة مبادرة (مهمة استباقية من agent_tasks) — نفس التلات أسباب ونفس
 * الأسامي بتوع Task 28، بس بمعرّف المهمة مش الرؤية، وبادئة `pd:` مختلفة عن `d:` عشان
 * الراوتر يفرّقهم قبل ما يلمس أي جدول. `pd:` + uuid (36) + `:` + كود حرف = 41 بايت، تحت
 * سقف تليجرام 64 لـcallback_data.
 */
export function proactiveDismissKeyboard(taskId: string): InlineKeyboardButton[][] {
  return [Object.keys(DISMISS_REASON_LABELS).map((code) => ({
    text: DISMISS_REASON_LABELS[code],
    callback_data: `pd:${taskId}:${code}`,
  }))];
}

/** "pd:<task uuid>:<n|w|t>" — أي حاجة تانية null، عشان زرار مضروب مايوصلش للداتابيز. */
export function parseProactiveDismissCallback(data: string): { taskId: string; reason: string } | null {
  const parts = data.split(":");
  if (parts.length !== 3 || parts[0] !== "pd") return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  const reason = DISMISS_REASON_CODES[parts[2]];
  if (!reason) return null;
  return { taskId: parts[1], reason };
}

/** عدد أيام بعربي سليم للمدد اللي الكتم ممكن يطلعها (3/7/30/60/120/180 وأي رقم تاني). */
export function arabicDays(n: number): string {
  if (n === 1) return "يوم واحد";
  if (n === 2) return "يومين";
  if (n >= 3 && n <= 10) return `${n} أيام`;
  return `${n} يوم`;
}

/**
 * رد البوت بعد ما العميل يرفض مبادرة. بياخد رد `zad_memory_record_proactive_dismissal`
 * زي ما هو. أي فشل بيتقال صراحة — العميل مايفتكرش إن الكتم اتسجّل وهو ماتسجّلش.
 */
export function proactiveDismissReply(
  result: { ok?: boolean; label?: string; reason?: string; days?: number } | null,
): string {
  if (!result?.ok || typeof result.days !== "number") {
    return "معرفتش أسجّل ده دلوقتي — جرّب تاني بعد شوية.";
  }
  const label = result.label ? `«${result.label}»` : "التنبيه ده";
  const period = arabicDays(result.days);
  switch (result.reason) {
    case "not_relevant": return `تمام ✅ مش هبعتلك ${label} تاني لمدة ${period}.`;
    case "timing":       return `تمام ✅ فهمت إنك عارف، ومش هكرر ${label} قبل ${period}.`;
    case "wrong_data":   return `شكرًا إنك نبهتني ✅ هعتبر أرقام ${label} محتاجة مراجعة، ومش هبعته قبل ${period}.`;
    default:             return `تمام ✅ مش هبعتلك ${label} لمدة ${period}.`;
  }
}

/** Task 28's dismiss reason → zad_memory note. Mirrors DismissalMemory.kt (client) and
 * zad-brain/validators.ts's own dismissal handling — same intentional small duplication
 * as BudgetMath.kt/buildSnapshot's cycle math (different runtimes, not worth a shared
 * module yet across a Kotlin app + two independent Deno functions). */
export function memoryNoteForDismissal(reason: string, subject: string): { scope: string; note: string; confidence: number } | null {
  switch (reason) {
    case "not_relevant": return { scope: "dismissal", note: `مش مهتم بتنبيهات زي "${subject}"`, confidence: 0.5 };
    case "wrong_data": return { scope: "data_quality", note: `العميل قال إن "${subject}" غلط — البيانات المصدر محتاجة مراجعة`, confidence: 0.7 };
    case "timing": return { scope: "dismissal", note: `عرف بالفعل عن "${subject}" وقت الرفض ده`, confidence: 0.3 };
    default: return null;
  }
}

/** grammY's ctx.match for a command handler is already just the text after the command
 * (or "" if none) — no more "/start " prefix to strip, unlike a hand-rolled regex. */
export function normalizeBindingCode(arg: string | undefined): string | null {
  const trimmed = (arg ?? "").trim();
  if (!/^[A-Za-z0-9-]{4,32}$/.test(trimmed)) return null;
  return trimmed.toUpperCase();
}

/** Confirm/cancel for a parsed spend intent. Only the pending-row id travels in
 * callback_data — the amount/title/category live in telegram_pending_writes, because
 * callback_data is capped at 64 bytes and a truncated amount would be a silent
 * data-corruption bug. */
export function confirmSpendKeyboard(pendingId: string): InlineKeyboardButton[][] {
  return [[
    { text: "✅ أكد التسجيل", callback_data: `x:${pendingId}` },
    { text: "✖️ إلغاء", callback_data: `c:${pendingId}` },
  ]];
}

/** "x:<uuid>" (confirm) / "c:<uuid>" (cancel) */
export function parseSpendCallback(data: string): { action: "confirm" | "cancel"; pendingId: string } | null {
  const parts = data.split(":");
  if (parts.length !== 2) return null;
  if (parts[0] !== "x" && parts[0] !== "c") return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { action: parts[0] === "x" ? "confirm" : "cancel", pendingId: parts[1] };
}

export type TransactionProposalDecision =
  | "confirm" | "reject" | "expense" | "income" | "transfer" | "duplicate" | "separate";

/**
 * سؤال "هل دي نفس المعاملة؟" — لما إشعارين بنفس المبلغ يوصلوا خلال ١٥ دقيقة (البنك
 * وInstaPay عن نفس الدفعة مثلًا)، أو لما دالة الحسم تلاقي معاملة متقيدة بنفس المبلغ.
 * القيم هنا متنسقة ومعزولة جاهزة من index.ts؛ الدالة بتركّب النص بس.
 */
export function duplicateProposalMessage(input: {
  amountText: string;
  title: string;
  twinTitle?: string | null;
  /** notification = إشعار تاني (بنك/محفظة)؛ transaction = معاملة اتسجلت من الشات أو يدوي. */
  twinSource: "notification" | "transaction";
}): string {
  const fromNotification = input.twinSource === "notification";
  return [
    fromNotification
      ? `وصلني إشعارين بمبلغ ${input.amountText} في نفس الوقت تقريبًا — هل دي نفس المعاملة؟`
      : `فيه عملية متسجلة بمبلغ ${input.amountText} في نفس الوقت تقريبًا — هل الإشعار ده هو نفس المعاملة؟`,
    input.twinTitle ? `${fromNotification ? "الأول" : "المتسجلة"}: ${input.twinTitle}` : "",
    `${fromNotification ? "التاني" : "الإشعار"}: ${input.title}`,
    "لو نفس المعاملة هتتحسب مرة واحدة بس.",
  ].filter(Boolean).join("\n");
}

export function duplicateProposalKeyboard(proposalId: string): InlineKeyboardButton[][] {
  return [
    [{ text: "نفس المعاملة — متتحسبش تاني", callback_data: `pm:${proposalId}` }],
    [{ text: "لأ، دي عملية تانية", callback_data: `ps:${proposalId}` }],
  ];
}

/** A bank-notification proposal is shared with Android, so Telegram only carries the
 * proposal id and the customer's decision. The amount never lives in callback_data. */
export function transactionProposalKeyboard(
  proposalId: string,
  status: "needs_classification" | "awaiting_confirmation",
  txnKind?: string | null,
): InlineKeyboardButton[][] {
  if (status === "needs_classification") {
    return [
      [
        { text: "مصروف", callback_data: `pe:${proposalId}` },
        { text: "دخل", callback_data: `pi:${proposalId}` },
        { text: "تحويل", callback_data: `pt:${proposalId}` },
      ],
      [
        { text: "رفض", callback_data: `pr:${proposalId}` },
        { text: "✏️ المبلغ غلط", callback_data: `pw:${proposalId}` },
      ],
    ];
  }

  const corrections = ["expense", "income", "transfer"]
    .filter((kind) => kind !== txnKind)
    .map((kind) => ({
      text: kind === "expense" ? "تصحيح: مصروف" : kind === "income" ? "تصحيح: دخل" : "تصحيح: تحويل",
      callback_data: `${kind === "expense" ? "pe" : kind === "income" ? "pi" : "pt"}:${proposalId}`,
    }));
  return [
    [
      { text: "أكد", callback_data: `pc:${proposalId}` },
      { text: "رفض", callback_data: `pr:${proposalId}` },
    ],
    corrections,
    // «الرقم ده غلط» (بلاغ ٢٠٢٦-٠٩-٢٥): كان الحل الوحيد «رفض» ومفيش طريقة تقول المبلغ الصح.
    [{ text: "✏️ المبلغ غلط", callback_data: `pw:${proposalId}` }],
  ];
}

/** "pw:<proposal_id>" — المبلغ اللي قريناه من الإشعار غلط. */
export function parseAmountWrongCallback(data: string): string | null {
  const parts = data.split(":");
  if (parts.length !== 2 || parts[0] !== "pw" || !/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return parts[1];
}

export function parseTransactionProposalCallback(
  data: string,
): { decision: TransactionProposalDecision; proposalId: string } | null {
  const parts = data.split(":");
  if (parts.length !== 2 || !/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  const decisions: Record<string, TransactionProposalDecision> = {
    pc: "confirm", pr: "reject", pe: "expense", pi: "income", pt: "transfer",
    pm: "duplicate", ps: "separate",
  };
  const decision = decisions[parts[0]];
  return decision ? { decision, proposalId: parts[1] } : null;
}

export function notificationReviewMessage(event: {
  packageName: string;
  title?: string | null;
  body: string;
}): string {
  const details = [event.title?.trim(), event.body.trim()].filter(Boolean).join(" - ").slice(0, 500);
  return [
    "إشعار بنكي محتاج مراجعتك",
    `المصدر: ${event.packageName}`,
    details,
    "المبلغ أو الاتجاه مش واضح. اختار من الأزرار، أو رد عليا بجملة زي: ده سحب 250 من البطاقة، أو ده إيداع 1000. هعرضه عليك للتأكيد قبل ما أغيّر الرصيد.",
  ].filter(Boolean).join("\n");
}

/**
 * أزرار الرد السريع على الإشعار الغامض — قبل كده السؤال كان نص بس وبتطلب من العميل
 * يكتب جملة، فمعظم الناس بيتجاهلوا. الأزرار بترسل نص جاهز يتعالج بنفس مسار agent_turn.
 * callback_data: nrev:<eventId>:<expense|income|skip> — يتفك في parseNotificationReviewCallback.
 */
export function notificationReviewKeyboard(eventId: string): InlineKeyboardButton[][] {
  return [
    [
      { text: "💳 مصروف/سحب", callback_data: `nrev:${eventId}:expense` },
      { text: "💰 إيداع", callback_data: `nrev:${eventId}:income` },
    ],
    [{ text: "تجاهل", callback_data: `nrev:${eventId}:skip` }],
  ];
}

export function parseNotificationReviewCallback(
  data: string,
): { eventId: string; direction: "expense" | "income" | "skip" } | null {
  const parts = data.split(":");
  if (parts.length !== 3 || parts[0] !== "nrev") return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  const direction = parts[2];
  if (direction !== "expense" && direction !== "income" && direction !== "skip") return null;
  return { eventId: parts[1], direction };
}

/**
 * تأكيد/إلغاء لأي أداة تانية محتاجة موافقة غير `log_transaction` — تعديل معاملة،
 * مسحها، أو تغيير السقف الشهري.
 *
 * من غير الكيبورد ده، الاقتراحات دي كانت بتوصل للعميل كسطر نصي بيقول "ابعتها لوحدها
 * عشان أأكدها معاك" — وهو أصلاً باعتها لوحدها، فنفس السطر بيتكرر للأبد. "امسح
 * المعاملة دي" من تليجرام كانت مستحيلة حرفياً، مش صعبة.
 *
 * "tx:"/"tc:" متمايزين عن "x:"/"c:" (فلوس) و"mx:"/"mc:" (دوا) عشان الراوتر يفرّق بين
 * التلات طوابير قبل ما يلمس أي جدول. نفس القاعدة: الـ id بس هو اللي بيسافر في
 * callback_data — الأداة ومدخلاتها في telegram_pending_tools، لأن الحد ٦٤ بايت.
 */
export function confirmToolKeyboard(pendingId: string): InlineKeyboardButton[][] {
  return [[
    { text: "✅ أكد", callback_data: `tx:${pendingId}` },
    { text: "✖️ إلغاء", callback_data: `tc:${pendingId}` },
  ]];
}

/** "tx:<uuid>" (confirm) / "tc:<uuid>" (cancel) */
export function parseToolCallback(data: string): { action: "confirm" | "cancel"; pendingId: string } | null {
  const parts = data.split(":");
  if (parts.length !== 2) return null;
  if (parts[0] !== "tx" && parts[0] !== "tc") return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { action: parts[0] === "tx" ? "confirm" : "cancel", pendingId: parts[1] };
}

/** "d:<insight_id>:<reason_code>" callback_data */
export function parseDismissCallback(data: string): { insightId: string; reasonCode: string } | null {
  const parts = data.split(":");
  if (parts.length !== 3 || parts[0] !== "d") return null;
  return { insightId: parts[1], reasonCode: parts[2] };
}

/** Confirm/cancel for a parsed medication schedule (Smart Medication Parsing). Same
 * "only the pending-row id in callback_data" reasoning as confirmSpendKeyboard — a
 * "mx:"/"mc:" prefix (distinct from spend's "x:"/"c:") so the callback router can tell
 * the two pending flows apart before touching either table. */
export function confirmMedicationKeyboard(pendingId: string): InlineKeyboardButton[][] {
  return [[
    { text: "✅ أكد وفعّل التذكير", callback_data: `mx:${pendingId}` },
    { text: "✖️ إلغاء", callback_data: `mc:${pendingId}` },
  ]];
}

/** "mx:<uuid>" (confirm) / "mc:<uuid>" (cancel) */
export function parseMedicationCallback(data: string): { action: "confirm" | "cancel"; pendingId: string } | null {
  const parts = data.split(":");
  if (parts.length !== 2) return null;
  if (parts[0] !== "mx" && parts[0] !== "mc") return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { action: parts[0] === "mx" ? "confirm" : "cancel", pendingId: parts[1] };
}

/** Telegram Micro-Checkins — "is <item> still in stock?" prompt buttons. Only the prompt
 * row's id travels in callback_data (same reasoning as confirmSpendKeyboard: a long
 * Arabic item name risks the 64-byte callback_data cap). */
export function checkInKeyboard(promptId: string): InlineKeyboardButton[][] {
  return [[
    { text: "✅ لسه موجود", callback_data: `ck:${promptId}:y` },
    { text: "❌ خلص", callback_data: `ck:${promptId}:n` },
  ]];
}

/** "ck:<uuid>:y|n" callback_data */
export function parseCheckInCallback(data: string): { promptId: string; stillInStock: boolean } | null {
  const parts = data.split(":");
  if (parts.length !== 3 || parts[0] !== "ck") return null;
  if (parts[2] !== "y" && parts[2] !== "n") return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { promptId: parts[1], stillInStock: parts[2] === "y" };
}

export function checkInPromptMessage(itemName: string): string {
  return `تذكير سريع: ${itemName} لسه موجود عندك ولا خلص؟`;
}

/** The zad_budget_state() row this button renders. Only the fields the message uses. */
export interface BudgetStateRow {
  /** The cycle's opening balance. Named for the column, which predates the ledger. */
  monthly_limit: number | null;
  spent: number;
  income: number;
  /** The ledger balance: opening + income - spent. Null only when no opening is set. */
  remaining: number | null;
  committed: number;
  available: number | null;
  days_left: number;
}

/**
 * Phase 0 — a renderer, not a calculator. It used to take (budget, spent, income) and do
 * `budget - spent + income` over a calendar month, which is not the figure the app shows:
 * the app is salary-cycle aware and subtracts fixed obligations to reach "المتاح". The
 * customer could therefore read one number in the app and a different one in Telegram for
 * the same day. Every value here now arrives already computed by zad_budget_state().
 *
 * A null opening balance prints "مش محدد" — never 0. Telling someone with no balance set
 * that they have 0 left is a different (and worse) statement than telling them it is
 * unknown.
 *
 * The wording changed with the ledger migration (20260816010000) and the numbers changed
 * underneath it. `remaining` is no longer `ceiling - spent`; it is the balance itself,
 * `opening + income - spent`. Calling that "المتبقي من السقف" would have described money
 * the customer has as a budget allowance they have left, which is the exact confusion the
 * ledger exists to remove.
 */
export function formatBalanceMessage(s: BudgetStateRow, currency: string): string {
  const unit = currency && currency !== "غير معروف" ? ` ${currency}` : "";
  const fmt = (n: number | null) => n === null ? "غير معروف" : `${n.toFixed(2)}${unit}`;
  if (s.monthly_limit === null) {
    return [
      `مصروف الدورة دي: ${fmt(s.spent)}`,
      "رصيدك لسه مش محدد، فمقدرش أقولك فاضل كام.",
      "ظبّطه من التطبيق وأنا أحسبهولك.",
    ].join("\n");
  }
  return [
    `رصيدك: ${fmt(s.remaining)}`,
    `(بدأت الدورة بـ ${fmt(s.monthly_limit)} — دخل: ${fmt(s.income)} — مصروف: ${fmt(s.spent)})`,
    `المتاح بعد خصم المحجوز (${fmt(s.committed)}): ${fmt(s.available)} — فاضل ${s.days_left} يوم في الدورة.`,
  ].join("\n");
}

export function formatTransactionsMessage(txs: Array<{ title: string; amount: number; txn_kind: string; created_at: string | null }>): string {
  if (txs.length === 0) return "مفيش معاملات مسجلة لسه.";
  return txs.slice(0, 10).map((t) => {
    const sign = t.txn_kind === "income" ? "+" : "-";
    const date = t.created_at?.slice(0, 10) ?? "";
    return `${sign}${t.amount.toFixed(2)} — ${t.title} (${date})`;
  }).join("\n");
}

export function formatInsightTitle(insight: { title: string; body: string }): string {
  return `${insight.title}\n${insight.body}`;
}

// ── الحلقة اللانهائية: مين يستاهل معالجة أصلاً (٢٠٢٦-٠٩-١٩) ──────────────────
//
// بلاغ: «البوت بيقرا رسايل نفسه ويرد عليها باستمرار». الفحص طلّع سببين مختلفين
// بينتجوا نفس المنظر بالظبط، ولازم الاتنين يتقفلوا:
//
// 1. **راسل مش بني آدم.** أي تحديث جاي من `is_bot` (بوت تاني، أو رسالة البوت نفسه
//    لما يكون في جروب/قناة ومتفعّل عنده privacy mode = off، أو رسالة متبعوتة
//    `via_bot`، أو بوست قناة اللي بيجي بـ`sender_chat` من غير `from` آدمي).
//    `zad-telegram-bot` كان بيعالج أي `message:text` من غير ما يبص على الراسل خالص.
//    رسالة بوت بترد عليها برسالة، اللي بترجع كتحديث، اللي يرد عليها… إلخ.
//
// 2. **إعادة تسليم من تليجرام.** الـwebhook هنا بيستنى لفة الوكيل كلها (نداء موديل،
//    ممكن ٣٠ ثانية+) قبل ما يرجع 200. تليجرام بيعتبر ده timeout ويعيد تسليم **نفس**
//    التحديث بنفس `update_id`، فلفة تانية بتبدأ جنب اللي لسه شغالة، وكل واحدة بترد.
//    ده اللي بيعمل «مئات الرسايل المتراكمة». الفلتر فوق مابيلمسش ده — عشان كده
//    فيه `update_id` dedup كمان في index.ts.
//
// الفلتر ده متعمد إنه **خالص وبدون شبكة**: أول سطر في المعالجة، قبل أي قراية
// داتابيز أو نداء موديل، عشان تحديث بوت مايكلّفش ولا استعلام.

/** الحد الأدنى من شكل تحديث تليجرام اللي الفلتر بيحتاجه. */
export interface UpdateEnvelope {
  update_id?: number;
  message?: { from?: { is_bot?: boolean }; via_bot?: unknown; sender_chat?: unknown };
  edited_message?: { from?: { is_bot?: boolean }; via_bot?: unknown; sender_chat?: unknown };
  callback_query?: { from?: { is_bot?: boolean } };
  channel_post?: unknown;
  edited_channel_post?: unknown;
  [k: string]: unknown;
}

/**
 * هل التحديث ده من بني آدم في محادثة عادية؟ `false` = يتسقط فوراً بـ200 من غير أي معالجة.
 *
 * بيترفض: أي `from.is_bot`، أي رسالة متبعوتة عن طريق بوت تاني (`via_bot`)، بوستات
 * القنوات (`channel_post`/`edited_channel_post`)، وأي رسالة راسلها قناة مش شخص
 * (`sender_chat` — بتوصل لما البوت أدمن في قناة أو في جروب متربوط بقناة).
 *
 * `edited_message` بيترفض كمان لأن البوت مابيتعاملش معاه أصلاً؛ تعديل رسالة قديمة كان
 * هيتقري كرسالة جديدة ويتعمل عليها لفة وكيل كاملة.
 */
export function isHumanUpdate(update: UpdateEnvelope | null | undefined): boolean {
  if (!update || typeof update !== "object") return false;
  if (update.channel_post || update.edited_channel_post) return false;
  if (update.edited_message) return false;
  const msg = update.message;
  if (msg) {
    if (msg.sender_chat) return false;
    if (msg.via_bot) return false;
    return msg.from?.is_bot !== true;
  }
  const cb = update.callback_query;
  if (cb) return cb.from?.is_bot !== true;
  // نوع تحديث مش مطلوب (my_chat_member، poll…) — مفيش handler ليه، فمفيش سبب نشغّل عليه حاجة.
  return false;
}

// ── أزرار الجرعة (٢٠٢٦-٠٩-١٩) ────────────────────────────────────────────────
//
// بلاغ: العميل بيكتب «أخدته» والبوت بيشكره من غير ما يسجّل حاجة، فالكرون بيفضل يبعت
// «فاتتك جرعة المضاد» كل نص ساعة. السبب إن تأكيد الجرعة كان ماشي على **فهم الموديل**
// للكلام، ولفة الوكيل ممكن تقع (نت/موديل/مهلة) وترجع رد قرايا من غير أي كتابة.
//
// الزر بيشيل الموديل من النص بالكامل: `callback_data` فيه معرّف لحظة الصوت اللي
// اتبعتت (`zad_voice_moments.id`)، والبوت بيقرا منها `item_ids` + `scheduled_at`
// وبينادي `zad_log_pharmacy_dose_atomic` على كل دوا بنفس الخانة الزمنية بالظبط.
// مفيش رسالة شكر غير بعد ما الـRPC ترجع ok.
//
// الطول: "dz:" + uuid(36) + ":" + حرف = ٤١ بايت، تحت سقف تليجرام (٦٤ بايت) بمسافة.

/** دقايق التأجيل لما العميل يدوس «فكّرني بعدين» — نفس الرقم في SQL (zad_dose_snoozes). */
export const DOSE_SNOOZE_MINUTES = 15;

export function doseKeyboard(momentId: string): InlineKeyboardButton[][] {
  return [
    [
      { text: "✅ أخدت الجرعة", callback_data: `dz:${momentId}:t` },
      // بلاغ ٢٠٢٦-٠٩-٢٥: «لما بدوس مخدتش الدوا مش بيقراها». الزرار ماكانش موجود أصلاً،
      // فالعميل اللي فوّت جرعة بقصد كان ملوش غير إنه يكتب — والكتابة ماكانتش بتتفهم —
      // والكرون يفضل يعاتبه عليها لحد ما الوقت يعدّي.
      { text: "❌ مخدتهاش", callback_data: `dz:${momentId}:k` },
    ],
    [{ text: `⏰ فكّرني بعد ${DOSE_SNOOZE_MINUTES} دقيقة`, callback_data: `dz:${momentId}:s` }],
  ];
}

export type DoseAction = "taken" | "skipped" | "snooze";

/** "dz:<uuid>:t" (اتاخدت) / "dz:<uuid>:k" (مخدتهاش) / "dz:<uuid>:s" (أجّل) */
export function parseDoseCallback(data: string): { momentId: string; action: DoseAction } | null {
  const parts = data.split(":");
  if (parts.length !== 3 || parts[0] !== "dz") return null;
  const actions: Record<string, DoseAction> = { t: "taken", k: "skipped", s: "snooze" };
  const action = actions[parts[2]];
  if (!action) return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { momentId: parts[1], action };
}

// ── الرد بالكلام بدل الزرار (٢٠٢٦-٠٩-٢٥) ────────────────────────────────────
//
// البلاغ: «لما أقول لا مش بيقراها، بيقرا الموافقة بس». السبب الجذري كان في الـregex
// نفسه: `/^\s*(لا|أيوه|…)\b/` — و`\b` في JavaScript حد كلمة **ASCII**. الحروف العربي
// مش «word characters» عنده، فمفيش أي حد بين «لا» وآخر الرسالة أو المسافة اللي بعدها.
// النتيجة المقاسة: «لا»، «أيوه»، «تمام»، «اه» كلهم false؛ «ok» و«no» بس اللي كانوا
// بيتفهموا. يعني كل رد عربي كان بيروح للموديل كرسالة عادية ومفيش حاجة بتتقفل.
//
// الحد هنا lookahead صريح: آخر الرسالة أو مسافة أو علامة ترقيم. والرسالة لازم تكون
// قصيرة — «تمام بس المبلغ ١٥٠ مش ٢٠٠» مش موافقة، ده تصحيح، ومكانه الموديل.
//
// «مش» و«أي» اتشالوا من القوايم عن قصد: «مش فاهم» مش رفض، و«أي حاجة» مش موافقة.
// طول ما الـregex القديم كان عاطل ماحدش خد باله إنهم غلط.

const WORD_END = String.raw`(?=$|[\s\p{P}\p{S}])`;
const YES_RE = new RegExp(
  String.raw`^\s*(?:أيوه|ايوه|أيوا|ايوا|أيوة|ايوة|أه|اه|آه|نعم|تم|تمام|ماشي|موافق|أكد|اكد|أكيد|اكيد|نفذ|نفّذ|اوك|أوك|أوكي|اوكي|صح|مظبوط|ok|okay|yes|yeah|yep|sure|confirm)` + WORD_END,
  "iu",
);
const NO_RE = new RegExp(
  String.raw`^\s*(?:لا|لأ|لاء|لاا|لع|إلغاء|الغاء|الغي|ألغي|رفض|ارفض|غلط|استنى|استني|بعدين|no|nope|cancel|stop|wait|later)` + WORD_END,
  "iu",
);

/** أقصى عدد كلمات لرسالة تتحسب «أيوه/لا». أطول من كده = كلام فيه معلومة، يروح للموديل. */
const MAX_YES_NO_WORDS = 4;

export function parseYesNoReply(text: string): "yes" | "no" | null {
  const t = text.trim();
  if (!t || t.split(/\s+/).length > MAX_YES_NO_WORDS) return null;
  if (NO_RE.test(t)) return "no";
  if (YES_RE.test(t)) return "yes";
  return null;
}

// «أخدته» / «مخدتش» صريحة عن الجرعة — بتتقرا حتى لو الرسالة أطول شوية («خدت الدوا الحمدلله»).
// النفي بيتفحص الأول: «مخدتهاش» فيها «خدت».
const DOSE_SKIPPED_RE = /(?:^|\s)(?:م|ما\s*)(?:ا?خدت|أخدت|اخدت)(?:ه|ها|هم)?ش(?=$|[\s\p{P}])|(?:^|\s)نسيت(?:ه|ها|هم)?(?=$|[\s\p{P}])|مش\s+(?:هاخد|هخد|واخد|واخدها|واخده)/u;
const DOSE_TAKEN_RE = /(?:^|\s)(?:ا?خدت|أخدت|اخدت|خدت)(?:ه|ها|هم|و)?(?=$|[\s\p{P}])|(?:^|\s)(?:ا?خدناه|شربته|شربتها)(?=$|[\s\p{P}])/u;

export function parseDoseReply(text: string): "taken" | "skipped" | null {
  const t = text.trim();
  if (!t || t.split(/\s+/).length > 8) return null;
  if (DOSE_SKIPPED_RE.test(t)) return "skipped";
  if (DOSE_TAKEN_RE.test(t)) return "taken";
  return null;
}

/** اللحظات اللي بتاخد أزرار الجرعة. `dose_nudge` مكتوبة بس بس برضه محتاجة الزرار. */
export const DOSE_MOMENTS: ReadonlySet<string> = new Set([
  "dose_due", "dose_nudge", "dose_missed", "dose_missed_again",
]);

/**
 * خانة كل دوا في تذكير الجرعة. تذكير المجموعة (20260926120000) بيحمل `facts.slots`
 * — دوائين بينهم نص ساعة في رسالة واحدة، وكل واحد لازم يتسجّل في خانته هو عشان
 * الفهرس الفريد (user_id, item_id, scheduled_at) ومولّد التذكيرات يشوفوه متجاوب عليه.
 * التذكير القديم مافيهوش slots، فكل الأدوية بتاخد `fallback` (facts.scheduled_at).
 */
export function doseSlots(facts: Record<string, unknown> | null | undefined, fallback: string): (itemId: string) => string {
  const map = new Map<string, string>();
  const slots = Array.isArray(facts?.slots) ? facts!.slots as unknown[] : [];
  for (const s of slots) {
    const o = s as { item_id?: unknown; scheduled_at?: unknown } | null;
    if (typeof o?.item_id === "string" && typeof o?.scheduled_at === "string") map.set(o.item_id, o.scheduled_at);
  }
  return (itemId) => map.get(itemId) ?? fallback;
}
