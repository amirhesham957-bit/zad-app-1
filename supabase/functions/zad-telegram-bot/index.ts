// zad-telegram-bot — Phase B4 (PRODUCT_PLAN.md), built on grammY per explicit user
// instruction (2026-07-30). Read-only: view balance/recent transactions/pending
// insights, act on Task 28's dismiss-with-reason from a Telegram button, and — as of
// v2 — hold a real conversation. No writes beyond dismissal; the agent is explicitly
// told (context.ts rule 5) not to claim it logged anything, because it can't.
//
// v2 (conversational): free text goes to Zad itself — the same zad-brain agent turn the
// app uses (agentTurn). There is no second model path here any more: the read-only
// fallback that answered through zad-core-intelligence's `ai_text` with its own persona
// was removed on 2026-10-02 (تشخيص زاد ١.٢), and so was `ai_text`.
//
// Identity: EPIC_1_4.md's own warning — "a chat_id is never an identity". A user
// generates a one-time binding code in the app (telegram_bindings row, user_id set,
// chat_id null); this function only trusts a chat_id once it's bound to that exact
// code via /start <code>. Every subsequent request is authorized by chat_id → user_id
// through that table, never by anything the client claims about itself.
import { decideLifeEvent } from "../_shared/lifeEventDecide.ts";
import { secretMatches } from "../_shared/cronSecret.ts";
import { recentOutbound } from "../_shared/outbound.ts";
import { proactiveTurn, recordConversation, trimProactive } from "../_shared/conversationLog.ts";
import { nextRenewal } from "../_shared/nextRenewal.ts";
import { Bot, type Context, InlineKeyboard, webhookCallback } from "npm:grammy@1";
import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { mediaGate } from "./entitlement.ts";
import { routePhoto } from "./photoRoute.ts";
import { alertEmotion, alertSpeechText, geminiKeysFromEnv, pcmToMp3, synthesizeAlertPcm, wantsVoice, speechLimitForMoment } from "./voiceAlert.ts";
import { detectDialectFromText, voiceCountry } from "../_shared/dialect.ts";
import { type BotDialect, chatBotDialect, localizeBotText } from "./botDialect.ts";
import { countryKeyboard, COUNTRY_QUESTION, countrySavedReply, parseCountryCallback, shouldAskCountry } from "./countryAsk.ts";
import { COMMUNITY_MARKETS, type CheapestRow, formatCommunityPricesPost } from "./communityPrices.ts";
import { CHAT_VOICE_REPLIES_PER_DAY, CHAT_VOICE_REPLY_MOMENT, TELEGRAM_WELCOME_MOMENT, type VoiceEmotion, type ZadVoiceGender, zadVoiceGender } from "../_shared/zadVoice.ts";
import { voiceReplyEmotion } from "./voiceReply.ts";
import {
  parsePurchaseCallback, purchaseDoneLine, purchaseFromPending, purchaseKeyboard, purchaseLinesFromPhoto,
  purchasePreview, type PendingPurchase, type PurchaseLine, type PurchaseMode,
} from "./purchasePhoto.ts";
import {
  batchDoneMessage, batchMedicineKeyboard, batchMedicineMessage, captionPerson, parseBatchCallback, routedMemberName,
  splitPhotoMedicines,
} from "./pharmacyPhoto.ts";
import { familyMedicineCandidates } from "../_shared/familyMembers.ts";
import { amazonPicks, amazonPicksReply } from "./amazonPicks.ts";
import { householdFamilyId, householdFilter } from "../_shared/household.ts";
import { marketFor } from "../_shared/amazonMarket.ts";
import { checkInPriority } from "../_shared/consumptionRate.ts";
import { PURCHASE_SOURCES, purchaseDaysByItem, restockKey } from "../_shared/restockCycle.ts";
import { extendCallback, formatExtend, formatLookup, parseExtendCallback, parseSupportCommand, SUPPORT_TEXT, SUPPORT_USAGE } from "./supportDesk.ts";
import {
  adCreditKeyboard,
  InlineKeyboardButton, mainMenuKeyboard, dismissKeyboard,
  proactiveDismissKeyboard, parseProactiveDismissCallback, proactiveDismissReply,
  parseProactiveReplyCallback, PROACTIVE_MORE_PROMPT, PROACTIVE_OK_TURN,
  reasonForCode, parseDismissCallback, appLinkRedirect, petCallKeyboard, parsePetCareCallback, petCareReply, normalizeBindingCode, bindingReply, isFamilyInviteCode, looksLikeLinkCode, FAMILY_CODE_REPLY, adminChatId, mapButtonRow, amazonButtonRows, amazonLinkButtons, amazonOpenUrl, amazonAppRedirect, type BindingStatus, unlinkReply, memoryNoteForDismissal,
  formatBalanceMessage, type BudgetStateRow, formatTransactionsMessage, formatInsightTitle,
  confirmSpendKeyboard, parseSpendCallback, pendingQuestionAnswered, refusedSpendReply,
  transactionProposalKeyboard, parseTransactionProposalCallback,
  duplicateProposalKeyboard, duplicateProposalMessage,
  notificationReviewMessage,
  notificationReviewKeyboard,
  parseNotificationReviewCallback,
  confirmMedicationKeyboard, parseMedicationCallback,
  checkInKeyboard, parseCheckInCallback, parseCheckinTextReply, checkInPromptMessage, checkInBundleMessage, checkInBundleKeyboard, deferForRecentOutbound, ignoredCheckinStreak, checkinPlan, CHECKIN_OFF_CALLBACK,
  confirmToolKeyboard, parseToolCallback, pendingConfirmsBlock, planConfirmations,
  isHumanUpdate, type UpdateEnvelope,
  doseKeyboard, parseDoseCallback, DOSE_MOMENTS, type DoseAction,
  closeDayKeyboard, closeDayReply, parseCloseDayCallback, salaryKeyboard, parseSalaryCallback, salaryReply, nightMessage,
  dealKeyboard, dealPhotoUrl, dealSourceRow, parseDealCallback, dealReply, lifeEventKeyboard, lifeEventReply, parseLifeEventCallback,
  type DigestCard, type DigestCode, digestButtons, digestCaption, digestCodesMessage, digestHeader, digestPhoto,
  welcomeSpeech, isFlyerPhoto, parseFlyerCaption, pickFlyerStore, flyerDealPayload, flyerReply, FLYER_HOW_TO, FLYER_SAVE_FAILED, type FlyerStoreRow,
  learningKeyboard, parseLearningCallback, learningReply,
  memoryCheckBlock, parseMemoryCheckCallback, memoryCheckReply, type MemoryCheck,
  habitTrialBlock, parseHabitTrialCallback, habitTrialReply, type HabitTrial,
  parseAmountWrongCallback, parseDoseReply, parseYesNoReply, type TransactionProposalDecision, doseSlots,
} from "./telegram.ts";
import {
  clampForTelegram,
  confirmSpendMessage, deriveWebhookSecret, money, receiptWallet,
  isolate, sanitizeName,
} from "./context.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
// NOT `!`-asserted, deliberately. A missing token blew up at module load — new Bot("")
// throws — which the platform surfaces as an opaque WORKER_ERROR/500 on every request
// with nothing useful in the logs, so the function couldn't tell you what was wrong.
// It now boots regardless and the GET probe reports which config is actually present.
const BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const BOT_CONFIGURED = BOT_TOKEN.length > 0;
// Telegram's setWebhook secret_token, verified by grammY itself when passed to
// webhookCallback below. If unset we derive one from the bot token rather than leaving
// verification off entirely — see deriveWebhookSecret in context.ts.
const WEBHOOK_SECRET_ENV = Deno.env.get("TELEGRAM_WEBHOOK_SECRET") ?? undefined;

// Gates the daily check-in cron trigger (?job=daily_checkins) below. This endpoint has to
// live on zad-telegram-bot because Telegram's own webhook needs verify_jwt=false on this
// function, so the platform-level JWT check that gates every other function doesn't apply
// here — without this, anyone on the internet could POST ?job=daily_checkins and spam
// every bound user.
//
// ── 2026-09-05: moved from plain literals to project secrets (بند BE-03) ────────
// The original comment defended the literals with "there is no tool available in this
// environment to provision a new Supabase project secret remotely". That stopped being
// true, and the defence was thin anyway: a value in git is permanently valid to anyone
// who can read the history, and rotating it required a code deploy.
//
// Both halves of the rotation are now done, so there is no fallback left. The callers
// (three cron jobs and four SECURITY DEFINER trigger functions) read their value from
// Supabase Vault via public.zad_cron_secret() — see migration 20260905150000. The old
// literals no longer authenticate anywhere, which is the point: the values still sitting
// in git history are now inert.
//
// A missing secret is a hard 401 plus an error log. That is deliberate. During the
// changeover this function accepted the pre-rotation literal as well, because a hard
// switch there would have been a silent 401 across every check-in, subscription alert,
// Telegram push and the weekly parent digest — the same failure that left
// zad_parent_digests empty for two months (config.toml, بند 34.3). That window is closed
// and the dual-accept is gone; keeping it would mean the git-history values still worked.

/**
 * Compares a received header against the secret configured for this project.
 *
 * Returns false for a missing header rather than throwing, so an unauthenticated caller
 * gets the same 401 as a wrong one and learns nothing from the difference. An unset
 * secret is logged as an error and rejects, rather than failing open.
 */

function toGrammyKeyboard(rows: InlineKeyboardButton[][]): InlineKeyboard {
  const kb = new InlineKeyboard();
  for (const row of rows) {
    row.forEach((btn, i) => {
      // زر رابط مقابل زر callback. من غير الفرع ده، btn.url بيتجاهَل و
      // kb.text بتتنادى بـcallback_data = undefined فالزر بيطلع ميت.
      if (btn.url) kb.url(btn.text, btn.url);
      else kb.text(btn.text, btn.callback_data ?? "");
      if (i < row.length - 1) kb.row();
    });
    kb.row();
  }
  return kb;
}

async function resolveUserId(sb: SupabaseClient, chatId: number): Promise<string | null> {
  const { data } = await sb.from("telegram_bindings")
    .select("user_id")
    .eq("chat_id", chatId)
    .not("bound_at", "is", null)
    .maybeSingle();
  return (data as { user_id: string } | null)?.user_id ?? null;
}

/** «انت في أنهي بلد؟» — مرة واحدة لحساب من غير بلد (countryAsk.ts). مابيوقفش الرسالة:
 * السؤال بيتبعت والرد على كلام العميل بيكمل عادي. أي فشل هنا بيتسجل ومابيكسرش الرد. */
async function maybeAskCountry(sb: SupabaseClient, chatId: number, userId: string): Promise<void> {
  try {
    const [{ data: user }, { data: binding }] = await Promise.all([
      sb.from("zad_users").select("country").eq("id", userId).maybeSingle(),
      sb.from("telegram_bindings").select("id,country_asked_at").eq("chat_id", chatId).not("bound_at", "is", null).maybeSingle(),
    ]);
    const b = binding as { id: string; country_asked_at: string | null } | null;
    if (!b || !shouldAskCountry((user as { country?: string | null } | null)?.country, b.country_asked_at)) return;
    // العلامة الأول: رسالتين ورا بعض مايسألوش مرتين.
    const { data: claimed } = await sb.from("telegram_bindings")
      .update({ country_asked_at: new Date().toISOString() })
      .eq("id", b.id).is("country_asked_at", null).select("id");
    if (!claimed?.length) return;
    await sendTelegramMessage(chatId, COUNTRY_QUESTION, countryKeyboard());
  } catch (e) {
    console.error("country ask failed:", e);
  }
}

/** Reverse of resolveUserId — the realtime_push job only knows user_id (from a DB trigger
 * row), never chat_id. Returns null for an unbound user, which the caller treats as a
 * silent no-op (most users won't have Telegram linked at all). */
async function resolveChatId(sb: SupabaseClient, userId: string): Promise<number | null> {
  const { data, error } = await sb.from("telegram_bindings")
    .select("chat_id")
    .eq("user_id", userId)
    .not("bound_at", "is", null)
    .maybeSingle();
  if (error) throw new Error(`telegram binding lookup failed (${error.code ?? "unknown"})`);
  return (data as { chat_id: number } | null)?.chat_id ?? null;
}

/** «اتعلمت إن» اللي اتقال في مهمة [taskId] ولسه مااتجاوبش ⇐ «صح / مش صح». أي فشل = من غير أزرار. */
async function learningRowsForTask(sb: SupabaseClient, userId: string, taskId: string): Promise<InlineKeyboardButton[][]> {
  const { data, error } = await sb.from("zad_house_learnings")
    .select("id").eq("user_id", userId).eq("task_id", taskId).is("answer", null).maybeSingle();
  if (error) console.error("[house_learning] lookup failed:", error.message);
  const id = (data as { id: string } | null)?.id;
  return id ? learningKeyboard(id) : [];
}

/** مراجعة الذاكرة (٥.٣) اللي اتسألت في مهمة [taskId] ولسه فيها سؤال مااتجاوبش. أي فشل = من غيرها. */
async function memoryChecksForTask(sb: SupabaseClient, userId: string, taskId: string): Promise<MemoryCheck[]> {
  const { data, error } = await sb.from("zad_memory_checks")
    .select("id,note,position").eq("user_id", userId).eq("task_id", taskId).is("answer", null);
  if (error) console.error("[memory_check] lookup failed:", error.message);
  return ((data ?? []) as MemoryCheck[]);
}

/** تجربة الأسبوعين (٥.٤) اللي اتقترحت أو اتقاست في مهمة [taskId] ولسه مستنية رد. أي فشل = من غيرها. */
async function habitTrialForTask(sb: SupabaseClient, userId: string, taskId: string): Promise<HabitTrial | null> {
  const { data, error } = await sb.from("zad_habit_trials")
    .select("id,kind,category,currency,status,baseline_weekly,result_weekly")
    .eq("user_id", userId)
    .or(`and(proposal_task_id.eq.${taskId},status.eq.proposed),and(result_task_id.eq.${taskId},status.eq.measured)`)
    .maybeSingle();
  if (error) console.error("[habit_trial] lookup failed:", error.message);
  return (data as HabitTrial | null) ?? null;
}

/** Direct Telegram API call, not a grammY ctx.reply — this fires OUTSIDE any inbound
 * webhook update (the cron job below has no ctx to reply through). */
/**
 * بيبعت سؤال "هل دي نفس المعاملة؟" لو الاقتراح متعلّم مكرر ولسه العميل ماردش عليه.
 * بيرجع false لو الاقتراح مش متعلّم (أو اتحسم، أو ماتقريش) — والنادي بيكمل بالرسالة
 * العادية. التوأم ممكن يكون اقتراح تاني (إشعار من تطبيق تاني) أو معاملة اتسجلت من الشات.
 */
async function sendDuplicateProposalQuestion(
  sb: SupabaseClient, chatId: number, userId: string, proposalId: string,
): Promise<boolean> {
  const { data, error } = await sb.from("zad_transaction_proposals")
    .select("id,status,amount,title,currency,duplicate_of_proposal_id,duplicate_of_transaction_id,duplicate_cleared_at")
    .eq("id", proposalId)
    .eq("user_id", userId)
    .maybeSingle();
  const row = data as {
    id: string; status: string; amount: number; title: string; currency: string | null;
    duplicate_of_proposal_id: string | null; duplicate_of_transaction_id: string | null;
    duplicate_cleared_at: string | null;
  } | null;
  if (error || !row) {
    if (error) console.error("duplicate proposal fetch failed:", error.message);
    return false;
  }
  if (row.status !== "needs_classification" && row.status !== "awaiting_confirmation") return false;
  if (row.duplicate_cleared_at || (!row.duplicate_of_proposal_id && !row.duplicate_of_transaction_id)) return false;

  let twinTitle: string | null = null;
  if (row.duplicate_of_proposal_id) {
    const { data: twin } = await sb.from("zad_transaction_proposals")
      .select("title").eq("id", row.duplicate_of_proposal_id).eq("user_id", userId).maybeSingle();
    twinTitle = (twin as { title?: string } | null)?.title ?? null;
  } else if (row.duplicate_of_transaction_id) {
    const { data: twin } = await sb.from("zad_transactions")
      .select("title").eq("id", row.duplicate_of_transaction_id).eq("user_id", userId).maybeSingle();
    twinTitle = (twin as { title?: string } | null)?.title ?? null;
  }

  const { data: u } = await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle();
  const cur = row.currency || (u as { currency?: string } | null)?.currency || "غير معروف";
  const text = duplicateProposalMessage({
    amountText: isolate(money(row.amount, cur)),
    title: isolate(sanitizeName(row.title)),
    twinTitle: twinTitle ? isolate(sanitizeName(twinTitle)) : null,
    twinSource: row.duplicate_of_proposal_id ? "notification" : "transaction",
  });
  await sendTelegramMessage(chatId, clampForTelegram(text), duplicateProposalKeyboard(row.id));
  return true;
}

/** A picture with its caption and buttons — one card of the season's deals message. */
async function sendTelegramPhotoCard(chatId: number, photo: string, caption: string, keyboard: InlineKeyboardButton[][]): Promise<void> {
  const response = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendPhoto`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId, photo, caption: caption.slice(0, 1000),
      ...(keyboard.length ? { reply_markup: { inline_keyboard: keyboard } } : {}),
    }),
  });
  const result = await response.json().catch(() => null) as { ok?: boolean } | null;
  if (!response.ok || result?.ok !== true) throw new Error(`Telegram sendPhoto failed (${response.status})`);
}

/** A picture by its public URL, ahead of the message it belongs to (ZAD_PLAN 4.20). */
async function sendTelegramPhoto(chatId: number, photo: string, caption: string): Promise<void> {
  const response = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendPhoto`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, photo, caption: caption.slice(0, 1000) }),
  });
  const result = await response.json().catch(() => null) as { ok?: boolean } | null;
  if (!response.ok || result?.ok !== true) throw new Error(`Telegram sendPhoto failed (${response.status})`);
}

async function sendTelegramMessage(chatId: number, text: string, keyboard?: InlineKeyboardButton[][]): Promise<void> {
  const response = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      ...(keyboard ? { reply_markup: { inline_keyboard: keyboard } } : {}),
    }),
  });
  const result = await response.json().catch(() => null) as { ok?: boolean } | null;
  if (!response.ok || result?.ok !== true) {
    throw new Error(`Telegram sendMessage failed (${response.status})`);
  }
}

