// Pure helpers — no grammY, no Supabase, no network. Framework-agnostic on purpose so
// they stay testable without spinning up a Bot instance (grammY's Bot needs a live
// token to construct in some code paths); index.ts is the only place that touches
// grammY or Supabase.

// تسوية الجرعة اتنقلت لباب واحد (ZAD_PLAN ٣.٤): العقل بيكتب، والبوت بيعرض.
import { type HabitTrial, habitTrialLabels, habitTrialStage, habitTrialText } from "../_shared/habitTrial.ts";
import { DOSE_SNOOZE_MINUTES, type DoseAction } from "../_shared/doseDoor.ts";
export { DOSE_SNOOZE_MINUTES, type DoseAction, doseAlreadyReply, doseSlots } from "../_shared/doseDoor.ts";

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

/** كود العيلة («ZAD-» + ١٠، `family_groups.invite_code`) — مش كود ربط تليجرام. مختبِرة بعتته
 * للبوت ٣١/١٠ وردّه كان «الكود ده غلط أو منتهي» من غير ما يقول الكود ده بيتحط فين. */
export function isFamilyInviteCode(text: string | undefined): boolean {
  return /^ZAD-[A-Z0-9]{6,}$/i.test((text ?? "").trim());
}

export const FAMILY_CODE_REPLY =
  "ده كود العيلة، مش كود ربط تليجرام 🙂 ادخله في تطبيق زاد من «العيلة» ← «انضم بكود». " +
  "وعشان تربط تليجرام: افتح الرئيسية في التطبيق ودوس «ربط بوت تليجرام»، وهيرجعك هنا مربوط على طول.";

/** كود الربط نفسه مبعوت كرسالة عادية من غير «/start» (٨ حروف من أبجدية التطبيق،
 * `TelegramLinkRemote._codeChars`). */
export function looksLikeLinkCode(text: string | undefined): boolean {
  return /^[A-HJ-NP-Z2-9]{8}$/i.test((text ?? "").trim());
}

/** What `zad_redeem_telegram_code` answered (20261010120000). A fresh code moves the chat to
 * the account that made it — the code is the proof — so "already bound to another user" is no
 * longer a refusal. `null` = the call itself failed. */
export type BindingStatus = "bound" | "moved" | "already_bound" | "invalid";

export function bindingReply(status: BindingStatus | null): string {
  switch (status) {
    case "bound": return "تم الربط بنجاح ✅ اختار من تحت:";
    case "moved": return "تم ✅ الشات ده بقى على حسابك الجديد، والحساب القديم مابقاش مربوط بيه. اختار من تحت:";
    case "already_bound": return "الشات ده مربوط بالحساب ده بالفعل ✅ اختار من تحت:";
    case "invalid": return "الكود ده غلط أو منتهي — افتح تطبيق زاد واعمل كود ربط جديد.";
    default: return "الربط ماكملش من عندنا — جرّب تاني بعد دقيقة.";
  }
}

export function unlinkReply(status: "unlinked" | "not_bound" | null): string {
  switch (status) {
    case "unlinked": return "تم فك الربط ✅ مش هبعتلك حاجة من الحساب ده تاني. لو عايز تربط حساب، اعمل كود من تطبيق زاد وابعته: /start الكود";
    case "not_bound": return "الشات ده مش مربوط بأي حساب أصلاً.";
    default: return "فك الربط ماكملش من عندنا — جرّب تاني بعد دقيقة.";
  }
}

/** `ZAD_ADMIN_CHAT_ID` — the private chat (a group or channel the bot is in) that system
 * health alerts go to, never a customer's chat (2026-10-10: «العقل ساكت» reached the owner's
 * own customer chat because alerts went to each admin's Telegram binding). A group's id is
 * negative. Anything that is not a whole number = no admin chat. */
export function adminChatId(raw: string | undefined | null): number | null {
  const trimmed = (raw ?? "").trim();
  if (!/^-?\d{1,20}$/.test(trimmed)) return null;
  const id = Number(trimmed);
  return Number.isSafeInteger(id) && id !== 0 ? id : null;
}

/** «📍 افتح على الخريطة» تحت رسالة المحل. بيقبل بس الشكل اللي zad-brain بيبنيه
 * (storeMapUrl) — أي رابط تاني مايتحطش زرار، حتى لو جاي من مسار محمي بسر. */
export function mapButtonRow(url: unknown): InlineKeyboardButton[] | null {
  if (typeof url !== "string") return null;
  if (!/^https:\/\/www\.google\.com\/maps\/search\/\?api=1&query=-?\d{1,3}\.\d{1,7},-?\d{1,3}\.\d{1,7}$/.test(url)) return null;
  return [{ text: "📍 افتح على الخريطة", url }];
}

