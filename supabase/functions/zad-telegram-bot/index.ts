// zad-telegram-bot — Phase B4 (PRODUCT_PLAN.md), built on grammY per explicit user
// instruction (2026-07-30). Read-only: view balance/recent transactions/pending
// insights, act on Task 28's dismiss-with-reason from a Telegram button, and — as of
// v2 — hold a real conversation. No writes beyond dismissal; the agent is explicitly
// told (context.ts rule 5) not to claim it logged anything, because it can't.
//
// v2 (conversational): free text goes to Zad itself instead of bouncing back a button
// menu. The customer's full picture is assembled server-side by context.ts using the
// same === SECTION === contract as the Kotlin client's buildFullChatContext(), and the
// model call routes through zad-core-intelligence's `ai_text` action so the bot
// inherits the app's Groq-pool-primary/Gemini-fallback policy instead of forking it.
//
// Identity: EPIC_1_4.md's own warning — "a chat_id is never an identity". A user
// generates a one-time binding code in the app (telegram_bindings row, user_id set,
// chat_id null); this function only trusts a chat_id once it's bound to that exact
// code via /start <code>. Every subsequent request is authorized by chat_id → user_id
// through that table, never by anything the client claims about itself.
import { secretMatches } from "../_shared/cronSecret.ts";
import { Bot, InlineKeyboard, webhookCallback } from "npm:grammy@1";
import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { mediaGate } from "./entitlement.ts";
import { alertEmotion, alertSpeechText, geminiKeysFromEnv, pcmToMp3, synthesizeAlertPcm, wantsVoice, speechLimitForMoment } from "./voiceAlert.ts";
import { detectDialectFromText, resolveDialect } from "../_shared/dialect.ts";
import { botDialectFor, type BotDialect, localizeBotText } from "./botDialect.ts";
import { COMMUNITY_MARKETS, type CheapestRow, formatCommunityPricesPost } from "./communityPrices.ts";
import type { VoiceEmotion } from "../_shared/zadVoice.ts";
import {
  adCreditKeyboard,
  InlineKeyboardButton, mainMenuKeyboard, dismissKeyboard,
  proactiveDismissKeyboard, parseProactiveDismissCallback, proactiveDismissReply,
  reasonForCode, parseDismissCallback, normalizeBindingCode, memoryNoteForDismissal,
  formatBalanceMessage, type BudgetStateRow, formatTransactionsMessage, formatInsightTitle,
  confirmSpendKeyboard, parseSpendCallback,
  transactionProposalKeyboard, parseTransactionProposalCallback,
  duplicateProposalKeyboard, duplicateProposalMessage,
  notificationReviewMessage,
  notificationReviewKeyboard,
  parseNotificationReviewCallback,
  confirmMedicationKeyboard, parseMedicationCallback,
  checkInKeyboard, parseCheckInCallback, checkInPromptMessage,
  confirmToolKeyboard, parseToolCallback,
  isHumanUpdate, type UpdateEnvelope,
  doseKeyboard, parseDoseCallback, DOSE_MOMENTS, DOSE_SNOOZE_MINUTES, type DoseAction,
  parseAmountWrongCallback, parseDoseReply, parseYesNoReply, type TransactionProposalDecision,
} from "./telegram.ts";
import {
  AgentContextInput, agentSystemPrompt, buildAgentContext, clampForTelegram,
  confirmSpendMessage, deriveWebhookSecret, money,
  confirmMedicationMessage,
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
  const text = speech?.trim() ? alertSpeechText("", speech, speechLimitForMoment(moment)) : alertSpeechText(title, body);
  const pcm = await synthesizeAlertPcm(text, geminiKeysFromEnv(), fetch, { emotion, country });
  if (!pcm) return; // السبب اتسجّل جوه synthesizeAlertPcm — النص وصل خلاص.
  await sendTelegramVoice(chatId, pcmToMp3(pcm));
  console.log(`[voiceAlert] delivered ${pcm.byteLength} bytes PCM as voice note`);
}

/** Server-side low-stock detection against zad_inventory + zad_consumption (Task 18's
 * learning loop) — deliberately NOT a port of ConsumptionLearner's on-device
 * SharedPreferences model, which never leaves the Android client. "Needs a check-in" here
 * means: at/under its low_stock_threshold, OR — when a real consumption rate has been
 * learned (rate_known) — predicted to run out within 2 days at that rate. Items with an
 * already-pending prompt are excluded (the unique index on telegram_checkin_prompts is the
 * hard guarantee; this filter just avoids the wasted query/round-trip).
 */