/** فويس نوت (MP3) — تليجرام بيعرضه كرسالة صوتية مش ملف. */
async function sendTelegramVoice(chatId: number, mp3: Uint8Array<ArrayBuffer>): Promise<void> {
  const form = new FormData();
  form.append("chat_id", String(chatId));
  form.append("voice", new Blob([mp3], { type: "audio/mpeg" }), "zad-alert.mp3");
  const response = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendVoice`, { method: "POST", body: form });
  const result = await response.json().catch(() => null) as { ok?: boolean; description?: string } | null;
  if (!response.ok || result?.ok !== true) {
    throw new Error(`Telegram sendVoice failed (${response.status}): ${result?.description ?? ""}`);
  }
}

/** شغل بعد الرد: realtime_push بيتنادى من pg_net بمهلة ١٥ ثانية، والصوت (TTS + تحويل)
 *  ممكن ياخد أكتر. `EdgeRuntime.waitUntil` بيكمّل الشغل بعد ما الرد يتبعت؛ لو مش متاح
 *  (تست محلي) الشغل بيكمّل عادي من غير ما حد يستناه. */
declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void } | undefined;
function runInBackground(task: Promise<unknown>): void {
  const guarded = task.catch((e) => console.error("[background] task failed:", e));
  if (typeof EdgeRuntime !== "undefined" && EdgeRuntime?.waitUntil) EdgeRuntime.waitUntil(guarded);
}

/**
 * رد الشات بصوت زاد (الشريحة ١٣). النص اتبعت خلاص؛ ده زيادة ومايوقعش حاجة. شروطه: الرد يستاهل
 * (voiceReplyEmotion)، والعميل مشترك في وسائط تليجرام لو الرد على نص (الفويس الوارد اتحاسب في
 * mediaGate)، و٤ في آخر ٢٤ ساعة بالكتير. الصف بيتسجل قبل التوليد — العدّ مايتخطاش لو التوليد وقع.
 */
async function maybeVoiceReply(sb: SupabaseClient, userId: string, chatId: number, text: string, inboundVoice: boolean): Promise<void> {
  const emotion = voiceReplyEmotion({ text, inboundVoice, transactional: false });
  if (!emotion) return;
  if (!inboundVoice) {
    const { data: status, error } = await sb.rpc("zad_entitlement_status", { p_user: userId });
    if (error || (status as { telegram_media?: unknown } | null)?.telegram_media !== true) return;
  }
  const { count, error: countErr } = await sb.from("zad_voice_moments")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId).eq("moment", CHAT_VOICE_REPLY_MOMENT)
    .gte("created_at", new Date(Date.now() - 86_400_000).toISOString());
  if (countErr || (count ?? 0) >= CHAT_VOICE_REPLIES_PER_DAY) return;
  const { error: claimErr } = await sb.from("zad_voice_moments").insert({
    user_id: userId, moment: CHAT_VOICE_REPLY_MOMENT, facts: { emotion, inbound_voice: inboundVoice },
    dedupe_key: `voice_reply:${crypto.randomUUID()}`, status: "sent", sent_at: new Date().toISOString(),
  });
  if (claimErr) {
    console.error("[voiceReply] claim failed:", claimErr.message);
    return;
  }
  await deliverVoiceAlert(sb, userId, chatId, "", text, emotion);
}

/**
 * الترحيب الصوتي أول ربط (طلب المالك ٣/١١): مرة واحدة للحساب طول العمر. الصف بيتحجز قبل التوليد بمفتاح
 * `telegram_welcome` (فريد مع user_id)، فـ/start مرتين أو ربط تاني بعد فك الربط مابيرحّبش تاني. ببلاش — مش جوه
 * وسائط تليجرام المدفوعة: ده أول انطباع، مرة واحدة.
 */
async function sendLinkWelcome(sb: SupabaseClient, userId: string, chatId: number): Promise<void> {
  const [{ data: user }, { data: profile }] = await Promise.all([
    sb.from("zad_users").select("name,country,currency").eq("id", userId).maybeSingle(),
    sb.from("zad_customer_profile").select("preferred_name,dialect").eq("user_id", userId).maybeSingle(),
  ]);
  const u = user as { name?: string | null; country?: string | null; currency?: string | null } | null;
  const p = profile as { preferred_name?: string | null; dialect?: string | null } | null;
  const dialect = chatBotDialect({ preferred: p?.dialect, country: u?.country, currency: u?.currency });
  const speech = welcomeSpeech(p?.preferred_name || u?.name || null, dialect);
  const { error: claimErr } = await sb.from("zad_voice_moments").insert({
    user_id: userId, moment: TELEGRAM_WELCOME_MOMENT, facts: { dialect },
    dedupe_key: TELEGRAM_WELCOME_MOMENT, status: "sent", sent_at: new Date().toISOString(),
  });
  if (claimErr) {
    // 23505 = اترحّب بيه قبل كده. غير كده: من غير صف مافيش ترحيب، بدل ما يتكرر.
    if (claimErr.code !== "23505") console.error("[welcome] claim failed:", claimErr.message);
    return;
  }
  await deliverVoiceAlert(sb, userId, chatId, "", speech, "cheerful", speech, TELEGRAM_WELCOME_MOMENT);
}

async function deliverVoiceAlert(
  sb: SupabaseClient,
  userId: string,
  chatId: number,
  title: string,
  body: string,
  emotion: VoiceEmotion,
  speech?: string,
  moment?: unknown,
): Promise<void> {
  // لهجة الحساب نفسه — نفس مصدر المكالمة الحية وقراءة الإشعارات.
  let country: string | null = null;
  try {
    const { data } = await sb.from("zad_users").select("country").eq("id", userId).maybeSingle();
    country = (data as { country?: string | null } | null)?.country ?? null;
  } catch (_e) { /* من غير لهجة */ }
  // صوت زاد اللي العميل اختاره في «ملفي» — نفس الصوت اللي بيسمعه في التطبيق. فشل القراءة = بنت.
  let voice: ZadVoiceGender = "female";
  try {
    const { data } = await sb.from("zad_customer_profile").select("zad_voice,dialect").eq("user_id", userId).maybeSingle();
    const vp = data as { zad_voice?: string | null; dialect?: string | null } | null;
    voice = zadVoiceGender(vp?.zad_voice);
    // لهجة «ملفي» بتكسب على بلد الحساب في لكنة الفويس، زي التطبيق (ZAD_PLAN ١٠.١٦).
    country = voiceCountry(country, vp?.dialect);
  } catch (_e) { /* الافتراضي */ }
  const text = speech?.trim() ? alertSpeechText("", speech, speechLimitForMoment(moment)) : alertSpeechText(title, body);
  const pcm = await synthesizeAlertPcm(text, geminiKeysFromEnv(), fetch, { emotion, country, voice });
  if (!pcm) return; // السبب اتسجّل جوه synthesizeAlertPcm — النص وصل خلاص.
  await sendTelegramVoice(chatId, pcmToMp3(pcm));
  console.log(`[voiceAlert] delivered ${pcm.byteLength} bytes PCM as voice note`);
}

/** Server-side low-stock detection against zad_inventory + zad_consumption (Task 18's
 * learning loop) — deliberately NOT a port of ConsumptionLearner's on-device
 * SharedPreferences model, which never leaves the Android client. "Needs a check-in" here
 * means (checkInPriority, 2026-11-11): with a consumption rate, known or approximate from
 * one cycle (20260930000000), predicted to run out within 2 days; without one, its purchase
 * cycle in this home (_shared/restockCycle.ts, the same the behaviour profile and the nightly
 * shopping list use) has mostly passed since it was last bought. The old no-rate rule, quantity <= threshold, asked about a single jar of halva
 * every night and never about milk. The most pressing come first under the daily cap. The
 * live SQL trigger (_inventory_needs_checkin) still uses the threshold. Items with an
 * already-pending prompt are excluded (the unique index on telegram_checkin_prompts is the
 * hard guarantee; this filter just avoids the wasted query/round-trip).
 */
async function findCheckInCandidates(sb: SupabaseClient, userId: string): Promise<Array<{ item_name: string; quantity: number; unit: string | null }>> {
  const [{ data: inv }, { data: cons }, { data: pending }, { data: occasional, error: occErr }, { data: seen }, { data: priors, error: priorErr }] = await Promise.all([
    sb.from("zad_inventory").select("item_name,quantity,category,unit,created_at,restock_mode,restock_cycle_days").eq("user_id", userId),
    sb.from("zad_consumption").select("item_name,avg_daily_qty,rate_known").eq("user_id", userId),
    sb.from("telegram_checkin_prompts").select("item_name").eq("user_id", userId).eq("status", "pending"),
    // حاجات على فترات مابتتسألش «لسه عندك؟» (ZAD_PLAN ٣.١٠).
    sb.rpc("zad_occasional_items", { p_user: userId }),
    // أيام شرا كل صنف: منها دورته في البيت ده (restockCycle.ts)، زي الملف السلوكي والحلم بالظبط.
    sb.from("zad_inventory_observations").select("item_name,observed_at").eq("user_id", userId)
      .in("source", [...PURCHASE_SOURCES])
      .gte("observed_at", new Date(Date.now() - 180 * 86_400_000).toISOString())
      .order("observed_at", { ascending: false }).limit(2000),
    // المعدل المبدئي لكل صنف من غير معدل ولا عادة شرا (أفراد البيت × استهلاك الفرد) — نفس كارت الموبايل.
    sb.rpc("zad_pantry_prior_days_for", { p_user: userId }),
  ]);
  if (occErr) console.error("checkin: occasional items failed:", occErr.message);
  if (priorErr) console.error("checkin: household priors failed:", priorErr.message);
  const priorByItem = new Map(
    (Array.isArray(priors) ? priors as Array<{ item_name: string; days_left: number | string | null; held: boolean }> : [])
      .map((p) => [p.item_name, { daysLeft: p.days_left, held: p.held === true }]),
  );
  const occasionalItems = new Set((Array.isArray(occasional) ? occasional as string[] : []).map((n) => n.trim()));

  const consByItem = new Map(
    ((cons ?? []) as Array<{ item_name: string; avg_daily_qty: number; rate_known: boolean }>)
      .map((c) => [c.item_name, c]),
  );
  const pendingItems = new Set(((pending ?? []) as Array<{ item_name: string }>).map((p) => p.item_name));

  const boughtOn = purchaseDaysByItem((seen ?? []) as Array<{ item_name: string; observed_at: string }>);

  // الأقرب يخلص الأول (checkInPriority): قبل كده الترتيب كان ترتيب الداتابيز، فسقف الاتنين في اليوم كان
  // بيروح لنفس الحلاوة ومسحوق الغسيل كل ليلة واللبن مابيجيش دوره.
  return ((inv ?? []) as Array<{
    item_name: string; quantity: number; category: string | null; unit: string | null; created_at: string | null;
    restock_mode: string | null; restock_cycle_days: number | null;
  }>)
    .filter((item) => !pendingItems.has(item.item_name) && !occasionalItems.has(item.item_name.trim()))
    .map((item) => ({
      item,
      priority: checkInPriority(
        {
          name: item.item_name, quantity: item.quantity, category: item.category,
          restockMode: item.restock_mode, cycleOverride: item.restock_cycle_days,
        },
        consByItem.get(item.item_name)?.avg_daily_qty,
        // صنف اتضاف بإيده من غير شرا متسجل: يوم إضافته هو أول شرا.
        boughtOn.get(restockKey(item.item_name)) ?? (item.created_at ? [item.created_at] : []),
        Date.now(),
        priorByItem.get(item.item_name),
      ),
    }))
    .filter((x): x is { item: typeof x.item; priority: number } => x.priority != null && x.priority >= 1)
    .sort((a, b) => b.priority - a.priority)
    .map(({ item }) => ({ item_name: item.item_name, quantity: item.quantity, unit: item.unit }));
}

/** The daily cron entry point. Capped at 2 prompts/user/day — this is a check-in nudge,
 * not a notification flood; a household with many low-stock items still only hears about
 * its two most pressing ones today (candidates aren't ranked beyond DB order — good enough
 * for a cap this small, not worth a scoring pass). Same cap applies to the real-time
 * job below (?job=live_checkin) — one shared daily budget, not two separate allowances. */
const MAX_CHECKINS_PER_USER_PER_DAY = 2;

/** كام prompt اتبعت النهاردة (UTC) للمستخدم ده، بغض النظر عن حالته دلوقتي (pending/
 *  answered/expired) — العدّاد هو "كام مرة إتقلق النهاردة"، مش "كام لسه مستني رد". */
async function checkinsSentToday(sb: SupabaseClient, userId: string): Promise<number> {
  const todayStart = new Date();
  todayStart.setUTCHours(0, 0, 0, 0);
  // The column is `sent_at`, not `created_at` — this table never had a created_at.
  // PostgREST answered 400 on every call (seen live 2026-08-16), the `count` came back
  // undefined, and `?? 0` turned the failure into "nobody has been asked today", so the
  // daily cap this function exists to enforce was never actually enforced.
  const { count, error } = await sb.from("telegram_checkin_prompts")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("sent_at", todayStart.toISOString());
  if (error) {
    // Fail closed: an unreadable counter must not read as "zero sent today" and let the
    // bot spam a user it has already asked.
    console.error("checkinsSentToday failed:", error.message);
    return Number.MAX_SAFE_INTEGER;
  }
  return count ?? 0;
}

/** بيبعت prompt واحد فعلياً — مشترك بين الكرون اليومي والمسار الفوري (live_checkin)
 *  عشان الاتنين يحترموا نفس السقف اليومي، مش نسختين بمنطق مختلف شوية. بيرجع false
 *  لو الكتابة فشلت — الكولر بيقرر يعمل إيه بالفشل. */
async function sendCheckInPrompt(
  sb: SupabaseClient, userId: string, chatId: number, itemName: string, quantity: number, unit: string | null,
): Promise<boolean> {
  const { data: prompt, error } = await sb.from("telegram_checkin_prompts")
    .insert({ user_id: userId, item_name: itemName, quantity_at_prompt: quantity })
    .select("id")
    .single();
  if (error || !prompt) {
    console.error("checkin prompt insert failed:", error?.message);
    return false;
  }
  await sendTelegramMessage(chatId, checkInPromptMessage(isolate(sanitizeName(itemName)), unit ? sanitizeName(unit) : null), checkInKeyboard((prompt as { id: string }).id));
  return true;
}

/** أكتر من صنف = رسالة واحدة (checkInBundleMessage). بيرجع عدد الأسئلة اللي اتسجلت واتبعتت. */
async function sendCheckInBundle(
  sb: SupabaseClient, userId: string, chatId: number, items: Array<{ item_name: string; quantity: number; unit: string | null }>,
  ignoredNote = false,
): Promise<number> {
  const prompts = await insertCheckinPrompts(sb, userId, items);
  if (prompts.length === 0) return 0;
  await sendTelegramMessage(
    chatId,
    checkInBundleMessage(prompts.map((p) => isolate(p.label)), ignoredNote),
    checkInBundleKeyboard(prompts, ignoredNote),
  );
  return prompts.length;
}

/** أقل مسافة بين آخر رسالة وصلت للعميل وسؤال المخزون. */
const CHECKIN_GAP_MS = 20 * 60 * 1000;

/**
 * أسئلة المخزون بتاعة الليلة للعميل ده بعد كل الحراس: سؤال واحد في اليوم، «بطّل» (الكتم)، السكوت بعد
 * التجاهل (checkinPlan)، والسقف. null = مفيش سؤال الليلة. مشتركة بين القفلة (اللي بتشيل الأسئلة)
 * والسؤال الاحتياطي، عشان الحراس يبقوا نفسهم في الطريقين.
 */
async function nightCheckin(
  sb: SupabaseClient, userId: string,
): Promise<{ candidates: Array<{ item_name: string; quantity: number; unit: string | null }>; plan: "ask" | "ask_with_note" } | null> {
  const alreadySentToday = await checkinsSentToday(sb, userId);
  if (alreadySentToday > 0) return null;
  const budget = MAX_CHECKINS_PER_USER_PER_DAY - alreadySentToday;
  if (budget <= 0) return null;
  // زاد بيلاحظ اللي اتساب (checkinPlan في telegram.ts): قال «بطّل» ⇒ ساكت لحد آخر الكتم؛ سابه
  // مرتين ⇒ بيقول إنه واخد باله ويعرض يبطّل؛ ٤ ⇒ ساكت أسبوعين من نفسه.
  const { data: mute } = await sb.from("zad_memory").select("id")
    .eq("user_id", userId).eq("subject_kind", "checkin").gt("suppress_until", new Date().toISOString())
    .limit(1).maybeSingle();
  if (mute) return null;
  const { data: recentPrompts } = await sb.from("telegram_checkin_prompts").select("status,sent_at")
    .eq("user_id", userId).order("sent_at", { ascending: false }).limit(8);
  const history = (recentPrompts ?? []) as Array<{ status: string; sent_at: string | null }>;
  const plan = checkinPlan(
    ignoredCheckinStreak(history.map((r) => r.status)),
    history[0]?.sent_at ? Date.parse(history[0].sent_at) : null,
    Date.now(),
  );
  if (plan === "rest") return null;
  const candidates = (await findCheckInCandidates(sb, userId)).slice(0, budget);
  return candidates.length > 0 ? { candidates, plan } : null;
}

/** بيسجّل الأسئلة ويرجّع id كل واحد باسمه — الأزرار بتشيل الـid. اللي فشل تسجيله بيتشال. */
async function insertCheckinPrompts(
  sb: SupabaseClient, userId: string, items: Array<{ item_name: string; quantity: number }>,
): Promise<Array<{ id: string; label: string; item_name: string }>> {
  const prompts: Array<{ id: string; label: string; item_name: string }> = [];
  for (const item of items) {
    const { data: prompt, error } = await sb.from("telegram_checkin_prompts")
      .insert({ user_id: userId, item_name: item.item_name, quantity_at_prompt: item.quantity })
      .select("id")
      .single();
    if (error || !prompt) {
      console.error("checkin prompt insert failed:", error?.message);
      continue;
    }
    prompts.push({ id: (prompt as { id: string }).id, label: sanitizeName(item.item_name), item_name: item.item_name });
  }
  return prompts;
}

/** أسئلة المخزون المفتوحة آخر ٢٤ ساعة ⇒ الرد المكتوب بيتسجل زي الزرار. true = اترد عليه هنا. */
async function answerCheckinsByText(ctx: Context, sb: SupabaseClient, userId: string, text: string): Promise<boolean> {
  const { data: rows, error } = await sb.from("telegram_checkin_prompts")
    .select("id,item_name,quantity_at_prompt")
    .eq("user_id", userId).eq("status", "pending")
    .gt("expires_at", new Date().toISOString())
    .gte("sent_at", new Date(Date.now() - 24 * 3_600_000).toISOString())
    .limit(6);
  if (error || !rows?.length) return false;
  const prompts = rows as Array<{ id: string; item_name: string; quantity_at_prompt: number }>;
  const answers = parseCheckinTextReply(text, prompts);
  if (!answers?.length) return false;
  const lines: string[] = [];
  for (const a of answers) {
    const prompt = prompts.find((p) => p.id === a.promptId)!;
    const amount = a.level.fraction === null
      ? { new_qty: prompt.quantity_at_prompt }
      : a.level.fraction === 0 ? { new_qty: 0 } : { fraction_left: a.level.fraction };
    const observed = await agentExecute(userId, "update_inventory_qty", {
      item_name: prompt.item_name, ...amount, reason: "رد العميل بالكلام على سؤال متابعة المخزون",
    });
    const label = isolate(sanitizeName(prompt.item_name));
    if (!observed.ok) {
      console.error("checkin text: update_inventory_qty refused", prompt.item_name, observed.summary ?? "(no summary)");
      lines.push(`معلش، مقدرتش أحفظ ${label} — جرّب تاني.`);
      continue;
    }
    await sb.from("telegram_checkin_prompts")
      // answer_fraction: the trigger judges the bet in zad_pantry_bets by it («قليل» = it was running out).
      .update({
        status: a.level.fraction === 0 ? "answered_no" : "answered_yes",
        answered_at: new Date().toISOString(),
        answer_fraction: a.level.fraction,
      })
      .eq("id", prompt.id).eq("status", "pending");
    lines.push(a.level.fraction === 0 ? `سجلتها خلصت ✅ ${label}` : `تمام ✅ ${label}: ${a.level.label}`);
  }
  await ctx.reply(lines.join("\n"));
  return true;
}

async function recordCheckinTurn(sb: SupabaseClient, userId: string, items: string[]): Promise<void> {
  await recordConversation(sb, userId, [{
    role: "assistant",
    text: proactiveTurn("سؤال المخزون", `سألتك فاضل قد إيه من ${items.join(" و")}`),
  }]);
}

async function runDailyCheckins(sb: SupabaseClient): Promise<{ usersChecked: number; promptsSent: number }> {
  // Pending prompts nobody ever answered would otherwise block that item forever.
  await sb.from("telegram_checkin_prompts")
    .update({ status: "expired" })
    .eq("status", "pending")
    .lt("expires_at", new Date().toISOString());

  const { data: bindings } = await sb.from("telegram_bindings")
    .select("user_id,chat_id")
    .not("bound_at", "is", null)
    .not("chat_id", "is", null);

  const rows = (bindings ?? []) as Array<{ user_id: string; chat_id: number }>;
  let promptsSent = 0;

  for (const b of rows) {
    // رسالة الليل الواحدة (ZAD_PLAN ١.٥، 20261024213500): الأسئلة بتركب على «اقفل يومك» في ساعة ليل
    // العميل. اللفة دي احتياطي للي ماوصلتلوش القفلة، بعد ساعته بـ٤٠ دقيقة. فشل القراية = مايسألش.
    const { data: due, error: dueErr } = await sb.rpc("zad_checkin_night_due", { p_user: b.user_id });
    if (dueErr) console.error("zad_checkin_night_due failed:", dueErr.message);
    if (due !== true) continue;
    // وصله حاجة في آخر ٢٠ دقيقة (جرعة، تحية، مهمة من العقل): يستنى لفة جاية بدل ما تيجي
    // الرسالتين ورا بعض. لفات :٥٠ بتسأل عادي — التأجيل مرة واحدة بس.
    if (deferForRecentOutbound(new Date()) && (await recentOutbound(sb, b.user_id, new Date(Date.now() - CHECKIN_GAP_MS).toISOString(), ["chat_voice_reply"])).length > 0) {
      continue;
    }
    const night = await nightCheckin(sb, b.user_id);
    if (!night) continue;
    const { candidates, plan } = night;
    let asked = 0;
    if (candidates.length === 1 && plan === "ask") {
      if (await sendCheckInPrompt(sb, b.user_id, b.chat_id, candidates[0].item_name, candidates[0].quantity, candidates[0].unit)) asked = 1;
    } else if (candidates.length > 0) {
      asked = await sendCheckInBundle(sb, b.user_id, b.chat_id, candidates, plan === "ask_with_note");
    }
    if (asked > 0) {
      promptsSent += asked;
      await recordCheckinTurn(sb, b.user_id, candidates.slice(0, asked).map((c) => c.item_name));
    }
  }

  return { usersChecked: rows.length, promptsSent };
}

/**
 * Daily cron: DMs any Telegram-bound user whose active subscription/bill renews within
 * the next 3 days (same window as the in-app renewal reminder — ZadCentralBrain.fullAnalysis
 * / ZadViewModel.generateSmartNotifications, which do daysLeft in 0..3). This is the piece
 * that was entirely missing: those two only ever produce an in-app row or a local Android
 * notification, nothing reaches Telegram. Same net.http_post + secret-header pattern as
 * runDailyCheckins (see telegram_checkin_pipeline migration) — no per-day dedup table like
 * check-ins have, since a subscription only enters the 0..3 day window once per renewal
 * cycle, so a user gets at most ~4 daily pings per bill, not an unbounded repeat.
 *
 * Also covers zad_obligations (rent/installments incl. تابي/تمارة/فاليو/utilities) — these
 * had NO due-date reminder anywhere at all until now (unlike subscriptions, which at least
 * had the in-app/local-notification version). Next-due-date math reuses
 * zad_obligation_next_due() (SQL, SECURITY INVOKER, pure function) instead of a third
 * reimplementation of the same recurrence rules already in BudgetMath.kt and zad-brain.
 */
async function runDailySubscriptionAlerts(sb: SupabaseClient): Promise<{ usersChecked: number; alertsSent: number }> {
  const { data: bindings } = await sb.from("telegram_bindings")
    .select("user_id,chat_id")
    .not("bound_at", "is", null)
    .not("chat_id", "is", null);

  const rows = (bindings ?? []) as Array<{ user_id: string; chat_id: number }>;
  let alertsSent = 0;
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  const todayStr = today.toISOString().slice(0, 10);

  for (const b of rows) {
    const [{ data: subs }, { data: obligations }, { data: userRow }] = await Promise.all([
      // No `currency` column exists on zad_subscriptions — asking for it made PostgREST
      // 400 the whole select (seen live 2026-08-16), so `subs` was always null and the
      // renewal reminders below have never fired once. The user's currency is already
      // fetched from zad_users in this same Promise.all.
      sb.from("zad_subscriptions")
        .select("title,amount,renewal_date,due_day,billing_cycle")
        .eq("user_id", b.user_id)
        .eq("is_active", true),
      sb.from("zad_obligations")
        .select("title,amount,kind,recurrence,due_day,due_date")
        .eq("user_id", b.user_id)
        .eq("active", true),
      sb.from("zad_users").select("currency").eq("id", b.user_id).maybeSingle(),
    ]);
    const currency = (userRow as { currency: string | null } | null)?.currency ?? null;

    for (const sub of (subs ?? []) as Array<{ title: string; amount: number; renewal_date: string | null; due_day: number | null; billing_cycle: string | null }>) {
      // التجديد الجاي، مش التاريخ المتخزن (المراجعة الشاملة ٢٠٢٦-١٠-٠٥): التاريخ اللي فات كان بيتخطى للأبد، فالتنبيه بيرن أول
      // شهر بس. نفس zad_subscription_next_renewal اللي الميزانية بتستخدمها.
      const next = nextRenewal(sub.renewal_date, sub.due_day, sub.billing_cycle, todayStr);
      if (!next) continue;
      const renewal = new Date(`${next}T00:00:00Z`);
      const daysLeft = Math.round((renewal.getTime() - today.getTime()) / 86400000);
      if (daysLeft < 0 || daysLeft > 3) continue;
      const amountText = `${sub.amount}${currency ? " " + currency : ""}`;
      const when = daysLeft === 0 ? "اليوم" : `خلال ${daysLeft} يوم`;
      const alertText = `🔔 ${isolate(sanitizeName(sub.title))} يتجدد ${when} (${isolate(amountText)})`;
      await sendTelegramMessage(b.chat_id, alertText);
      await recordConversation(sb, b.user_id, [{ role: "assistant", text: proactiveTurn("", alertText) }]);
      alertsSent++;
    }

    for (const ob of (obligations ?? []) as Array<{ title: string; amount: number; kind: string; recurrence: string; due_day: number | null; due_date: string | null }>) {
      const { data: nextDue } = await sb.rpc("zad_obligation_next_due", {
        p_recurrence: ob.recurrence, p_due_day: ob.due_day, p_due_date: ob.due_date, p_asof: todayStr,
      });
      if (!nextDue) continue;
      const dueDate = new Date(nextDue as string);
      if (isNaN(dueDate.getTime())) continue;
      const daysLeft = Math.round((dueDate.getTime() - today.getTime()) / 86400000);
      if (daysLeft < 0 || daysLeft > 3) continue;
      const amountText = `${ob.amount}${currency ? " " + currency : ""}`;
      const when = daysLeft === 0 ? "اليوم" : `خلال ${daysLeft} يوم`;
      const alertText = `🔔 ${isolate(sanitizeName(ob.title))} مستحق ${when} (${isolate(amountText)})`;
      await sendTelegramMessage(b.chat_id, alertText);
      await recordConversation(sb, b.user_id, [{ role: "assistant", text: proactiveTurn("", alertText) }]);
      alertsSent++;
    }
  }

  return { usersChecked: rows.length, alertsSent };
}



/** أداة اتنفذت فعلاً سيرفر-سايد، أو اقتراح مالي مستني تأكيد — نفس شكل رد agent_turn. */
interface AgentExecuted { tool: string; summary: string }
interface AgentProposal { tool: string; summary: string; input: Record<string, unknown> }
interface AgentTurnResult {
  ok: boolean;
  reply: string;
  executed: AgentExecuted[];
  proposals: AgentProposal[];
  /** العقل رفض اللفة لنفاد رصيد الإعلانات — الرد بياخد زر شحن بدل نص وبس. */
  needs_ad_credit?: boolean;
}

/**
 * المرحلة ٢-د — لفة محادثة عبر zad-brain باستدعاء أدوات حقيقي.
 *
 * بتحل محل برومبتات تصنيف النية المنفصلة (spendIntentPrompt/medicationIntentPrompt) اللي
 * كانت بتشوف الرسالة تلات مرات بتلات أسئلة ضيقة. دلوقتي الموديل شايف الرسالة مرة واحدة
 * ومعاه كل الأدوات، فرسالة زي "صرفت ٥٠ بقالة وضيف لبن للمخزون" بتتعامل كاملة بدل ما
 * تتقسم على مسارين مايعرفوش بعض.
 *
 * `user_id` في الجسم مقبول هنا لأن النداء بمفتاح service-role — راجع resolveAuthedUserId
 * في zad-brain. الهوية نفسها جاية من telegram_bindings، مش من أي حاجة العميل بيدّعيها.
 */
/**
 * Turns an internal failure string into something a customer should actually read.
 *
 * The reason strings themselves are diagnostics — "zad-brain rejected the turn (ok:false)",
 * "gemini 503: {...}", raw HTTP bodies. Those were being pasted straight into the chat, so
 * on 2026-08-15 the customer's Telegram window was a wall of English stack-talk instead of
 * an answer. Telling them the write didn't happen is right and stays; naming our internal
 * component and quoting the upstream JSON at them is not, and it also leaks how the
 * backend is wired to anyone who talks to the bot.
 *
 * The full `reason` still goes to console.error at every call site, so nothing is lost for
 * debugging — it just stops being the customer's problem.
 */
function userFacingFailure(reason: string): string {
  const r = reason.toLowerCase();
  if (r.includes("429") || r.includes("quota") || r.includes("exhausted")) {
    return "عقلي وصل حد الاستخدام دلوقتي — رجّعني تاني بعد شوية وهنفذ الطلب فوراً 🙏";
  }
  if (r.includes("503") || r.includes("unavailable") || r.includes("high demand") || r.includes("overload")) {
    return "مفكر بالحاجة دي، بس الخدمة زحمة لحظة — ابعت الطلب تاني وأنا منفذهولك";
  }
  if (r.includes("timeout") || r.includes("timed out") || r.includes("abort")) {
    return "الطلب أخد وقت أطول من اللازم — ابعت تاني وأنا أنفذه على طول";
  }
  return "حصلت مشكلة لحظية عندى — ابعت الطلب تاني وهنجهزه";
}

/**
 * سجل صريح لكل مرة لفة الوكيل بتقع على الرد القرائي.
 *
 * من غيره مفيش أي أثر للفشل ده: `agent_actions` بيتكتب وقت النجاح بس، فقناة كاملة
 * ممكن تفضل واقعة أيام والجدول يقول إنها "مش مستخدمة" مش "بتفشل". `agent_logs` هو
 * نفس الجدول اللي zad-core-intelligence بيكتب فيه ودشبورد الرصد بيقراه لايف.
 * status لازم يكون واحد من success/warning/error (agent_logs_status_check).
 * fire-and-forget زي المصدر التاني بالظبط — فشل السجل ماينفعش يكسر الرد نفسه.
 */
function logAgentFallback(
  sb: SupabaseClient,
  userId: string | null,
  channel: string,
  reason: string,
): void {
  sb.from("agent_logs").insert({
    user_id: userId,
    agent_name: "zad-telegram-bot",
    tool_used: "agent_turn",
    payload: { channel, reason, fell_back_to: "read-only prose reply" },
    status: "warning",
  }).then(({ error }: { error: { message: string } | null }) => {
    if (error) console.error("[telegram] agent_logs insert failed:", error.message);
  });
}

/** errorReason is set only when the agent path failed and the caller fell back to the
 * read-only prose reply — it's what tells the Telegram user (and the logs) why their
 * "عدّل"/"ذكرني" request silently became a plain answer instead of an executed action.
 * It is an internal string: pass it through [userFacingFailure] before it reaches a chat. */
/**
 * آخر لفات المحادثة من zad_chat_turns، بترتيب زمني تصاعدي زي ما زاد-برين متوقع.
 *
 * ثمانية عشان ده بالظبط اللي handleAgentTurn بياخده (`.slice(-8)`) — سحب أكتر
 * بيتقص هناك ويتحمّل شبكة بلا فايدة. تطبيق أندرويد بيبعت نفس الشكل من Room،
 * فالقناتين بيدّوا العقل نفس العقد.
 */
const CHAT_HISTORY_TURNS = 8;

/**
 * صفوف zad_chat_turns → الشكل اللي zad-brain متوقعه.
 *
 * مصدَّرة عشان تتختبر: الاستعلام بينزل **تنازلي** (عشان `limit` يمسك الأحدث مش
 * الأقدم) والعقل عايزهم **تصاعدي**، فالعكس هنا مش تجميل — من غيره المحادثة
 * بتوصل مقلوبة والعقل يقرا الرد قبل السؤال.
 *
 * أي دور مش "assistant" بيتحوّل لـ"user": handleAgentTurn بيرمي أي دور تالت
 * بصمت، فالتحويل هنا بيمنع لفة تختفي من غير ما حد ياخد باله.
 */
export function toBrainHistory(
  rows: Array<{ role: string; text: string }>,
): Array<{ role: "user" | "assistant"; text: string }> {
  return [...rows].reverse().map((r) => ({
    role: r.role === "assistant" ? "assistant" as const : "user" as const,
    text: r.text,
  }));
}

async function loadChatHistory(
  sb: SupabaseClient,
  userId: string,
): Promise<Array<{ role: "user" | "assistant"; text: string }>> {
  try {
    const { data, error } = await sb
      .from("zad_chat_turns")
      .select("role,text")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(CHAT_HISTORY_TURNS * 2);
    if (error) {
      console.error("loadChatHistory failed:", error);
      return [];
    }
    // نفس قص العقل: آخر ٣ مبادرات بس (_shared/conversationLog.ts).
    return trimProactive(toBrainHistory(data ?? [])).slice(-CHAT_HISTORY_TURNS);
  } catch (e) {
    // فشل قراءة السياق يخلي اللفة بلا ذاكرة — مش يكسرها. ده السلوك اللي كان
    // موجود قبل الجدول ده أصلاً، فالرجوع ليه آمن.
    console.error("loadChatHistory threw:", e);
    return [];
  }
}

/** تسجيل لفة. الفشل بيتسجل ومابيوقفش الرد — الذاكرة مش أهم من الرد نفسه. */
async function recordChatTurn(
  sb: SupabaseClient,
  userId: string,
  role: "user" | "assistant",
  text: string,
): Promise<void> {
  const trimmed = text.trim();
  if (!trimmed) return;
  try {
    const { error } = await sb.from("zad_chat_turns").insert({
      user_id: userId,
      role,
      // نفس سقف العمود في المايجريشن — القص هنا يمنع رفض الكتابة كلها.
      text: trimmed.slice(0, 4000),
    });
    if (error) console.error("recordChatTurn failed:", error);
  } catch (e) {
    console.error("recordChatTurn threw:", e);
  }
}

async function agentTurn(userId: string, message: string, history: Array<{ role: "user" | "assistant"; text: string }> = []): Promise<{ result: AgentTurnResult | null; errorReason?: string }> {
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/zad-brain`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${SERVICE_ROLE_KEY}` },
      // source: "telegram" — تصنيف عرضي بس لـ agent_actions (أي فعل يتنفّذ يتوسم إنه
      // جه من القناة دي)، مش أداة أمان: الهوية أصلاً محسومة بمفتاح service-role +
      // userId من telegram_bindings، مش من الحقل ده.
      // history — اللفات السابقة. من غيرها كل رسالة بتبدأ من الصفر: محادثة
      // حقيقية 2026-09-06 راح فيها مبلغ ("اخصم 50 جنيه" ← "مصروف" ← العقل سأل عن
      // المبلغ تاني) لأن الرسالة الأولى عمرها ما وصلت. العقل بيدعمها من زمان
      // (handleAgentTurn بيتحقق من الأدوار وبيقص على ٨) — تليجرام بس ماكانش بيبعت.
      body: JSON.stringify({ action: "agent_turn", user_id: userId, message, source: "telegram", history }),
    });
    if (!res.ok) {
      const bodyText = await res.text().catch(() => "");
      const reason = `zad-brain HTTP ${res.status}${bodyText ? `: ${bodyText.slice(0, 200)}` : ""}`;
      console.error("agentTurn: zad-brain returned", res.status, bodyText);
      return { result: null, errorReason: reason };
    }
    const json = await res.json() as AgentTurnResult;
    if (json?.ok === false) {
      console.error("agentTurn: zad-brain replied ok:false", json);
      return { result: null, errorReason: "zad-brain rejected the turn (ok:false)" };
    }
    return { result: json };
  } catch (e) {
    const reason = e instanceof Error ? e.message : String(e);
    console.error("agentTurn failed:", e);
    return { result: null, errorReason: reason };
  }
}

/**
 * Telegram never writes a confirmed financial operation itself.  The pending row is
 * only a UI hand-off for the Telegram button; the actual mutation must go back to
 * zad-brain so it gets the same validation, audit trail, and budget side effects as
 * an approval from the in-app chat.
 */
/** دمج مع صف البنك (zad-brain bankTwin.ts): سطر يقول إن مفيش صف تاني. */
function bankTwinNote(summary: string | undefined): string {
  return String(summary ?? "").includes("نفس حركة البنك") ? "\nدي نفس حركة البنك اللي وصلت قبلها — سمّيتها بدل ما تتحسب مرتين." : "";
}

async function agentConfirm(userId: string, tool: string, input: Record<string, unknown>): Promise<{ ok: boolean; summary?: string }> {
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/zad-brain`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${SERVICE_ROLE_KEY}` },
      body: JSON.stringify({ action: "agent_confirm", user_id: userId, tool, input, source: "telegram" }),
    });
    if (!res.ok) {
      console.error("agentConfirm: zad-brain returned", res.status, await res.text().catch(() => ""));
      return { ok: false };
    }
    const data = await res.json() as { ok?: boolean; summary?: string };
    return { ok: data.ok === true, summary: data.summary };
  } catch (error) {
    console.error("agentConfirm failed:", error);
    return { ok: false };
  }
}

/** Runs a deterministic, non-financial household tool through the shared brain.
 * OCR/voice handlers only extract fields; they never mutate inventory or pharmacy
 * tables themselves, which keeps learning observations and the audit trail unified. */
async function agentExecute(userId: string, tool: string, input: Record<string, unknown>): Promise<{ ok: boolean; summary?: string }> {
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/zad-brain`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${SERVICE_ROLE_KEY}` },
      body: JSON.stringify({ action: "agent_execute", user_id: userId, tool, input, source: "telegram" }),
    });
    if (!res.ok) {
      console.error("agentExecute: zad-brain returned", res.status, await res.text().catch(() => ""));
      return { ok: false };
    }
    const data = await res.json() as { ok?: boolean; summary?: string };
    return { ok: data.ok === true, summary: data.summary };
  } catch (error) {
    console.error("agentExecute failed:", error);
    return { ok: false };
  }
}

/** A fetch for any zad-core-intelligence action (voice_agent,
 * analyze_receipt, ...) that returns a structured JSON body rather than a plain string. */
async function callCoreIntelligence<T>(action: string, payload: Record<string, unknown>): Promise<T | null> {
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/zad-core-intelligence`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${SERVICE_ROLE_KEY}` },
      body: JSON.stringify({ action, payload }),
    });
    if (!res.ok) {
      console.error(`callCoreIntelligence: ${action} returned`, res.status);
      return null;
    }
    return await res.json() as T;
  } catch (e) {
    console.error(`callCoreIntelligence: ${action} failed:`, e);
    return null;
  }
}

/** Telegram file download is a two-step dance: resolve file_id → file_path via getFile,
 * then GET the actual bytes from the file/ CDN host. Both calls use the bot token, not the
 * webhook secret — this is Telegram's own API, unrelated to inbound webhook auth. */
async function downloadTelegramFileBytes(fileId: string): Promise<ArrayBuffer | null> {
  try {
    const infoRes = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/getFile?file_id=${fileId}`);
    const info = await infoRes.json();
    const filePath = info?.result?.file_path;
    if (!filePath) {
      console.error("downloadTelegramFileBytes: getFile returned no file_path", JSON.stringify(info));
      return null;
    }
    const fileRes = await fetch(`https://api.telegram.org/file/bot${BOT_TOKEN}/${filePath}`);
    if (!fileRes.ok) {
      console.error("downloadTelegramFileBytes: file download HTTP", fileRes.status);
      return null;
    }
    return await fileRes.arrayBuffer();
  } catch (e) {
    console.error("downloadTelegramFileBytes failed:", e);
    return null;
  }
}