/**
 * «🛒 حليب على أمازون» — زرار لكل صنف خلص (zad-brain/restockLink.ts). اللينك بيوصل من
 * realtime_push، فبيتقبل بس لو لينك https لمتجر أمازون؛ ٣ بالكتير.
 */
export function amazonButtonRows(links: unknown): InlineKeyboardButton[][] {
  if (!Array.isArray(links)) return [];
  const rows: InlineKeyboardButton[][] = [];
  for (const l of links) {
    const name = typeof l?.name === "string" ? l.name.trim().slice(0, 40) : "";
    const url = typeof l?.url === "string" ? l.url : "";
    if (!name || url.length > 1000 || !/^https:\/\/www\.amazon\.(eg|sa|ae|com\.tr|com)\/[^\s]*$/.test(url)) continue;
    rows.push([{ text: `🛒 ${name} على أمازون`, url }]);
    if (rows.length >= 3) break;
  }
  return rows;
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

/** "x:<uuid>" (confirm) / "c:<uuid>" (cancel) / "xa:<uuid>" (confirm — «دي عملية تانية»، allow_duplicate) */
export function parseSpendCallback(data: string): { action: "confirm" | "cancel" | "again"; pendingId: string } | null {
  const parts = data.split(":");
  if (parts.length !== 2) return null;
  if (parts[0] !== "x" && parts[0] !== "c" && parts[0] !== "xa") return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { action: parts[0] === "x" ? "confirm" : parts[0] === "xa" ? "again" : "cancel", pendingId: parts[1] };
}

/**
 * العقل رفض التسجيل بعد «أكد» — الرد للعميل بسببه، مش «جرب تاني» (حساب المالك ١/١١: ٣ ضغطات على «أكد» للإيجار
 * ورسالة واحدة «التسجيل فشل»، والسبب إن مصروف بنفس المبلغ اتسجل من دقايق). نص الرفض مكتوب للموديل
 * («اسأل العميل… allow_duplicate=true»)، فبيتحوّل هنا لكلام وزرارين لو هو تكرار، وأول جملة بس لو حاجة تانية.
 */
export function refusedSpendReply(summary: string | undefined, pendingId: string): { text: string; keyboard?: InlineKeyboardButton[][] } {
  const s = String(summary ?? "");
  const dup = s.match(/بنفس المبلغ \(([^)]+)\) اتسجّل من (\d+) دقيقة باسم "([^"]*)"/);
  if (dup) {
    return {
      text: `فيه مصروف بنفس المبلغ (${dup[1]}) اتسجّل من ${dup[2]} دقيقة باسم «${dup[3]}». دي عملية تانية ولا نفس اللي فاتت؟`,
      keyboard: [[
        { text: "➕ دي عملية تانية", callback_data: `xa:${pendingId}` },
        { text: "✖️ نفس اللي فاتت", callback_data: `c:${pendingId}` },
      ]],
    };
  }
  const reason = s.replace(/^مرفوض:\s*/, "").split(/(?<=[.!؟?])\s/)[0]?.trim();
  return { text: reason && s.startsWith("مرفوض") ? `ماسجلتهاش: ${reason}` : "معلش، التسجيل فشل — جرب تاني." };
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
/**
 * «فاضل قد إيه؟» (ZAD_PLAN ٣.٩): الإجابة قراية حقيقية مش «موجود» بس. «لسه موجود» كانت بتسجّل نفس
 * الكمية اللي اتسأل عليها، فالمعدّل مابيتعلمش منها حاجة. كل زرار نسبة من آخر شرا، والسيرفر بيحسب
 * الكمية (update_inventory_qty.fraction_left). «y» فاضل بيتقرا للرسايل القديمة اللي لسه مفتوحة.
 */
export const CHECKIN_LEVELS = {
  t: { label: "كتير", fraction: 0.75 },
  h: { label: "نصه", fraction: 0.5 },
  l: { label: "قليل", fraction: 0.2 },
  n: { label: "خلص", fraction: 0 },
} as const;
type CheckinLevel = keyof typeof CHECKIN_LEVELS;
const LEVEL_ORDER: CheckinLevel[] = ["t", "h", "l", "n"];

export function checkInKeyboard(promptId: string): InlineKeyboardButton[][] {
  return [LEVEL_ORDER.map((k) => ({
    text: k === "n" ? `❌ ${CHECKIN_LEVELS[k].label}` : CHECKIN_LEVELS[k].label,
    callback_data: `ck:${promptId}:${k}`,
  }))];
}