async function findCheckInCandidates(sb: SupabaseClient, userId: string): Promise<Array<{ item_name: string; quantity: number }>> {
  const [{ data: inv }, { data: cons }, { data: pending }] = await Promise.all([
    sb.from("zad_inventory").select("item_name,quantity,low_stock_threshold").eq("user_id", userId),
    sb.from("zad_consumption").select("item_name,avg_daily_qty,rate_known").eq("user_id", userId),
    sb.from("telegram_checkin_prompts").select("item_name").eq("user_id", userId).eq("status", "pending"),
  ]);

  const consByItem = new Map(
    ((cons ?? []) as Array<{ item_name: string; avg_daily_qty: number; rate_known: boolean }>)
      .map((c) => [c.item_name, c]),
  );
  const pendingItems = new Set(((pending ?? []) as Array<{ item_name: string }>).map((p) => p.item_name));

  return ((inv ?? []) as Array<{ item_name: string; quantity: number; low_stock_threshold: number | null }>)
    .filter((item) => {
      if (pendingItems.has(item.item_name)) return false;
      const threshold = item.low_stock_threshold ?? 2;
      if (item.quantity <= threshold) return true;
      const rate = consByItem.get(item.item_name);
      if (rate?.rate_known && rate.avg_daily_qty > 0) {
        return item.quantity / rate.avg_daily_qty <= 2;
      }
      return false;
    })
    .map((item) => ({ item_name: item.item_name, quantity: item.quantity }));
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
async function sendCheckInPrompt(sb: SupabaseClient, userId: string, chatId: number, itemName: string, quantity: number): Promise<boolean> {
  const { data: prompt, error } = await sb.from("telegram_checkin_prompts")
    .insert({ user_id: userId, item_name: itemName, quantity_at_prompt: quantity })
    .select("id")
    .single();
  if (error || !prompt) {
    console.error("checkin prompt insert failed:", error?.message);
    return false;
  }
  await sendTelegramMessage(chatId, checkInPromptMessage(isolate(sanitizeName(itemName))), checkInKeyboard((prompt as { id: string }).id));
  return true;
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
    const alreadySentToday = await checkinsSentToday(sb, b.user_id);
    const budget = MAX_CHECKINS_PER_USER_PER_DAY - alreadySentToday;
    if (budget <= 0) continue;
    const candidates = await findCheckInCandidates(sb, b.user_id);
    for (const item of candidates.slice(0, budget)) {
      if (await sendCheckInPrompt(sb, b.user_id, b.chat_id, item.item_name, item.quantity)) promptsSent++;
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
        .select("title,amount,renewal_date")
        .eq("user_id", b.user_id)
        .eq("is_active", true)
        .not("renewal_date", "is", null),
      sb.from("zad_obligations")
        .select("title,amount,kind,recurrence,due_day,due_date")
        .eq("user_id", b.user_id)
        .eq("active", true),
      sb.from("zad_users").select("currency").eq("id", b.user_id).maybeSingle(),
    ]);
    const currency = (userRow as { currency: string | null } | null)?.currency ?? null;

    for (const sub of (subs ?? []) as Array<{ title: string; amount: number; renewal_date: string }>) {
      const renewal = new Date(sub.renewal_date);
      if (isNaN(renewal.getTime())) continue;
      const daysLeft = Math.round((renewal.getTime() - today.getTime()) / 86400000);
      if (daysLeft < 0 || daysLeft > 3) continue;
      const amountText = `${sub.amount}${currency ? " " + currency : ""}`;
      const when = daysLeft === 0 ? "اليوم" : `خلال ${daysLeft} يوم`;
      await sendTelegramMessage(b.chat_id, `🔔 ${isolate(sanitizeName(sub.title))} يتجدد ${when} (${isolate(amountText)})`);
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
      await sendTelegramMessage(b.chat_id, `🔔 ${isolate(sanitizeName(ob.title))} مستحق ${when} (${isolate(amountText)})`);
      alertsSent++;
    }
  }

  return { usersChecked: rows.length, alertsSent };
}

/** Pulls the same picture of the customer the in-app chat gets. Every query is
 * user-scoped explicitly — this runs on the service-role key, so RLS is NOT the
 * guard here; the .eq("user_id", userId) on each query is. */
async function fetchAgentContext(sb: SupabaseClient, userId: string): Promise<AgentContextInput> {
  const today = new Date().toISOString().slice(0, 10);

  // العيلة بتتجاب على خطوتين لأن family_members مالهاش عمود بيربط عضو بعضو مباشرة: الأول
  // نلاقي عضوية المستخدم عشان نعرف family_id، وبعدين نجيب كل أعضاء العيلة دي.
  const { data: myMembership } = await sb.from("family_members")
    .select("family_id").eq("user_id", userId).maybeSingle();
  const familyId = (myMembership as { family_id: string } | null)?.family_id ?? null;

  const [user, txs, inv, subs, obligations, debts, pharmacy, shopping, insights, tasbiha, memory, family, budget, domainObs, lifeObs] = await Promise.all([
    sb.from("zad_users").select("name,monthly_limit,currency,country").eq("id", userId).maybeSingle(),
    // The 200-newest window is what the prompt's "آخر 30 معاملة" section is sliced from.
    // It is no longer what any total is computed over — totals come from the RPC below,
    // which sees every row regardless of this limit, so a heavy month can no longer
    // silently under-report.
    sb.from("zad_transactions").select("title,amount,txn_kind,category,created_at")
      .eq("user_id", userId).order("created_at", { ascending: false }).limit(200),
    sb.from("zad_inventory").select("item_name,quantity,unit,expiry_date").eq("user_id", userId).limit(60),
    sb.from("zad_subscriptions").select("title,amount,renewal_date,is_active").eq("user_id", userId).limit(30),
    // zad_obligations معندهاش status — active/confirmed بس (بند 30.1، schema_contract_test.ts).
    sb.from("zad_obligations").select("title,amount,due_date,active").eq("user_id", userId).limit(30),
    sb.from("zad_debts").select("name,remaining_balance,interest_rate,minimum_payment,due_day").eq("user_id", userId).eq("is_active", true).limit(30),
    sb.from("zad_pharmacy_items").select("name,remaining_quantity,unit,dosage").eq("user_id", userId).limit(30),
    sb.from("zad_shopping_list").select("item_name,is_purchased").eq("user_id", userId).limit(40),
    sb.from("zad_insights").select("title,body").eq("user_id", userId).eq("status", "pending").limit(8),
    sb.from("family_tasbiha").select("garden_name,tree_emoji,level,score,total_clicks,streak_days").eq("user_id", userId).limit(10),
    sb.from("zad_memory").select("scope,note").eq("user_id", userId).limit(20),
    familyId
      ? sb.from("family_members").select("role,alias,balance,savings_goal").eq("family_id", familyId).limit(20)
      : Promise.resolve({ data: [] as unknown[] }),
    // Phase 0 — the single authority for every budget figure the bot states. Shared with
    // the app's own screens and with zad-brain; see
    // migrations/20260809120000_single_budget_authority.sql.
    sb.rpc("zad_budget_state", { p_user: userId }),
    // نفس الملاحظات اللي العقل بيشوفها في buildSnapshot. من غيرها نفس السؤال بياخد
    // إجابة أغنى في التطبيق منها في تيليجرام — وده بالظبط التفاوت اللي اتقفل النهارده
    // في الذاكرة ورجع من هنا مع كل ملاحظة جديدة اتضافت.
    sb.rpc("zad_domain_observations", { p_user: userId }),
    sb.rpc("zad_lifestyle_observations", { p_user: userId }),
  ]);

  if ((budget as any)?.error) {
    console.error(`[zad-telegram-bot] zad_budget_state FAILED: ${String((budget as any).error.message ?? (budget as any).error)}`);
  }

  return {
    userName: (user.data as any)?.name ?? null,
    budget: ((budget as any)?.data ?? null) as any,
    // "غير معروف" بدل "ر.س" — كان افتراض ميت خلّى البوت يرد على عميل في مصر "مفيش
    // ولا ريال" وهو فلوسه بالمصري. لو العمود موجود، قيمته الحقيقية (EGP/SAR/TRY)
    // هي اللي بتوصل من الكلاينت (MarketPrefs → syncMarketProfile).
    currency: (user.data as any)?.currency ?? "غير معروف",
    country: (user.data as any)?.country ?? null,
    today,
    family: (family.data ?? []) as any,
    transactions: (txs.data ?? []) as any,
    inventory: (inv.data ?? []) as any,
    subscriptions: (subs.data ?? []) as any,
    obligations: (obligations.data ?? []) as any,
    debts: (debts.data ?? []) as any,
    pharmacy: (pharmacy.data ?? []) as any,
    shopping: (shopping.data ?? []) as any,
    insights: (insights.data ?? []) as any,
    tasbiha: (tasbiha.data ?? []) as any,
    memory: (memory.data ?? []) as any,
    // الاتنين بيتلموا في مصفوفة واحدة: الموديل مايهموش الملاحظة جت من أنهي دالة، يهمه
    // إيه اللي محتاج تصرّف. الترتيب بالأهمية بيحصل في buildAgentContext.
    observations: ([...(domainObs.data ?? []), ...(lifeObs.data ?? [])]) as any,
  };
}