/** Chunked to avoid a call-stack overflow from String.fromCharCode(...bytes) on a large
 * array — voice notes/photos are small (KB, not MB) but no reason to rely on that. */
function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

interface VoiceAgentResult {
  action: "chat" | "add_expense" | "add_income" | "check_budget" | "add_inventory" | "log_pharmacy_dose" | "add_pharmacy";
  message: string;
  data: {
    amount?: number; title?: string; category?: string;
    dosage?: string; daily_dose_count?: number; dose_times?: string; unit?: string;
  } | null;
  transcript: string;
}

interface AnalyzeReceiptResult {
  total: number;
  category: string;
  storeName: string;
  // "pharmacy" | "grocery" | "general" — see zad-core-intelligence's analyze_receipt.
  receiptType: string;
  /** cash | card | wallet | "" (البون ماقالش) — الموجة ٢، 2b257ef5. */
  paymentMethod?: string;
  items: Array<{ name: string; product?: string; price: number; quantity: number; unit: string; category: string }>;
}

// Constructed with a syntactically-valid placeholder when the token is missing so the
// module still loads and the GET probe can explain the misconfiguration. No request is
// ever routed to this bot in that state — Deno.serve short-circuits below.
const bot = new Bot(BOT_CONFIGURED ? BOT_TOKEN : "0:placeholder");

// ── لهجة رسايل البوت الثابتة (botDialect.ts) ─────────────────────────────────
// كل رسالة طالعة من البوت (ctx.reply وغيره عبر grammY) بتعدّي على localizeBotText بلهجة الشات:
// ملف العميل ← كلامه في الرسالة دي ← بلد السوق/العملة. رد العقل مابيتطابقش مع الرسايل الثابتة
// فبيعدّي زي ما هو (هو أصلاً بلهجته). كاش ١٠ دقايق لكل شات عشان مانقراش الداتابيز مع كل رد.
const chatDialectCache = new Map<number, { dialect: BotDialect; at: number }>();
const chatTextHint = new Map<number, string>();
const chatUiEnglish = new Set<number>();

async function chatDialect(chatId: number): Promise<BotDialect> {
  const hit = chatDialectCache.get(chatId);
  if (hit && Date.now() - hit.at < 10 * 60_000) return hit.dialect;
  let dialect: BotDialect = "EG";
  try {
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const userId = await resolveUserId(sb, chatId);
    const [userRow, profileRow] = userId
      ? await Promise.all([
        sb.from("zad_users").select("country,currency").eq("id", userId).maybeSingle().then((r) => r.data as { country?: string; currency?: string } | null),
        sb.from("zad_customer_profile").select("dialect").eq("user_id", userId).maybeSingle().then((r) => r.data as { dialect?: string | null } | null),
      ])
      : [null, null];
    dialect = chatBotDialect({
      preferred: profileRow?.dialect,
      text: chatTextHint.get(chatId) ?? null,
      country: userRow?.country,
      currency: userRow?.currency,
      uiEnglish: chatUiEnglish.has(chatId),
    });
  } catch (e) {
    console.warn("[botDialect] lookup failed, using Egyptian:", (e as Error)?.message);
  }
  chatDialectCache.set(chatId, { dialect, at: Date.now() });
  return dialect;
}

// كلام العميل نفسه تلميح للهجة (لو واضح) — قبل أي handler.
bot.use(async (ctx, next) => {
  const chatId = ctx.chat?.id;
  const text = ctx.message?.text ?? ctx.message?.caption;
  if (chatId && text && detectDialectFromText(text)) {
    chatTextHint.set(chatId, text);
    chatDialectCache.delete(chatId);
  } else if (chatId && ctx.from?.language_code?.startsWith("en")) {
    // آخر تلميح، مش كلام العميل — شوف chatBotDialect.
    chatUiEnglish.add(chatId);
  }
  await next();
});

bot.api.config.use(async (prev, method, payload, signal) => {
  const p = payload as { chat_id?: number | string; text?: string };
  if ((method === "sendMessage" || method === "editMessageText") && typeof p.text === "string" && typeof p.chat_id === "number") {
    const dialect = await chatDialect(p.chat_id);
    if (dialect !== "EG") (payload as { text: string }).text = localizeBotText(p.text, dialect);
  }
  return prev(method, payload, signal);
});

bot.command("start", async (ctx) => {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const chatId = ctx.chat.id;
  if (isFamilyInviteCode(ctx.match as string | undefined)) {
    await ctx.reply(FAMILY_CODE_REPLY);
    return;
  }
  const code = normalizeBindingCode(ctx.match as string | undefined);

  if (!code) {
    const userId = await resolveUserId(sb, chatId);
    if (userId) {
      await ctx.reply("اختار من تحت:", { reply_markup: toGrammyKeyboard(mainMenuKeyboard()) });
    } else {
      await ctx.reply("أهلاً! لو عندك كود ربط من تطبيق زاد ابعته كده: /start الكود");
    }
    return;
  }
  await redeemLinkCode(ctx, sb, code);
});

/** كود جديد = إثبات ملكية الحساب اللي عمله، فالشات بيتنقل له حتى لو كان مربوط بحساب تاني — في
 * transaction واحدة جوه الداتابيز (20261010120000). من «/start الكود» أو الكود لوحده كرسالة. */
async function redeemLinkCode(ctx: Context, sb: SupabaseClient, code: string): Promise<void> {
  const chatId = ctx.chat!.id;
  const { data, error } = await sb.rpc("zad_redeem_telegram_code", { p_code: code, p_chat_id: chatId });
  if (error) console.error("[start] redeem failed:", error.message);
  const status = error ? null : ((data as { status?: BindingStatus } | null)?.status ?? null);
  if (status === "bound" || status === "moved" || status === "already_bound") {
    await ctx.reply(bindingReply(status), { reply_markup: toGrammyKeyboard(mainMenuKeyboard()) });
    const userId = (data as { user_id?: string }).user_id;
    // أول ربط للحساب ده (مش «مربوط بالفعل»): ترحيب بصوت زاد، في الخلفية — الرد النصي وصل خلاص.
    if (userId && status !== "already_bound") runInBackground(sendLinkWelcome(sb, userId, chatId));
    if (userId) await maybeAskCountry(sb, chatId, userId);
  } else {
    await ctx.reply(bindingReply(status));
  }
}

bot.command("unlink", async (ctx) => {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data, error } = await sb.rpc("zad_unlink_telegram_chat", { p_chat_id: ctx.chat.id });
  if (error) console.error("[unlink] failed:", error.message);
  const status = error ? null : ((data as { status?: "unlinked" | "not_bound" } | null)?.status ?? null);
  await ctx.reply(unlinkReply(status));
});

bot.command("menu", async (ctx) => {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const userId = await resolveUserId(sb, ctx.chat.id);
  if (!userId) {
    await ctx.reply("أهلاً! لو عندك كود ربط من تطبيق زاد ابعته كده: /start الكود");
    return;
  }
  await ctx.reply("اختار من تحت، أو اسألني أي حاجة بالكلام العادي:", {
    reply_markup: toGrammyKeyboard(mainMenuKeyboard()),
  });
});

/** التحليل الكامل — نفس بيانات الشات، بس السؤال جاهز، عشان العميل ياخد قراءة شاملة
 * من غير ما يكتب سؤال. */
// ── مكتب الدعم (supportDesk.ts، 20261107123000) — شات الأدمن بس ─────────────────────────────────────────────
/** الشات ده هو شات الأدمن ومش شات عميل؟ نفس شرط admin_alert. */
async function isAdminChat(sb: SupabaseClient, chatId: number | undefined): Promise<boolean> {
  const admin = adminChatId(Deno.env.get("ZAD_ADMIN_CHAT_ID"));
  if (admin === null || chatId !== admin) return false;
  return !(await resolveUserId(sb, chatId));
}

bot.command("support", async (ctx) => {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  if (!(await isAdminChat(sb, ctx.chat.id))) return; // صمت: الأمر مش موجود لأي حد تاني
  const cmd = parseSupportCommand("support", String(ctx.match ?? ""));
  if (cmd.kind !== "lookup") {
    await ctx.reply(SUPPORT_USAGE.support);
    return;
  }
  const { data, error } = await sb.rpc("zad_support_lookup", { p_admin_chat: ctx.chat.id, p_query: cmd.query });
  if (error) {
    console.error("[support] lookup failed:", error.message);
    await ctx.reply(SUPPORT_TEXT.lookupFailed);
    return;
  }
  await ctx.reply(formatLookup(data as Record<string, unknown> | null));
});

bot.command("extend", async (ctx) => {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  if (!(await isAdminChat(sb, ctx.chat.id))) return;
  const cmd = parseSupportCommand("extend", String(ctx.match ?? ""));
  if (cmd.kind !== "extend") {
    await ctx.reply(SUPPORT_USAGE.extend);
    return;
  }
  await ctx.reply(`تجديد ${cmd.tier ?? "الباقة الحالية (أو pro)"} ${cmd.days} يوم للحساب ${cmd.userId}؟`, {
    reply_markup: {
      inline_keyboard: [[
        { text: "✅ جدّد", callback_data: extendCallback(cmd.userId, cmd.days, cmd.tier) },
        { text: "❌ إلغاء", callback_data: "sx:cancel" },
      ]],
    },
  });
});

bot.callbackQuery(/^sx:/, async (ctx) => {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  await ctx.answerCallbackQuery().catch(() => {});
  if (!(await isAdminChat(sb, ctx.chat?.id))) return;
  const data = ctx.callbackQuery.data;
  if (data === "sx:cancel") {
    await ctx.editMessageText(SUPPORT_TEXT.cancelled).catch(() => {});
    return;
  }
  const req = parseExtendCallback(data);
  if (!req) return;
  const { data: res, error } = await sb.rpc("zad_support_extend", {
    p_admin_chat: ctx.chat!.id, p_user: req.userId, p_days: req.days, p_tier: req.tier,
  });
  if (error) console.error("[support] extend failed:", error.message);
  await ctx.editMessageText(error ? SUPPORT_TEXT.extendFailed : formatExtend(res as Record<string, unknown> | null))
    .catch(() => {});
});

/**
 * ترشيحات أمازون (ZAD_PLAN ١٠.٤): أهم ٣ حاجات ناقصة في البيت، بزراير لمتجر أمازون بتاع بلده وتاجه.
 * من غير موديل — نفس الاحتياج والكتالوج بتوع شريط أمازون في الرئيسية. المخزن مخزن البيت (زي restock_link).
 */
async function replyAmazonPicks(sb: SupabaseClient, userId: string, reply: Context["reply"]): Promise<void> {
  const family = await householdFamilyId(sb, userId);
  const [inv, cons, shop, catalog, user] = await Promise.all([
    sb.from("zad_inventory").select("item_name,quantity,low_stock_threshold,unit").or(householdFilter(userId, family)).limit(300),
    sb.from("zad_consumption").select("item_name,avg_daily_qty,rate_known").eq("user_id", userId).limit(300),
    sb.from("zad_shopping_list").select("item_name,is_purchased").or(householdFilter(userId, family)).eq("is_purchased", false).limit(100),
    sb.from("affiliate_products").select("id,product_name_ar,product_name_search_keywords,asin,asin_verified,image_url,average_price_sar,is_active").eq("is_active", true).limit(200),
    sb.from("zad_users").select("country").eq("id", userId).maybeSingle(),
  ]);
  const failed = [inv, cons, shop, catalog, user].find((r) => r.error);
  if (inv.error || shop.error) {
    console.error("[amazon_picks] read failed:", failed?.error?.message);
    await reply("مقدرتش أشوف المخزن دلوقتي — جرب تاني كمان شوية.");
    return;
  }
  if (failed) console.error("[amazon_picks] partial read:", failed.error?.message);
  const market = marketFor((user.data as { country?: string | null } | null)?.country, (n) => Deno.env.get(n));
  const picks = amazonPicks(inv.data ?? [], cons.data ?? [], shop.data ?? [], catalog.data ?? [], market);
  const rows = amazonButtonRows(picks, (u) => amazonOpenUrl(SUPABASE_URL, u));
  await reply(amazonPicksReply(picks, market.domain), rows.length ? { reply_markup: toGrammyKeyboard(rows) } : undefined);
}

bot.command("amazon", async (ctx) => {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const userId = await resolveUserId(sb, ctx.chat.id);
  if (!userId) {
    await ctx.reply("الحساب ده مش مربوط — افتح تطبيق زاد واعمل كود ربط.");
    return;
  }
  await replyAmazonPicks(sb, userId, ctx.reply.bind(ctx));
});

bot.command("tahlil", async (ctx) => {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const userId = await resolveUserId(sb, ctx.chat.id);
  if (!userId) {
    await ctx.reply("الحساب ده مش مربوط — افتح تطبيق زاد واعمل كود ربط.");
    return;
  }
  await ctx.replyWithChatAction("typing");
  // نفس لفة العقل اللي الرسالة النصية بتاخدها — عقل واحد.
  const analysisPrompt = "اعملي تحليل سريع لوضعي المالي وحالة البيت: أهم ٣ ملاحظات، وأهم حاجة أعملها دلوقتي.";
  const { result: turn, errorReason } = await agentTurn(userId, analysisPrompt);
  if (turn?.reply.trim()) {
    await ctx.reply(clampForTelegram(turn.reply.trim()));
    return;
  }
  // من غير عقل احتياطي (تشخيص زاد ١.٢): كان بيرد بتحليل من موديل تاني بشخصية تانية لما العقل يقع.
  if (errorReason) console.error("tahlil: the brain did not answer:", errorReason);
  await ctx.reply(errorReason
    ? `⚠️ ${userFacingFailure(errorReason)} — ابعت /tahlil تاني كمان شوية.`
    : "معلش، التحليل مش متاح دلوقتي — جرب كمان شوية.");
});

// المحادثة الحقيقية — أي كلام عادي بيروح لزاد بنفس السياق والشخصية بتوع الشات
// اللي جوه التطبيق، مش رد ثابت بقائمة أزرار زي النسخة الأولى.
/**
 * لفة الوكيل + تجهيز الرد، من غير أي اعتماد على نوع الرسالة اللي جابت النص.
 * اتفصلت عن `bot.on("message:text")` عشان الصوت يقدر يستخدم **نفس** اللفة بالظبط:
 * كان الصوت بيعدي على `voice_agent` اللي بيعرف ٧ أفعال، والنص بياخد ٣٦ أداة — يعني
 * فويس نوت بتقول "اشترك نتفليكس ١٠٠ في الشهر" مكانش ليها أي طريق تتسجل كاشتراك.
 * القناة مالهاش لازمة تحدد قدرات الوكيل.
 *
 * بترجّع null بس لما اللفة نفسها تقع (نت/موديل/مهلة) — ساعتها المنادي بيقع على
 * الرد القرائي، وبيقول للعميل صراحةً إن التنفيذ ماحصلش.
 */
const TELEGRAM_RETRY_TRIGGER = "telegram_retry";
/** بعدها الرسالة بتتساب والعميل بيتقاله يبعتها تاني — رد بعد نص ساعة مابقاش رد. */
const RETRY_WINDOW_MS = 30 * 60 * 1000;
const RETRY_MAX_ATTEMPTS = 3;

/** يعيد رسايل تليجرام اللي العقل وقع عليها. كل صف بيتحجز بزيادة attempts قبل التنفيذ. */
async function retryFailedTurns(sb: SupabaseClient): Promise<{ answered: number; dropped: number; waiting: number }> {
  const { data: rows } = await sb.from("zad_brain_queue")
    .select("id,user_id,user_message,attempts,created_at")
    .eq("trigger", TELEGRAM_RETRY_TRIGGER)
    .order("created_at", { ascending: true })
    .limit(5);
  let answered = 0, dropped = 0, waiting = 0;
  for (const row of (rows ?? []) as Array<{ id: string; user_id: string; user_message: string; attempts: number; created_at: string }>) {
    let msg: { chat_id?: number; text?: string } = {};
    try { msg = JSON.parse(row.user_message ?? "{}"); } catch { /* صف بايظ: بيتشال تحت */ }
    const chatId = Number(msg.chat_id);
    const text = String(msg.text ?? "").trim();
    const expired = Date.now() - Date.parse(row.created_at) > RETRY_WINDOW_MS || row.attempts >= RETRY_MAX_ATTEMPTS;
    if (!chatId || !text || expired) {
      await sb.from("zad_brain_queue").delete().eq("id", row.id);
      if (chatId && text) {
        const giveUp = `معلش، ماقدرتش أرد على «${text.slice(0, 80)}» — ابعتها تاني لو لسه محتاجها 🙏`;
        await sendTelegramMessage(chatId, giveUp);
        await recordChatTurn(sb, row.user_id, "assistant", giveUp);
      }
      dropped++;
      continue;
    }
    // الحجز: لو نسخة تانية من الجوب حجزته قبلنا، attempts اتغيّر وده مابيرجعش صف.
    const { data: claimed } = await sb.from("zad_brain_queue")
      .update({ attempts: row.attempts + 1 }).eq("id", row.id).eq("attempts", row.attempts).select("id");
    if (!claimed?.length) continue;
    const turn = await agentTurnReply(sb, row.user_id, chatId, text, false);
    if (turn.lines.length === 0) {
      waiting++;
      continue;
    }
    const body = clampForTelegram(`بخصوص «${text.slice(0, 60)}»:\n\n${turn.lines.join("\n\n")}`);
    const keyboard = turn.pendingId ? confirmSpendKeyboard(turn.pendingId)
      : turn.toolPendingId ? confirmToolKeyboard(turn.toolPendingId) : undefined;
    await sendTelegramMessage(chatId, body, keyboard);
    for (const f of turn.followUps ?? []) await sendTelegramMessage(chatId, f.text, f.keyboard);
    await sb.from("zad_brain_queue").delete().eq("id", row.id);
    answered++;
  }
  return { answered, dropped, waiting };
}

/** كام رسالة يتلزق فيهم السؤال المعلّق بالكتير. */
const PENDING_QUESTION_MAX_TURNS = 3;