/** "ck:<uuid>:t|h|l|n|y" callback_data. [fraction] null = «لسه موجود» القديمة (الكمية زي ما هي). */
export function parseCheckInCallback(
  data: string,
): { promptId: string; stillInStock: boolean; fraction: number | null; label: string | null } | null {
  const parts = data.split(":");
  if (parts.length !== 3 || parts[0] !== "ck") return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  if (parts[2] === "y") return { promptId: parts[1], stillInStock: true, fraction: null, label: null };
  if (!(parts[2] in CHECKIN_LEVELS)) return null;
  const level = CHECKIN_LEVELS[parts[2] as CheckinLevel];
  return { promptId: parts[1], stillInStock: level.fraction > 0, fraction: level.fraction, label: level.label };
}

/** [unit] من صف المخزون — السؤال بالوحدة («كام كيلو») عشان العميل يقدر يكتب رقم بدل الزرار. */
export function checkInPromptMessage(itemName: string, unit?: string | null): string {
  const u = (unit ?? "").trim();
  const hint = u ? `«فاضل ٢ ${u}»` : "«فاضل ٢»";
  return `تذكير سريع: فاضل قد إيه من ${itemName}؟\nاختار، أو اكتبلي الكمية زي ${hint}.`;
}

/**
 * أكتر من صنف في نفس الليلة = رسالة واحدة بصف زراير لكل صنف (منسّق المبادرات، ٢٠٢٦-١٠-١٨).
 * كانت رسالتين ورا بعض كل يوم الساعة ٩ — المقاس على ١٤ يوم. كل زرار لسه شايل id السؤال بتاعه،
 * فالرد بيتعامل زي الأول بالظبط. [items] أساميهم متنضفة ومعزولة من المنادي.
 */
export function checkInBundleMessage(items: string[], ignoredNote = false): string {
  const list = items.map((i) => `• ${i}`).join("\n");
  return ignoredNote
    ? `${CHECKIN_IGNORED_NOTE}\n${list}`
    : `تذكير سريع: فاضل قد إيه من الحاجات دي؟\n${list}`;
}

/**
 * سؤال المخزون الاحتياطي بيلف كل نص ساعة بالليل (:٢٠ و:٥٠، 20261024213500). لفات :٢٠ بس (قبل
 * الدقيقة ٤٥ UTC) بتأجّل العميل اللي وصله حاجة لسه — لفة :٥٠ اللي بعدها بتسأل.
 */
export function deferForRecentOutbound(now: Date): boolean {
  return now.getUTCMinutes() < 45;
}

// ── زاد بيلاحظ اللي اتساب (طلب المالك ٢٠٢٦-١٠-١٨: «لو تجاهلوه يرد يقولهم مبتردش ليه») ──────────
// المقاس آخر ٣٠ يوم: المالك ساب ٢٥ من ٥٦ سؤال مخزون (٤٤٪) لحد ما انتهوا، وعميل تاني ماردّش ولا مرة
// على ٦ — وزاد فضل يسأل كل ليلة بنفس الكلام.

/** كام سؤال ورا بعض اتساب لحد ما انتهى، من الأحدث. اللي لسه مستني مابيتعدّش ولا بيقطع. */
export function ignoredCheckinStreak(statusesNewestFirst: readonly string[]): number {
  let n = 0;
  for (const s of statusesNewestFirst) {
    if (s === "pending") continue;
    if (s !== "expired") break;
    n++;
  }
  return n;
}

export type CheckinPlan = "ask" | "ask_with_note" | "rest";

/** أيام الراحة بعد ما السؤال اتساب ٤ مرات ورا بعض حتى بعد ما زاد قال إنه واخد باله. */
export const CHECKIN_REST_DAYS = 14;

/**
 * مرتين ورا بعض من غير رد ⇒ زاد بيقول إنه واخد باله ويعرض يبطّل. ٤ ⇒ بيسكت أسبوعين من نفسه
 * (السكوت عن «بطّل» برضه رد)، وبعدها يرجع يسأل بنفس الجملة.
 */
export function checkinPlan(streak: number, lastSentAtMs: number | null, nowMs: number): CheckinPlan {
  if (streak < 2) return "ask";
  if (streak < 4) return "ask_with_note";
  const rested = lastSentAtMs === null || nowMs - lastSentAtMs >= CHECKIN_REST_DAYS * 86_400_000;
  return rested ? "ask_with_note" : "rest";
}

export const CHECKIN_IGNORED_NOTE =
  "بقالي كام ليلة بسألك عن المخزون ومش بترد 😅 لو السؤال ده مش فارق معاك دوس «بطّل» وهسكت عنه. ولو لسه عايزه:";