/** Routes through zad-core-intelligence's `ai_text` rather than calling Groq directly,
 * so the bot inherits the exact same multi-key Groq pool + Gemini fallback the app uses
 * — one provider policy, not a second one drifting out of sync here. */
async function askZad(systemPrompt: string, userPrompt: string): Promise<string | null> {
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/zad-core-intelligence`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${SERVICE_ROLE_KEY}` },
      body: JSON.stringify({ action: "ai_text", payload: { system_prompt: systemPrompt, user_prompt: userPrompt } }),
    });
    if (!res.ok) {
      console.error("askZad: core-intelligence returned", res.status);
      return null;
    }
    const json = await res.json();
    return json?.ok === false ? null : (json?.text ?? null);
  } catch (e) {
    console.error("askZad failed:", e);
    return null;
  }
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
      .limit(CHAT_HISTORY_TURNS);
    if (error) {
      console.error("loadChatHistory failed:", error);
      return [];
    }
    return toBrainHistory(data ?? []);
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

/** Generic version of askZad's fetch for any zad-core-intelligence action (voice_agent,
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
  items: Array<{ name: string; price: number; quantity: number; unit: string; category: string }>;
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
    dialect = botDialectFor(resolveDialect({
      preferred: profileRow?.dialect,
      text: chatTextHint.get(chatId) ?? null,
      country: userRow?.country,
      currency: userRow?.currency,
    }));
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
  } else if (chatId && ctx.from?.language_code?.startsWith("en") && !chatTextHint.has(chatId)) {
    chatTextHint.set(chatId, "How much did I spend this week and what is left in the budget");
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

  const { data: link } = await sb.from("telegram_bindings")
    .select("id,code_expires_at")
    .eq("binding_code", code)
    .is("bound_at", null)
    .maybeSingle();
  const expired = !link || new Date((link as any).code_expires_at) < new Date();
  if (expired) {
    await ctx.reply("الكود ده غلط أو منتهي — افتح تطبيق زاد واعمل كود ربط جديد.");
    return;
  }

  const { error } = await sb.from("telegram_bindings")
    .update({ chat_id: chatId, bound_at: new Date().toISOString() })
    .eq("id", (link as any).id);
  if (error) {
    // الأرجح unique violation على chat_id (الحساب ده مربوط بيوزر تاني بالفعل)
    await ctx.reply("فشل الربط — الحساب ده ممكن يكون مربوط بيوزر تاني بالفعل.");
  } else {
    await ctx.reply("تم الربط بنجاح ✅ اختار من تحت:", { reply_markup: toGrammyKeyboard(mainMenuKeyboard()) });
  }
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
bot.command("tahlil", async (ctx) => {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const userId = await resolveUserId(sb, ctx.chat.id);
  if (!userId) {
    await ctx.reply("الحساب ده مش مربوط — افتح تطبيق زاد واعمل كود ربط.");
    return;
  }
  await ctx.replyWithChatAction("typing");
  // كان بيروح مباشرة لسياق منفصل (fetchAgentContext + askZad) بدل agentTurn — نفس
  // مسار الرسالة النصية العادية تحت، فالتحليل ممكن يختلف عن رد الشات العادي لأنهم
  // مبنيين من دالتين مختلفتين لنفس الصورة. دلوقتي بيفضّل الوكيل الموحد الأول، ونفس
  // fallback بس لو فشل — مش تنفيذ جديد، نفس البنية.
  const analysisPrompt = "اعملي تحليل سريع لوضعي المالي وحالة البيت: أهم ٣ ملاحظات، وأهم حاجة أعملها دلوقتي.";
  const { result: turn, errorReason } = await agentTurn(userId, analysisPrompt);
  if (turn?.reply.trim()) {
    await ctx.reply(clampForTelegram(turn.reply.trim()));
    return;
  }
  if (errorReason) console.error("photo analysis fell back to read-only:", errorReason);
  const notice = errorReason
    ? `⚠️ ${userFacingFailure(errorReason)}، فده تحليل مبدئي من البيانات المسجّلة:\n\n`
    : "";
  const agentInput = await fetchAgentContext(sb, userId);
  const context = buildAgentContext(agentInput);
  const answer = await askZad(
    agentSystemPrompt(resolveDialect({ country: agentInput.country, currency: agentInput.currency })),
    `${context}\n\n=== سؤال العميل ===\n${analysisPrompt}`,
  );
  await ctx.reply(answer ? clampForTelegram(notice + answer) : clampForTelegram(notice + "معلش، التحليل مش متاح دلوقتي — جرب كمان شوية."));
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
async function agentTurnReply(
  sb: SupabaseClient,
  userId: string,
  chatId: number,
  text: string,
): Promise<{ lines: string[]; pendingId?: string; toolPendingId?: string; errorReason?: string; needsAdCredit?: boolean }> {
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
    .select("title,body,about_item,created_at")
    .eq("user_id", userId)
    .eq("kind", "question")
    .eq("status", "pending")
    .gte("created_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  const q = openQ as { title: string; body: string; about_item: string | null } | null;
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

  // السياق بيتقرا **قبل** ما رسالة اللفة دي تتسجل، عشان الرسالة الحالية تتبعت
  // مرة واحدة (في `message`) مش مرتين.
  const history = await loadChatHistory(sb, userId);
  const { result: turn, errorReason } = await agentTurn(userId, outgoing, history);
  // بتتسجل حتى لو اللفة فشلت: العميل قالها فعلاً، والرسالة الجاية محتاجة تشوفها.
  // ده بالظبط سيناريو "اخصم 50 جنيه" ← "مصروف" — الأولى لازم تعيش عشان التانية تفهم.
  await recordChatTurn(sb, userId, "user", outgoing);
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

  const lines: string[] = [];
  if (turn.reply.trim()) lines.push(turn.reply.trim());
  // رد العقل بيتسجل كمان — من غيره العميل يفتكر إن البوت سأله سؤال، والبوت
  // يشوف رسالة العميل بلا السؤال اللي ردّت عليه.
  await recordChatTurn(sb, userId, "assistant", turn.reply);
  for (const done of turn.executed) lines.push(`✅ ${isolate(sanitizeName(done.summary))}`);

  const money = turn.proposals.find((p) => p.tool === "log_transaction");
  const rest = turn.proposals.filter((p) => p !== money);

  // كان: `ℹ️ … — ابعتها لوحدها عشان أأكدها معاك` — والعميل أصلاً باعتها لوحدها،
  // فالسطر يتكرر للأبد ومفيش زرار. الاقتراح دلوقتي بياخد صف في telegram_pending_tools
  // وزر تأكيد حقيقي. رسالة تليجرام الواحدة بتشيل كيبورد واحد، فأول اقتراح غير مالي هو
  // اللي بياخد الزرار والباقي بيتقال بصراحة إنه محتاج رسالة لوحده.
  let toolPendingId: string | undefined;
  for (const extra of rest) {
    if (toolPendingId) {
      lines.push(`ℹ️ ${extra.summary} — ابعتها في رسالة لوحدها عشان أقدر أحط ليها زر تأكيد.`);
      continue;
    }
    const { data: row, error } = await sb.from("telegram_pending_tools").insert({
      user_id: userId,
      chat_id: chatId,
      tool: extra.tool,
      input: extra.input,
      summary: extra.summary,
    }).select("id").single();
    if (error || !row) {
      console.error("pending tool insert failed:", error);
      lines.push(`ℹ️ ${extra.summary} — معلش، مقدرتش أجهّز التأكيد. جرب تاني.`);
      continue;
    }
    lines.push(`⚠️ ${extra.summary}\n\nأأكدها؟`);
    toolPendingId = (row as { id: string }).id;
  }

  // الفلوس ليها الأولوية على الزرار الواحد — تأكيد معاملة أخطر من تأكيد أداة تانية.
  if (!money) return { lines, toolPendingId };

  const amount = Number(money.input.amount);
  const kind = money.input.txn_kind === "income" ? "income" : "expense";
  const title = String(money.input.title ?? "مصروف").slice(0, 80);
  const category = String(money.input.category ?? "أخرى").slice(0, 40);
  const currency = (await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle())
    .data?.currency ?? "غير معروف";
  const { data: pending, error } = await sb.from("telegram_pending_writes").insert({
    user_id: userId,
    chat_id: chatId,
    txn_kind: kind,
    amount,
    title,
    category,
    confidence: null,
  }).select("id").single();

  if (error || !pending) {
    console.error("pending write insert failed:", error);
    lines.push("معلش، مقدرتش أجهّز تأكيد المصروف — جرب تاني.");
    return { lines };
  }

  lines.push(confirmSpendMessage({ is_spend: true, kind, amount, title, category, confidence: 1 }, currency));
  return { lines, pendingId: (pending as { id: string }).id };
}

/**
 * تأكيد/رفض مصروف معلّق **بالنص** ("أيوه"/"لا") بدل الضغط على الزر — نفس منطق
 * مسار callback بالظبط: إعادة تحقق مالك، claim بـ status=idempotent، تنفيذ عبر
 * agent_confirm سيرفر-سايد. بيرجع true لو فيه pending اتعالج (فمتتعتبرش الرسالة
 * سؤال جديد)، وfalse لو مفيش حاجة معلّقة.
 */