async function agentTurnReply(
  sb: SupabaseClient,
  userId: string,
  chatId: number,
  text: string,
  recordUser = true,
): Promise<{ lines: string[]; pendingId?: string; toolPendingId?: string; followUps?: ConfirmFollowUp[]; errorReason?: string; needsAdCredit?: boolean }> {
  // ── ربط الإجابة بالسؤال ──────────────────────────────────────────────────
  // زاد بيبعت أسئلة على تليجرام ("راتبك بيجي يوم ١٦ من كل شهر — أظبط الشهر عندك على
  // كده؟") والرد بييجي كرسالة عادية مالهاش أي علاقة بالسؤال. حصل فعلاً: السؤال كان عن
  // **يوم** بداية الدورة، العميل رد "لا بوم 30"، والوكيل قرا الرقم كـ**سقف شهري ٣٠
  // جنيه** واستنى تأكيد عليه. الرقم كان صح والوحدة غلط، ومحدش كان عارف إن فيه سؤال أصلاً.
  //
  // السؤال المعلّق بيتبعت كـ**سياق** مش كـwrapper. ده مقصود: لو لفّينا الرسالة في
  // ANSWER_PREFIX زي ما التطبيق بيعمل، بنبقى بنجزم إنها إجابة — والعميل ساعات بيبعت
  // طلب جديد تماماً والسؤال لسه معلّق ("سجل ٥٠ قهوة"). السياق بيدّي النموذج القدرة
  // يربط، والتعليمات بتقوله يتجاهل لو مفيش علاقة. الجزم بيغلط، الاختيار لأ.
  let outgoing = text;
  const { data: openQ } = await sb.from("zad_insights")
    .select("id,title,body,about_item,created_at")
    .eq("user_id", userId)
    .eq("kind", "question")
    .eq("status", "pending")
    .gte("created_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  let q = openQ as { id: string; title: string; body: string; about_item: string | null; created_at: string } | null;
  // سؤال اتبعت مع ٣ رسايل ومااتردش عليه بيبطّل يتلزق (حساب المالك ١/١١–٢/١١: «مصاريف من غير تصنيف 124.54» اتلزق
  // في ٧ رسايل والعقل سأل «أحطها في البقالة؟» تاني بعد ما صنّفها). الكارت بيفضل في التطبيق.
  if (q) {
    const { count } = await sb.from("zad_chat_turns").select("id", { count: "exact", head: true })
      .eq("user_id", userId).eq("role", "user").gte("created_at", q.created_at)
      .like("text", "=== سؤال معلّق من زاد%");
    if ((count ?? 0) >= PENDING_QUESTION_MAX_TURNS) {
      await sb.from("zad_insights").update({ status: "seen" }).eq("id", q.id).eq("status", "pending");
      q = null;
    }
  }
  if (q) {
    const about = q.about_item ? ` (بخصوص: ${q.about_item})` : "";
    outgoing =
      "=== سؤال معلّق من زاد، اتبعت للعميل خلال آخر ٢٤ ساعة ===\n" +
      `${q.title} — ${q.body}${about}\n` +
      "=== نهاية السؤال ===\n" +
      "لو الرسالة اللي تحت رد على السؤال ده، فسّرها في سياقه — خصوصاً الأرقام: رقم في " +
      "رد على سؤال عن يوم هو **يوم**، مش مبلغ. لو الرسالة طلب جديد مالوش علاقة، تجاهل " +
      "السؤال ده تماماً.\n\n" +
      text;
  }

  // تأكيدات مستنية زرار (ZAD_PLAN ١٠.٧): بعد بلوك السؤال (عدّاد PENDING_QUESTION_MAX_TURNS بيدوّر على أوله)، وقبل
  // الرسالة. آخر ساعتين بس — الأقدم العميل سابه، وانتهاء صلاحيته بيقفله.
  const { data: waiting } = await sb.from("telegram_pending_writes")
    .select("amount,title,txn_kind")
    .eq("user_id", userId).eq("status", "pending")
    .gt("expires_at", new Date().toISOString())
    .gte("created_at", new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString())
    .order("created_at", { ascending: true }).limit(8);
  if (Array.isArray(waiting) && waiting.length > 0) {
    const cur = String((await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle()).data?.currency ?? "");
    const block = pendingConfirmsBlock(waiting as Array<{ amount: number | null; title: string | null; txn_kind: string | null }>, cur);
    if (block) outgoing = outgoing === text ? block + text : outgoing.slice(0, outgoing.length - text.length) + block + text;
  }

  // السياق بيتقرا **قبل** ما رسالة اللفة دي تتسجل، عشان الرسالة الحالية تتبعت
  // مرة واحدة (في `message`) مش مرتين.
  const history = await loadChatHistory(sb, userId);
  const { result: turn, errorReason } = await agentTurn(userId, outgoing, history);
  // بتتسجل حتى لو اللفة فشلت: العميل قالها فعلاً، والرسالة الجاية محتاجة تشوفها.
  // ده بالظبط سيناريو "اخصم 50 جنيه" ← "مصروف" — الأولى لازم تعيش عشان التانية تفهم.
  if (recordUser) await recordChatTurn(sb, userId, "user", outgoing);
  if (!turn) return { lines: [], errorReason: errorReason ?? "agent turn unavailable" };

  // لفة رجعت 200 وهي فاضية تماماً — لا رد، ولا أداة اتنفذت، ولا اقتراح — كانت بتخرج
  // بـ lines فاضية و errorReason غير موجود، فالمعالج تحت كان بيفتكرها الـ fallback
  // القرائي العادي ويرد على العميل من غير أي تحذير. من ناحية العميل دي نفس حالة
  // "الوكيل مش متاح" بالظبط، فلازم تحمل نفس السبب الصريح.
  if (!turn.reply?.trim() && !turn.executed?.length && !turn.proposals?.length) {
    return { lines: [], errorReason: "zad-brain returned an empty turn (HTTP 200, no reply, no executed tool, no proposal)" };
  }

  // نفاد رصيد الإعلانات: الرد بياخد زر شحن. لو رجعنا بنص وبس، العميل واقف في
  // تليجرام ومش عارف يعمل إيه — والحل جوه التطبيق.
  if (turn.needs_ad_credit) {
    await recordChatTurn(sb, userId, "assistant", turn.reply);
    return { lines: [turn.reply.trim()], needsAdCredit: true };
  }

  // العقل صنّف المصروف في لفة شايلة السؤال ⇒ السؤال اتجاوب، مايتلزقش في الرسالة الجاية.
  if (q && pendingQuestionAnswered(turn.executed.map((e) => e.tool))) {
    await sb.from("zad_insights").update({ status: "acted" }).eq("id", q.id).eq("status", "pending");
  }

  const lines: string[] = [];
  if (turn.reply.trim()) lines.push(turn.reply.trim());
  for (const done of turn.executed) lines.push(`✅ ${isolate(sanitizeName(done.summary))}`);
  // رد العقل بيتسجل كمان — من غيره العميل يفتكر إن البوت سأله سؤال، والبوت
  // يشوف رسالة العميل بلا السؤال اللي ردّت عليه. بالإيصالات (✅) كمان: لفة ردها كله
  // إيصال كانت بتتسجل من غير رد خالص (٢٠٢٦-٠٩-٣٠ ٢٢:٣٤ «اصحي كمان دقيقة»)، فتاني يوم
  // سؤال «سعر حليب فيفا» قرا الطلب كأنه لسه مستني وسجّل ميعاد صحيان تاني.
  await recordChatTurn(sb, userId, "assistant", lines.join("\n"));

  // كل اقتراح بزرار (ZAD_PLAN ١٠.٧، planConfirmations): الأول بيركب على رسالة الرد، والباقي رسايل تحتها كل واحدة
  // بزرارها. الفلوس الأول — تأكيد معاملة أخطر من تأكيد أداة تانية. رسالة تليجرام الواحدة بتشيل كيبورد واحد.
  const { ordered, overflow } = planConfirmations(turn.proposals);
  let pendingId: string | undefined;
  let toolPendingId: string | undefined;
  const followUps: ConfirmFollowUp[] = [];
  let currency: string | null = null;
  for (const proposal of ordered) {
    let confirm: { text: string; keyboard: InlineKeyboardButton[][]; spendId?: string; toolId?: string } | null;
    if (proposal.tool === "log_transaction") {
      currency ??= String((await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle()).data?.currency ?? "غير معروف");
      const cur: string = currency;
      const amount = Number(proposal.input.amount);
      const kind = proposal.input.txn_kind === "income" ? "income" : "expense";
      const title = String(proposal.input.title ?? "مصروف").slice(0, 80);
      const category = String(proposal.input.category ?? "أخرى").slice(0, 40);
      // «اشتريت لبن وعيش بـ٤٠»: الأصناف بتتحجز مع المصروف (٣.٦ د) وبتتسجل معاه في شرا واحد.
      const boughtLines = kind === "expense" && Array.isArray(proposal.input.lines) && proposal.input.lines.length > 0
        ? proposal.input.lines.slice(0, 30)
        : null;
      const { data: pending, error } = await sb.from("telegram_pending_writes").insert({
        user_id: userId,
        chat_id: chatId,
        txn_kind: kind,
        amount,
        title,
        category,
        confidence: null,
        purchase_lines: boughtLines,
      }).select("id").single();
      if (error || !pending) {
        console.error("pending write insert failed:", error);
        lines.push(`معلش، مقدرتش أجهّز تأكيد «${isolate(sanitizeName(title))}» — جرب تاني.`);
        continue;
      }
      const spendId = (pending as { id: string }).id;
      confirm = {
        text: confirmSpendMessage({ is_spend: true, kind, amount, title, category, confidence: 1 }, cur),
        keyboard: confirmSpendKeyboard(spendId),
        spendId,
      };
    } else {
      const { data: row, error } = await sb.from("telegram_pending_tools").insert({
        user_id: userId,
        chat_id: chatId,
        tool: proposal.tool,
        input: proposal.input,
        summary: proposal.summary,
      }).select("id").single();
      if (error || !row) {
        console.error("pending tool insert failed:", error);
        lines.push(`ℹ️ ${proposal.summary} — معلش، مقدرتش أجهّز التأكيد. جرب تاني.`);
        continue;
      }
      const toolId = (row as { id: string }).id;
      confirm = { text: `⚠️ ${proposal.summary}\n\nأأكدها؟`, keyboard: confirmToolKeyboard(toolId), toolId };
    }
    if (!pendingId && !toolPendingId) {
      lines.push(confirm.text);
      pendingId = confirm.spendId;
      toolPendingId = confirm.toolId;
    } else {
      followUps.push({ text: confirm.text, keyboard: confirm.keyboard });
    }
  }
  for (const extra of overflow) {
    lines.push(`ℹ️ ${extra.summary} — ابعتها في رسالة لوحدها عشان أقدر أحط ليها زر تأكيد.`);
  }
  if (followUps.length > 0) lines.push(`👇 وتحت ${followUps.length === 1 ? "تأكيد تاني" : `${followUps.length} تأكيدات كمان`} — كل عملية بزرارها.`);
  return { lines, pendingId, toolPendingId, followUps };
}

/** تأكيد زيادة في نفس اللفة: رسالة لوحدها بزرارها، بعد رسالة الرد. */
type ConfirmFollowUp = { text: string; keyboard: InlineKeyboardButton[][] };

/**
 * تأكيد/رفض مصروف معلّق **بالنص** ("أيوه"/"لا") بدل الضغط على الزر — نفس منطق
 * مسار callback بالظبط: إعادة تحقق مالك، claim بـ status=idempotent، تنفيذ عبر
 * agent_confirm سيرفر-سايد. بيرجع true لو فيه pending اتعالج (فمتتعتبرش الرسالة
 * سؤال جديد)، وfalse لو مفيش حاجة معلّقة.
 */
async function handleSpendCallbackText(
  ctx: { reply: (t: string, o?: { reply_markup: InlineKeyboard }) => Promise<unknown> },
  sb: SupabaseClient,
  userId: string,
  isAffirm: boolean
): Promise<boolean> {
  const { data: rows } = await sb.from("telegram_pending_writes")
    .select("id,txn_kind,amount,title,category,status,expires_at,wallet,merchant_name,source_type,purchase_lines")
    .eq("user_id", userId)
    .eq("status", "pending")
    .order("created_at", { ascending: false })
    .limit(1);
  const row = (rows as {
    id: string; txn_kind: string; amount: number; title: string;
    category: string | null; status: string; expires_at: string;
    wallet: string | null; merchant_name: string | null; source_type: string | null;
    purchase_lines: unknown;
  }[] | null)?.[0];
  if (!row) return false;

  if (!isAffirm) {
    await sb.from("telegram_pending_writes").update({ status: "cancelled" }).eq("id", row.id).eq("status", "pending");
    await ctx.reply("تمام، ملغيته ✖️");
    return true;
  }
  if (new Date(row.expires_at) < new Date()) {
    await sb.from("telegram_pending_writes").update({ status: "cancelled" }).eq("id", row.id);
    await ctx.reply("الطلب ده انتهت صلاحيته — ابعت المصروف تاني.");
    return true;
  }
  // صورة فاتورة محجوزة كشرا (٣.٦ ج): «أيوه» = «سجّل الكل»، ولو مفيش مبلغ اتقرا = الأصناف.
  // الأصناف من الشات («اشتريت لبن وعيش بـ٤٠») بتكمّل تحت مع log_transaction زي الزرار x:.
  if (row.amount == null || (row.purchase_lines != null && row.source_type === "receipt")) {
    await recordPendingPurchase(ctx, sb, userId, row as unknown as PendingPurchase & { status: string; expires_at: string },
      row.amount != null ? "all" : "lines");
    return true;
  }

  const { error: claimError } = await sb.from("telegram_pending_writes")
    .update({ status: "confirmed" })
    .eq("id", row.id)
    .eq("status", "pending");
  if (claimError) {
    await ctx.reply("حصلت مشكلة، جرب تاني.");
    return true;
  }

  const confirmed = await agentConfirm(userId, "log_transaction", {
    amount: row.amount,
    title: row.title,
    category: row.category ?? undefined,
    txn_kind: row.txn_kind,
    // «أيوه» بالكتابة زي زرار التأكيد: اللي البون قاله. كانت card ثابتة هنا، فبون اتدفع كاش
    // واتأكد بالكتابة كان بيتسجل فيزا.
    wallet: row.wallet ?? "card",
    merchant_name: row.merchant_name ?? undefined,
    source_type: row.source_type ?? undefined,
    lines: Array.isArray(row.purchase_lines) ? row.purchase_lines : undefined,
  });
  if (!confirmed.ok) {
    console.error("telegram text confirmation via zad-brain refused:", String(confirmed.summary ?? "").slice(0, 200));
    await sb.from("telegram_pending_writes").update({ status: "pending" }).eq("id", row.id);
    const refused = refusedSpendReply(confirmed.summary, row.id);
    await ctx.reply(refused.text, refused.keyboard ? { reply_markup: toGrammyKeyboard(refused.keyboard) } : undefined);
    return true;
  }
  const { data: u } = await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle();
  const cur = (u as { currency?: string } | null)?.currency ?? "غير معروف";
  await ctx.reply(`اتسجل ✅ ${isolate(sanitizeName(row.title))} — ${isolate(money(row.amount, cur))}` + bankTwinNote(confirmed.summary));
  return true;
}

/**
 * تأكيد/رفض أداة غير مالية معلّقة **بالنص** — نفس بروتوكول مسار tx:/tc:: claim
 * مشروط بـ status ثم تنفيذ عبر zad-brain (agent_confirm). بترجع true لو اتعالجت.
 */
async function handleToolCallbackText(
  ctx: { reply: (t: string) => Promise<unknown> },
  sb: SupabaseClient,
  userId: string,
  isAffirm: boolean
): Promise<boolean> {
  const { data: rows } = await sb.from("telegram_pending_tools")
    .select("id,user_id,tool,input,summary,status,expires_at")
    .eq("user_id", userId)
    .eq("status", "pending")
    .order("created_at", { ascending: false })
    .limit(1);
  const row = (rows as {
    id: string; user_id: string; tool: string; input: Record<string, unknown>;
    summary: string; status: string; expires_at: string;
  }[] | null)?.[0];
  if (!row || row.user_id !== userId) return false;

  if (!isAffirm) {
    await sb.from("telegram_pending_tools").update({ status: "cancelled" }).eq("id", row.id).eq("status", "pending");
    await ctx.reply("تمام، ملغيته ✖️");
    return true;
  }
  if (new Date(row.expires_at).getTime() < Date.now()) {
    await sb.from("telegram_pending_tools").update({ status: "cancelled" }).eq("id", row.id);
    await ctx.reply("الطلب ده عدى عليه وقت طويل — ابعته تاني لو لسه عايزه.");
    return true;
  }

  const { error: claimError } = await sb.from("telegram_pending_tools")
    .update({ status: "confirmed" })
    .eq("id", row.id)
    .eq("status", "pending");
  if (claimError) {
    await ctx.reply("معلش، حصلت مشكلة — جرب تاني.");
    return true;
  }

  const confirmed = await agentConfirm(userId, row.tool, row.input);
  if (!confirmed.ok) {
    console.error("telegram tool text confirmation failed:", row.tool);
    await sb.from("telegram_pending_tools").update({ status: "pending" }).eq("id", row.id);
    await ctx.reply("معلش، التنفيذ فشل — جرب تاني.");
    return true;
  }
  await ctx.reply(`تنفذ ✅ ${row.summary}`);
  return true;
}

bot.on("message:text", async (ctx) => {
  if (ctx.message.text.startsWith("/")) return; // أوامر متسجلة فوق بتتعامل لوحدها
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const userId = await resolveUserId(sb, ctx.chat.id);
  if (!userId) {
    if (isFamilyInviteCode(ctx.message.text)) {
      await ctx.reply(FAMILY_CODE_REPLY);
    } else if (looksLikeLinkCode(ctx.message.text)) {
      await redeemLinkCode(ctx, sb, normalizeBindingCode(ctx.message.text)!);
    } else {
      await ctx.reply("أهلاً! لو عندك كود ربط من تطبيق زاد ابعته كده: /start الكود");
    }
    return;
  }
  await maybeAskCountry(sb, ctx.chat.id, userId);

  // تأكيد/رفض بالنص — العميل يقدر يرد "أيوه"/"لا" بدل الضغط على الزر (نفس اللي
  // بيعمله التطبيق). بنقرا أحدث pending write/tool لسه pending بتاعه، ولو رده
  // موافق/رافض ننفذ نفس منطق الـ callback بالظبط عبر handleSpendCallbackText /
  // handleToolCallbackText تحت (idempotent: claim بـ status).
  //
  // ٢٠٢٦-٠٩-٢٥: الـregex القديم كان بـ`\b` فمكانش بيشوف أي رد عربي خالص (parseYesNoReply
  // في telegram.ts فيها السبب بالتفصيل)، وكان بيدوّر على المصروف المكتوب والأداة بس — لا
  // تذكير الجرعة ولا اقتراح الإشعار البنكي. دلوقتي الاتنين بيتقفلوا بالكلام كمان.
  const yesNo = parseYesNoReply(ctx.message.text);
  if (yesNo) {
    const isAffirm = yesNo === "yes";
    if (await handleSpendCallbackText(ctx, sb, userId, isAffirm)) return;
    if (await handleToolCallbackText(ctx, sb, userId, isAffirm)) return;
  }
  const doseReply = parseDoseReply(ctx.message.text);
  if (yesNo || doseReply) {
    const [dose, proposal] = await Promise.all([openDoseMoment(sb, userId), yesNo ? openProposal(sb, userId) : null]);
    // «لا» لوحدها ممكن تبقى على الجرعة أو على الإشعار البنكي — بتروح للي اتبعت آخر.
    // «أخدته» / «مخدتش» عن الدوا بس، مهما كان فيه اقتراح.
    const toDose = dose && (doseReply || !proposal || dose.sentAt >= proposal.createdAt);
    if (toDose) {
      const action = doseReply ?? (yesNo === "yes" ? "taken" : "skipped");
      await ctx.reply(await settleDose(sb, userId, dose.id, action));
      return;
    }
    if (proposal && yesNo) {
      if (yesNo === "no") {
        await resolveProposalAndReply(ctx, sb, ctx.chat.id, userId, proposal.id, "reject");
      } else if (proposal.status === "awaiting_confirmation") {
        await resolveProposalAndReply(ctx, sb, ctx.chat.id, userId, proposal.id, "confirm");
      } else {
        // «أيوه» على حركة مش معروف اتجاهها ماتكفيش — مانخمنش مصروف ولا دخل.
        await sendTelegramMessage(ctx.chat.id, "تمام — بس دي مصروف ولا دخل ولا تحويل؟",
          transactionProposalKeyboard(proposal.id, "needs_classification"));
      }
      return;
    }
    // مفيش حاجة معلّقة → كمّل كرسالة عادية للوكيل
  }

  // سؤال المخزون بالكلام (طلب المالك ٧/١١): «لسه زي ما هي»، «باقي حبة»، «الرز خلص والزيت نصه» — بنفس طريق الزرار.
  // مفيش فهم أكيد = الرسالة بتكمّل للعقل زي الأول.
  if (await answerCheckinsByText(ctx, sb, userId, ctx.message.text)) return;

  await ctx.replyWithChatAction("typing");

  // المرحلة ٢-د — نداء واحد بكل الأدوات، بدل تلات مرات تصنيف نية منفصلة. الأدوات
  // المباشرة (مخزون/صيدلية/تسوق/بلد وعملة) بتكون اتنفذت خلاص لما الرد ده يوصل؛ أدوات
  // الفلوس بترجع كاقتراح لسه ماحصلش، وبيتحوّل لنفس زر التأكيد الموجود من الأول.
  const turnReply = await agentTurnReply(sb, userId, ctx.chat.id, ctx.message.text);
  const errorReason = turnReply.errorReason;

  if (turnReply.lines.length > 0) {
    const body = clampForTelegram(turnReply.lines.join("\n\n"));
    if (turnReply.needsAdCredit) {
      await ctx.reply(body, { reply_markup: toGrammyKeyboard(adCreditKeyboard(SUPABASE_URL)) });
    } else if (turnReply.pendingId) {
      await ctx.reply(body, { reply_markup: toGrammyKeyboard(confirmSpendKeyboard(turnReply.pendingId)) });
    } else if (turnReply.toolPendingId) {
      await ctx.reply(body, { reply_markup: toGrammyKeyboard(confirmToolKeyboard(turnReply.toolPendingId)) });
    }
    if (turnReply.pendingId || turnReply.toolPendingId) {
      for (const f of turnReply.followUps ?? []) await ctx.reply(f.text, { reply_markup: toGrammyKeyboard(f.keyboard) });
    } else if (!turnReply.needsAdCredit) {
      const shop = amazonLinkButtons(body, (u) => amazonOpenUrl(SUPABASE_URL, u));
      await ctx.reply(shop.text, shop.rows.length ? { reply_markup: toGrammyKeyboard(shop.rows) } : undefined);
      // رد فيه إحساس (تشجيع، قلق، عتاب خفيف) ⇒ بصوت زاد كمان (voiceReply.ts)، بعد النص وفي الخلفية.
      runInBackground(maybeVoiceReply(sb, userId, ctx.chat.id, turnReply.lines.join("\n\n"), false));
    }
    return;
  }

  // العقل مش متاح (نت/موديل/مهلة): مفيش عقل تاني يخمّن بتعليمات تانية (كان بيرد من بيانات
  // قديمة وبرده ماكانش بيتحفظ، ٢٠٢٦-١٠-٠١). الرسالة بتدخل طابور، والرد الحقيقي بيوصل أول ما
  // العقل يرجع (job=retry_failed كل دقيقتين).
  if (errorReason) {
    console.error("agent turn failed, queued for retry:", errorReason);
    logAgentFallback(sb, userId, "text", errorReason);
  }
  const { error: queueErr } = await sb.from("zad_brain_queue").insert({
    user_id: userId, trigger: TELEGRAM_RETRY_TRIGGER,
    user_message: JSON.stringify({ chat_id: ctx.chat.id, text: ctx.message.text }),
    last_error: (errorReason ?? "").slice(0, 300),
  });
  const holding = queueErr
    ? "معلش، مش قادر أرد دلوقتي ومقدرتش أحفظ رسالتك — ابعتها تاني كمان شوية 🙏"
    : "معلش، مش قادر أرد دلوقتي 🙏 رسالتك محفوظة، وهرد عليك هنا أول ما أرجع — مش محتاج تبعتها تاني.";
  await ctx.reply(holding);
  await recordChatTurn(sb, userId, "assistant", holding);
});

// رسالة صوتية — نفس فكرة رسالة الكتابة العادية، بس بعد تفريغ الصوت لنص عبر
// zad-core-intelligence's voice_agent (Whisper + استخراج نية بخطوة واحدة). أي صرف/دخل
// برضه بيعدي على نفس تأكيد الكتابة العادية (telegram_pending_writes + زر تأكيد) — مفيش
// كتابة مباشرة في zad_transactions من صوت متسمعش صح، نفس قاعدة الأمان بتاعة النص.
// إضافة مخزون بس هي اللي بتتكتب مباشرة (نفس فلسفة مسح الكاميرا في التطبيق: مخزون خطره
// أقل بكتير من فلوس حقيقية في الدفتر).
bot.on("message:voice", async (ctx) => {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const userId = await resolveUserId(sb, ctx.chat.id);
  if (!userId) {
    await ctx.reply("أهلاً! لو عندك كود ربط من تطبيق زاد ابعته كده: /start الكود");
    return;
  }
  // البوابة المدفوعة — قبل التنزيل عن قصد: مستخدم مقفول ميصحش نصرف عليه
  // تنزيل ملف ولا نداء موديل. النص بتاعه لسه شغال مجاناً، فهو مش مقطوع.
  const gate = await mediaGate(sb, userId, "voice");
  if (!gate.allowed) {
    await ctx.reply(gate.reply!);
    return;
  }

  await ctx.replyWithChatAction("typing");

  const bytes = await downloadTelegramFileBytes(ctx.message.voice.file_id);
  if (!bytes) {
    await ctx.reply("معلش، مقدرتش أنزّل الرسالة الصوتية — جرب تاني.");
    return;
  }

  const result = await callCoreIntelligence<VoiceAgentResult>("voice_agent", {
    audio_base64: arrayBufferToBase64(bytes),
    mime_type: ctx.message.voice.mime_type || "audio/ogg",
  });
  if (!result || !result.transcript) {
    await ctx.reply("معلش، مسمعتش كلام واضح في الرسالة الصوتية — جرب تاني.");
    return;
  }
  const heard = `🎤 "${isolate(sanitizeName(result.transcript))}"\n\n`;

  // كان هنا dispatch يدوي على `result.action` — ٧ أفعال بس (مصروف/دخل/مخزون/دوا/
  // ميزانية/جرعة/دردشة)، بينما نفس الجملة مكتوبة كانت بتوصل لـ٣٦ أداة. الفرق مكانش
  // في الأمان، كان في إن الصوت اتبنى قبل لفة الوكيل ومحدش رجع وصّله بيها: فويس نوت
  // بتقول "اشترك نتفليكس ١٠٠ في الشهر" مكانش ليها أي طريق تتسجل كاشتراك.
  //
  // التفريغ هو الحاجة الوحيدة اللي محتاجينها من voice_agent دلوقتي. النص الناتج بيدخل
  // نفس agentTurnReply اللي الكتابة بتدخله — نفس الأدوات، نفس التحقق، نفس سجل التدقيق،
  // ونفس زر التأكيد على الفلوس. مفيش مسار كتابة تاني اتفتح هنا.
  const turnReply = await agentTurnReply(sb, userId, ctx.chat.id, result.transcript);

  if (turnReply.lines.length > 0) {
    const body = clampForTelegram(heard + turnReply.lines.join("\n\n"));
    if (turnReply.needsAdCredit) {
      await ctx.reply(body, { reply_markup: toGrammyKeyboard(adCreditKeyboard(SUPABASE_URL)) });
    } else if (turnReply.pendingId) {
      await ctx.reply(body, { reply_markup: toGrammyKeyboard(confirmSpendKeyboard(turnReply.pendingId)) });
    } else if (turnReply.toolPendingId) {
      await ctx.reply(body, { reply_markup: toGrammyKeyboard(confirmToolKeyboard(turnReply.toolPendingId)) });
    }
    if (turnReply.pendingId || turnReply.toolPendingId) {
      for (const f of turnReply.followUps ?? []) await ctx.reply(f.text, { reply_markup: toGrammyKeyboard(f.keyboard) });
    } else if (!turnReply.needsAdCredit) {
      const shop = amazonLinkButtons(body, (u) => amazonOpenUrl(SUPABASE_URL, u));
      await ctx.reply(shop.text, shop.rows.length ? { reply_markup: toGrammyKeyboard(shop.rows) } : undefined);
      // بعت فويس ⇒ الرد يتقال بصوت زاد كمان (voiceReply.ts)، بعد النص وفي الخلفية.
      runInBackground(maybeVoiceReply(sb, userId, ctx.chat.id, turnReply.lines.join("\n\n"), true));
    }
    return;
  }

  // اللفة نفسها وقعت. الرسالة الصوتية دايماً بتبقى طلب — الصمت أو "تمام" هنا بيخلي
  // العميل يفتكر إن اللي قاله اتسجل، وهو ماتسجلش.
  if (turnReply.errorReason) {
    console.error("voice agent turn failed:", turnReply.errorReason);
    logAgentFallback(sb, userId, "voice", turnReply.errorReason);
  }
  await ctx.reply(clampForTelegram(
    heard + `⚠️ ${userFacingFailure(turnReply.errorReason ?? "")}. اللي قلته **ماتسجّلش** — جرب تبعته تاني كمان شوية.`,
  ));
  await recordChatTurn(sb, userId, "assistant", "ماقدرتش أنفّذ الرسالة الصوتية دي وقتها، ومااتسجلش منها حاجة.");
});

// صورة (فاتورة أو صنف) — نفس مبدأ التسجيل الصوتي: الأصناف بتتضاف للمخزون مباشرة (زي
// مسح الكاميرا في التطبيق)، أي مبلغ إجمالي مقروء من الفاتورة بيعدي على نفس تأكيد
// الكتابة العادية قبل ما يتسجل في zad_transactions.
// محادثة واحدة لكل اللي حصل (_shared/conversationLog.ts): الصورة والزرار وردود زاد عليهم بيتكتبوا في
// zad_chat_turns، عشان «الدوا بعتهولك» بعد صورة دوا مايتردش عليها بـ«ورّيني بعت إيه؟» (١٥/١٠).
// طبقة قبل الهاندلر الأصلي: بتلقط ctx.reply وبتكتب بعد ما يخلص، من غير ما تلمس منطقه.
// deno-lint-ignore no-explicit-any
function captureReplies(ctx: any): string[] {
  const said: string[] = [];
  const original = ctx.reply.bind(ctx);
  // deno-lint-ignore no-explicit-any
  ctx.reply = (text: string, ...rest: any[]) => {
    if (typeof text === "string") said.push(text);
    return original(text, ...rest);
  };
  return said;
}

bot.on("message:photo", async (ctx, next) => {
  const said = captureReplies(ctx);
  await next();
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const userId = await resolveUserId(sb, ctx.chat.id).catch(() => null);
  if (!userId) return;
  const caption = ctx.message.caption?.trim();
  await recordConversation(sb, userId, [
    { role: "user", text: `[بعت صورة على تليجرام${caption ? `: «${caption.slice(0, 200)}»` : ""}]` },
    { role: "assistant", text: said.join("\n\n") },
  ]);
});

bot.on("callback_query:data", async (ctx, next) => {
  const said = captureReplies(ctx);
  await next();
  if (said.length === 0) return;
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const chatId = ctx.chat?.id;
  const userId = chatId ? await resolveUserId(sb, chatId).catch(() => null) : null;
  if (!userId) return;
  const data = ctx.callbackQuery.data;
  const label = (ctx.callbackQuery.message?.reply_markup?.inline_keyboard ?? []).flat()
    // deno-lint-ignore no-explicit-any
    .find((b: any) => b.callback_data === data)?.text;
  await recordConversation(sb, userId, [
    { role: "user", text: `[داس على زرار${label ? ` «${label}»` : ""}]` },
    { role: "assistant", text: said.join("\n\n") },
  ]);
});

/** Zad's public flyer bucket (migration 20261103200000) — the only pictures a deal may carry. */
const FLYER_PREFIX = `${SUPABASE_URL}/storage/v1/object/public/zad-flyers/`;

/**
 * نشرة محل من شات الأدمن (طلب المالك ٣/١١ بدل الإيميل في ٤.١٣): الصورة بتتحفظ في zad-flyers، وجيميناي بيقرا عروضها،
 * وكل عرض بيدخل zad_deals بـ`flyer` ورابط الصورة — فتحية الصبح بتبعت النشرة نفسها للي محتاج الصنف. شات الأدمن بس:
 * عميل بيبعت صورة = فاتورة زي ما هي، ومحدش غير المالك يقدر يدخّل عروض.
 */
async function handleFlyerPhoto(ctx: Context & { message: { photo: Array<{ file_id: string }>; caption?: string } }): Promise<void> {
  const parsed = parseFlyerCaption(ctx.message.caption);
  if (!parsed) {
    await ctx.reply(FLYER_HOW_TO);
    return;
  }
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: rows, error: rowsErr } = await sb.from("zad_deal_seed_stores").select("country,store,currency").eq("active", true);
  if (rowsErr) console.error("[flyer] seed stores failed:", rowsErr.message);
  const target = pickFlyerStore((rows ?? []) as FlyerStoreRow[], parsed);
  if ("error" in target) {
    await ctx.reply(target.error === "ambiguous"
      ? `«${parsed.store}» موجود في أكتر من بلد — اكتب البلد كمان، زي: «${parsed.store} السعودية».`
      : `مش عارف «${parsed.store}» في أي بلد — اكتب البلد كمان، زي: «${parsed.store} مصر».`);
    return;
  }
  await ctx.replyWithChatAction("typing");
  const sizes = ctx.message.photo;
  const bytes = await downloadTelegramFileBytes(sizes[sizes.length - 1].file_id);
  if (!bytes) {
    await ctx.reply("معلش، مقدرتش أنزّل الصورة — جرب تاني.");
    return;
  }
  const path = `${target.country}/${new Date().toISOString().slice(0, 10)}/${crypto.randomUUID()}.jpg`;
  const { error: upErr } = await sb.storage.from("zad-flyers").upload(path, new Uint8Array(bytes), { contentType: "image/jpeg" });
  if (upErr) {
    console.error("[flyer] upload failed:", upErr.message);
    await ctx.reply(FLYER_SAVE_FAILED);
    return;
  }
  const imageUrl = `${FLYER_PREFIX}${path}`;
  const reply = await callCoreIntelligence<{ ok?: boolean; deals?: Array<{ item_name: string; price: number; price_before: number | null; valid_until: string | null }> }>(
    "store_deals_flyer", { store: target.store, country: target.country, currency: target.currency, image_url: imageUrl, caption: ctx.message.caption ?? "" },
  );
  const deals = reply?.ok && Array.isArray(reply.deals) ? reply.deals : [];
  let put = 0;
  let refused = 0;
  const items: string[] = [];
  let until: string | null = null;
  for (const deal of deals) {
    const { data, error } = await sb.rpc("zad_deal_put", { p: flyerDealPayload(target, deal, imageUrl) });
    if (!error && (data as { ok?: boolean } | null)?.ok) {
      put++;
      items.push(`${deal.item_name} بـ${deal.price}${deal.price_before ? ` بدل ${deal.price_before}` : ""}`);
      if (deal.valid_until && (!until || deal.valid_until.slice(0, 10) > until)) until = deal.valid_until.slice(0, 10);
    } else {
      refused++;
      if (error) console.error("[flyer] deal put failed:", error.message);
    }
  }
  if (put === 0) {
    const { error: rmErr } = await sb.storage.from("zad-flyers").remove([path]);
    if (rmErr) console.error("[flyer] cleanup failed:", rmErr.message);
  }
  console.log(`[flyer] ${target.country} «${target.store}» read=${deals.length} put=${put} refused=${refused}`);
  await ctx.reply(flyerReply(target.store, { read: !!reply?.ok, put, refused, items, until }));
}