/** "ckoff" — العميل قال بطّل سؤال المخزون. */
export const CHECKIN_OFF_CALLBACK = "ckoff";

export function checkInBundleKeyboard(prompts: Array<{ id: string; label: string }>, offerStop = false): InlineKeyboardButton[][] {
  const rows = prompts.map((p) => {
    const label = [...p.label].length > 10 ? [...p.label].slice(0, 9).join("") + "…" : p.label;
    // الصف بيبدأ باسم الصنف عشان كل صف يبان لأنهي حاجة.
    return LEVEL_ORDER.map((k, i) => ({
      text: i === 0 ? `${label}: ${CHECKIN_LEVELS[k].label}` : CHECKIN_LEVELS[k].label,
      callback_data: `ck:${p.id}:${k}`,
    }));
  });
  return offerStop ? [...rows, [{ text: "🔕 بطّل تسألني", callback_data: CHECKIN_OFF_CALLBACK }]] : rows;
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

// ── «اقفل يومك» (20261019140000) ───────────────────────────────────────────
//
// رسالة الليل من zad-brain (لحظة close_day) بأزرارها. أي زرار = اليوم اتقفل
// (`zad_close_day_service`، اليوم من اللحظة نفسها) ونقط للرفيق مرة في اليوم. الزرارين
// التانيين مابيكتبوش فلوس: بيطلبوا المصروف بالكلام، وده بيعدّي على لفة الوكيل وتأكيدها.
//
// الطول: "cd:" + uuid(36) + ":" + حرف = ٤١ بايت، تحت سقف تليجرام (٦٤).

/** نفس الاسم في zad-brain/voiceMoments.ts — الفانكشنين منفصلتين في النشر. */
export const CLOSE_DAY_MOMENT = "close_day";

export type CloseDayOutcome = "all_good" | "cash" | "missing";

export function closeDayKeyboard(momentId: string): InlineKeyboardButton[][] {
  return [
    [{ text: "✅ تمام كده", callback_data: `cd:${momentId}:o` }],
    [
      { text: "💵 صرفت كاش", callback_data: `cd:${momentId}:c` },
      { text: "➕ في حاجة ناقصة", callback_data: `cd:${momentId}:m` },
    ],
  ];
}

/**
 * رسالة الليل الواحدة (ZAD_PLAN ١.٥): «اقفل يومك» وتحتها أسئلة المخزون لو فيه. [questions] من
 * checkInBundleMessage — أزرارها بتتحط تحت أزرار القفلة، وكل زرار شايل id سؤاله زي الأول.
 */
export function nightMessage(closeDay: string, questions: string | null): string {
  return questions ? `${closeDay}\n\n${questions}` : closeDay;
}

// ── «ده المرتب؟» (20261025001500، ZAD_PLAN ٢.٤) ─────────────────────────────
// "sal:" + uuid(36) + ":" + حرف = ٤٢ بايت.

export function salaryKeyboard(momentId: string): InlineKeyboardButton[][] {
  return [[
    { text: "✅ أيوه، ابدأ الدورة من النهارده", callback_data: `sal:${momentId}:y` },
    { text: "لأ، مش المرتب", callback_data: `sal:${momentId}:n` },
  ]];
}

export function parseSalaryCallback(data: string): { momentId: string; yes: boolean } | null {
  const parts = data.split(":");
  if (parts.length !== 3 || parts[0] !== "sal" || (parts[2] !== "y" && parts[2] !== "n")) return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { momentId: parts[1], yes: parts[2] === "y" };
}

// عرض الصبح (ZAD_PLAN ٤.٢٠): "dl:" + uuid(36) + ":" + حرف = ٤١ بايت.

export function dealKeyboard(momentId: string): InlineKeyboardButton[][] {
  return [[
    { text: "🛒 ضيفه لقايمتي", callback_data: `dl:${momentId}:a` },
    { text: "🙅 مش مهتم", callback_data: `dl:${momentId}:n` },
  ], [
    { text: "⚠️ العرض ده غلط", callback_data: `dl:${momentId}:w` },
  ]];
}

/** The deal's own source as the morning greeting stored it (facts.taste_deal.source). */
export type DealSource = { kind?: unknown; url?: unknown } | null | undefined;

const DEAL_LINK_TEXT: Record<string, string> = {
  youtube: "▶️ الفيديو",
  instagram: "📸 البوست",
  flyer: "📰 النشرة",
  partner: "🔗 رابط الشراكة",
};

/**
 * ZAD_PLAN 4.20: the deal's link as a button under the morning greeting — the post, the video, the flyer or the shop's
 * page. https only; a receipt deal (bills from homes nearby) has no link and gets no button.
 */
export function dealSourceRow(source: DealSource): InlineKeyboardButton[] | null {
  const url = typeof source?.url === "string" ? source.url.trim() : "";
  if (!/^https:\/\/[^\s]{4,500}$/.test(url)) return null;
  const kind = typeof source?.kind === "string" ? source.kind : "";
  return [{ text: DEAL_LINK_TEXT[kind] ?? "🔗 صفحة العرض", url }];
}

/**
 * ZAD_PLAN 4.20: a picture for the deal. A YouTube deal shows its video's thumbnail (public, by the video's id), and a
 * flyer deal the flyer itself — only from Zad's own bucket ([flyerPrefix]). An Instagram post's picture is never stored,
 * so its link button carries it instead.
 */
export function dealPhotoUrl(source: DealSource, flyerPrefix = ""): string | null {
  if (source?.kind === "flyer" && typeof source.url === "string" && flyerPrefix && source.url.startsWith(flyerPrefix) &&
    /^https:\/\/[^\s]{4,500}$/.test(source.url)) {
    return source.url;
  }
  if (source?.kind !== "youtube" || typeof source.url !== "string") return null;
  const id = /^https:\/\/www\.youtube\.com\/watch\?v=([\w-]{6,20})$/.exec(source.url.trim())?.[1];
  return id ? `https://i.ytimg.com/vi/${id}/hqdefault.jpg` : null;
}

/** `wrong` = «العرض ده غلط» (ZAD_PLAN ٤.١٩): بلاغ بيدخل قياس الدقة، مش جواب «ضيفه/مش مهتم». */
export function parseDealCallback(data: string): { momentId: string; add: boolean; wrong: boolean } | null {
  const parts = data.split(":");
  if (parts.length !== 3 || parts[0] !== "dl" || !["a", "n", "w"].includes(parts[2])) return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { momentId: parts[1], add: parts[2] === "a", wrong: parts[2] === "w" };
}

/** الرد بعد zad_deal_answer_service. `null` = الكتابة فشلت — يتقال صراحةً. */
export function dealReply(result: { ok?: boolean; already?: boolean; answer?: string; item?: string; already_listed?: boolean } | null): string {
  if (!result) return "معلش، ماقدرتش أسجّل ده دلوقتي — جرّب تاني بعد شوية.";
  if (!result.ok) return "العرض ده مابقاش موجود.";
  const item = result.item ?? "الصنف";
  if (result.already) return result.answer === "add" ? `«${item}» في قايمتك بالفعل ✅` : "تمام، اتسجّل قبل كده.";
  if (result.answer === "wrong") return `شكراً إنك قلت 🙏 مش هعرض «${item}» ده تاني، والبلاغ بيدخل في مراجعة العروض.`;
  if (result.answer === "add") return result.already_listed ? `«${item}» كان في قايمتك أصلاً ✅` : `تمام ✅ ضفت «${item}» لقايمتك.`;
  return `تمام، مش هعرض عليك «${item}» تاني الشهر ده.`;
}

// «اتعلمت إن» (ZAD_PLAN ٥.٢): "hl:" + uuid(36) + ":" + حرف = ٤١ بايت. الجواب بيقيس بوابة المرحلة ٥.

export function learningKeyboard(learningId: string): InlineKeyboardButton[][] {
  return [[
    { text: "✅ صح", callback_data: `hl:${learningId}:y` },
    { text: "❌ مش صح", callback_data: `hl:${learningId}:n` },
  ]];
}

export function parseLearningCallback(data: string): { learningId: string; yes: boolean } | null {
  const parts = data.split(":");
  if (parts.length !== 3 || parts[0] !== "hl" || (parts[2] !== "y" && parts[2] !== "n")) return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { learningId: parts[1], yes: parts[2] === "y" };
}

/** الرد بعد zad_house_learning_answer_service. `null` = الكتابة فشلت — يتقال صراحةً. */
export function learningReply(result: { ok?: boolean; already?: boolean; answer?: string } | null): string {
  if (!result) return "معلش، ماقدرتش أسجّل ردك دلوقتي — جرّب تاني بعد شوية.";
  if (!result.ok) return "الملاحظة دي مابقتش موجودة.";
  if (result.already) return "تمام، ردك اتسجّل قبل كده.";
  return result.answer === "yes" ? "تمام ✅ هفتكرها." : "تمام، شكراً إنك صحّحتني — مش هقولها تاني.";
}

// مراجعة الذاكرة الشهرية (ZAD_PLAN ٥.٣): "mc:" + uuid(36) + ":" + حرف = ٤١ بايت. كل ملاحظة سطر برقمها وزرارين.

const ARABIC_DIGITS = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"];
const arabicNumber = (n: number) => String(n).replace(/\d/g, (d) => ARABIC_DIGITS[Number(d)]);

export interface MemoryCheck { id: string; note: string; position: number }

/** الملاحظات مترقّمة تحت رسالة الموديل، وكل واحدة بزرارينها بنفس الرقم. */
export function memoryCheckBlock(checks: readonly MemoryCheck[]): { text: string; rows: InlineKeyboardButton[][] } {
  const sorted = [...checks].sort((a, b) => a.position - b.position);
  return {
    text: sorted.map((c) => `${arabicNumber(c.position)}) ${c.note}`).join("\n"),
    rows: sorted.map((c) => [
      { text: `✅ ${arabicNumber(c.position)} صح`, callback_data: `mc:${c.id}:y` },
      { text: `❌ ${arabicNumber(c.position)} مش صح`, callback_data: `mc:${c.id}:n` },
    ]),
  };
}

export function parseMemoryCheckCallback(data: string): { checkId: string; yes: boolean } | null {
  const parts = data.split(":");
  if (parts.length !== 3 || parts[0] !== "mc" || (parts[2] !== "y" && parts[2] !== "n")) return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { checkId: parts[1], yes: parts[2] === "y" };
}

/** الرد بعد zad_memory_check_answer_service. `null` = الكتابة فشلت — يتقال صراحةً. */
export function memoryCheckReply(result: { ok?: boolean; already?: boolean; answer?: string; position?: number } | null): string {
  if (!result) return "معلش، ماقدرتش أسجّل ردك دلوقتي — جرّب تاني بعد شوية.";
  if (!result.ok) return "الملاحظة دي مابقتش موجودة.";
  const n = typeof result.position === "number" ? ` (${arabicNumber(result.position)})` : "";
  if (result.already) return `ردك على دي${n} اتسجّل قبل كده.`;
  return result.answer === "yes" ? `تمام ✅ هفضل فاكرها${n}.` : `تمام، شلتها${n} — شكراً إنك صحّحتني.`;
}

export type { HabitTrial };

// حلقة المبادرة (ZAD_PLAN ٥.٤): "ht:" + uuid(36) + ":" + حرف = ٤١ بايت. نفس الزرارين بيبدأوا التجربة وبعدها بيثبّتوها،
// والمرحلة من الصف. الأرقام من الجدول، مش من الموديل.

/** سطور التجربة تحت رسالة الموديل وزرارينها؛ null لو المرحلة مافيهاش سؤال أو النوع مش معروف. */
export function habitTrialBlock(trial: HabitTrial): { text: string; rows: InlineKeyboardButton[][] } | null {
  const text = habitTrialText(trial);
  const stage = habitTrialStage(trial);
  if (!text || !stage) return null;
  const labels = habitTrialLabels(stage);
  return {
    text,
    rows: [[
      { text: labels.yes, callback_data: `ht:${trial.id}:y` },
      { text: labels.no, callback_data: `ht:${trial.id}:n` },
    ]],
  };
}

export function parseHabitTrialCallback(data: string): { trialId: string; yes: boolean } | null {
  const parts = data.split(":");
  if (parts.length !== 3 || parts[0] !== "ht" || (parts[2] !== "y" && parts[2] !== "n")) return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { trialId: parts[1], yes: parts[2] === "y" };
}

/** الرد بعد zad_habit_trial_answer_service. `null` = الكتابة فشلت — يتقال صراحةً. */
export function habitTrialReply(result: { ok?: boolean; already?: boolean; answer?: string } | null): string {
  if (!result) return "معلش، ماقدرتش أسجّل ردك دلوقتي — جرّب تاني بعد شوية.";
  if (!result.ok) return "التجربة دي مابقتش موجودة.";
  if (result.already) return "تمام، ردك اتسجّل قبل كده.";
  switch (result.answer) {
    case "start": return "يلا بينا ✅ التجربة بدأت النهارده لمدة أسبوعين، وبعدها هقولك النتيجة بالأرقام.";
    case "decline": return "تمام، مش هقترحها تاني الفترة دي.";
    case "keep": return "تمام ✅ ثبّتناها — هفتكرها وأبني عليها.";
    case "drop": return "تمام، بطّلناها. شكراً إنك جرّبت.";
    default: return "تمام.";
  }
}

/** الرد بعد zad_salary_cycle_service. `null` = الكتابة فشلت — يتقال صراحةً. */
export function salaryReply(result: { ok?: boolean; already?: boolean; answer?: string; day?: number } | null): string {
  if (!result) return "معلش، ماقدرتش أغيّر الدورة دلوقتي — جرّب تاني بعد شوية.";
  if (!result.ok) return "ماقدرتش ألاقي السؤال ده — غيّر يوم القبض من «ملفي» لو حابب.";
  if (result.answer === "yes") {
    return result.already ? `الدورة بتبدأ يوم ${result.day} بالفعل ✅` : `تمام ✅ الدورة بقت بتبدأ يوم ${result.day}، والميزانية بتتحسب من النهارده.`;
  }
  return "تمام، سايب الدورة زي ما هي.";
}

/** "cd:<uuid>:o" (تمام) / "cd:<uuid>:c" (كاش) / "cd:<uuid>:m" (ناقص) */
export function parseCloseDayCallback(data: string): { momentId: string; outcome: CloseDayOutcome } | null {
  const parts = data.split(":");
  if (parts.length !== 3 || parts[0] !== "cd") return null;
  const outcomes: Record<string, CloseDayOutcome> = { o: "all_good", c: "cash", m: "missing" };
  const outcome = outcomes[parts[2]];
  if (!outcome) return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { momentId: parts[1], outcome };
}

/** الرد بعد الـRPC. `null` = الكتابة فشلت — يتقال صراحةً. */
export function closeDayReply(
  outcome: CloseDayOutcome,
  result: { ok?: boolean; already?: boolean; xp?: number; reason?: string } | null,
): string {
  if (!result) return "معلش، ماقدرتش أقفل يومك دلوقتي — جرّب تاني بعد شوية.";
  if (!result.ok) {
    return result.reason === "stale"
      ? "الرسالة دي بتاعة يوم فات — هسألك تاني النهارده بالليل."
      : "ماقدرتش ألاقي اليوم ده — هسألك تاني النهارده بالليل.";
  }
  const xp = !result.already && (result.xp ?? 0) > 0 ? ` (+${result.xp} نقطة لرفيقك)` : "";
  if (outcome === "cash") return `تمام، يومك اتقفل${xp}. اكتبلي صرفت كام وفين، مثلاً: «صرفت ٥٠ كاش قهوة».`;
  if (outcome === "missing") return `تمام، يومك اتقفل${xp}. قولّي إيه اللي ناقص وبكام، وأنا أسجله بعد ما تأكد.`;
  return result.already ? "يومك متقفل خلاص ✅ تصبح على خير." : `يومك اتقفل ✅${xp} شكراً إنك خلّيتني أشوف كل حاجة.`;
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



/** أدوات بتجاوب سؤال «كان على إيه؟» (تصنيف أو تعديل المصروف). */
export function pendingQuestionAnswered(executedTools: readonly string[]): boolean {
  return executedTools.some((t) => t === "set_transaction_category" || t === "update_transaction");
}

// ── نشرات المحلات من شات الأدمن (طلب المالك ٣/١١: «كل العروض والنشرات على بوت تليجرام بالصور مش الجيميل») ──

/** بلاد أسواق زاد بالاسم أو بالكود، زي ما المالك ممكن يكتبها في كلام الصورة. */
const FLYER_COUNTRY_WORDS: Record<string, string> = {
  "السعوديه": "SA", "السعودية": "SA", "سعودي": "SA", "sa": "SA", "ksa": "SA",
  "مصر": "EG", "eg": "EG", "الامارات": "AE", "الإمارات": "AE", "ae": "AE", "uae": "AE",
  "الكويت": "KW", "kw": "KW", "قطر": "QA", "qa": "QA", "البحرين": "BH", "bh": "BH", "عمان": "OM", "عُمان": "OM", "om": "OM",
  "الاردن": "JO", "الأردن": "JO", "jo": "JO",
};

const FLYER_FILLER = new Set(["نشره", "نشرة", "نشرات", "عروض", "عرض", "flyer", "offers", "-", "—", ":"]);

/** «نشرة كيو السعودية» ⇒ المحل «كيو» والبلد SA. من غير اسم محل = null. */
export function parseFlyerCaption(caption: string | null | undefined): { store: string; country: string | null } | null {
  const words = String(caption ?? "").replace(/[«»"#]/g, " ").split(/\s+/).filter(Boolean);
  let country: string | null = null;
  const kept: string[] = [];
  for (const w of words) {
    const code = FLYER_COUNTRY_WORDS[w.toLowerCase()];
    if (code && !country) { country = code; continue; }
    if (FLYER_FILLER.has(w.toLowerCase())) continue;
    kept.push(w);
  }
  const store = kept.join(" ").trim().slice(0, 60);
  return store.length >= 2 ? { store, country } : null;
}

/** مفتاح اسم المحل: من غير «ال» ولا أشكال الألف والتاء المربوطة، زي zad_inventory_name_key. */
export function flyerStoreKey(name: string): string {
  return String(name ?? "").trim().toLowerCase().replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي")
    .split(/\s+/).filter(Boolean).map((w) => (w.startsWith("ال") && w.length > 2 ? w.slice(2) : w)).join(" ");
}

export type FlyerStoreRow = { country: string; store: string; currency: string };

/**
 * المحل والبلد والعملة من قايمة محلات العروض (zad_deal_seed_stores). محل في أكتر من بلد (نون) من غير بلد في الكلام =
 * «قولي البلد»؛ محل مش في القايمة بس البلد مكتوبة = بعملة البلد دي من القايمة.
 */
export function pickFlyerStore(
  rows: readonly FlyerStoreRow[], parsed: { store: string; country: string | null },
): FlyerStoreRow | { error: "ambiguous" | "unknown" } {
  const key = flyerStoreKey(parsed.store);
  const named = rows.filter((r) => flyerStoreKey(r.store) === key && (!parsed.country || r.country === parsed.country));
  if (named.length === 1) return named[0];
  if (named.length > 1) return { error: "ambiguous" };
  const inCountry = parsed.country ? rows.find((r) => r.country === parsed.country) : undefined;
  return inCountry ? { country: inCountry.country, store: parsed.store, currency: inCountry.currency } : { error: "unknown" };
}

/** عرض مقري من النشرة ⇒ zad_deal_put. ثقة ٠٫٧: نشرة المحل نفسه والمالك هو اللي بعتها. */
export function flyerDealPayload(
  target: FlyerStoreRow,
  deal: { item_name: string; price: number; price_before: number | null; valid_until: string | null },
  imageUrl: string,
): Record<string, unknown> {
  return {
    country: target.country, city: "", store: target.store, item_name: deal.item_name, price: deal.price,
    price_before: deal.price_before, currency: target.currency,
    deal_kind: deal.price_before !== null ? "discount" : "price", valid_until: deal.valid_until,
    source_kind: "flyer", source_url: imageUrl, confidence: 0.7,
  };
}

/** الرد على المالك بعد ما النشرة اتقرت. */
export function flyerReply(
  store: string,
  result: { read: boolean; put: number; refused: number; items: string[]; until: string | null },
): string {
  if (!result.read) return `معلش، ماقدرتش أقرا نشرة «${store}» دلوقتي — ابعتها تاني بعد شوية.`;
  if (result.put === 0) {
    return result.refused > 0
      ? `قريت ${result.refused} عرض من نشرة «${store}» بس ولا واحد اتسجّل (سعر أو تاريخ مش مقبول).`
      : `مالقيتش في الصورة دي عروض واضحة لـ«${store}» (صنف وسعره). جرّب صورة أوضح أو صفحة تانية من النشرة.`;
  }
  const shown = result.items.slice(0, 8).map((i) => `• ${i}`).join("\n");
  const more = result.items.length > 8 ? `\n… و${result.items.length - 8} كمان` : "";
  return `📰 نشرة «${store}»: سجّلت ${result.put} عرض${result.until ? ` لحد ${result.until}` : " (من غير تاريخ ⇒ ٧ أيام)"}:\n${shown}${more}` +
    (result.refused > 0 ? `\n(و${result.refused} اترفضوا)` : "") +
    "\n\nهتوصل العملاء اللي محتاجينها في تحية الصبح بصورة النشرة.";
}

/**
 * الصورة دي نشرة ولا فاتورة؟ شات الأدمن بس. ولو شات الأدمن مربوط بحساب عميل (المالك حط شاته هو)، فواتيره لازم
 * تفضل فواتير: النشرة ساعتها بس لما الكلام يبدأ بـ«نشرة» أو «عروض».
 */
export function isFlyerPhoto(chatId: number, adminChat: number | null, isCustomer: boolean, caption: string | null | undefined): boolean {
  if (adminChat === null || chatId !== adminChat) return false;
  return !isCustomer || /^\s*(نشر[هة]|نشرات|عروض)/.test(String(caption ?? ""));
}

// نصوص شات الأدمن: المالك بس بيشوفها، فمالهاش نسخ لهجات زي ردود العملاء (botDialect_test).

/** الصورة ماتحفظتش في zad-flyers. */
export const FLYER_SAVE_FAILED = "معلش، ماقدرتش أحفظ صورة النشرة — جرب تاني بعد شوية.";

/** «نشرة» من غير اسم محل: إزاي تتبعت. */
export const FLYER_HOW_TO = "ابعت صورة النشرة ومعاها اسم المحل في الكلام، زي: «كيو» أو «نشرة كارفور مصر». صفحة صفحة لو النشرة كذا صفحة.";