async function handleSpendCallbackText(
  ctx: { reply: (t: string) => Promise<unknown> },
  sb: SupabaseClient,
  userId: string,
  isAffirm: boolean
): Promise<boolean> {
  const { data: rows } = await sb.from("telegram_pending_writes")
    .select("id,txn_kind,amount,title,category,status,expires_at")
    .eq("user_id", userId)
    .eq("status", "pending")
    .order("created_at", { ascending: false })
    .limit(1);
  const row = (rows as {
    id: string; txn_kind: string; amount: number; title: string;
    category: string | null; status: string; expires_at: string;
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
    wallet: "card",
  });
  if (!confirmed.ok) {
    console.error("telegram text confirmation via zad-brain failed");
    await sb.from("telegram_pending_writes").update({ status: "pending" }).eq("id", row.id);
    await ctx.reply("معلش، التسجيل فشل — جرب تاني.");
    return true;
  }
  const { data: u } = await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle();
  const cur = (u as { currency?: string } | null)?.currency ?? "غير معروف";
  await ctx.reply(`اتسجل ✅ ${isolate(sanitizeName(row.title))} — ${isolate(money(row.amount, cur))}`);
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
    await ctx.reply("أهلاً! لو عندك كود ربط من تطبيق زاد ابعته كده: /start الكود");
    return;
  }

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

  await ctx.replyWithChatAction("typing");

  // المرحلة ٢-د — نداء واحد بكل الأدوات، بدل تلات مرات تصنيف نية منفصلة. الأدوات
  // المباشرة (مخزون/صيدلية/تسوق/بلد وعملة) بتكون اتنفذت خلاص لما الرد ده يوصل؛ أدوات
  // الفلوس بترجع كاقتراح لسه ماحصلش، وبيتحوّل لنفس زر التأكيد الموجود من الأول.
  const turnReply = await agentTurnReply(sb, userId, ctx.chat.id, ctx.message.text);
  const errorReason = turnReply.errorReason;

  if (turnReply.lines.length > 0) {
    const body = clampForTelegram(turnReply.lines.join("\n\n"));
    if (turnReply.needsAdCredit) {
      await ctx.reply(body, { reply_markup: toGrammyKeyboard(adCreditKeyboard()) });
    } else if (turnReply.pendingId) {
      await ctx.reply(body, { reply_markup: toGrammyKeyboard(confirmSpendKeyboard(turnReply.pendingId)) });
    } else if (turnReply.toolPendingId) {
      await ctx.reply(body, { reply_markup: toGrammyKeyboard(confirmToolKeyboard(turnReply.toolPendingId)) });
    } else {
      await ctx.reply(body);
    }
    return;
  }

  // fallback: الوكيل مش متاح (نت/موديل/مهلة) — الرد القرائي القديم أحسن من صمت.
  // بيتشال في المرحلة ٢-هـ بعد ما agent_turn يثبت نفسه على مستخدمين حقيقيين.
  //
  // errorReason دلوقتي بيتحط في الحالتين اللي بيوصلوا هنا: الوكيل مش متاح (turn === null)
  // **و** لفة رجعت 200 وهي فاضية. الافتراض القديم إنه بيبقى موجود في الحالة الأولى بس هو
  // اللي كان بيخلي اللفة الفاضية تعدي من غير أي تحذير. لو أي أمر تنفيذي (عدّل/ذكرني/ضيف)
  // وقع على المسار ده، لازم العميل يعرف إنه رد قراءة بس ومحصلش تنفيذ فعلي، بدل ما يفتكر
  // إن التعديل اتسجل وهو ماتسجلش. صمت هنا هو بالظبط الشكوى اللي البلاغ ده بيوصفها.
  if (errorReason) {
    console.error("agent turn fell back to read-only:", errorReason);
    logAgentFallback(sb, userId, "text", errorReason);
  }
  const notice = errorReason
    ? `⚠️ ${userFacingFailure(errorReason)}. اللي تحت رد قراءة من بياناتك المسجّلة — لو كنت طالب تعديل أو إضافة أو تذكير، **هو ماتسجّلش**، جرب تاني كمان شوية.\n\n`
    : "";

  const agentInput = await fetchAgentContext(sb, userId);
  const context = buildAgentContext(agentInput);
  const answer = await askZad(
    agentSystemPrompt(resolveDialect({ text: ctx.message.text, country: agentInput.country, currency: agentInput.currency })),
    `${context}\n\n=== سؤال العميل ===\n${ctx.message.text}`,
  );

  if (answer) {
    await ctx.reply(clampForTelegram(notice + answer));
  } else {
    await ctx.reply(clampForTelegram(notice + "معلش، مش قادر أرد دلوقتي — جرب تاني كمان شوية، أو اختار من القائمة:"), {
      reply_markup: toGrammyKeyboard(mainMenuKeyboard()),
    });
  }
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
      await ctx.reply(body, { reply_markup: toGrammyKeyboard(adCreditKeyboard()) });
    } else if (turnReply.pendingId) {
      await ctx.reply(body, { reply_markup: toGrammyKeyboard(confirmSpendKeyboard(turnReply.pendingId)) });
    } else if (turnReply.toolPendingId) {
      await ctx.reply(body, { reply_markup: toGrammyKeyboard(confirmToolKeyboard(turnReply.toolPendingId)) });
    } else {
      await ctx.reply(body);
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
});