bot.on("message:photo", async (ctx) => {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const userId = await resolveUserId(sb, ctx.chat.id);
  if (isFlyerPhoto(ctx.chat.id, adminChatId(Deno.env.get("ZAD_ADMIN_CHAT_ID")), !!userId, ctx.message.caption)) {
    await handleFlyerPhoto(ctx);
    return;
  }
  if (!userId) {
    await ctx.reply("أهلاً! لو عندك كود ربط من تطبيق زاد ابعته كده: /start الكود");
    return;
  }
  // البوابة المدفوعة — قبل التنزيل عن قصد: مستخدم مقفول ميصحش نصرف عليه
  // تنزيل ملف ولا نداء موديل. النص بتاعه لسه شغال مجاناً، فهو مش مقطوع.
  const gate = await mediaGate(sb, userId, "scan");
  if (!gate.allowed) {
    await ctx.reply(gate.reply!);
    return;
  }

  await ctx.replyWithChatAction("typing");

  // آخر عنصر في مصفوفة PhotoSize دايماً أعلى دقة بعتها تليجرام (الترتيب تصاعدي مضمون)
  const sizes = ctx.message.photo;
  const largest = sizes[sizes.length - 1];
  const bytes = await downloadTelegramFileBytes(largest.file_id);
  if (!bytes) {
    await ctx.reply("معلش، مقدرتش أنزّل الصورة — جرب تاني.");
    return;
  }

  const result = await callCoreIntelligence<AnalyzeReceiptResult>("analyze_receipt", {
    image_base64: arrayBufferToBase64(bytes),
    mime_type: "image/jpeg", // تليجرام بيضغط صور الـ photo دايماً JPEG
  });
  if (!result || (result.items.length === 0 && (!result.total || result.total <= 0))) {
    await ctx.reply("معلش، مقدرتش أقرا حاجة واضحة في الصورة دي — جرب صورة أوضح.");
    return;
  }

  // كارت ميزانية/رصيد (سكرين شوت راتب أو رصيد حساب، مش فاتورة مقاضي فعلية): مفيش أصناف
  // نحقنها، ومفيش مصروف نسجله — كتابة monthly_limit من رقم OCR بدون تأكيد صريح خطر (رقم
  // غلط بيكسر كل حسابات الميزانية). أقصى حاجة آمنة: نعرض الرقم اللي اتقرا ونوجّه المستخدم
  // يأكده بجملة عادية في الشات، اللي عنده مسار تأكيد فعلي بالفعل (voice_agent/chat actions).
  // وين تروح الصورة: كلام العميل في الكابشن الأول، وبعده نوع القارئ (photoRoute.ts).
  const route = routePhoto(result.receiptType, ctx.message.caption);

  if (route === "budget_card") {
    // مفيش مسار كتابة لـ monthly_limit من الشات/الصوت حالياً (check_budget قراءة بس) —
    // مينفعش نعد المستخدم بأمر نصي بيسجلها، فبس نوضح إنها مش فاتورة ونوجهه للتطبيق.
    const amountHint = result.total > 0
      ? `قريت رقم ${result.total} في الصورة دي، بس شكلها كارت رصيد أو راتب مش فاتورة مقاضي — مقريتش منها أصناف. لو عايز تحدد ميزانيتك، ده من تطبيق زاد.`
      : "الصورة دي شكلها كارت رصيد أو راتب مش فاتورة، فمقريتش منها أصناف.";
    await ctx.reply(amountHint);
    return;
  }

  // OCR only supplies fields. Nothing is written before the customer picks a button (owner's
  // decision 2026-10-19, ZAD_PLAN ٣.٦ ج): the money and the lines are held together in
  // telegram_pending_writes, and «سجّل الكل» / «المخزن بس» send them as one purchase
  // (zad_record_purchase_service). Before, the pantry filled at once and a «لأ» left half a
  // purchase behind.
  const currencyOf = async () =>
    (await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle()).data?.currency ?? "غير معروف";
  const wallet = receiptWallet(result.paymentMethod);
  const total = result.total > 0 ? Math.round(result.total * 100) / 100 : null;

  async function holdPurchase(input: {
    title: string; category: string; sourceType: string; lines: PurchaseLine[]; merchant: string | null; before?: string;
  }): Promise<boolean> {
    const { data: pending, error } = await sb.from("telegram_pending_writes").insert({
      user_id: userId, chat_id: ctx.chat.id, txn_kind: "expense", amount: total,
      title: input.title, category: input.category, confidence: 0.75, wallet,
      merchant_name: input.merchant, source_type: input.sourceType,
      purchase_lines: input.lines.length > 0 ? input.lines : null,
    }).select("id").single();
    if (error || !pending) {
      console.error("photo purchase pending insert failed:", error?.message);
      return false;
    }
    const preview = purchasePreview(input.lines);
    const body = total
      ? confirmSpendMessage({ is_spend: true, kind: "expense", amount: total, title: input.title, category: input.category, confidence: 0.75 }, await currencyOf(), wallet)
      : "مقريتش مبلغ واضح في الفاتورة — أضيف الأصناف من غير مصروف؟";
    await ctx.reply(
      [input.before, preview, body].filter((s) => s).join("\n\n"),
      { reply_markup: toGrammyKeyboard(purchaseKeyboard((pending as { id: string }).id, { hasAmount: total !== null, hasLines: input.lines.length > 0 })) },
    );
    return true;
  }

  if (route === "pharmacy" && result.items.length > 0) {
    // المعروف يدخل مع الشرا، والجديد بتأكيد واحد للفاتورة كلها (قرار المالك ١٣/١١ — كانت رسالة لكل دوا):
    // دوا جديد بيفتح تذكيرات، فمايتضافش من غير ضغطة. ولمين من الكابشن («دا دوا مامتي»)، ولو مقالش
    // الأزرار بتسأل — والعقل (add_pharmacy_item) هو اللي بيقرر صيدلية مين.
    const { data: meds } = await sb.from("zad_pharmacy_items").select("name").eq("user_id", userId);
    const { known, fresh } = splitPhotoMedicines(
      result.items,
      ((meds ?? []) as Array<{ name: string | null }>).map((m) => m.name ?? ""),
    );
    if (fresh.length > 0) {
      const who = captionPerson(ctx.message.caption);
      const batchId = crypto.randomUUID();
      const { error: medErr } = await sb.from("telegram_pending_pharmacy").insert(fresh.map((med) => ({
        user_id: userId, chat_id: ctx.chat.id, name: med.name, unit: med.unit, quantity: med.quantity,
        category: "عام", daily_dose_count: 1, dose_times: null, batch_id: batchId,
        for_person: who?.kind === "person" ? who.label : null,
      })));
      if (medErr) {
        console.error("photo pharmacy pending insert failed:", medErr.message);
      } else {
        const members = who === null
          ? (await familyMedicineCandidates(sb, userId).catch(() => [])).filter((m) => m.granted)
          : [];
        await ctx.reply(batchMedicineMessage(fresh, who, known.length), {
          reply_markup: toGrammyKeyboard(batchMedicineKeyboard(batchId, who, members)),
        });
      }
    }
    const lines = purchaseLinesFromPhoto(known.map((m) => ({ ...m, category: "عام" })), "pharmacy");
    if (total || lines.length > 0) {
      const held = await holdPurchase({
        title: (result.storeName || "فاتورة صيدلية").slice(0, 80), category: "الرعاية الصحية",
        sourceType: "receipt", lines, merchant: result.storeName?.trim() ? result.storeName.trim().slice(0, 80) : null,
      });
      if (held) return;
    }
    if (fresh.length === 0) await ctx.reply("معلش، ملقتش أصناف واضحة في الصورة دي.");
    return;
  }

  // أصناف المخزون من فاتورة بقالة بس — أكل مطعم أو بنزين أو خدمة مش حاجة في البيت. أسعار البون
  // للجمهور («اتشاف هنا») بتتبلّغ من الدالة لسطور المخزن، مع الشرا.
  const lines = purchaseLinesFromPhoto(route === "grocery" ? result.items : [], "pantry");
  if (total || lines.length > 0) {
    const held = await holdPurchase({
      title: (result.storeName || "فاتورة").slice(0, 80), category: (result.category || "أخرى").slice(0, 40),
      // المصروف بيتسجل إنه من فاتورة وباسم المحل (20261011170000) — زي فاتورة التطبيق.
      sourceType: "receipt", lines, merchant: result.storeName?.trim() ? result.storeName.trim().slice(0, 80) : null,
    });
    if (held) return;
  }

  await ctx.reply("معلش، ملقتش أصناف ولا مبلغ واضح في الصورة دي.");
});

/**
 * «سجّل الكل» / «المخزن بس» على صف محجوز: نفس بروتوكول تأكيد المصروف (claim بـstatus، ولو فشل
 * يرجع pending)، والكتابة كلها في zad_record_purchase_service. مفتاح الشرا = id الصف، فداسة مرتين
 * أو إعادة بعد فشل ملتبس بترجع نفس الرد. مصروف بنفس المبلغ من دقايق (غالباً صف البنك لنفس الدفعة)
 * = دمج، زي شيت الفاتورة في التطبيق: مصروف واحد، والأصناف بتدخل.
 */
async function recordPendingPurchase(
  ctx: { reply: (t: string) => Promise<unknown> },
  sb: SupabaseClient,
  userId: string,
  row: PendingPurchase & { status: string; expires_at: string },
  mode: PurchaseMode,
): Promise<void> {
  if (row.status !== "pending") {
    await ctx.reply("الطلب ده اتعامل معاه قبل كده.");
    return;
  }
  if (new Date(row.expires_at) < new Date()) {
    await sb.from("telegram_pending_writes").update({ status: "cancelled" }).eq("id", row.id);
    await ctx.reply("الطلب ده انتهت صلاحيته — ابعت الفاتورة تاني.");
    return;
  }
  const purchase = purchaseFromPending(row, mode);
  if (!purchase) {
    await ctx.reply(mode === "all" ? "مفيش مبلغ في الفاتورة دي أسجله." : "مفيش أصناف في الفاتورة دي أضيفها.");
    return;
  }
  const { error: claimError } = await sb.from("telegram_pending_writes")
    .update({ status: "confirmed" }).eq("id", row.id).eq("status", "pending");
  if (claimError) {
    await ctx.reply("حصلت مشكلة، جرب تاني.");
    return;
  }

  const send = (p: Record<string, unknown>) =>
    sb.rpc("zad_record_purchase_service", { p_user: userId, p_purchase: p });
  let { data, error } = await send(purchase);
  let result = data as Record<string, unknown> | null;
  const twin = (result?.twin as { id?: string } | undefined)?.id;
  if (!error && result?.status === "duplicate_suspected" && twin) {
    ({ data, error } = await send({ ...purchase, merge_with: twin }));
    result = data as Record<string, unknown> | null;
  }
  if (error || result?.ok !== true) {
    console.error("telegram purchase failed:", error?.message ?? String(result?.reason ?? result?.status ?? "no result"));
    await sb.from("telegram_pending_writes").update({ status: "pending" }).eq("id", row.id);
    await ctx.reply("معلش، التسجيل فشل — جرب تاني.");
    return;
  }

  const done = purchaseDoneLine(result);
  if (mode === "lines") {
    await ctx.reply(`تمام ✅ ${done || "الأصناف اتضافت"} — من غير مصروف.`);
    return;
  }
  const { data: u } = await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle();
  const cur = (u as { currency?: string } | null)?.currency ?? "غير معروف";
  const merged = result.status === "merged" ? " (على نفس عملية البنك)" : "";
  await ctx.reply(
    `اتسجل ✅ ${isolate(sanitizeName(row.title))} — ${isolate(money(Number(row.amount), cur))}${merged}` +
      (done ? `\n${done}` : ""),
  );
}

// Bank notifications use one durable proposal shared with Android. The RPC locks the
// row and posts at most one transaction, so two quick taps or an app + Telegram race
// both return the same terminal result without duplicating money. Shared by the buttons
// and by a typed «أيوه/لا» (2026-09-25).
async function resolveProposalAndReply(
  ctx: { reply: (t: string) => Promise<unknown> },
  sb: SupabaseClient,
  chatId: number,
  userId: string,
  proposalId: string,
  decision: TransactionProposalDecision,
): Promise<void> {
  const { data: result, error } = await sb.rpc("zad_resolve_transaction_proposal_service", {
    p_user: userId,
    p_proposal: proposalId,
    p_decision: decision,
    p_channel: "telegram",
  });
  if (error || !result) {
    console.error("transaction proposal resolution failed:", error?.message ?? "missing result");
    await ctx.reply("معلش، مقدرتش أنفذ القرار دلوقتي. جرب تاني.");
    return;
  }
  const resolved = result as { ok?: boolean; status?: string; already_resolved?: boolean };
  if (resolved.status === "duplicate_suspected") {
    // الدالة ماقيدتش: فيه معاملة متسجلة بنفس المبلغ من ربع ساعة. نفس السؤال اللي بيظهر
    // في التطبيق، والقرار التالي (pd/ps) بيرجع لنفس الدالة.
    if (!(await sendDuplicateProposalQuestion(sb, chatId, userId, proposalId))) {
      await ctx.reply("فيه عملية متسجلة بنفس المبلغ في نفس الوقت تقريبًا. افتح التطبيق وقولي دي نفس المعاملة ولا لأ.");
    }
    return;
  }
  if (resolved.status === "merged") {
    await ctx.reply(resolved.already_resolved ? "اتحسبت مرة واحدة بالفعل." : "تمام، اعتبرتهم معاملة واحدة ومش هتتحسب مرتين.");
    return;
  }
  if (resolved.status === "needs_classification") {
    // "عملية تانية" على اقتراح اتجاهه لسه مش معروف — مايتقيدش بتخمين.
    await sendTelegramMessage(chatId, "تمام، عملية تانية. دي مصروف ولا دخل ولا تحويل؟",
      transactionProposalKeyboard(proposalId, "needs_classification"));
    return;
  }
  if (resolved.status === "expired") {
    await ctx.reply("الطلب ده انتهت صلاحيته.");
    return;
  }
  if (resolved.status === "rejected") {
    await ctx.reply(resolved.already_resolved ? "العملية كانت مرفوضة بالفعل." : "تمام، العملية اترفضت ومش هتتحسب.");
    return;
  }
  if (resolved.status === "posted") {
    await ctx.reply(resolved.already_resolved ? "العملية كانت متسجلة بالفعل، وماتكررتش." : "تمام، اتأكدت واتسجلت مرة واحدة.");
    return;
  }
  await ctx.reply("القرار موصلش لحالة نهائية. افتح التطبيق وراجع العملية.");
  return;
}

// ── تسوية تذكير الجرعة: زرار أو كلام، نفس المسار (٢٠٢٦-٠٩-١٩، ومخدتهاش ٢٠٢٦-٠٩-٢٥) ──
//
// باب واحد (ZAD_PLAN ٣.٤): الكتابة نفسها في أداة العقل answer_dose_reminder (_shared/doseDoor.ts)،
// والبوت بيعرض ردها بس. الرد بيقول صراحةً لو حاجة ماتسجلتش.
async function settleDose(_sb: SupabaseClient, userId: string, momentId: string, action: DoseAction): Promise<string> {
  const done = await agentExecute(userId, "answer_dose_reminder", { moment_id: momentId, action });
  return done.summary?.replace(/^مرفوض:\s*/, "")
    ?? "معلش، مقدرتش أسجّل ده دلوقتي — ماتسجلش، جرّب من صفحة الصيدلية في التطبيق.";
}

/**
 * آخر تذكير جرعة اتبعت للعميل من ٣ ساعات ومحدش رد عليه — عشان «أخدته» / «لا» المكتوبة
 * تتربط بيه. «محدش رد» = مفيش صف في `zad_pharmacy_doses` للخانة دي لأي دوا فيها.
 */
async function openDoseMoment(sb: SupabaseClient, userId: string): Promise<{ id: string; sentAt: number } | null> {
  const since = new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString();
  const { data } = await sb.from("zad_voice_moments")
    .select("id,facts,sent_at,created_at")
    .eq("user_id", userId)
    .in("moment", [...DOSE_MOMENTS])
    .eq("status", "sent")
    .gte("created_at", since)
    .order("created_at", { ascending: false })
    .limit(5);
  for (const row of (data ?? []) as Array<{ id: string; facts: Record<string, unknown>; sent_at: string | null; created_at: string }>) {
    const ids = Array.isArray(row.facts?.item_ids) ? (row.facts.item_ids as unknown[]).map(String) : [];
    const scheduledAt = typeof row.facts?.scheduled_at === "string" ? row.facts.scheduled_at : null;
    if (ids.length === 0 || !scheduledAt) continue;
    const slotOf = doseSlots(row.facts, scheduledAt);
    const { data: answered } = await sb.from("zad_pharmacy_doses")
      .select("item_id,scheduled_at")
      .eq("user_id", userId).in("item_id", ids);
    const done = new Set(((answered ?? []) as Array<{ item_id: string; scheduled_at: string | null }>)
      .filter((a) => a.scheduled_at)
      .map((a) => `${a.item_id}|${new Date(a.scheduled_at!).getTime()}`));
    // مفتوح لو أي دوا في التذكير لسه ماتجاوبش عليه في خانته.
    if (ids.some((id) => !done.has(`${id}|${new Date(slotOf(id)).getTime()}`))) {
      return { id: row.id, sentAt: new Date(row.sent_at ?? row.created_at).getTime() };
    }
  }
  return null;
}

/** آخر اقتراح معاملة بنكية لسه مستني قرار (نفس الحالات اللي الأزرار بتشتغل عليها). */
async function openProposal(sb: SupabaseClient, userId: string): Promise<{ id: string; status: string; createdAt: number } | null> {
  const { data } = await sb.from("zad_transaction_proposals")
    .select("id,status,created_at")
    .eq("user_id", userId)
    .in("status", ["awaiting_confirmation", "needs_classification"])
    .gt("expires_at", new Date().toISOString())
    .gte("created_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  const row = data as { id: string; status: string; created_at: string } | null;
  return row ? { id: row.id, status: row.status, createdAt: new Date(row.created_at).getTime() } : null;
}

bot.on("callback_query:data", async (ctx) => {
  await ctx.answerCallbackQuery();
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const chatId = ctx.chat?.id;
  if (!chatId) return;

  const userId = await resolveUserId(sb, chatId);
  if (!userId) {
    await ctx.reply("الحساب ده مش مربوط — افتح تطبيق زاد واعمل كود ربط.");
    return;
  }

  const data = ctx.callbackQuery.data;

  const country = parseCountryCallback(data);
  if (country) {
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    // نفس اللي شاشة اختيار السوق في التطبيق بتكتبه (setMarket)، ونقرا الصف تاني قبل ما نقول «تمام».
    const { data: saved, error } = await sb.from("zad_users")
      .update({ country: country.country, currency: country.currency })
      .eq("id", userId).select("country").maybeSingle();
    const ok = !error && (saved as { country?: string } | null)?.country === country.country;
    if (!ok) console.error("country save failed:", error?.message ?? "row not read back");
    await ctx.reply(ok ? countrySavedReply(country.label) : "ماقدرتش أحفظ البلد دلوقتي — جرّب تاني بعد شوية، أو اختارها من إعدادات التطبيق.");
    return;
  }

  // ── زر الجرعة: قاعدة البيانات الأول، الشكر بعدين (٢٠٢٦-٠٩-١٩) ─────────────
  //
  // ده المسار اللي بيستبدل «اكتب أخدته وسيب الموديل يفهم». الترتيب هنا مقصود بالحرف:
  // بنقرا اللحظة من `zad_voice_moments` (مصدر الحقيقة الوحيد لأسماء الأدوية
  // ومواعيدها — مفيش أي اسم بييجي من كلام الموديل)، بننادي الـRPC الذرّية لكل دوا،
  // وبنرد على العميل **بس** لو الكتابة نجحت. أي فشل بيقول له صراحةً إنها ماتسجلتش.
  const doseCallback = parseDoseCallback(data);
  if (doseCallback) {
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    await ctx.reply(await settleDose(sb, userId, doseCallback.momentId, doseCallback.action));
    return;
  }

  // «اقفل يومك»: اليوم بيتقفل في الداتابيز الأول، والرد بعدين. الملكية واليوم بيتحققوا جوه الـRPC.
  const closeDay = parseCloseDayCallback(data);
  if (closeDay) {
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    const { data: result, error } = await sb.rpc("zad_close_day_service", {
      p_user: userId, p_moment: closeDay.momentId, p_outcome: closeDay.outcome,
    });
    if (error) console.error("[close_day] rpc failed:", error.message);
    await ctx.reply(closeDayReply(closeDay.outcome, error ? null : result as Parameters<typeof closeDayReply>[1]));
    return;
  }

  // «ده المرتب؟»: الدورة بتتنقل في الداتابيز الأول (الملكية من اللحظة جوه الـRPC)، والرد بعدين.
  const salary = parseSalaryCallback(data);
  if (salary) {
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    const { data: result, error } = await sb.rpc("zad_salary_cycle_service", {
      p_user: userId, p_moment: salary.momentId, p_yes: salary.yes,
    });
    if (error) console.error("[salary_cycle] rpc failed:", error.message);
    await ctx.reply(salaryReply(error ? null : result as Parameters<typeof salaryReply>[0]));
    return;
  }

  // حدث حياة (ZAD_PLAN ٢.٨): «سجّله وفكّرني» / «لأ» — نفس القرار بتاع كارت التطبيق، والملكية بـuser_id.
  const lifeEvent = parseLifeEventCallback(data);
  if (lifeEvent) {
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    const result = await decideLifeEvent(sb, userId, lifeEvent.id, lifeEvent.yes).catch((e) => {
      console.error("[life_event] decide failed:", (e as Error)?.message);
      return null;
    });
    await ctx.reply(lifeEventReply(result));
    return;
  }

  // عرض الصبح (ZAD_PLAN ٤.٢٠): «ضيفه لقايمتي» / «مش مهتم» — الملكية والكتابة جوه الـRPC، والرد بعدين.
  const deal = parseDealCallback(data);
  if (deal) {
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    const { data: result, error } = deal.wrong
      ? await sb.rpc("zad_deal_report_service", { p_user: userId, p_moment: deal.momentId })
      : await sb.rpc("zad_deal_answer_service", { p_user: userId, p_moment: deal.momentId, p_add: deal.add });
    if (error) console.error("[deal_answer] rpc failed:", error.message);
    await ctx.reply(dealReply(error ? null : result as Parameters<typeof dealReply>[0]));
    return;
  }

  // «اتعلمت إن» (ZAD_PLAN ٥.٢): «صح / مش صح» — الملكية والجواب الواحد جوه الـRPC، والرد بعدين.
  const learning = parseLearningCallback(data);
  if (learning) {
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    const { data: result, error } = await sb.rpc("zad_house_learning_answer_service", {
      p_user: userId, p_learning: learning.learningId, p_yes: learning.yes,
    });
    if (error) console.error("[house_learning] rpc failed:", error.message);
    await ctx.reply(learningReply(error ? null : result as Parameters<typeof learningReply>[0]));
    return;
  }

  // تجربة الأسبوعين (ZAD_PLAN ٥.٤): «نجرب / لأ» ثم «ثبّتها / بطّلها» — المرحلة والملكية جوه الـRPC.
  const habitTrial = parseHabitTrialCallback(data);
  if (habitTrial) {
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    const { data: result, error } = await sb.rpc("zad_habit_trial_answer_service", {
      p_user: userId, p_trial: habitTrial.trialId, p_yes: habitTrial.yes,
    });
    if (error) console.error("[habit_trial] rpc failed:", error.message);
    await ctx.reply(habitTrialReply(error ? null : result as Parameters<typeof habitTrialReply>[0]));
    return;
  }

  // مراجعة الذاكرة (ZAD_PLAN ٥.٣): زرار لكل ملاحظة — بيتشال لوحده بس، عشان الباقيين يفضلوا يتجاوبوا.
  const memoryCheck = parseMemoryCheckCallback(data);
  if (memoryCheck) {
    const { data: result, error } = await sb.rpc("zad_memory_check_answer_service", {
      p_user: userId, p_check: memoryCheck.checkId, p_yes: memoryCheck.yes,
    });
    if (error) console.error("[memory_check] rpc failed:", error.message);
    const rows = (ctx.callbackQuery?.message as { reply_markup?: { inline_keyboard?: InlineKeyboardButton[][] } } | undefined)
      ?.reply_markup?.inline_keyboard ?? [];
    const left = new InlineKeyboard();
    for (const row of rows) {
      if (row.some((b) => b.callback_data?.startsWith(`mc:${memoryCheck.checkId}:`))) continue;
      for (const b of row) b.url ? left.url(b.text, b.url) : left.text(b.text, b.callback_data ?? "");
      left.row();
    }
    await ctx.editMessageReplyMarkup({ reply_markup: left }).catch(() => {});
    await ctx.reply(memoryCheckReply(error ? null : result as Parameters<typeof memoryCheckReply>[0]));
    return;
  }

  // «✏️ المبلغ غلط» (٢٠٢٦-٠٩-٢٥): الاقتراح بيترفض — الرقم الغلط مايدخلش الدفتر أبداً — والعميل
  // بيتقاله يكتب المبلغ الصح، فبيعدّي على لفة الوكيل وزرار تأكيد عادي زي أي مصروف.
  const amountWrongId = parseAmountWrongCallback(data);
  if (amountWrongId) {
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    const { data: result, error } = await sb.rpc("zad_resolve_transaction_proposal_service", {
      p_user: userId, p_proposal: amountWrongId, p_decision: "reject", p_channel: "telegram",
    });
    const status = (result as { status?: string } | null)?.status;
    if (error || (status !== "rejected")) {
      console.error("amount-wrong reject failed:", error?.message ?? JSON.stringify(result));
      await ctx.reply(status === "posted"
        ? "العملية دي كانت اتسجلت بالفعل — عدّل المبلغ من صفحة المعاملات في التطبيق."
        : "معلش، مقدرتش أقفل الاقتراح ده دلوقتي — جرب تاني.");
      return;
    }
    await ctx.reply("تمام، شلت الرقم الغلط ومش هيتحسب. ابعتلي المبلغ الصح كده: «صرفت ١٥٠ جنيه في المكان» وأنا أسجلها بعد ما تأكد.");
    return;
  }

  // رفض مبادرة استباقية ← ذاكرة مهيكلة الماسح بيقراها (subject_kind/suppress_until).
  // الملكية بتتحقق جوه الدالة نفسها (المهمة لازم تكون بتاعة userId المحلول من الشات).
  // نداء الرفيق: [🍖 أكّله] / [💧 اسقيه] بيكتب وقت الأكلة أو الشربة على السيرفر (zad_companion_care، اللي
  // الموبايل بيسحب منه والسيرفر بيكسب — greatest()). last_care_at والسلسلة مابيتلمسوش: دول حساب الموبايل.
  const petCare = parsePetCareCallback(data);
  if (petCare) {
    const now = new Date().toISOString();
    const { data: careRow, error: careErr } = await sb.from("zad_companion_care")
      .update(petCare.care === "fed" ? { fed_at: now, updated_at: now } : { watered_at: now, updated_at: now })
      .eq("user_id", userId)
      .select("user_id")
      .maybeSingle();
    if (careErr || !careRow) {
      if (careErr) console.error("[pet_care] update failed:", careErr.message);
      await ctx.reply("معرفتش أوصله دلوقتي — افتح زاد واهتم بيه من هناك 💛");
      return;
    }
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    await ctx.reply(petCareReply(petCare.care));
    return;
  }

  // «تمام» / «قولّي أكتر» تحت مبادرة: رد، مش رفض — مفيش كتم. «عرفت خلاص» على رسايل قديمة بيتعامل زي «تمام»: ده
  // اللي العميل كان يقصده (بلاغ المالك ١١/١١: أي زرار كان بيسكّت التنبيه أيام).
  const proactiveReply = parseProactiveReplyCallback(data);
  const oldKnew = parseProactiveDismissCallback(data);
  if (proactiveReply || oldKnew?.reason === "timing") {
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    if (proactiveReply?.kind === "more") {
      await ctx.replyWithChatAction("typing");
      const more = await agentTurnReply(sb, userId, chatId, PROACTIVE_MORE_PROMPT);
      await ctx.reply(more.lines.length ? clampForTelegram(more.lines.join("\n\n")) : "معلش، مش قادر أشرح دلوقتي — ابعتلي سؤالك وهرد عليك أول ما أقدر 🙏");
      return;
    }
    // لفة من العميل: حارس النتيجة (zad_guardian_outcomes) بيعدّها رد، فالنوع مابيسكتش لوحده بعدين كأنه اتجاهل.
    await recordChatTurn(sb, userId, "user", PROACTIVE_OK_TURN);
    await ctx.reply("💛");
    return;
  }

  const proactiveDismiss = oldKnew;
  if (proactiveDismiss) {
    const { data: result, error } = await sb.rpc("zad_memory_record_proactive_dismissal", {
      p_user: userId, p_task_id: proactiveDismiss.taskId, p_reason: proactiveDismiss.reason,
    });
    if (error) console.error("[proactive_dismissal] rpc failed:", error.message);
    else if (!(result as { ok?: boolean } | null)?.ok) console.error("[proactive_dismissal] rejected:", JSON.stringify(result));
    // الأزرار بتتشال عشان نفس الرسالة ماتترفضش مرتين بسببين مختلفين.
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    await ctx.reply(proactiveDismissReply(error ? null : result as Parameters<typeof proactiveDismissReply>[0]));
    return;
  }

  // رد سريع على الإشعار البنكي الغامض (أزرار مصروف/إيداع/تجاهل) — بيبعت نص جاهز
  // لنفس مسار agent_turn، فبياخد تأكيد وaudit زي أي رسالة عادية.
  const reviewCallback = parseNotificationReviewCallback(data);
  if (reviewCallback) {
    if (reviewCallback.direction === "skip") {
      await ctx.reply("تمام، الإشعار ده هيتتجاهل ومش هيتسجل.");
      return;
    }
    const event = await sb.from("zad_notification_ingest_events")
      .select("id,package_name,title,body")
      .eq("id", reviewCallback.eventId)
      .eq("user_id", userId)
      .maybeSingle();
    const ev = event.data as { package_name: string; title: string | null; body: string } | null;
    if (!ev) {
      await ctx.reply("الإشعار ده مش موجود أو اتقفل — جرّب ابعتلي المبلغ بنفسك.");
      return;
    }
    const snippet = `${ev.title ?? ""} ${ev.body}`.trim().slice(0, 200);
    const directionText = reviewCallback.direction === "expense" ? "ده مصروف/سحب" : "ده إيداع";
    const turn = await agentTurn(userId, `${directionText}. الإشعار: ${snippet}`);
    if (turn.result?.reply) {
      await ctx.reply(turn.result.reply);
    } else {
      await ctx.reply("استلمت ردك — هسألك تفاصيل لو احتجت أرقام أدق.");
    }
    return;
  }

  // Bank notifications use one durable proposal shared with Android. The RPC locks the
  // row and posts at most one transaction, so two quick taps or an app + Telegram race
  // both return the same terminal result without duplicating money.
  const proposalCallback = parseTransactionProposalCallback(data);
  if (proposalCallback) {
    await resolveProposalAndReply(ctx, sb, chatId, userId, proposalCallback.proposalId, proposalCallback.decision);
    return;
  }

  // تأكيد أداة غير مالية (tx:/tc:) — نفس بروتوكول تأكيد الفلوس بالظبط: نقرا الصف،
  // نتأكد إنه بتاع نفس المستخدم، ما اتصرفش فيه قبل كده، وما انتهتش صلاحيته؛ ندّعيه
  // بتحديث مشروط عشان ضغطتين سريعتين ما ينفذوش الأداة مرتين؛ وبعدين ننفذ عن طريق
  // zad-brain نفسه (agent_confirm) مش من هنا — تليجرام مابيكتبش عملية مؤكدة بنفسه
  // أبداً، عشان التحقق وسجل التدقيق يفضلوا في مكان واحد.
  const toolCallback = parseToolCallback(data);
  if (toolCallback) {
    const { data: pendingRow } = await sb.from("telegram_pending_tools")
      .select("id,user_id,tool,input,summary,status,expires_at")
      .eq("id", toolCallback.pendingId)
      .maybeSingle();
    const row = pendingRow as {
      id: string; user_id: string; tool: string; input: Record<string, unknown>;
      summary: string; status: string; expires_at: string;
    } | null;

    if (!row || row.user_id !== userId) {
      await ctx.reply("الطلب ده مش موجود.");
      return;
    }
    if (row.status !== "pending") {
      await ctx.reply("الطلب ده اتصرف فيه خلاص.");
      return;
    }
    if (toolCallback.action === "cancel") {
      await sb.from("telegram_pending_tools").update({ status: "cancelled" }).eq("id", row.id);
      await ctx.reply("تمام، ملغي.");
      return;
    }
    if (new Date(row.expires_at).getTime() < Date.now()) {
      await sb.from("telegram_pending_tools").update({ status: "cancelled" }).eq("id", row.id);
      await ctx.reply("الطلب ده عدى عليه وقت طويل — ابعته تاني لو لسه عايزه.");
      return;
    }

    const { error: claimError } = await sb.from("telegram_pending_tools")
      .update({ status: "confirmed" })
      .eq("id", row.id)
      .eq("status", "pending");
    if (claimError) {
      await ctx.reply("معلش، حصلت مشكلة — جرب تاني.");
      return;
    }

    const done = await agentConfirm(userId, row.tool, row.input);
    if (!done.ok) {
      // رجّع الصف لـ pending: الأداة ماتنفذتش، فالعميل لازم يقدر يضغط تأكيد تاني
      // بدل ما الطلب يفضل "مؤكد" وهو محصلش — نفس تصرف تأكيد الفلوس.
      await sb.from("telegram_pending_tools").update({ status: "pending" }).eq("id", row.id);
      await ctx.reply("معلش، مقدرتش أنفذها — جرب تاني كمان شوية.");
      return;
    }
    await ctx.reply(`✅ ${isolate(sanitizeName(done.summary ?? row.summary))}`);
    return;
  }

  if (data === "az") {
    await replyAmazonPicks(sb, userId, ctx.reply.bind(ctx));
    return;
  }

  if (data === "b") {
    // Phase 0 — the same RPC row the app's budget card and zad-brain read. This button
    // used to run its own calendar-month sum AND blank the ceiling whenever
    // limit_confirmed_at was null, which is null on accounts that do hold a real
    // monthly_limit (AGENT_GAP_ANALYSIS.md §6) — so it told those customers their budget
    // was 0. Both behaviours are gone: one query, one formula, salary-cycle aware.
    const { data: state, error } = await sb.rpc("zad_budget_state", { p_user: userId });
    if (error || !state) {
      console.error(`[zad-telegram-bot] /balance zad_budget_state FAILED: ${String(error?.message ?? error)}`);
      await ctx.reply("مقدرتش أحسب الرصيد دلوقتي — جرب تاني بعد شوية.");
      return;
    }
    const { data: user } = await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle();
    await ctx.reply(formatBalanceMessage(state as BudgetStateRow, (user as any)?.currency ?? ""));
    return;
  }

  if (data === "t") {
    const { data: txs } = await sb.from("zad_transactions")
      .select("title,amount,txn_kind,created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(10);
    await ctx.reply(formatTransactionsMessage((txs ?? []) as any));
    return;
  }

  if (data === "i") {
    const { data: insights } = await sb.from("zad_insights")
      .select("id,title,body")
      .eq("user_id", userId)
      .eq("status", "pending")
      // كارت عن يوم فات («تجديد بكرة ٣ أكتوبر» يوم ٥) مايتعرضش.
      .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
      .limit(5);
    const rows = (insights ?? []) as Array<{ id: string; title: string; body: string }>;
    if (rows.length === 0) {
      await ctx.reply("مفيش تنبيهات معلقة دلوقتي 👍");
    } else {
      for (const insight of rows) {
        await ctx.reply(formatInsightTitle(insight), { reply_markup: toGrammyKeyboard(dismissKeyboard(insight.id)) });
      }
    }
    return;
  }

  // «سجّل الكل» / «المخزن بس» على صورة فاتورة (٣.٦ ج). «لأ» هو زرار الإلغاء العادي (c:) تحت.
  const purchasePick = parsePurchaseCallback(data);
  if (purchasePick) {
    const { data: pendingRow } = await sb.from("telegram_pending_writes")
      .select("id,amount,title,category,status,expires_at,wallet,merchant_name,source_type,purchase_lines")
      .eq("id", purchasePick.pendingId)
      .eq("user_id", userId)
      .maybeSingle();
    if (!pendingRow) {
      await ctx.reply("الطلب ده مش موجود أو مش بتاعك.");
      return;
    }
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    await recordPendingPurchase(ctx, sb, userId, pendingRow as PendingPurchase & { status: string; expires_at: string }, purchasePick.mode);
    return;
  }

  // تأكيد/إلغاء تسجيل مصروف. الكتابة الوحيدة في zad_transactions بتحصل هنا بس،
  // بعد ضغطة تأكيد صريحة من العميل.
  const spend = parseSpendCallback(data);
  if (spend) {
    const { data: pendingRow } = await sb.from("telegram_pending_writes")
      .select("id,user_id,txn_kind,amount,title,category,status,expires_at,wallet,merchant_name,source_type,purchase_lines")
      .eq("id", spend.pendingId)
      // إعادة التحقق: الـ chat اللي بيأكد لازم يكون لسه مربوط بنفس اليوزر صاحب الطلب.
      .eq("user_id", userId)
      .maybeSingle();

    const row = pendingRow as {
      id: string; txn_kind: string; amount: number; title: string;
      category: string | null; status: string; expires_at: string; wallet: string | null;
      merchant_name: string | null; source_type: string | null; purchase_lines: unknown;
    } | null;

    if (!row) {
      await ctx.reply("الطلب ده مش موجود أو مش بتاعك.");
      return;
    }
    if (row.status !== "pending") {
      await ctx.reply("الطلب ده اتعامل معاه قبل كده.");
      return;
    }
    if (new Date(row.expires_at) < new Date()) {
      await sb.from("telegram_pending_writes").update({ status: "cancelled" }).eq("id", row.id);
      await ctx.reply("الطلب ده انتهت صلاحيته — ابعت المصروف تاني.");
      return;
    }

    if (spend.action === "cancel") {
      await sb.from("telegram_pending_writes").update({ status: "cancelled" }).eq("id", row.id);
      await ctx.reply("تمام، ملغي ✖️");
      return;
    }

    // اتنقل لـ confirmed الأول: لو الإدخال فشل بعد كده مش هنكرر الكتابة، ولو ضغط
    // تأكيد مرتين بسرعة التانية هتلاقي status مش pending وتقف.
    const { error: claimError } = await sb.from("telegram_pending_writes")
      .update({ status: "confirmed" })
      .eq("id", row.id)
      .eq("status", "pending");
    if (claimError) {
      await ctx.reply("حصلت مشكلة، جرب تاني.");
      return;
    }

    const confirmed = await agentConfirm(userId, "log_transaction", {
      amount: row.amount,
      title: row.title,
      category: row.category ?? undefined,
      txn_kind: row.txn_kind,
      // اللي البون قاله (receiptWallet)؛ نص أو صوت أو بون ماقالش = card زي الأول.
      wallet: row.wallet ?? "card",
      merchant_name: row.merchant_name ?? undefined,
      source_type: row.source_type ?? undefined,
      // أصناف «اشتريت لبن وعيش بـ٤٠» (٣.٦ د): log_transaction بيبعتهم مع الفلوس لباب الشرا.
      lines: Array.isArray(row.purchase_lines) ? row.purchase_lines : undefined,
      // «➕ دي عملية تانية» تحت سؤال التكرار: الجواب من العميل نفسه.
      ...(spend.action === "again" ? { allow_duplicate: true } : {}),
    });
    if (!confirmed.ok) {
      console.error("telegram expense confirmation via zad-brain refused:", String(confirmed.summary ?? "").slice(0, 200));
      await sb.from("telegram_pending_writes").update({ status: "pending" }).eq("id", row.id);
      const refused = refusedSpendReply(confirmed.summary, row.id);
      await ctx.reply(refused.text, refused.keyboard ? { reply_markup: toGrammyKeyboard(refused.keyboard) } : undefined);
      return;
    }

    const { data: u } = await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle();
    const cur = (u as { currency?: string } | null)?.currency ?? "غير معروف";
    await ctx.reply(`اتسجل ✅ ${isolate(sanitizeName(row.title))} — ${isolate(money(row.amount, cur))}` + bankTwinNote(confirmed.summary));
    return;
  }

  // فاتورة صيدلية = تأكيد واحد (pharmacyPhoto.ts، قرار المالك ١٣/١١). نفس بروتوكول تأكيد الدوا الواحد تحت:
  // claim بـstatus، والكتابة من العقل (add_pharmacy_item) دوا دوا — وهو اللي بيقرر صيدلية مين وبيتأكد من الموافقة.
  const pharmacyBatch = parseBatchCallback(data);
  if (pharmacyBatch) {
    const { data: batchRows } = await sb.from("telegram_pending_pharmacy")
      .select("id,name,unit,quantity,category,for_person,status,expires_at")
      .eq("batch_id", pharmacyBatch.batchId)
      .eq("user_id", userId)
      .order("created_at");
    const rows = (batchRows ?? []) as Array<{
      id: string; name: string; unit: string; quantity: number; category: string;
      for_person: string | null; status: string; expires_at: string;
    }>;
    if (rows.length === 0) {
      await ctx.reply("الطلب ده مش موجود أو مش بتاعك.");
      return;
    }
    const open = rows.filter((r) => r.status === "pending");
    if (open.length === 0) {
      await ctx.reply("الطلب ده اتعامل معاه قبل كده.");
      return;
    }
    if (pharmacyBatch.choice.kind === "cancel" || open.some((r) => new Date(r.expires_at) < new Date())) {
      const expired = pharmacyBatch.choice.kind !== "cancel";
      await sb.from("telegram_pending_pharmacy").update({ status: "cancelled" })
        .eq("batch_id", pharmacyBatch.batchId).eq("user_id", userId).eq("status", "pending");
      await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
      await ctx.reply(expired ? "الطلب ده انتهت صلاحيته — ابعت الصورة تاني." : "تمام، ملغي ✖️");
      return;
    }

    let target: Record<string, unknown> = {};
    let forLabel: string | null = null;
    if (pharmacyBatch.choice.kind === "caption" && open[0].for_person) {
      target = { for_person: open[0].for_person };
      forLabel = open[0].for_person;
    } else if (pharmacyBatch.choice.kind === "member") {
      const prefix = pharmacyBatch.choice.prefix;
      const match = (await familyMedicineCandidates(sb, userId).catch(() => []))
        .filter((m) => m.granted && m.userId.toLowerCase().startsWith(prefix));
      if (match.length !== 1) {
        await ctx.reply("مقدرتش ألاقي الفرد ده في عيلتك، أو مابقاش موافق إنك تتابع أدويته. سجّلهم «بتوعي» أو ابعت الصورة تاني.");
        return;
      }
      target = { for_member_id: match[0].userId };
    }

    const { data: claimedRows, error: claimError } = await sb.from("telegram_pending_pharmacy")
      .update({ status: "confirmed" })
      .eq("batch_id", pharmacyBatch.batchId).eq("user_id", userId).eq("status", "pending")
      .select("id");
    if (claimError) {
      await ctx.reply("حصلت مشكلة، جرب تاني.");
      return;
    }
    const claimed = new Set(((claimedRows ?? []) as Array<{ id: string }>).map((r) => r.id));
    const todo = open.filter((r) => claimed.has(r.id));
    const names = todo.map((r) => r.name);
    const added: string[] = [];
    const failed: string[] = [];
    let memberName: string | null = null;
    for (const [i, row] of todo.entries()) {
      const res = await agentExecute(userId, "add_pharmacy_item", {
        name: row.name, unit: row.unit, quantity: row.quantity, category: row.category, ...target,
        // صاحب الصيدلية (لو فرد تاني) بيتبلّغ مرة واحدة بالفاتورة كلها، مع آخر دوا.
        member_notice: i === todo.length - 1 ? { names, untimed: names } : false,
      });
      if (res.ok) {
        added.push(row.name);
        memberName ??= routedMemberName(res.summary);
      } else {
        console.error("telegram batch add_pharmacy through zad-brain failed:", row.name, (res.summary ?? "no summary").slice(0, 300));
        failed.push(row.name);
        // يرجع pending: الزرار نفسه بيعيد اللي فشل بس.
        await sb.from("telegram_pending_pharmacy").update({ status: "pending" }).eq("id", row.id);
      }
    }
    if (failed.length === 0) await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    await ctx.reply(batchDoneMessage({ added, failed, memberName, forLabel }));
    return;
  }

  // تأكيد/إلغاء دواء جديد بجدول جرعات (Smart Medication Parsing). الكتابة الوحيدة في
  // zad_pharmacy_items من الشات بتحصل هنا بس، بعد ضغطة تأكيد صريحة — نفس مبدأ تسجيل
  // المصروف فوق بالظبط، لأن دواء جديد بيفتح تذكيرات متكررة لما التطبيق يعمل sync.
  const medication = parseMedicationCallback(data);
  if (medication) {
    const { data: pendingRow } = await sb.from("telegram_pending_pharmacy")
      .select("id,name,dosage,daily_dose_count,dose_times,unit,quantity,category,status,expires_at")
      .eq("id", medication.pendingId)
      .eq("user_id", userId)
      .maybeSingle();

    const row = pendingRow as {
      id: string; name: string; dosage: string | null; daily_dose_count: number;
      dose_times: string | null; unit: string; quantity: number; category: string;
      status: string; expires_at: string;
    } | null;

    if (!row) {
      await ctx.reply("الطلب ده مش موجود أو مش بتاعك.");
      return;
    }
    if (row.status !== "pending") {
      await ctx.reply("الطلب ده اتعامل معاه قبل كده.");
      return;
    }
    if (new Date(row.expires_at) < new Date()) {
      await sb.from("telegram_pending_pharmacy").update({ status: "cancelled" }).eq("id", row.id);
      await ctx.reply("الطلب ده انتهت صلاحيته — ابعت تفاصيل الدواء تاني.");
      return;
    }

    if (medication.action === "cancel") {
      await sb.from("telegram_pending_pharmacy").update({ status: "cancelled" }).eq("id", row.id);
      await ctx.reply("تمام، ملغي ✖️");
      return;
    }

    const { error: claimError } = await sb.from("telegram_pending_pharmacy")
      .update({ status: "confirmed" })
      .eq("id", row.id)
      .eq("status", "pending");
    if (claimError) {
      await ctx.reply("حصلت مشكلة، جرب تاني.");
      return;
    }

    const added = await agentExecute(userId, "add_pharmacy_item", {
      name: row.name,
      dosage: row.dosage,
      daily_dose_count: row.daily_dose_count,
      dose_times: row.dose_times,
      unit: row.unit,
      quantity: row.quantity,
      category: row.category,
    });
    if (!added.ok) {
      // السبب كان بيضيع (١٣/١١: ٩ مرات «failed» من غير ولا كلمة ليه).
      console.error("telegram add_pharmacy through zad-brain failed:", (added.summary ?? "no summary").slice(0, 300));
      await sb.from("telegram_pending_pharmacy").update({ status: "pending" }).eq("id", row.id);
      await ctx.reply("معلش، التسجيل فشل — جرب تاني.");
      return;
    }

    // مفيش AlarmManager على السيرفر — التذكيرات الفعلية بتتفعل لما تطبيق زاد يعمل sync
    // ويلاقي الدواء الجديد في zad_pharmacy_items (نفس آلية PharmacyReminderScheduler
    // اللي بتشتغل تلقائي عند أي تغيير في قائمة الأدوية).
    // من صورة: مفيش مواعيد لسه — السؤال هنا، وتحية الصبح بتسأل تاني مرة لو ماتردش (الموجة ٣، ٧أ).
    await ctx.reply(row.dose_times
      ? `اتسجل ✅ ${isolate(sanitizeName(row.name))} — المواعيد: ${isolate(row.dose_times)}\nهتلاقي التذكير شغال في التطبيق بعد أول فتح.`
      : `اتسجل ✅ ${isolate(sanitizeName(row.name))}. بتاخده الساعة كام؟ قولي («٨ الصبح و٨ بالليل») وأفعّل التذكير.`);
    return;
  }

  // «🔕 بطّل تسألني» على سؤال المخزون: كتم شهر، ومتسجل كذاكرة العقل بيشوفها (مايعرضش يسأل تاني).
  if (data === CHECKIN_OFF_CALLBACK) {
    // باب واحد (ZAD_PLAN ٣.٤): الذاكرة بيكتبها العقل (mute_checkin).
    const muted = await agentExecute(userId, "mute_checkin", {});
    if (!muted.ok) {
      console.error("[checkin_off] mute through zad-brain failed");
      await ctx.reply("معلش، مقدرتش أحفظ ده دلوقتي — جرّب تاني.");
      return;
    }
    await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => {});
    await ctx.reply("خلاص، مش هسألك عن المخزون بالليل تاني 👌 لو حبيت أرجع أسأل، قولّي.");
    return;
  }

  // Telegram Micro-Checkins — "لسه موجود ✅" / "خلص ❌" reply to a proactive daily prompt.
  const checkin = parseCheckInCallback(data);
  if (checkin) {
    const { data: promptRow } = await sb.from("telegram_checkin_prompts")
      .select("id,item_name,quantity_at_prompt,status,expires_at")
      .eq("id", checkin.promptId)
      .eq("user_id", userId)
      .maybeSingle();
    const prompt = promptRow as {
      id: string; item_name: string; quantity_at_prompt: number; status: string; expires_at: string;
    } | null;

    if (!prompt) {
      await ctx.reply("السؤال ده مش موجود أو مش بتاعك.");
      return;
    }
    if (prompt.status !== "pending") {
      await ctx.reply("رديت على السؤال ده قبل كده.");
      return;
    }
    if (new Date(prompt.expires_at) < new Date()) {
      await sb.from("telegram_checkin_prompts").update({ status: "expired" }).eq("id", prompt.id);
      await ctx.reply("السؤال ده قديم — هسأل تاني في المرة الجاية.");
      return;
    }

    // نفس نمط zad-brain's update_inventory_qty tool بالظبط: أي إجابة كمية لازم تتسجل
    // كـ observation وتعيد حساب معدل الاستهلاك، وإلا الصنف يفضل "غير معروف" للأبد
    // (Task 18 Fault B) والعقل يسأل عنه تاني وتاني من غير ما يتعلم حاجة.
    // «كتير/نصه/قليل» نسبة من آخر شرا، والعقل بيحسب الكمية (ZAD_PLAN ٣.٩). «لسه موجود» القديمة
    // (fraction = null) بتسجّل الكمية زي ما هي.
    const amount = checkin.fraction === null
      ? { new_qty: prompt.quantity_at_prompt }
      : checkin.fraction === 0 ? { new_qty: 0 } : { fraction_left: checkin.fraction };
    const observed = await agentExecute(userId, "update_inventory_qty", {
      item_name: prompt.item_name,
      ...amount,
      reason: "إجابة العميل على سؤال متابعة المخزون",
    });
    if (!observed.ok) {
      console.error("checkin: update_inventory_qty refused", prompt.item_name, observed.summary ?? "(no summary)");
      await ctx.reply("معلش، مقدرتش أحفظ إجابتك — جرّب تاني.");
      return;
    }

    await sb.from("telegram_checkin_prompts")
      .update({
        status: checkin.stillInStock ? "answered_yes" : "answered_no",
        answered_at: new Date().toISOString(),
        answer_fraction: checkin.fraction,
      })
      .eq("id", prompt.id);

    const itemLabel = isolate(sanitizeName(prompt.item_name));
    await ctx.reply(
      !checkin.stillInStock ? `سجلتها خلصت ✅ ${itemLabel}`
        : checkin.label ? `تمام ✅ ${itemLabel}: فاضل ${checkin.label} — كده بتعلم بيخلص في قد إيه.`
        : "تمام ✅ هفتكر إني سألت عنه.",
    );
    return;
  }

  const dismiss = parseDismissCallback(data);
  if (dismiss) {
    const reason = reasonForCode(dismiss.reasonCode);
    if (!reason) return;
    const { data: insight } = await sb.from("zad_insights")
      .select("title,about_item")
      .eq("id", dismiss.insightId)
      .eq("user_id", userId)
      .maybeSingle();
    await sb.from("zad_insights")
      .update({ status: "dismissed", dismiss_reason: reason, updated_at: new Date().toISOString() })
      .eq("id", dismiss.insightId)
      .eq("user_id", userId);
    const subject = (insight as any)?.about_item ?? (insight as any)?.title ?? "";
    const note = memoryNoteForDismissal(reason, subject);
    if (note) {
      await sb.rpc("zad_memory_upsert", { p_user: userId, p_scope: note.scope, p_note: note.note, p_conf: note.confidence });
    }
    await ctx.reply("تم ✅");
  }
});

// An explicitly-set project secret always wins; otherwise derive one (see context.ts for
// why). Either way WEBHOOK_SECRET is now always a real value, so grammY's secretToken
// check is genuinely enforced — previously it fell through to undefined and was skipped.
const WEBHOOK_SECRET = BOT_CONFIGURED
  ? (WEBHOOK_SECRET_ENV ?? await deriveWebhookSecret(BOT_TOKEN))
  : "";
const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/zad-telegram-bot`;

/** Self-registration. setWebhook can't be run from the deploy path used here (it needs
 * the bot token, which is a write-only secret), so the function registers itself: it
 * already has the token at runtime. Idempotent — checks getWebhookInfo first and only
 * calls setWebhook when the registered URL differs from this deployment's. */
async function ensureWebhook(force = false): Promise<Record<string, unknown>> {
  if (!BOT_CONFIGURED) {
    return { ok: false, reason: "TELEGRAM_BOT_TOKEN is not set on this project" };
  }
  try {
    const infoRes = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo`);
    const info = await infoRes.json();
    const current = info?.result?.url ?? "";
    if (!force && current === FUNCTION_URL) {
      return {
        ok: true, changed: false, url: current,
        pending: info?.result?.pending_update_count ?? 0,
        // آخر خطأ تسليم من تليجرام. مش سر — بس هو الفرق بين "تليجرام مش قادر
        // يسلّم" و"تليجرام مستلمش حاجة أصلاً"، والاتنين شكلهم واحد من برّه.
        last_error: info?.result?.last_error_message ?? null,
        last_error_at: info?.result?.last_error_date
          ? new Date(info.result.last_error_date * 1000).toISOString() : null,
      };
    }
    const setRes = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/setWebhook`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        url: FUNCTION_URL,
        secret_token: WEBHOOK_SECRET,
        allowed_updates: ["message", "callback_query"],
        drop_pending_updates: false,
      }),
    });
    const set = await setRes.json();
    console.log("ensureWebhook: setWebhook ->", JSON.stringify(set));
    return { ok: set?.ok === true, changed: true, previous: current, url: FUNCTION_URL, telegram: set };
  } catch (e) {
    console.error("ensureWebhook failed:", e);
    return { ok: false, error: String(e) };
  }
}

/**
 * مسح الطابور المتراكم عند تليجرام + إعادة الربط (٢٠٢٦-٠٩-١٩).
 *
 * لما الحلقة تكون شغالة فترة، تليجرام بيبقى ماسك مئات التحديثات المعلّقة وبيعيد
 * تسليمها أول ما الفانكشن ترجع تستجيب — يعني إصلاح الكود لوحده مش كفاية، الطابور
 * القديم لسه هينزل. `deleteWebhook` بـ`drop_pending_updates: true` بيرمي الطابور ده،
 * وبعدها `setWebhook` بيرجّع الربط.
 *
 * ⚠️ مش في `ensureWebhook` وعمره ما هيتنادى لوحده: إسقاط الطابور بيرمي كمان رسايل
 * عملاء حقيقية لسه ماتعالجتش. ده إجراء يدوي بسيكريت، مش سلوك تلقائي عند كل نشر.
 */
async function resetWebhook(): Promise<Record<string, unknown>> {
  if (!BOT_CONFIGURED) return { ok: false, reason: "TELEGRAM_BOT_TOKEN is not set on this project" };
  const before = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo`)
    .then((r) => r.json()).catch(() => null);
  const dropped = before?.result?.pending_update_count ?? null;
  const delRes = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/deleteWebhook`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ drop_pending_updates: true }),
  });
  const del = await delRes.json();
  if (del?.ok !== true) {
    console.error("resetWebhook: deleteWebhook rejected:", JSON.stringify(del));
    return { ok: false, stage: "deleteWebhook", telegram: del };
  }
  const setRes = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/setWebhook`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      url: FUNCTION_URL,
      secret_token: WEBHOOK_SECRET,
      allowed_updates: ["message", "callback_query"],
      drop_pending_updates: true,
    }),
  });
  const set = await setRes.json();
  console.log("resetWebhook: setWebhook ->", JSON.stringify(set));
  return { ok: set?.ok === true, dropped_pending: dropped, url: FUNCTION_URL, telegram: set };
}