// صورة (فاتورة أو صنف) — نفس مبدأ التسجيل الصوتي: الأصناف بتتضاف للمخزون مباشرة (زي
// مسح الكاميرا في التطبيق)، أي مبلغ إجمالي مقروء من الفاتورة بيعدي على نفس تأكيد
// الكتابة العادية قبل ما يتسجل في zad_transactions.
bot.on("message:photo", async (ctx) => {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const userId = await resolveUserId(sb, ctx.chat.id);
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
  if (result.receiptType === "budget_card") {
    // مفيش مسار كتابة لـ monthly_limit من الشات/الصوت حالياً (check_budget قراءة بس) —
    // مينفعش نعد المستخدم بأمر نصي بيسجلها، فبس نوضح إنها مش فاتورة ونوجهه للتطبيق.
    const amountHint = result.total > 0
      ? `قريت رقم ${result.total} في الصورة دي، بس شكلها كارت رصيد أو راتب مش فاتورة مقاضي — مقريتش منها أصناف. لو عايز تحدد ميزانيتك، ده من تطبيق زاد.`
      : "الصورة دي شكلها كارت رصيد أو راتب مش فاتورة، فمقريتش منها أصناف.";
    await ctx.reply(amountHint);
    return;
  }

  // OCR only supplies fields. Both pharmacy and inventory mutations are executed by
  // zad-brain; the receipt total still waits for the normal financial confirmation.
  if (result.receiptType === "pharmacy" && result.items.length > 0) {
    let addedCount = 0;
    for (const item of result.items) {
      if (!item.name?.trim()) continue;
      const qty = Number.isFinite(item.quantity) && item.quantity > 0 ? Math.round(item.quantity) : 1;
      const added = await agentExecute(userId, "add_pharmacy_item", {
        name: item.name.trim(),
        quantity: qty,
        unit: item.unit || "قرص",
        category: "عام",
      });
      if (!added.ok) {
        console.error("photo pharmacy through zad-brain failed");
        continue;
      }
      addedCount++;
    }
    const summary = addedCount > 0
      ? `✅ اتضاف ${addedCount} صنف للصيدلية${result.storeName ? ` من ${result.storeName}` : ""}.`
      : "";
    if (result.total > 0) {
      const currency = (await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle()).data?.currency ?? "غير معروف";
      const title = (result.storeName || "فاتورة صيدلية").slice(0, 80);
      const { data: pending, error } = await sb.from("telegram_pending_writes").insert({
        user_id: userId, chat_id: ctx.chat.id, txn_kind: "expense", amount: Math.round(result.total * 100) / 100,
        title, category: "الرعاية الصحية", confidence: 0.75,
      }).select("id").single();
      if (!error && pending) {
        await ctx.reply(`${summary}${summary ? "\n\n" : ""}` + confirmSpendMessage({ is_spend: true, kind: "expense", amount: result.total, title, category: "الرعاية الصحية", confidence: 0.75 }, currency), {
          reply_markup: toGrammyKeyboard(confirmSpendKeyboard((pending as { id: string }).id)),
        });
        return;
      }
    }
    await ctx.reply(summary || "معلش، ملقتش أصناف واضحة في الصورة دي.");
    return;
  }

  let addedCount = 0;
  for (const item of result.items) {
    if (!item.name?.trim()) continue;
    const qty = Number.isFinite(item.quantity) && item.quantity > 0 ? Math.round(item.quantity) : 1;
    const added = await agentExecute(userId, "add_inventory_item", {
      item_name: item.name.trim(),
      quantity: qty,
      unit: item.unit || "قطعة",
      category: item.category || null,
    });
    if (added.ok) {
      addedCount++;
    } else {
      console.error("photo inventory through zad-brain failed");
    }
  }
  const itemsSummary = addedCount > 0
    ? `✅ اتضاف ${addedCount} صنف للمخزون${result.storeName ? ` من ${result.storeName}` : ""}.`
    : "";

  if (result.total > 0) {
    const currency = (await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle())
      .data?.currency ?? "غير معروف";
    const title = (result.storeName || "فاتورة").slice(0, 80);
    const category = (result.category || "أخرى").slice(0, 40);
    const { data: pending, error } = await sb.from("telegram_pending_writes").insert({
      user_id: userId,
      chat_id: ctx.chat.id,
      txn_kind: "expense",
      amount: Math.round(result.total * 100) / 100,
      title,
      category,
      confidence: 0.75,
    }).select("id").single();
    if (!error && pending) {
      await ctx.reply(
        (itemsSummary ? itemsSummary + "\n\n" : "") +
          confirmSpendMessage({ is_spend: true, kind: "expense", amount: result.total, title, category, confidence: 0.75 }, currency),
        { reply_markup: toGrammyKeyboard(confirmSpendKeyboard((pending as { id: string }).id)) },
      );
      return;
    }
    console.error("photo pending write insert failed:", error);
  }

  await ctx.reply(itemsSummary || "معلش، ملقتش أصناف ولا مبلغ واضح في الصورة دي.");
});

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
// الترتيب مقصود بالحرف: بنقرا اللحظة من `zad_voice_moments` (مصدر الحقيقة الوحيد لأسماء
// الأدوية ومواعيدها — مفيش أي اسم بييجي من كلام الموديل)، بنكتب في الداتابيز، وبنرد على
// العميل **بس** لو الكتابة نجحت. أي فشل بيقول له صراحةً إنها ماتسجلتش.
async function settleDose(sb: SupabaseClient, userId: string, momentId: string, action: DoseAction): Promise<string> {
  const { data: momentRow } = await sb.from("zad_voice_moments")
    .select("id,user_id,moment,facts")
    .eq("id", momentId).eq("user_id", userId).maybeSingle();
  const moment = momentRow as { moment: string; facts: Record<string, unknown> } | null;
  if (!moment) {
    return "التذكير ده مش موجود عندي — افتح صفحة الصيدلية في التطبيق وسجّل الجرعة من هناك.";
  }
  const itemIds = Array.isArray(moment.facts?.item_ids)
    ? (moment.facts.item_ids as unknown[]).map(String).filter((v) => /^[0-9a-fA-F-]{36}$/.test(v))
    : [];
  const scheduledAt = typeof moment.facts?.scheduled_at === "string" ? moment.facts.scheduled_at : null;
  if (itemIds.length === 0 || !scheduledAt) {
    return "التذكير ده قديم ومش مربوط بدوا محدد — سجّل الجرعة من صفحة الصيدلية في التطبيق.";
  }

  if (action === "snooze") {
    // التأجيل بيتكتب في جدول، مش في الذاكرة: الكرون هو اللي بيقرا منه فبيسكت عن
    // نفس الجرعة لحد ما الوقت يعدّي، وبعدها بيبعت تذكير واحد جديد.
    const until = new Date(Date.now() + DOSE_SNOOZE_MINUTES * 60_000).toISOString();
    const { error: snoozeErr } = await sb.from("zad_dose_snoozes").upsert(
      itemIds.map((itemId) => ({
        user_id: userId, item_id: itemId, scheduled_at: scheduledAt, snooze_until: until,
      })),
      { onConflict: "user_id,item_id,scheduled_at" },
    );
    if (snoozeErr) {
      console.error("[dose] snooze failed:", snoozeErr.message);
      return "معلش، مقدرتش أأجّل التذكير — هفضل أفكّرك زي ما هو.";
    }
    return `تمام، هسكت ${DOSE_SNOOZE_MINUTES} دقيقة وأفكّرك تاني.`;
  }

  const names: string[] = [];
  const failed: string[] = [];
  if (action === "skipped") {
    // صف `skipped` في نفس الخانة الزمنية: الفهرس الفريد (user_id, item_id, scheduled_at)
    // بيخليه الإجابة الوحيدة على الجرعة دي، و`zad_enqueue_missed_doses` بيعتبره إجابة
    // فبيبطّل «فاتتك الجرعة». units = 0 لأن مفيش حاجة خرجت من العلبة. الـinsert مش upsert
    // عن قصد: الفهرس جزئي (WHERE scheduled_at IS NOT NULL) وON CONFLICT مايقدرش يستنتجه؛
    // وتكرار (23505) معناه إن الجرعة اتجاوب عليها قبل كده — مش فشل.
    const { data: items } = await sb.from("zad_pharmacy_items").select("id,name").eq("user_id", userId).in("id", itemIds);
    const nameOf = new Map(((items ?? []) as Array<{ id: string; name: string }>).map((i) => [i.id, i.name]));
    for (const itemId of itemIds) {
      const { error } = await sb.from("zad_pharmacy_doses").insert({
        user_id: userId, item_id: itemId, scheduled_at: scheduledAt, status: "skipped", units: 0,
      });
      if (error && (error as { code?: string }).code !== "23505") {
        console.error("[dose] skip failed:", itemId, error.message);
        failed.push(itemId);
      } else {
        names.push(String(nameOf.get(itemId) ?? "الدوا"));
      }
    }
  } else {
    for (const itemId of itemIds) {
      const { data: result, error } = await sb.rpc("zad_log_pharmacy_dose_atomic", {
        p_user: userId,
        p_item: itemId,
        // الخانة الزمنية بتاعة التذكير نفسه، مش دلوقتي: الفهرس الفريد
        // (user_id, item_id, scheduled_at) بيخلي ضغطتين على نفس الزر عملية واحدة،
        // وبيخلي الكرون يشوف إن الجرعة دي بالذات اتاخدت.
        p_scheduled_at: scheduledAt,
        p_taken_at: new Date().toISOString(),
      });
      const r = result as { ok?: boolean; name?: string; remaining_quantity?: number } | null;
      if (error || !r?.ok) {
        console.error("[dose] log failed:", itemId, error?.message ?? JSON.stringify(r));
        failed.push(itemId);
      } else {
        names.push(String(r.name ?? "الدوا"));
      }
    }
  }
  if (names.length === 0) {
    return "معلش، مقدرتش أسجّل ده دلوقتي — ماتسجلش، جرّب من صفحة الصيدلية في التطبيق.";
  }
  // التذكير ده خلص شغله: مايتبعتش تاني ولا يتحسب كجرعة فايتة.
  await sb.from("zad_voice_moments")
    .update({ status: "sent", error: null })
    .eq("id", momentId).eq("user_id", userId);
  const label = names.join(" و");
  const partial = failed.length > 0 ? " — بس فيه دوا مقدرتش أسجله، راجع صفحة الصيدلية." : "";
  return action === "skipped"
    ? `تمام، سجّلت إنك مخدتش جرعة ${label} المرة دي، ومش هعاتبك عليها. الجرعة الجاية هفكّرك بيها في ميعادها${partial}`
    : failed.length > 0
      ? `اتسجلت جرعة ${label} ✅${partial}`
      : `اتسجلت جرعة ${label} ✅ تمام عليك.`;
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
    const { count } = await sb.from("zad_pharmacy_doses")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId).in("item_id", ids).eq("scheduled_at", scheduledAt);
    if ((count ?? 0) === 0) return { id: row.id, sentAt: new Date(row.sent_at ?? row.created_at).getTime() };
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
  const proactiveDismiss = parseProactiveDismissCallback(data);
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

  // تأكيد/إلغاء تسجيل مصروف. الكتابة الوحيدة في zad_transactions بتحصل هنا بس،
  // بعد ضغطة تأكيد صريحة من العميل.
  const spend = parseSpendCallback(data);
  if (spend) {
    const { data: pendingRow } = await sb.from("telegram_pending_writes")
      .select("id,user_id,txn_kind,amount,title,category,status,expires_at")
      .eq("id", spend.pendingId)
      // إعادة التحقق: الـ chat اللي بيأكد لازم يكون لسه مربوط بنفس اليوزر صاحب الطلب.
      .eq("user_id", userId)
      .maybeSingle();

    const row = pendingRow as {
      id: string; txn_kind: string; amount: number; title: string;
      category: string | null; status: string; expires_at: string;
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
      wallet: "card",
    });
    if (!confirmed.ok) {
      console.error("telegram expense confirmation via zad-brain failed");
      await sb.from("telegram_pending_writes").update({ status: "pending" }).eq("id", row.id);
      await ctx.reply("معلش، التسجيل فشل — جرب تاني.");
      return;
    }

    const { data: u } = await sb.from("zad_users").select("currency").eq("id", userId).maybeSingle();
    const cur = (u as { currency?: string } | null)?.currency ?? "غير معروف";
    await ctx.reply(`اتسجل ✅ ${isolate(sanitizeName(row.title))} — ${isolate(money(row.amount, cur))}`);
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
      console.error("telegram add_pharmacy through zad-brain failed");
      await sb.from("telegram_pending_pharmacy").update({ status: "pending" }).eq("id", row.id);
      await ctx.reply("معلش، التسجيل فشل — جرب تاني.");
      return;
    }

    // مفيش AlarmManager على السيرفر — التذكيرات الفعلية بتتفعل لما تطبيق زاد يعمل sync
    // ويلاقي الدواء الجديد في zad_pharmacy_items (نفس آلية PharmacyReminderScheduler
    // اللي بتشتغل تلقائي عند أي تغيير في قائمة الأدوية).
    await ctx.reply(`اتسجل ✅ ${isolate(sanitizeName(row.name))} — المواعيد: ${isolate(row.dose_times ?? "")}\nهتلاقي التذكير شغال في التطبيق بعد أول فتح.`);
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
    const newQty = checkin.stillInStock ? prompt.quantity_at_prompt : 0;
    const observed = await agentExecute(userId, "update_inventory_qty", {
      item_name: prompt.item_name,
      new_qty: newQty,
      reason: "إجابة العميل على سؤال متابعة المخزون",
    });
    if (!observed.ok) {
      await ctx.reply("معلش، مقدرتش أحفظ إجابتك — جرّب تاني.");
      return;
    }

    await sb.from("telegram_checkin_prompts")
      .update({ status: checkin.stillInStock ? "answered_yes" : "answered_no", answered_at: new Date().toISOString() })
      .eq("id", prompt.id);

    await ctx.reply(checkin.stillInStock ? "تمام ✅ هفتكر إني سألت عنه." : `سجلتها خلصت ✅ ${isolate(sanitizeName(prompt.item_name))}`);
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