// Register on cold start too, so a redeploy re-asserts the webhook without anyone
// having to poke it. Fire-and-forget: a Telegram outage must not stop the function
// from booting and serving updates it may already be receiving.
if (BOT_CONFIGURED) {
  ensureWebhook().catch((e) => console.error("boot ensureWebhook:", e));
} else {
  console.error("zad-telegram-bot: TELEGRAM_BOT_TOKEN is not set — bot is inert.");
}

// ── منع تكرار المعالجة (٢٠٢٦-٠٩-١٩) ─────────────────────────────────────────
//
// تليجرام بيضمن التسليم **مرة على الأقل**، مش مرة واحدة بالظبط. الـwebhook هنا بيستنى
// لفة الوكيل كلها قبل ما يرجّع 200، فأي لفة بطيئة (نداء موديل) بتتقري عنده كـtimeout
// وبيعيد تسليم نفس `update_id` — واللفة التانية بترد تاني. ده نص الحلقة اللانهائية،
// والنص التاني (راسل بوت) بيتقفل في isHumanUpdate.
//
// طبقتين عن قصد:
//  - كاش في الذاكرة: بيقفل أسرع إعادة تسليم — اللي بتنزل على نفس النسخة — من غير أي
//    استعلام. مابيكفيش لوحده: كل نسخة (isolate) ليها ذاكرتها، وتليجرام ممكن يوزّع.
//  - جدول `telegram_processed_updates`: مفتاحه الأساسي هو `update_id` نفسه، فالحجز
//    ذرّي — أول INSERT بيكسب والباقي بياخد 23505 ويترمي.
//
// بيفشل **مفتوح** عن قصد: لو الجدول مش موجود أو الداتابيز وقعت، التحديث بيتعالج.
// تكرار نادر أرحم من بوت ميت.
const seenUpdateIds = new Map<number, number>();
const SEEN_UPDATE_TTL_MS = 60 * 60_000;
const SEEN_UPDATE_MAX = 2_000;

/** `true` = التحديث ده لسه ماتعالجش وإحنا حجزناه. `false` = مكرر، يترمي بـ200. */
async function claimUpdate(sb: SupabaseClient, updateId: unknown): Promise<boolean> {
  if (typeof updateId !== "number" || !Number.isFinite(updateId)) return true;
  const now = Date.now();
  const seenAt = seenUpdateIds.get(updateId);
  if (seenAt !== undefined && now - seenAt < SEEN_UPDATE_TTL_MS) return false;
  if (seenUpdateIds.size > SEEN_UPDATE_MAX) {
    for (const [id, at] of seenUpdateIds) {
      if (now - at >= SEEN_UPDATE_TTL_MS) seenUpdateIds.delete(id);
    }
    // لسه كبير بعد التنضيف (سيل تحديثات) — الأقدم يمشي.
    while (seenUpdateIds.size > SEEN_UPDATE_MAX) {
      const oldest = seenUpdateIds.keys().next();
      if (oldest.done) break;
      seenUpdateIds.delete(oldest.value);
    }
  }
  seenUpdateIds.set(updateId, now);

  const { error } = await sb.from("telegram_processed_updates").insert({ update_id: updateId });
  if (!error) return true;
  if (error.code === "23505") {
    console.log(`[dedupe] update ${updateId} already processed — dropped`);
    return false;
  }
  console.error("[dedupe] claim failed, processing anyway:", error.code ?? "", error.message);
  return true;
}

// grammY بيستنى ١٠ ثواني بس افتراضياً، ولفة العقل (موديل + أدوات + مراجعة) بتعدّيهم:
// ٢٠٢٦-٠٩-٢٩ ١٩:٣٨ «Request timed out after 10000 ms». الرد وصل ساعتها لأن الشغل كمّل
// بعد ما رجّعنا 200، بس الـruntime مش ملزم يكمّله بعد الرد. ٥٠ ثانية تحت مهلة تليجرام،
// والتكرار لو حصل بيقفله claimUpdate.
const handleUpdate = webhookCallback(bot, "std/http", { secretToken: WEBHOOK_SECRET, timeoutMilliseconds: 50_000 });

/** اسم البوت المسجّل بالتوكن ده — تشخيص، ومعلومة عامة مش سر. */
async function identifyBot(): Promise<Record<string, unknown>> {
  if (!BOT_CONFIGURED) return { ok: false, reason: "no token" };
  try {
    const res = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/getMe`);
    const j = await res.json();
    return j?.ok
      ? { ok: true, username: j.result?.username, id: j.result?.id, name: j.result?.first_name }
      : { ok: false, telegram: j?.description ?? "getMe failed" };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

Deno.serve(async (req: Request) => {
  // GET is not a Telegram update — it's the health/registration probe. Reports whether
  // the webhook is wired up, without ever echoing the token or the secret itself.
  if (req.method === "GET") {
    // زرار «افتح زاد» تحت رسايل الرفيق، وزرار أمازون لتطبيق أمازون (telegram.ts): تحويل لمكان من قايمة مقفولة.
    const query = new URL(req.url).searchParams;
    const open = query.get("open");
    if (open !== null) {
      const location = open === "amazon"
        ? amazonAppRedirect(query.get("u"), req.headers.get("user-agent"))
        : appLinkRedirect(open, query.get("code"));
      return location
        ? new Response(null, { status: 302, headers: { Location: location, "Cache-Control": "no-store" } })
        : new Response("not found", { status: 404 });
    }
    const status = await ensureWebhook(query.get("force") === "1");
    return new Response(
      JSON.stringify({
        function: "zad-telegram-bot",
        // Presence only — never the values themselves.
        config: {
          bot_token: BOT_CONFIGURED,
          webhook_secret: WEBHOOK_SECRET.length > 0,
          webhook_secret_source: WEBHOOK_SECRET_ENV ? "env" : (BOT_CONFIGURED ? "derived" : "none"),
          supabase_url: Boolean(SUPABASE_URL),
          service_role_key: Boolean(SERVICE_ROLE_KEY),
        },
        webhook: status,
        // اسم البوت من getMe — معلومة عامة (أي حد يقدر يشوفها في تليجرام)، مش سر.
        // بتجاوب على السؤال الوحيد اللي مافيش طريقة تانية تجاوبه: هل التوكن
        // المسجّل هنا بتاع نفس البوت اللي العميل بيبعتله؟ لو لأ، كل حاجة تانية
        // هتبان سليمة (webhook مظبوط، صفر معلّق) والرسايل تروح لمكان تاني.
        bot: await identifyBot(),
      }, null, 2),
      { headers: { "Content-Type": "application/json" } },
    );
  }
  // Daily check-in cron trigger — see the secrets block at the top for why this
  // needs its own auth instead of relying on verify_jwt. Checked before BOT_CONFIGURED so
  // a misconfigured bot token still reports a clear reason instead of falling through to
  // "bot not configured" below, which would otherwise read as this branch not existing.
  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "daily_checkins") {
    if (!(await secretMatches(req.headers.get("X-Checkin-Cron-Secret"), "ZAD_CHECKIN_CRON_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    if (!BOT_CONFIGURED) {
      return new Response(JSON.stringify({ ok: false, reason: "bot not configured" }), { status: 503 });
    }
    try {
      const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
      const result = await runDailyCheckins(sb);
      return new Response(JSON.stringify({ ok: true, ...result }), { headers: { "Content-Type": "application/json" } });
    } catch (e) {
      console.error("runDailyCheckins failed:", e);
      return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
    }
  }
  // رسايل تليجرام اللي العقل ماقدرش يرد عليها وقتها: بتتعاد كل دقيقتين، والرد بيتبعت في نفس الشات.
  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "retry_failed") {
    if (!(await secretMatches(req.headers.get("X-Checkin-Cron-Secret"), "ZAD_CHECKIN_CRON_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    if (!BOT_CONFIGURED) return new Response(JSON.stringify({ ok: false, reason: "bot not configured" }), { status: 503 });
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const result = await retryFailedTurns(sb);
    return new Response(JSON.stringify({ ok: true, ...result }), { headers: { "Content-Type": "application/json" } });
  }

  // Daily subscription/bill renewal cron trigger — same shape as daily_checkins above,
  // own secret (ZAD_SUBSCRIPTION_CRON_SECRET).
  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "subscription_alerts") {
    if (!(await secretMatches(req.headers.get("X-Subscription-Cron-Secret"), "ZAD_SUBSCRIPTION_CRON_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    if (!BOT_CONFIGURED) {
      return new Response(JSON.stringify({ ok: false, reason: "bot not configured" }), { status: 503 });
    }
    try {
      const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
      const result = await runDailySubscriptionAlerts(sb);
      return new Response(JSON.stringify({ ok: true, ...result }), { headers: { "Content-Type": "application/json" } });
    } catch (e) {
      console.error("runDailySubscriptionAlerts failed:", e);
      return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
    }
  }

  // Real-time push — fired by a Postgres trigger (zad_transactions AFTER INSERT), not
  // cron. Payload is pre-formatted title/body text; this endpoint only resolves the
  // chat_id and delivers, no calculation happens here. Missing binding is a silent
  // no-op (200), not an error — most rows won't belong to a Telegram-linked user.
  // بوست قناة المجتمع اليومي: أرخص الأسعار من بلاغات العملاء (20260914011000). نفس سيكريت
  // realtime_push (موجود في vault). من غير TELEGRAM_COMMUNITY_CHAT_ID بيتخطى بهدوء.
  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "community_prices") {
    if (!(await secretMatches(req.headers.get("X-Realtime-Push-Secret"), "ZAD_REALTIME_PUSH_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    const communityChat = (Deno.env.get("TELEGRAM_COMMUNITY_CHAT_ID") ?? "").trim();
    if (!BOT_CONFIGURED || !communityChat) {
      console.log("[community_prices] skipped — bot or TELEGRAM_COMMUNITY_CHAT_ID not configured");
      return new Response(JSON.stringify({ ok: true, posted: false, reason: "not configured" }), { headers: { "Content-Type": "application/json" } });
    }
    try {
      const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
      const days = 7;
      const byMarket = [];
      for (const m of COMMUNITY_MARKETS) {
        const { data, error } = await sb.rpc("zad_cheapest_prices", { p_currency: m.currency, p_location: null, p_days: days, p_limit: 10 });
        if (error) throw new Error(`zad_cheapest_prices ${m.currency}: ${error.message}`);
        byMarket.push({ ...m, rows: (data ?? []) as CheapestRow[] });
      }
      const post = formatCommunityPricesPost(byMarket, days);
      if (!post) {
        return new Response(JSON.stringify({ ok: true, posted: false, reason: "not enough reports" }), { headers: { "Content-Type": "application/json" } });
      }
      const res = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ chat_id: communityChat, text: post }),
      });
      const ok = res.ok;
      if (!ok) console.error("[community_prices] telegram rejected:", res.status, (await res.text()).slice(0, 300));
      return new Response(JSON.stringify({ ok, posted: ok }), { status: ok ? 200 : 502, headers: { "Content-Type": "application/json" } });
    } catch (e) {
      console.error("[community_prices] failed:", e);
      return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
    }
  }

  // فحص فويس التنبيهات من غير إرسال (٢٠٢٦-٠٩-١٤): «البوت مابيبعتش فويسات». النص بيوصل (delivery.telegram
  // = delivered) والصوت بيتعمل في الخلفية بعد الرد — أي فشل هناك بيتسجل في اللوج بس. هنا نفس الخطوات
  // (TTS بصوت زاد + تحويل MP3) بجملة ثابتة، بالتوقيت والحجم. مفيش بيانات عميل ولا إرسال.
  // موسم العروض (الجمعة البيضاء، طلب المالك ٤/١١): zad-brain بيبعت أحسن العروض اللي البيت محتاجها (seasonDigest.ts).
  // سطر عنوان، وبعده كل عرض كارت لوحده: صورة (غلاف فيديو يوتيوب) أو نص، وزرار رابطه؛ وبعدهم الأكواد. كل الكلام من
  // الحقائق اللي جاية، مفيش موديل هنا. delivered = العنوان وصل؛ كارت فشل بيتسجل في اللوج بس.
  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "deals_digest") {
    if (!(await secretMatches(req.headers.get("X-Realtime-Push-Secret"), "ZAD_REALTIME_PUSH_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    if (!BOT_CONFIGURED) return Response.json({ ok: false, reason: "bot not configured" }, { status: 503 });
    try {
      const { user_id, season, cards, codes } = await req.json() as { user_id?: string; season?: unknown; cards?: unknown; codes?: unknown };
      if (!user_id) return Response.json({ ok: false, reason: "missing user_id" }, { status: 400 });
      const list = (Array.isArray(cards) ? cards : []).slice(0, 4) as DigestCard[];
      const codeList = (Array.isArray(codes) ? codes : []) as DigestCode[];
      const codesMessage = digestCodesMessage(codeList);
      if (!list.length && !codesMessage) return Response.json({ ok: true, delivered: false, reason: "empty" });
      const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
      const chatId = await resolveChatId(sb, user_id);
      if (chatId === null) return Response.json({ ok: true, delivered: false, reason: "not linked" });
      const top = list.length > 0 && list.every((c) => (c as { why?: unknown }).why === "top");
      await sendTelegramMessage(chatId, digestHeader(season, list.length, codesMessage?.count ?? 0, top));
      for (const card of list) {
        const caption = digestCaption(card);
        const buttons = digestButtons(card);
        const photo = digestPhoto(card);
        try {
          if (photo) await sendTelegramPhotoCard(chatId, photo, caption, buttons);
          else await sendTelegramMessage(chatId, caption, buttons.length ? buttons : undefined);
        } catch (e) {
          console.error("deals_digest: card failed:", e);
          if (photo) await sendTelegramMessage(chatId, caption, buttons.length ? buttons : undefined).catch(() => {});
        }
      }
      if (codesMessage) {
        await sendTelegramMessage(chatId, codesMessage.text, codesMessage.rows.length ? codesMessage.rows : undefined)
          .catch((e) => console.error("deals_digest: codes failed:", e));
      }
      return Response.json({ ok: true, delivered: true, cards: list.length });
    } catch (e) {
      console.error("deals_digest failed:", e);
      return Response.json({ ok: false, error: String(e) }, { status: 500 });
    }
  }

  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "voice_selftest") {
    if (!(await secretMatches(req.headers.get("X-Realtime-Push-Secret"), "ZAD_REALTIME_PUSH_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    const text = alertSpeechText("", "صباح الخير يا بطل! النهارده عندك دوا الضغط الساعة تسعة، وميعاد البنك الساعة خمسة. متنساش تفطر كويس، وأنا معاك طول اليوم.", speechLimitForMoment("morning_greeting"));
    const t0 = Date.now();
    const origError = console.error;
    const errors: string[] = [];
    console.error = (...a: unknown[]) => { errors.push(a.map(String).join(" ").replace(/[^\x20-\x7E]/g, "").slice(0, 200)); origError(...a); };
    try {
      const pcm = await synthesizeAlertPcm(text, geminiKeysFromEnv(), fetch, { emotion: "warm" as VoiceEmotion, country: "EG" });
      const ttsMs = Date.now() - t0;
      if (!pcm) return Response.json({ ok: false, stage: "tts", tts_ms: ttsMs, errors });
      const t1 = Date.now();
      const mp3 = pcmToMp3(pcm);
      return Response.json({
        ok: true, keys: geminiKeysFromEnv().length, tts_ms: ttsMs, pcm_bytes: pcm.byteLength,
        audio_seconds: Math.round(pcm.byteLength / 2 / 24000), mp3_ms: Date.now() - t1, mp3_bytes: mp3.byteLength, errors,
      });
    } catch (e) {
      return Response.json({ ok: false, stage: "threw", error: String((e as Error)?.message ?? e).slice(0, 200), errors });
    } finally {
      console.error = origError;
    }
  }

  // إعادة ضبط الـwebhook: يرمي الطابور المتراكم عند تليجرام ويربط من جديد. بسيكريت
  // لأن الـGET probe تحت مفتوح للكل (verify_jwt=false على الفانكشن دي) — من غير
  // البوابة دي أي حد على النت يقدر يمسح رسايل عملاء لسه ماوصلتش.
  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "reset_webhook") {
    if (!(await secretMatches(req.headers.get("X-Realtime-Push-Secret"), "ZAD_REALTIME_PUSH_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    try {
      return Response.json(await resetWebhook());
    } catch (e) {
      console.error("reset_webhook failed:", e);
      return Response.json({ ok: false, error: String(e) }, { status: 500 });
    }
  }

  // تنبيهات صحة النظام (zad_notify_admin، 20261010130000) — لشات الأدمن السري بس، عمرها
  // ما بتروح لشات عميل. من غير ZAD_ADMIN_CHAT_ID التنبيه بيتسجل في اللوج ومابيتبعتش.
  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "admin_alert") {
    if (!(await secretMatches(req.headers.get("X-Realtime-Push-Secret"), "ZAD_REALTIME_PUSH_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    if (!BOT_CONFIGURED) {
      return new Response(JSON.stringify({ ok: false, reason: "bot not configured" }), { status: 503 });
    }
    try {
      const { title, body } = await req.json() as { title?: string; body?: string };
      if (!title || !body) {
        return new Response(JSON.stringify({ ok: false, reason: "missing title/body" }), { status: 400 });
      }
      const chatId = adminChatId(Deno.env.get("ZAD_ADMIN_CHAT_ID"));
      if (chatId === null) {
        console.warn(`[admin_alert] ZAD_ADMIN_CHAT_ID not set — not sent: ${title}`);
        return new Response(JSON.stringify({ ok: true, delivered: false, reason: "no admin chat" }), { headers: { "Content-Type": "application/json" } });
      }
      // الشات ده مربوط كشات عميل؟ يبقى مش قناة أدمن — نفس الغلطة اللي بنقفلها.
      const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
      if (await resolveUserId(sb, chatId)) {
        console.error(`[admin_alert] ZAD_ADMIN_CHAT_ID is a customer chat — refused: ${title}`);
        return new Response(JSON.stringify({ ok: false, delivered: false, reason: "admin chat is a customer chat" }), { status: 409 });
      }
      await sendTelegramMessage(chatId, `${title}\n\n${body}`);
      return new Response(JSON.stringify({ ok: true, delivered: true }), { headers: { "Content-Type": "application/json" } });
    } catch (e) {
      console.error("admin_alert failed:", e);
      return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
    }
  }

  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "realtime_push") {
    if (!(await secretMatches(req.headers.get("X-Realtime-Push-Secret"), "ZAD_REALTIME_PUSH_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    if (!BOT_CONFIGURED) {
      return new Response(JSON.stringify({ ok: false, reason: "bot not configured" }), { status: 503 });
    }
    try {
      const payload = await req.json();
      const { user_id, title, body, dismiss_task_id, speech, dose_moment_id, close_day_moment_id, salary_moment_id, deal_moment_id, map_url, amazon_links, pet_need, life_event_id, life_event_offer, life_event_link } = payload as {
        // اختياري: حدث حياة (٢.٨) — زرار الرابط و[سجّله وفكّرني] [لأ] لو فيه ميعاد جاي.
        life_event_id?: string; life_event_offer?: boolean; life_event_link?: unknown;
        user_id?: string; title?: string; body?: string; dismiss_task_id?: string;
        // اختياري: نداء الرفيق — أزراره بتفتح التطبيق (petCallKeyboard) بدل أزرار الرفض.
        pet_need?: string;
        // اختياري: كلام الفويس لو مختلف عن نص الرسالة (كلام بلهجة وإحساس بدل عنوان وأرقام).
        speech?: string;
        // اختياري: تنبيه جرعة — معرّف صف zad_voice_moments، بيتحوّل لزرار «أخدت الجرعة».
        dose_moment_id?: string;
        // اختياري: «اقفل يومك» — معرّف اللحظة، بيتحوّل لأزرارها الـ٣.
        close_day_moment_id?: string;
        // اختياري: «ده المرتب؟» — معرّف اللحظة، بيتحوّل لزرارين.
        salary_moment_id?: string;
        // اختياري: تحية صبح فيها عرض — معرّف اللحظة، بيتحوّل لـ[ضيفه لقايمتي] [مش مهتم].
        deal_moment_id?: string;
        // اختياري: رسالة محل — رابط خرايط المحل، بيبقى زرار فوق أزرار الرفض.
        map_url?: string;
        // اختياري: صنف ضروري خلص — لينكات أمازون، كل واحد زرار «🛒 … على أمازون».
        amazon_links?: unknown;
      };
      if (!user_id || !title || !body) {
        return new Response(JSON.stringify({ ok: false, reason: "missing user_id/title/body" }), { status: 400 });
      }
      const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
      const chatId = await resolveChatId(sb, user_id);
      if (chatId === null) {
        return new Response(JSON.stringify({ ok: true, delivered: false, reason: "not linked" }), { headers: { "Content-Type": "application/json" } });
      }
      // اختياري: لو الرسالة مبادرة من مهمة استباقية، بتاخد أزرار رفض (pd:<task>). تريجرات
      // الداتابيز مابتبعتش الحقل ده، فرسايلهم بتفضل زي ما هي من غير أزرار.
      // تنبيه جرعة بيكسب على زرار الرفض: الأهم إن العميل يقدر يسجّل إنه خدها بضغطة
      // واحدة من غير ما يعدّي على فهم الموديل للكلام (سبب «بيشكرني ومابيسجلش»).
      const mapRow = mapButtonRow(map_url);
      const amazonRows = amazonButtonRows(amazon_links, (u) => amazonOpenUrl(SUPABASE_URL, u));
      const validTask = !!dismiss_task_id && /^[0-9a-fA-F-]{36}$/.test(dismiss_task_id);
      const petRows = validTask && (pet_need === "hungry" || pet_need === "thirsty")
        ? petCallKeyboard(pet_need, SUPABASE_URL)
        : [];
      const dismissRows = validTask && !petRows.length ? proactiveDismissKeyboard(dismiss_task_id!) : [];
      // «اتعلمت إن» (٥.٢): الملخص الأسبوعي اللي قال نمط بياخد «صح / مش صح» فوق أزرار الرفض. فشل القراية = من غيرهم.
      const learningRows = dismissRows.length ? await learningRowsForTask(sb, user_id, dismiss_task_id!) : [];
      // مراجعة الذاكرة (٥.٣): الملاحظات مترقّمة تحت الرسالة وزرارين لكل واحدة — النص من الجدول، مش من الموديل.
      const memoryChecks = dismissRows.length ? await memoryChecksForTask(sb, user_id, dismiss_task_id!) : [];
      const memoryBlock = memoryChecks.length ? memoryCheckBlock(memoryChecks) : null;
      // تجربة الأسبوعين (٥.٤): السلوك والأرقام من الجدول تحت الرسالة، وزرارين المرحلة.
      const habitTrial = dismissRows.length ? await habitTrialForTask(sb, user_id, dismiss_task_id!) : null;
      const habitBlock = habitTrial ? habitTrialBlock(habitTrial) : null;
      const closeDay = !dose_moment_id && close_day_moment_id && /^[0-9a-fA-F-]{36}$/.test(close_day_moment_id);
      // رسالة الليل الواحدة (ZAD_PLAN ١.٥): «اقفل يومك» بتشيل أسئلة المخزون بأزرارها، بنفس حراس
      // السؤال لوحده. فشل أي حاجة هنا = القفلة لوحدها، والسؤال الاحتياطي مابيطلعش الليلة دي.
      let nightQuestions: { text: string; rows: InlineKeyboardButton[][]; items: string[] } | null = null;
      if (closeDay) {
        try {
          const night = await nightCheckin(sb, user_id);
          const prompts = night ? await insertCheckinPrompts(sb, user_id, night.candidates) : [];
          if (night && prompts.length > 0) {
            nightQuestions = {
              text: checkInBundleMessage(prompts.map((p) => isolate(p.label)), night.plan === "ask_with_note"),
              rows: checkInBundleKeyboard(prompts, night.plan === "ask_with_note"),
              items: prompts.map((p) => p.item_name),
            };
          }
        } catch (e) {
          console.error("realtime_push: night questions failed:", e);
        }
      }
      // عرض الصبح (ZAD_PLAN ٤.٢٠): رابط العرض زرار فوق «ضيفه / مش مهتم»، وصورته قبل الرسالة لو ليه صورة (فيديو يوتيوب).
      // المصدر من صف اللحظة نفسها بملكية العميل؛ فشل القراية = الرسالة بأزرارها من غير رابط.
      const dealSource: { row: InlineKeyboardButton[] | null; photo: string | null; caption: string } = { row: null, photo: null, caption: "" };
      if (!dose_moment_id && !closeDay && !salary_moment_id && deal_moment_id && /^[0-9a-fA-F-]{36}$/.test(deal_moment_id)) {
        const { data: moment, error: momentErr } = await sb.from("zad_voice_moments")
          .select("facts").eq("id", deal_moment_id).eq("user_id", user_id).maybeSingle();
        if (momentErr) console.error("realtime_push: deal source lookup failed:", momentErr.message);
        const deal = (moment as { facts?: { taste_deal?: { item?: unknown; store?: unknown; source?: { kind?: unknown; url?: unknown } } } } | null)
          ?.facts?.taste_deal;
        dealSource.row = dealSourceRow(deal?.source);
        dealSource.photo = dealPhotoUrl(deal?.source, FLYER_PREFIX);
        dealSource.caption = `🏷️ ${String(deal?.item ?? "")}${deal?.store ? ` — ${String(deal.store)}` : ""}`;
      }
      const lifeRows = life_event_id && /^[0-9a-fA-F-]{36}$/.test(life_event_id)
        ? lifeEventKeyboard(life_event_id, life_event_offer === true, life_event_link)
        : [];
      const keyboard = lifeRows.length
        ? lifeRows
        : dose_moment_id && /^[0-9a-fA-F-]{36}$/.test(dose_moment_id)
        ? doseKeyboard(dose_moment_id)
        : closeDay
        ? [...closeDayKeyboard(close_day_moment_id!), ...(nightQuestions?.rows ?? [])]
        : salary_moment_id && /^[0-9a-fA-F-]{36}$/.test(salary_moment_id)
        ? salaryKeyboard(salary_moment_id)
        : deal_moment_id && /^[0-9a-fA-F-]{36}$/.test(deal_moment_id)
        ? [...(dealSource.row ? [dealSource.row] : []), ...dealKeyboard(deal_moment_id)]
        : petRows.length
        ? petRows
        : mapRow || amazonRows.length || dismissRows.length
        ? [...(mapRow ? [mapRow] : []), ...amazonRows, ...learningRows, ...(memoryBlock?.rows ?? []), ...(habitBlock?.rows ?? []), ...dismissRows]
        : undefined;
      const shown = [body, memoryBlock?.text, habitBlock?.text].filter(Boolean).join("\n\n");
      if (dealSource.photo) {
        await sendTelegramPhoto(chatId, dealSource.photo, dealSource.caption)
          .catch((e) => console.error("realtime_push: deal photo failed:", e));
      }
      await sendTelegramMessage(chatId, nightMessage(`${title}\n\n${shown}`, nightQuestions?.text ?? null), keyboard);
      if (nightQuestions) await recordCheckinTurn(sb, user_id, nightQuestions.items);
      // تنبيه حرج (اللي بعته قال voice:true): فويس بصوت زاد بعد النص، في الخلفية.
      const voice = wantsVoice(payload);
      if (voice) {
        runInBackground(deliverVoiceAlert(sb, user_id, chatId, title, body, alertEmotion(payload, `${title} ${body}`), typeof speech === "string" ? speech : undefined, (payload as { moment?: unknown }).moment));
      }
      return new Response(JSON.stringify({ ok: true, delivered: true, voice: voice ? "queued" : "none" }), { headers: { "Content-Type": "application/json" } });
    } catch (e) {
      console.error("realtime_push failed:", e);
      return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
    }
  }

  // The parser could not recover a usable amount, so there is no safe structured proposal
  // yet. Telegram asks for the missing amount/direction in free text; the normal chat agent
  // will parse that reply and still require its usual financial confirmation.
  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "review_notification") {
    if (!(await secretMatches(req.headers.get("X-Confirm-Transaction-Secret"), "ZAD_CONFIRM_TRANSACTION_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    if (!BOT_CONFIGURED) {
      return new Response(JSON.stringify({ ok: false, reason: "bot not configured" }), { status: 503 });
    }
    try {
      const { user_id, ingest_event_id } = await req.json() as { user_id?: string; ingest_event_id?: string };
      if (!user_id || !ingest_event_id) {
        return new Response(JSON.stringify({ ok: false, reason: "missing user_id/ingest_event_id" }), { status: 400 });
      }
      const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
      const chatId = await resolveChatId(sb, user_id);
      if (chatId === null) {
        return new Response(JSON.stringify({ ok: true, delivered: false, reason: "not linked" }), {
          headers: { "Content-Type": "application/json" },
        });
      }

      const { data: event, error } = await sb.from("zad_notification_ingest_events")
        .select("id,user_id,status,package_name,title,body")
        .eq("id", ingest_event_id)
        .eq("user_id", user_id)
        .maybeSingle();
      const row = event as {
        status: string; package_name: string; title: string | null; body: string;
      } | null;
      if (error || !row) {
        console.error("review_notification event fetch failed:", error?.message ?? "not found");
        return new Response(JSON.stringify({ ok: false, reason: "notification not found" }), { status: 404 });
      }
      if (row.status !== "received" && row.status !== "ambiguous") {
        return new Response(JSON.stringify({ ok: true, delivered: false, reason: "already resolved" }), {
          headers: { "Content-Type": "application/json" },
        });
      }

      await sendTelegramMessage(chatId, clampForTelegram(notificationReviewMessage({
        packageName: sanitizeName(row.package_name),
        title: row.title ? sanitizeName(row.title) : null,
        body: sanitizeName(row.body),
      })), notificationReviewKeyboard(ingest_event_id));
      return new Response(JSON.stringify({ ok: true, delivered: true }), {
        headers: { "Content-Type": "application/json" },
      });
    } catch (e) {
      console.error("review_notification failed:", e);
      return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
    }
  }

  // A bank notification proposal already exists in the database. This endpoint only
  // resolves the linked chat and renders that same proposal; it never copies the amount
  // into a second pending table, so app and Telegram cannot disagree.
  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "confirm_transaction") {
    if (!(await secretMatches(req.headers.get("X-Confirm-Transaction-Secret"), "ZAD_CONFIRM_TRANSACTION_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    if (!BOT_CONFIGURED) {
      return new Response(JSON.stringify({ ok: false, reason: "bot not configured" }), { status: 503 });
    }
    try {
      const { user_id, proposal_id } = await req.json() as { user_id?: string; proposal_id?: string };
      if (!user_id || !proposal_id) {
        return new Response(JSON.stringify({ ok: false, reason: "missing user_id/proposal_id" }), { status: 400 });
      }
      const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
      const chatId = await resolveChatId(sb, user_id);
      if (chatId === null) {
        return new Response(JSON.stringify({ ok: true, delivered: false, reason: "not linked" }), {
          headers: { "Content-Type": "application/json" },
        });
      }

      const { data: proposal, error } = await sb.from("zad_transaction_proposals")
        .select("id,user_id,status,txn_kind,amount,title,category,currency,merchant_name,bank_name")
        .eq("id", proposal_id)
        .eq("user_id", user_id)
        .maybeSingle();
      const row = proposal as {
        id: string; status: "needs_classification" | "awaiting_confirmation" | "posted" | "rejected" | "expired";
        txn_kind: string | null; amount: number; title: string; category: string | null;
        currency: string | null; merchant_name: string | null; bank_name: string | null;
      } | null;
      if (error || !row) {
        console.error("confirm_transaction proposal fetch failed:", error?.message ?? "not found");
        return new Response(JSON.stringify({ ok: false, reason: "proposal not found" }), { status: 404 });
      }
      if (row.status !== "needs_classification" && row.status !== "awaiting_confirmation") {
        return new Response(JSON.stringify({ ok: true, delivered: false, reason: "already resolved" }), {
          headers: { "Content-Type": "application/json" },
        });
      }

      // إشعار بنفس مبلغ إشعار تاني خلال ربع ساعة: السؤال نفسه بيتغير لـ"هل دي نفس المعاملة؟"
      // بدل "أكد؟" — من غير كده العميل بيشوف رسالتين تأكيد لنفس الدفعة ويأكد الاتنين.
      if (await sendDuplicateProposalQuestion(sb, chatId, user_id, row.id)) {
        return new Response(JSON.stringify({ ok: true, delivered: true, kind: "duplicate_question" }), {
          headers: { "Content-Type": "application/json" },
        });
      }

      const { data: u } = await sb.from("zad_users").select("currency").eq("id", user_id).maybeSingle();
      const cur = row.currency || (u as { currency?: string } | null)?.currency || "غير معروف";
      const source = row.merchant_name || row.bank_name;
      const direction = row.status === "needs_classification"
        ? "مش واضح دي مصروف ولا دخل ولا تحويل"
        : row.txn_kind === "income" ? "دخل متوقع" : row.txn_kind === "transfer" ? "تحويل متوقع" : "مصروف متوقع";
      const text = [
        `حركة بنكية: ${isolate(money(row.amount, cur))}`,
        isolate(sanitizeName(row.title)),
        source ? `المصدر: ${isolate(sanitizeName(source))}` : "",
        direction,
        "راجعها قبل ما تأثر على الرصيد.",
      ].filter(Boolean).join("\n");

      await sendTelegramMessage(chatId, clampForTelegram(text), transactionProposalKeyboard(row.id, row.status, row.txn_kind));
      return new Response(JSON.stringify({ ok: true, delivered: true }), {
        headers: { "Content-Type": "application/json" },
      });
    } catch (e) {
      console.error("confirm_transaction failed:", e);
      return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
    }
  }

  // Real-time check-in — fired by a Postgres trigger (zad_inventory AFTER UPDATE) the
  // instant an item crosses into low-stock/predicted-depletion territory, instead of
  // waiting for runDailyCheckins' once-a-day pass. Reuses the exact same prompt-sending
  // path and daily budget as the cron job — this is not a second, unlimited channel.
  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "live_checkin") {
    if (!(await secretMatches(req.headers.get("X-Live-Checkin-Secret"), "ZAD_LIVE_CHECKIN_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    if (!BOT_CONFIGURED) {
      return new Response(JSON.stringify({ ok: false, reason: "bot not configured" }), { status: 503 });
    }
    try {
      const { user_id, item_name, quantity } = await req.json() as { user_id?: string; item_name?: string; quantity?: number };
      if (!user_id || !item_name || typeof quantity !== "number") {
        return new Response(JSON.stringify({ ok: false, reason: "missing user_id/item_name/quantity" }), { status: 400 });
      }
      const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
      const chatId = await resolveChatId(sb, user_id);
      if (chatId === null) {
        return new Response(JSON.stringify({ ok: true, delivered: false, reason: "not linked" }), { headers: { "Content-Type": "application/json" } });
      }
      // حاجة على فترات (الرنجة كل شهرين، ZAD_PLAN ٣.١٠): «لسه عندك؟» عليها إزعاج مش مساعدة. لو السؤال
      // نفسه فشل، السؤال بيتبعت زي الأول.
      const { data: occasional, error: occErr } = await sb.rpc("zad_item_is_occasional", { p_user: user_id, p_item: item_name });
      if (occErr) console.error("live_checkin: occasional check failed:", occErr.message);
      if (occasional === true) {
        return new Response(JSON.stringify({ ok: true, delivered: false, reason: "occasional item" }), { headers: { "Content-Type": "application/json" } });
      }
      const alreadySentToday = await checkinsSentToday(sb, user_id);
      if (alreadySentToday >= MAX_CHECKINS_PER_USER_PER_DAY) {
        return new Response(JSON.stringify({ ok: true, delivered: false, reason: "daily budget spent" }), { headers: { "Content-Type": "application/json" } });
      }
      const { data: existingPending } = await sb.from("telegram_checkin_prompts")
        .select("id").eq("user_id", user_id).eq("item_name", item_name).eq("status", "pending").maybeSingle();
      if (existingPending) {
        return new Response(JSON.stringify({ ok: true, delivered: false, reason: "already pending" }), { headers: { "Content-Type": "application/json" } });
      }
      const { data: unitRow } = await sb.from("zad_inventory").select("unit")
        .eq("user_id", user_id).eq("item_name", item_name).limit(1).maybeSingle();
      const unit = (unitRow as { unit?: string | null } | null)?.unit ?? null;
      const delivered = await sendCheckInPrompt(sb, user_id, chatId, item_name, quantity, unit);
      return new Response(JSON.stringify({ ok: true, delivered }), { headers: { "Content-Type": "application/json" } });
    } catch (e) {
      console.error("live_checkin failed:", e);
      return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
    }
  }

  if (!BOT_CONFIGURED) {
    // Fail loudly rather than 500-ing opaquely: Telegram retries on 5xx, and a retry
    // loop against a misconfigured project helps nobody.
    return new Response("bot not configured", { status: 503 });
  }

  // ── الحارس: مين يدخل لفة الوكيل أصلاً (٢٠٢٦-٠٩-١٩) ────────────────────────
  // أول حاجة بعد التحقق من الإعداد، وقبل grammY وقبل أي نداء ذكاء اصطناعي.
  // بيرجّع 200 دايماً للمرفوض — 4xx/5xx بيخلي تليجرام يعيد التسليم، وده بالظبط
  // اللي بنحاول نوقفه.
  //
  // الجسم بيتقرا مرة واحدة هنا وبيتبني منه Request جديد لـgrammY: `req.json()`
  // بيستهلك الـbody ومينفعش يتقرا تاني.
  // التحقق من سر الـwebhook **قبل** أي قراية أو كتابة. grammY بيتحقق منه برضه، بس
  // بعد ما الحارس تحت يكون كتب صف حجز في الداتابيز — يعني أي حد على النت كان يقدر
  // يضخّم `telegram_processed_updates` بطلبات مزوّرة. تليجرام بيبعت الهيدر ده مع كل
  // تحديث لأن setWebhook بيتسجّل بـsecret_token (شوف ensureWebhook فوق).
  if (req.headers.get("X-Telegram-Bot-Api-Secret-Token") !== WEBHOOK_SECRET) {
    console.error("[guard] webhook secret mismatch — rejected");
    return new Response("unauthorized", { status: 401 });
  }

  let update: UpdateEnvelope;
  let rawBody: string;
  try {
    rawBody = await req.text();
    update = JSON.parse(rawBody) as UpdateEnvelope;
  } catch {
    // جسم مش JSON مش تحديث تليجرام — مالوش لازمة يوصل grammY.
    return new Response("OK", { status: 200 });
  }

  if (!isHumanUpdate(update)) {
    console.log("[guard] dropped non-human update", JSON.stringify({
      update_id: update?.update_id,
      kind: update?.message ? "message" : update?.callback_query ? "callback_query" : "other",
      is_bot: update?.message?.from?.is_bot ?? update?.callback_query?.from?.is_bot ?? null,
    }));
    return new Response("OK", { status: 200 });
  }

  const dedupeClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  if (!(await claimUpdate(dedupeClient, update.update_id))) {
    return new Response("OK", { status: 200 });
  }

  try {
    // Request جديدة بنفس الطريقة والهيدرز (grammY بيتحقق من secret_token منها)
    // وبجسم مقرووء تاني.
    return await handleUpdate(new Request(req.url, { method: req.method, headers: req.headers, body: rawBody }));
  } catch (e) {
    console.error("zad-telegram-bot error:", e);
    // 500 هنا = تليجرام يعيد التسليم = نفس اللفة تتنفذ تاني. الحجز فوق بيمنع كده
    // برضه، بس الأنضف إننا نقر بالاستلام: الخطأ متسجل في اللوج ومحدش بيستفيد من
    // إعادة محاولة نداء موديل وقع.
    return new Response("OK", { status: 200 });
  }
});