const handleUpdate = webhookCallback(bot, "std/http", { secretToken: WEBHOOK_SECRET });

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
    const status = await ensureWebhook(new URL(req.url).searchParams.get("force") === "1");
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

  if (req.method === "POST" && new URL(req.url).searchParams.get("job") === "realtime_push") {
    if (!(await secretMatches(req.headers.get("X-Realtime-Push-Secret"), "ZAD_REALTIME_PUSH_SECRET"))) {
      return new Response("unauthorized", { status: 401 });
    }
    if (!BOT_CONFIGURED) {
      return new Response(JSON.stringify({ ok: false, reason: "bot not configured" }), { status: 503 });
    }
    try {
      const payload = await req.json();
      const { user_id, title, body, dismiss_task_id, speech, dose_moment_id } = payload as {
        user_id?: string; title?: string; body?: string; dismiss_task_id?: string;
        // اختياري: كلام الفويس لو مختلف عن نص الرسالة (كلام بلهجة وإحساس بدل عنوان وأرقام).
        speech?: string;
        // اختياري: تنبيه جرعة — معرّف صف zad_voice_moments، بيتحوّل لزرار «أخدت الجرعة».
        dose_moment_id?: string;
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
      const keyboard = dose_moment_id && /^[0-9a-fA-F-]{36}$/.test(dose_moment_id)
        ? doseKeyboard(dose_moment_id)
        : dismiss_task_id && /^[0-9a-fA-F-]{36}$/.test(dismiss_task_id)
        ? proactiveDismissKeyboard(dismiss_task_id)
        : undefined;
      await sendTelegramMessage(chatId, `${title}\n\n${body}`, keyboard);
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
      const alreadySentToday = await checkinsSentToday(sb, user_id);
      if (alreadySentToday >= MAX_CHECKINS_PER_USER_PER_DAY) {
        return new Response(JSON.stringify({ ok: true, delivered: false, reason: "daily budget spent" }), { headers: { "Content-Type": "application/json" } });
      }
      const { data: existingPending } = await sb.from("telegram_checkin_prompts")
        .select("id").eq("user_id", user_id).eq("item_name", item_name).eq("status", "pending").maybeSingle();
      if (existingPending) {
        return new Response(JSON.stringify({ ok: true, delivered: false, reason: "already pending" }), { headers: { "Content-Type": "application/json" } });
      }
      const delivered = await sendCheckInPrompt(sb, user_id, chatId, item_name, quantity);
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
