// Notification ingest path (m4.5 pass3b), moved verbatim from index.ts.
import { recordAction } from "./audit.ts";
import { DECISION_GROQ_MODEL, MODEL_ROUTINE, SUPABASE_URL, accountTimeZone, gateCall } from "./brainConsts.ts";
import { callModel } from "./callModel.ts";
import { commitIntent } from "./commitIntent.ts";
import { CORS_HEADERS } from "./corsHeaders.ts";
import { type LearnedFormat, learnedSenders, senderKnown } from "./learnedFormats.ts";
import { LIFE_EVENT_SCHEMA, type LifeEvent, type LifeKind, eventInstant, lifeEventCard, lifeEventPrompt, lifeKindOf, parseLifeEvent } from "./lifeEvents.ts";
import { readNotificationEvent } from "./notificationEvents.ts";
import { type GateVerdict, decideGate, gatePrompt, looksLikeMoneyMoved, parseGateVerdict, proposalFieldsFromVerdict, proposalTitle, ruleGate, txnKindFor } from "./notificationGate.ts";
import { normalizeClientClassification, sha256Hex } from "./notificationHelpers.ts";
import { OFFER_SCHEMA, isOfferApp, offerExpiresAt, offerPrompt, parseOffer, storeFromPackage } from "./notificationOffers.ts";
import { proposalPushText, pushToDevice, pushToTelegram } from "./push.ts";
import { redactNotificationText } from "./redact.ts";
import { DUPLICATE_PROPOSAL_WINDOW_MS, localNowContext, pickCrossChannelTwin, pickDuplicateProposalSibling, twinEnrichment } from "./shared.ts";
import { SupabaseClient } from "jsr:@supabase/supabase-js@2";

// Gates zad-telegram-bot's ?job=confirm_transaction, which this function calls after it
// reads a bank notification. The literal lives in both files rather than in an env var,
// matching that function's four existing job secrets (CHECKIN_CRON_SECRET and friends) —
// they are in-file constants because their other callers are SQL triggers with the value
// embedded. Keep this in step with CONFIRM_TRANSACTION_SECRET there; a mismatch shows up
// as every notification silently falling back to an in-app question.
// Shared with zad-telegram-bot, which checks it on ?job=confirm_transaction. Project
// secret since 2026-09-05 (بند BE-03); the pre-rotation literal is gone and no longer
// authenticates anywhere.
//
// Empty string rather than a fallback when unset: sending an empty header makes
// zad-telegram-bot reject with a 401 that shows up in its logs, which is a far better
// failure than silently reaching for a value from git history.
const NOTIFICATION_CONFIRM_SECRET = Deno.env.get("ZAD_CONFIRM_TRANSACTION_SECRET") ?? "";

// صيغ البنوك اللي اتعلمت (learnedFormats.ts): بتتقري كل ١٠ دقايق، ولو القراية فشلت يفضل اللي قبلها.
const LEARNED_TTL_MS = 10 * 60_000;
let learnedCache: { at: number; rows: LearnedFormat[] } | null = null;
export async function learnedFormats(sb: SupabaseClient): Promise<LearnedFormat[]> {
  if (learnedCache && Date.now() - learnedCache.at < LEARNED_TTL_MS) return learnedCache.rows;
  const { data, error } = await sb.rpc("zad_bank_formats_learned", { p_min_users: 3 });
  if (error) {
    console.warn("[learned_formats] read failed:", error.message);
    return learnedCache?.rows ?? [];
  }
  learnedCache = { at: Date.now(), rows: (data ?? []) as LearnedFormat[] };
  return learnedCache.rows;
}

type NotificationPrompt =
  | { job: "confirm_transaction"; proposalId: string }
  | { job: "review_notification" };
type NotificationPromptDelivery = "delivered" | "not_linked" | "retryable_failure" | "in_flight";

/**
 * Deliver at most one active Telegram prompt for an ingest event. The database claim is a
 * two-minute lease: a crashed invocation can be resumed, while concurrent notification
 * reposts cannot both message the customer. Delivery is marked only after Telegram accepts
 * the request, so a transient outage remains retryable.
 */
async function deliverNotificationPrompt(
  sb: SupabaseClient,
  userId: string,
  ingestEventId: string,
  prompt: NotificationPrompt,
): Promise<NotificationPromptDelivery> {
  const { data: eventState, error: stateError } = await sb.from("zad_notification_ingest_events")
    .select("confirmation_prompt_delivered_at")
    .eq("id", ingestEventId)
    .eq("user_id", userId)
    .maybeSingle();
  if (stateError) {
    console.error("notification prompt state fetch failed:", stateError.message);
    return "retryable_failure";
  }
  if ((eventState as { confirmation_prompt_delivered_at?: string | null } | null)?.confirmation_prompt_delivered_at) {
    return "delivered";
  }

  const { data: claimed, error: claimError } = await sb.rpc("zad_claim_notification_prompt_service", {
    p_user: userId,
    p_event: ingestEventId,
  });
  if (claimError) {
    console.error("notification prompt claim failed:", claimError.message);
    return "retryable_failure";
  }
  if (claimed !== true) return "in_flight";

  let delivery: NotificationPromptDelivery = "retryable_failure";
  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/zad-telegram-bot?job=${prompt.job}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Confirm-Transaction-Secret": NOTIFICATION_CONFIRM_SECRET,
      },
      body: JSON.stringify({
        user_id: userId,
        ingest_event_id: ingestEventId,
        ...(prompt.job === "confirm_transaction" ? { proposal_id: prompt.proposalId } : {}),
      }),
    });
    const responseBody = await response.json().catch(() => ({})) as { delivered?: boolean; reason?: string };
    if (response.ok && responseBody.delivered === true) {
      delivery = "delivered";
    } else if (response.ok && responseBody.reason === "not linked") {
      delivery = "not_linked";
      // تليجرام مش مربوط → FCM يغطي الفراغ (الوعي اللحظي). fire-and-forget.
      if (prompt.job !== "confirm_transaction") {
        pushToDevice(sb, userId, "زاد محتاج رأيك 💭", "في معاملة بنكية مستنية تأكيدك — افتح زاد للتأكيد.", { route: "transaction_proposals" }).catch(() => {});
      }
    }
  } catch (e) {
    console.error("notification prompt to telegram failed:", (e as Error).message);
    if (prompt.job !== "confirm_transaction") {
      pushToDevice(sb, userId, "زاد محتاج رأيك 💭", "في معاملة بنكية مستنية تأكيدك — افتح زاد للتأكيد.", { route: "transaction_proposals" }).catch(() => {});
    }
  }

  // سؤال «إنت؟» بيروح الموبايل **مع** تليجرام، مش بداله بس (طلب صاحب المشروع ٢٠٢٦-٠٩-٢٨):
  // ٤ من ٩ اقتراحات وصل سؤالها تليجرام وانتهت من غير رد. data-only عشان التطبيق هو اللي
  // يعرضه بزرارين «أيوه، أنا» / «مش أنا» (أندرويد مابيحطش أزرار على إشعار notification).
  if (prompt.job === "confirm_transaction") {
    try {
      const { data: p } = await sb.from("zad_transaction_proposals")
        .select("amount,currency,merchant_name,title,txn_kind")
        .eq("id", prompt.proposalId)
        .eq("user_id", userId)
        .maybeSingle();
      const text = proposalPushText((p ?? {}) as Parameters<typeof proposalPushText>[0]);
      const pushed = await pushToDevice(sb, userId, text.title, text.body, {
        route: "transaction_proposals",
        kind: "confirm_transaction",
        proposal_id: prompt.proposalId,
      }, true);
      // وصل الموبايل = السؤال وصل العميل، حتى لو تليجرام مش مربوط أو وقع.
      if (pushed === "sent" && delivery !== "delivered") delivery = "delivered";
    } catch (e) {
      console.error("confirm_transaction push failed:", (e as Error).message);
    }
  }

  const { error: finishError } = await sb.rpc("zad_finish_notification_prompt_service", {
    p_user: userId,
    p_event: ingestEventId,
    p_delivered: delivery === "delivered",
  });
  if (finishError) console.error("notification prompt finish failed:", finishError.message);
  return delivery;
}

/**
 * Server-side gate for Android NotificationListenerService. The phone may parse the bank
 * format, but this endpoint still re-applies the trust rules before any money write:
 * failed/pending/informational text never writes; ambiguous text waits for confirmation;
 * a parse with a usable amount becomes a durable proposal, and only a user decision can
 * turn that proposal into a transaction. Low-confidence direction requires classification.
 */
/** مهلة بوابة «فلوس اتحركت فعلاً؟» — موديل خفيف بيرد في ثانية أو اتنين وقت الطبيعي. */
const NOTIFICATION_GATE_TIMEOUT_MS = 15_000;

/**
 * حدث حياة من إشعار (٢.٨): نداء تاني للموديل يطلّع التفاصيل (لو وقع: الحدث بالنوع بس)، صف في zad_life_events،
 * وكارت للعميل — سؤال «أسجّله وأفكرك؟» لو فيه ميعاد جاي، وإلا ملاحظة. مفيش ميعاد بيتعمل هنا (life_event_decide).
 */
async function recordLifeEvent(
  sb: SupabaseClient,
  userId: string,
  ingestEventId: string,
  kind: LifeKind,
  title: string,
  text: string,
  rawText: string,
): Promise<{ life_event_id: string | null; offered: boolean }> {
  const tz = await accountTimeZone(sb, userId);
  const now = localNowContext(tz);
  let ev: LifeEvent | null = null;
  try {
    const p = lifeEventPrompt({ kind, title, text, todayLocal: `${now.date} ${now.time}`, weekday: now.weekday });
    let timer: ReturnType<typeof setTimeout> | undefined;
    const reply = await Promise.race([
      callModel({
        model: MODEL_ROUTINE, system: p.system, tools: [], history: [{ role: "user", text: p.user }], maxTokens: 300,
        responseSchema: LIFE_EVENT_SCHEMA, groqModel: DECISION_GROQ_MODEL,
      }),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error("life event read timed out")), NOTIFICATION_GATE_TIMEOUT_MS);
      }),
    ]).finally(() => clearTimeout(timer));
    ev = parseLifeEvent(reply.text ?? "", kind, rawText);
  } catch (e) {
    console.warn("[life_event] model unavailable:", (e as Error)?.message);
  }
  ev ??= parseLifeEvent("{}", kind, rawText)!;
  const at = eventInstant(ev, now.utc_offset);
  const offered = kind !== "result_ready" && at !== null && Date.parse(at) > Date.now() + 15 * 60_000;
  const { data: row, error } = await sb.from("zad_life_events").upsert({
    user_id: userId, ingest_event_id: ingestEventId, kind, title: ev.title, event_at: at,
    place: ev.place, action_hint: ev.action, link: ev.link,
  }, { onConflict: "user_id,ingest_event_id" }).select("id").maybeSingle();
  if (error || !row) {
    console.error("[life_event] insert failed:", error?.message ?? "no row");
    return { life_event_id: null, offered: false };
  }
  const id = (row as { id: string }).id;
  const hasTime = (ev.whenLocal ?? "").length > 10;
  const whenText = at
    ? new Date(at).toLocaleString("ar-EG", {
      timeZone: tz, weekday: "long", day: "numeric", month: "long", ...(hasTime ? { hour: "numeric", minute: "2-digit" } : {}),
    })
    : null;
  const card = lifeEventCard(ev, whenText, offered);
  await sb.from("zad_insights").upsert({
    user_id: userId, kind: offered ? "question" : "insight", surface: "home_card", priority: "normal",
    title: card.title, body: card.body,
    dedupe_key: `life_event_${id}`,
    action_type: offered ? "yes_no" : null,
    about_item: `life_event:${id}`,
    status: "pending", updated_at: new Date().toISOString(),
  }, { onConflict: "user_id,dedupe_key" });
  // The same card on Telegram, with its two answers — the app's card waits for the app to open (ZAD_PLAN ٢.٨).
  pushToTelegram(userId, card.title, card.body, fetch, undefined, false, undefined, undefined, undefined, undefined,
    undefined, undefined, undefined, { id, offered, link: ev.link })
    .catch((e) => console.warn("[life_event] telegram failed:", (e as Error)?.message));
  return { life_event_id: id, offered };
}

/**
 * عرض من إشعار تطبيق تسوق أو توصيل (ZAD_PLAN ١٠.١٤): نداء تاني للموديل يطلّع المحل والصنف والخصم والكود
 * والانتهاء، وصف في zad_notification_offers **لصاحبه بس**. مفيش كارت ولا رسالة تليجرام: العرض بيستنى لحد ما
 * العميل يسأل (find_deals) أو يفتح العروض — إشعار التطبيق نفسه وصله خلاص.
 */
async function recordNotificationOffer(
  sb: SupabaseClient,
  userId: string,
  ingestEventId: string,
  packageName: string,
  title: string,
  text: string,
  rawText: string,
): Promise<{ offer_id: string | null }> {
  const tz = await accountTimeZone(sb, userId);
  const now = localNowContext(tz);
  let offer = null;
  try {
    const p = offerPrompt({ packageName, title, text, todayLocal: `${now.date} ${now.time} (${now.weekday})` });
    let timer: ReturnType<typeof setTimeout> | undefined;
    const reply = await Promise.race([
      callModel({
        model: MODEL_ROUTINE, system: p.system, tools: [], history: [{ role: "user", text: p.user }], maxTokens: 300,
        responseSchema: OFFER_SCHEMA, groqModel: DECISION_GROQ_MODEL,
      }),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error("offer read timed out")), NOTIFICATION_GATE_TIMEOUT_MS);
      }),
    ]).finally(() => clearTimeout(timer));
    offer = parseOffer(reply.text ?? "", rawText, storeFromPackage(packageName));
  } catch (e) {
    console.warn("[notification_offer] model unavailable:", (e as Error)?.message);
  }
  if (!offer) return { offer_id: null };
  const { data: row, error } = await sb.from("zad_notification_offers").upsert({
    user_id: userId, ingest_event_id: ingestEventId, package_name: packageName.slice(0, 120),
    store: offer.store, item: offer.item, discount_percent: offer.discountPercent, discount_amount: offer.discountAmount,
    currency: offer.currency, code: offer.code, link: offer.link,
    expires_at: offerExpiresAt(offer.expiresOn, now.utc_offset),
  }, { onConflict: "user_id,ingest_event_id" }).select("id").maybeSingle();
  if (error || !row) {
    console.error("[notification_offer] insert failed:", error?.message ?? "no row");
    return { offer_id: null };
  }
  return { offer_id: (row as { id: string }).id };
}

export async function handleNotificationIngest(sb: SupabaseClient, userId: string, body: any): Promise<Response> {
  const packageName = String(body.package_name ?? "").trim();
  const title = String(body.title ?? "").trim();
  const text = String(body.text ?? "").trim();
  const rawText = `${title} ${text}`.trim();
  if (!packageName || !rawText) {
    return new Response(JSON.stringify({ ok: false, status: "ignored", reason: "empty_notification" }), {
      status: 400, headers: CORS_HEADERS,
    });
  }

  // البصمة بتتحسب على النص الخام عشان التكرار يفضل يتمسك بنفس الدقة، والنص اللي بيتخزّن
  // منقّى. الاتنين مقصودين: المطابقة محتاجة الخام، والتخزين لأ.
  const dedupeHash = await sha256Hex(`${userId}\n${packageName}\n${rawText}`);
  const { data: insertedEvent, error: dedupeErr } = await sb.from("zad_notification_ingest_events").insert({
    user_id: userId,
    dedupe_hash: dedupeHash,
    package_name: packageName,
    title: redactNotificationText(title),
    body: redactNotificationText(text),
    client_classification: String(body.client_classification ?? null),
    status: "received",
  }).select("id").maybeSingle();
  let ingestEventId = (insertedEvent as { id?: string } | null)?.id;
  let existingEventStatus: string | null = null;
  if (dedupeErr) {
    const code = (dedupeErr as any)?.code;
    if (code === "23505") {
      const { data: existingEvent, error: existingEventError } = await sb.from("zad_notification_ingest_events")
        .select("id,status")
        .eq("user_id", userId)
        .eq("dedupe_hash", dedupeHash)
        .maybeSingle();
      if (existingEventError || !existingEvent) {
        console.error("notification duplicate recovery failed:", existingEventError?.message ?? "event missing");
        return new Response(JSON.stringify({ ok: false, status: "rejected", reason: "duplicate_recovery_failed" }), {
          status: 500, headers: CORS_HEADERS,
        });
      }
      ingestEventId = (existingEvent as { id: string }).id;
      existingEventStatus = (existingEvent as { status: string }).status;
      if (["logged", "ignored", "rejected"].includes(existingEventStatus)) {
        return new Response(JSON.stringify({ ok: true, status: "ignored", reason: "duplicate" }), { headers: CORS_HEADERS });
      }
    } else {
      console.error("notification dedupe insert failed:", dedupeErr.message);
      return new Response(JSON.stringify({ ok: false, status: "rejected", reason: "audit_insert_failed" }), {
        status: 500, headers: CORS_HEADERS,
      });
    }
  }
  if (!ingestEventId) {
    return new Response(JSON.stringify({ ok: false, status: "rejected", reason: "audit_event_missing" }), {
      status: 500, headers: CORS_HEADERS,
    });
  }

  const mark = async (status: string, reason?: string, transactionId?: string | null) => {
    // الحالات النهائية بتختم processed_at — إيداع الإغلاق idempotent (مايتحطش تاني لو موجود).
    const terminal = ["logged", "ignored", "rejected"].includes(status);
    await sb.from("zad_notification_ingest_events")
      .update({
        status, rejection_reason: reason ?? null, transaction_id: transactionId ?? null,
        updated_at: new Date().toISOString(),
        ...(terminal ? { processed_at: new Date().toISOString() } : {}),
      })
      .eq("user_id", userId).eq("dedupe_hash", dedupeHash);
  };

  // م٦.٤: أحداث الإشعارات (موعد دكتور، طيران، أبشر) — مقفولة افتراضياً بمفتاح لكل نوع. من غير مفتاح مفتوح مفيش قراءة.
  // النص الخام مابيتخزنش ولا بيتسجل؛ الاستخراج المنظّم بس بيتكتب في zad_notification_reads.
  try {
    const nowCtx = localNowContext(await accountTimeZone(sb, userId));
    const ev = await readNotificationEvent({
      async enabledKinds(uid) {
        const { data } = await sb.from("zad_notification_switches").select("kind").eq("user_id", uid).eq("enabled", true);
        return new Set(((data ?? []) as { kind: string }[]).map((r) => r.kind)) as Set<any>;
      },
      async insertRead(row) {
        const { error } = await sb.from("zad_notification_reads").insert(row);
        if (error) console.error("[notification_event] insert failed:", error.message);
        return !error;
      },
      async commitIntent(intent) {
        const { data, error } = await sb.rpc("zad_commit_intent", { p_intent: intent });
        return { ok: !error && (data as { ok?: boolean } | null)?.ok === true };
      },
    }, { userId, ingestEventId, title, text, utcOffset: nowCtx.utc_offset });
    if (ev) {
      await mark("ignored", `notification_event:${ev.kind}`);
      return new Response(JSON.stringify({ ok: true, status: "notification_event", classification: "informational_only", kind: ev.kind, stored: ev.stored, intent: ev.intent }), { headers: CORS_HEADERS });
    }
  } catch (e) {
    console.warn("[notification_event] failed:", (e as Error)?.message);
  }

  // ١٠.١٤: تطبيق تسوق أو توصيل — كلمات الإعلان عنده هي العرض نفسه، مش ضجيج.
  const offerSource = isOfferApp(packageName);
  const rule = ruleGate(rawText, offerSource);
  if (rule) {
    await mark("ignored", rule);
    return new Response(JSON.stringify({ ok: true, status: "ignored", classification: rule }), { headers: CORS_HEADERS });
  }

  // ── بوابة «فلوس اتحركت فعلاً؟» (notificationGate.ts) — قبل أي سؤال أو اقتراح. ──
  const knownSender = senderKnown(packageName, title, learnedSenders(await learnedFormats(sb)));
  let verdict: GateVerdict | null = null;
  try {
    const g = gatePrompt({ packageName, title, text, knownSender });
    // حد أقصى للبوابة كلها: السلسلة ممكن تمشي على ٧ موديلات × ٢٠ ث، والصف متسجل "received"
    // قبل النداء — طلب بيموت في النص كان بيسيبه كده للأبد. تقرير ما بعد النشر ٢٠٢٦-٠٩-٢٨: ١٠
    // معاملات مكتملة من ٢٩ إشعار واقفين "received". بعد المهلة الحكم null، وده بالظبط سلوك
    // "الموديل وقع" الموثّق في decideGate (بنك معروف ⇒ نسأل).
    let gateTimer: ReturnType<typeof setTimeout> | undefined;
    const reply = await Promise.race([
      gateCall(g),
      new Promise<never>((_, reject) => {
        gateTimer = setTimeout(() => reject(new Error(`gate timed out after ${NOTIFICATION_GATE_TIMEOUT_MS}ms`)), NOTIFICATION_GATE_TIMEOUT_MS);
      }),
    ]).finally(() => clearTimeout(gateTimer));
    verdict = parseGateVerdict(reply.text ?? "", rawText);
  } catch (e) {
    console.warn("[notification_gate] model unavailable:", (e as Error)?.message);
  }
  const gate = decideGate(verdict, knownSender, looksLikeMoneyMoved(rawText), offerSource);
  const gateTag = `gate:${verdict?.kind ?? "unavailable"}:${verdict ? verdict.confidence.toFixed(2) : "-"}${knownSender ? ":known" : ""}`;
  console.log(`[notification_gate] ${packageName} → ${gate} (${gateTag})`);
  if (gate === "ignore") {
    await mark("ignored", gateTag);
    return new Response(JSON.stringify({ ok: true, status: "ignored", classification: "informational_only", gate: verdict?.kind ?? "unavailable" }), { headers: CORS_HEADERS });
  }
  if (gate === "reminder" && verdict) {
    // تذكير دفع جاي — مش معاملة. ملاحظة في «رؤى زاد» بدل سؤال «إيداع ولا خصم».
    const what = verdict.kind === "installment_due" ? "قسط" : verdict.kind === "subscription_renewal" ? "تجديد اشتراك" : "فاتورة";
    const who = verdict.counterparty ?? knownSender ?? packageName;
    const money = verdict.amount ? ` بـ${verdict.amount}${verdict.currency ? ` ${verdict.currency}` : ""}` : "";
    await sb.from("zad_insights").upsert({
      user_id: userId, kind: "insight", surface: "home_card", priority: "normal",
      title: `🔔 ${what} جاي`,
      body: `${who}: ${what}${money} مستحق قريب. لو التزام ثابت، قولي أسجّله عشان يتحسب من المتاح.`,
      dedupe_key: `notif_reminder_${dedupeHash.slice(0, 24)}`,
      status: "pending", updated_at: new Date().toISOString(),
    }, { onConflict: "user_id,dedupe_key" });
    await mark("ignored", gateTag);
    return new Response(JSON.stringify({ ok: true, status: "reminder", classification: "informational_only", gate: verdict.kind }), { headers: CORS_HEADERS });
  }

  if (gate === "life_event" && verdict) {
    // ٢.٨: موعد/حكومي/نتيجة/شحنة — مش فلوس. الحدث بيتسجل مقترح، والعميل بيتسأل قبل أي ميعاد (lifeEvents.ts).
    const kind = lifeKindOf(verdict.kind)!;
    const res = await recordLifeEvent(sb, userId, ingestEventId, kind, title, text, rawText);
    await mark("ignored", `life_event:${kind}`);
    return new Response(JSON.stringify({ ok: true, status: "life_event", classification: "informational_only", gate: verdict.kind, ...res }), { headers: CORS_HEADERS });
  }

  if (gate === "offer") {
    const res = await recordNotificationOffer(sb, userId, ingestEventId, packageName, title, text, rawText);
    await mark("ignored", res.offer_id ? "offer" : "offer:empty");
    return new Response(JSON.stringify({ ok: true, status: "offer", classification: "informational_only", gate: "promo_or_ad", ...res }), { headers: CORS_HEADERS });
  }

  const parsed = body.parsed ?? {};
  const clientClassification = normalizeClientClassification(body.client_classification);
  // المبلغ والعملة والتاجر وأرقام الكارت من قراءة الموديل لما يكون متأكد إن الفلوس اتحركت — مش من regex الموبايل بس.
  const fields = proposalFieldsFromVerdict({ gate, verdict, parsed, rawText, packageName, title, knownSender });
  const amount = fields.amount ?? NaN;
  const confidence = Number(parsed.confidence ?? 0);
  if (!Number.isFinite(amount) || amount <= 0) {
    await mark("ambiguous", "needs_confirmation");
    // كان بيقف هنا — العميل يشوفه بس لو دوّر يدوي على شاشة المعاملات، مفيش سؤال فعلي.
    // دلوقتي سؤال حقيقي (نفس شكل ask_user) يظهر في "رؤى زاد" فوراً؛ إجابة العميل
    // بتعدي على answerBrainQuestion → triggerBrainEvent → نفس حلقة الأدوات
    // (log_transaction) فتتسجل صح، مش تتخمن وتتقفل صامتة.
    const amountGuess = Number.isFinite(amount) && amount > 0 ? `${Math.round(amount * 100) / 100}` : "غير واضح";
    await sb.from("zad_insights").upsert({
      user_id: userId, kind: "question", surface: "home_card", priority: "normal",
      title: "معاملة بنكية محتاجة تأكيد",
      // النص المقتبس هنا منقّى كمان — الصف ده بيتعرض للعميل **وبيدخل سياق النموذج**، يعني
      // نسخة تانية من نفس النص بترسّب في مكان تالت. المبلغ باقي زي ما هو لأنه هو السؤال.
      body: gate === "money" && verdict
        ? `وصل إشعار ${verdict.kind === "credit" || verdict.kind === "refund" ? "فلوس داخلة" : "خصم"} من ${knownSender ?? packageName} بس المبلغ مش واضح. قولي المبلغ وأنا أسجّله. النص: "${redactNotificationText(rawText).slice(0, 200)}"`
        : `وصل إشعار من ${knownSender ?? packageName} فيه فلوس بس مش متأكدة إنها عملية فعلاً. هل دي عملية حصلت؟ أيوة = اتحسبها، لأ = تجاهلها. النص: "${redactNotificationText(rawText).slice(0, 200)}"`,
      dedupe_key: `notif_ambiguous_${dedupeHash.slice(0, 24)}`,
      action_type: "yes_no",
      about_item: rawText.slice(0, 200),
      status: "pending", updated_at: new Date().toISOString(),
    }, { onConflict: "user_id,dedupe_key" });
    const promptDelivery = await deliverNotificationPrompt(sb, userId, ingestEventId, {
      job: "review_notification",
    });
    const shouldRetryDelivery = promptDelivery === "retryable_failure" || promptDelivery === "in_flight";
    return new Response(JSON.stringify({
      ok: true,
      status: shouldRetryDelivery ? "delivery_retry" : "ambiguous",
      classification: "ambiguous",
      channel: promptDelivery === "delivered" ? "telegram_and_app" : "app",
      prompt_delivery: promptDelivery,
    }), { headers: CORS_HEADERS });
  }

  // نوع العملية من البوابة لما تكون متأكدة إنها فلوس اتحركت — أدق من تخمين الموبايل من الكلمات.
  const parsedKind = gate === "money" && verdict
    ? txnKindFor(verdict.kind)
    : parsed.txn_kind === "transfer"
      ? "transfer"
      : (parsed.txn_kind === "income" || parsed.is_expense === false ? "income" : "expense");
  // البوابة قالت «فلوس اتحركت» ⇒ العميل بيأكد بس (مش بيصنّف). غير كده السلوك القديم.
  const needsClassification = gate !== "money" && (clientClassification !== "completed" || confidence < 0.9);
  const txnKind = needsClassification ? null : parsedKind;
  const sourceLabel = fields.merchantName;

  // تصنيف مقصد الخصم (اشتراك/قسط/فاتورة/إيجار) — العميل بيسأل "الخصم ده ليه؟"
  // فلما الإشعار فيه إشارة دورية، بنحوّل العنوان للنوع ونسأل بس لو مش متأكدين.
  const deductionKind = (() => {
    const t = rawText;
    if (/تجديد\s*اشتراك|اشتراك|subscription|netflix|spotify|shahid|jawwy|anghami|stc|mobily|zain/i.test(t)) return "اشتراك";
    if (/قسط|أقساط|تقسيط|installment|تمويل|أمر خصم/i.test(t)) return "قسط";
    if (/إيجار|ايجار|rent/i.test(t)) return "إيجار";
    if (/فاتورة|كهربا|كهرباء|مياه|نت|إنترنت|جوال|bill|electric|water/i.test(t)) return "فاتورة";
    return null;
  })();
  const suggestedTitle = verdict?.kind === "cash_withdrawal"
    ? `سحب كاش — ${fields.bankName}`.slice(0, 80)
    : deductionKind
    ? `${deductionKind} — ${sourceLabel}`.slice(0, 80)
    : null;

  const proposalRow = {
    user_id: userId,
    source_event_id: ingestEventId,
    idempotency_key: dedupeHash,
    source_type: "notification_listener",
    status: needsClassification ? "needs_classification" : "awaiting_confirmation",
    txn_kind: txnKind,
    amount: Math.round(amount * 100) / 100,
    title: suggestedTitle ?? proposalTitle({
      merchant: sourceLabel, bank: fields.bankName, clientTitle: String(parsed.title ?? ""), notificationTitle: title, packageName,
    }),
    category: String(parsed.category ?? (txnKind === "income" ? "دخل" : txnKind === "transfer" ? "تحويل" : "أخرى")).trim().slice(0, 40),
    currency: fields.currency,
    wallet: "card",
    transfer_to: txnKind === "transfer" ? "cash" : null,
    merchant_name: sourceLabel,
    bank_name: fields.bankName,
    card_last_digits: fields.cardLastDigits,
    confidence: Number.isFinite(confidence) ? Math.max(0, Math.min(1, confidence)) : null,
  };

  type ProposalState = { id: string; status: string };

  // ─── طبقة dedupe ضبابية (migration 20260829020000) ───
  // الهاش الحرفي بينكسر أول ما البنك يعيد الإشعار بنص مختلف (رصيد متبقي/توقيت).
  // البصمة الضبابية (مبلغ + تاجر مطبّع) خلال 20 دقيقة بتلقط الrepost قبل ما يولّد
  // اقتراح تاني. مش هاش ممتاز 100% — ده سد ثقب شائع، والهاش الحرفي بيفضل هو الحكم.
  let fuzzySibling: ProposalState | null = null;
  if (Number.isFinite(amount) && amount > 0 && ingestEventId) {
    const windowStart = new Date(Date.now() - 20 * 60000).toISOString();
    const { data: tokensRes } = await sb.rpc("zad_notif_fuzzy_key", { p_title: title, p_body: text });
    const merchantTokens = (tokensRes ?? null) as string[] | null;
    if (merchantTokens && merchantTokens.length > 0) {
      const { data: siblingEvents } = await sb.from("zad_notification_ingest_events")
        .select("id")
        .eq("user_id", userId)
        .overlaps("fuzzy_tokens", merchantTokens)
        .neq("id", ingestEventId)
        .gte("created_at", windowStart)
        .limit(5);
      var siblingEventRows = ((siblingEvents ?? []) as Array<{ id: string }>);
    } else {
      var siblingEventRows: Array<{ id: string }> = [];
    }
    const siblingIds = siblingEventRows.map((e) => e.id);
    if (siblingIds.length > 0) {
      const { data: siblingProposal } = await sb.from("zad_transaction_proposals")
        .select("id,status")
        .eq("user_id", userId)
        .in("source_event_id", siblingIds)
        .eq("amount", Math.round(amount * 100) / 100)
        .in("status", ["awaiting_confirmation", "needs_classification"])
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      fuzzySibling = (siblingProposal as ProposalState | null) ?? null;
    }
  }

  const { data: existingProposal, error: existingProposalError } = await sb.from("zad_transaction_proposals")
    .select("id,status")
    .eq("user_id", userId)
    .eq("idempotency_key", dedupeHash)
    .maybeSingle();
  if (existingProposalError) {
    console.error("notification proposal recovery failed:", existingProposalError.message);
    await mark("received", "proposal_lookup_failed");
    return new Response(JSON.stringify({ ok: false, status: "rejected", reason: "proposal_lookup_failed" }), {
      status: 500, headers: CORS_HEADERS,
    });
  }

  let proposal = (existingProposal ?? fuzzySibling) as ProposalState | null;
  let createdProposal = false;
  if (!existingProposal && fuzzySibling) {
    // repost بنص مختلف لنفس العملية — نعيد استخدام اقتراح الأخ بدل ما نكرر الإزعاج.
    // كانت `status: "duplicate_fuzzy"` وهي مش في status_check: الـPATCH بيرجع 400 من غير ما حد يشوفه، والصف
    // بيفضل received، فكل إعادة لنفس الإشعار بتعدّي البوابة تاني (truecaller ١/١١ ١٧:٤٠، نفس رسالة البنك).
    await mark("ignored", "duplicate_fuzzy");
    const promptDeliveryFuzzy = await deliverNotificationPrompt(sb, userId, ingestEventId, {
      job: "confirm_transaction",
      proposalId: fuzzySibling.id,
    });
    return new Response(JSON.stringify({
      ok: true,
      status: promptDeliveryFuzzy === "delivered" ? "duplicate_fuzzy" : "delivery_retry",
      proposal_id: fuzzySibling.id,
      prompt_delivery: promptDeliveryFuzzy,
    }), { headers: CORS_HEADERS });
  }
  if (proposal && ["posted", "rejected", "expired"].includes(proposal.status)) {
    return new Response(JSON.stringify({
      ok: true,
      status: "ignored",
      reason: "duplicate_resolved_proposal",
      proposal_id: proposal.id,
    }), { headers: CORS_HEADERS });
  }
  if (!proposal) {
    // ─── تكرار عبر المصادر: نفس المبلغ خلال ١٥ دقيقة من أي تطبيق ───
    // الطبقة الضبابية فوق محتاجة كلمة تاجر مشتركة، ورسالة البنك ورسالة InstaPay عن نفس
    // الدفعة غالبًا مافيهمش. الاقتراح بيتعمل عادي بس بيتعلّم، فسؤاله بيبقى "هل دي نفس
    // المعاملة؟" — ومهما ضغط العميل، دالة الحسم نفسها بتمنع القيد التاني (20260913213000).
    // فشل الاستعلام ده مايوقفش الاستلام: الحارس الحقيقي في دالة الحسم مش هنا.
    const { data: amountSiblings, error: amountSiblingsError } = await sb.from("zad_transaction_proposals")
      .select("id,status,txn_kind,transaction_id,created_at,currency,source_event_id,merchant_name,bank_name")
      .eq("user_id", userId)
      .eq("amount", proposalRow.amount)
      .neq("idempotency_key", dedupeHash)
      .in("status", ["awaiting_confirmation", "needs_classification", "posted"])
      .gte("created_at", new Date(Date.now() - DUPLICATE_PROPOSAL_WINDOW_MS).toISOString())
      .limit(10);
    if (amountSiblingsError) console.error("duplicate sibling lookup failed:", amountSiblingsError.message);

    // نفس الدفعة من تطبيق تاني خلال ٥ دقايق ← دمج صامت، مفيش اقتراح تاني ولا سؤال تاني
    // (pickCrossChannelTwin في shared.ts). الإشعار متسجل كـignored بسبب واضح للمراجعة.
    const siblingRows = (amountSiblings ?? []) as Array<{
      id: string; status: string; txn_kind: string | null; transaction_id: string | null;
      created_at: string; currency: string | null; source_event_id: string | null;
      merchant_name: string | null; bank_name: string | null;
    }>;
    const siblingEventIds = siblingRows.map((r) => r.source_event_id).filter((v): v is string => !!v);
    const packageOf = new Map<string, string>();
    if (siblingEventIds.length > 0) {
      const { data: siblingEvents } = await sb.from("zad_notification_ingest_events")
        .select("id,package_name").eq("user_id", userId).in("id", siblingEventIds);
      for (const e of (siblingEvents ?? []) as Array<{ id: string; package_name: string }>) packageOf.set(e.id, e.package_name);
    }
    const twin = pickCrossChannelTwin(
      siblingRows.map((r) => ({ ...r, package_name: r.source_event_id ? packageOf.get(r.source_event_id) ?? null : null })),
      { packageName, currency: proposalRow.currency, txnKind },
      Date.now(),
    );
    if (twin) {
      // الرسالة التانية بتكمّل الأولى: التاجر لو الأولى كان فيها اسم البنك بس.
      const twinRow = siblingRows.find((r) => r.id === twin.id);
      const patch = twinRow ? twinEnrichment(twinRow, { merchant: sourceLabel, bank: fields.bankName }) : null;
      if (patch) {
        const { error: enrichErr } = await sb.from("zad_transaction_proposals").update(patch)
          .eq("id", twin.id).eq("user_id", userId).in("status", ["awaiting_confirmation", "needs_classification"]);
        if (enrichErr) console.error("[notification_ingest] twin enrichment failed:", enrichErr.message);
      }
      await mark("ignored", `merged_cross_channel:${twin.id}`);
      return new Response(JSON.stringify({
        ok: true, status: "ignored", reason: "merged_cross_channel", proposal_id: twin.id,
      }), { headers: CORS_HEADERS });
    }
    const duplicateOf = pickDuplicateProposalSibling(
      (amountSiblings ?? []) as Array<{ id: string; status: string; txn_kind: string | null; transaction_id: string | null; created_at: string }>,
      txnKind,
    );

    const { data: insertedProposal, error: proposalError } = await sb.from("zad_transaction_proposals")
      .insert({ ...proposalRow, duplicate_of_proposal_id: duplicateOf?.id ?? null })
      .select("id,status")
      .single();
    if ((proposalError as { code?: string } | null)?.code === "23505") {
      // A concurrent repost won the insert race. Recover its row and continue delivery;
      // the unique key already guarantees both requests refer to the same proposal.
      const { data: racedProposal, error: raceLookupError } = await sb.from("zad_transaction_proposals")
        .select("id,status")
        .eq("user_id", userId)
        .eq("idempotency_key", dedupeHash)
        .maybeSingle();
      if (!raceLookupError && racedProposal) proposal = racedProposal as ProposalState;
    } else if (!proposalError && insertedProposal) {
      proposal = insertedProposal as ProposalState;
      createdProposal = true;
    }
    if (!proposal) {
      // The audit row is intentionally left resumable. A retry with the same dedupe hash
      // will recover it and attempt this insert again instead of disappearing as a duplicate.
      console.error("notification proposal insert failed:", proposalError?.message ?? "missing row");
      await mark("received", "proposal_insert_failed");
      return new Response(JSON.stringify({ ok: false, status: "rejected", reason: "proposal_insert_failed" }), {
        status: 500, headers: CORS_HEADERS,
      });
    }
  }
  if (["posted", "rejected", "expired"].includes(proposal.status)) {
    return new Response(JSON.stringify({
      ok: true,
      status: "ignored",
      reason: "duplicate_resolved_proposal",
      proposal_id: proposal.id,
    }), { headers: CORS_HEADERS });
  }

  const promptDelivery = await deliverNotificationPrompt(sb, userId, ingestEventId, {
    job: "confirm_transaction",
    proposalId: proposal.id,
  });
  const deliveredToTelegram = promptDelivery === "delivered";
  const shouldRetryDelivery = promptDelivery === "retryable_failure" || promptDelivery === "in_flight";
  const proposalNeedsClassification = proposal.status === "needs_classification";

  if (createdProposal) {
    await recordAction(sb, userId, { source: "event", runId: null }, {
      tool: "parse_notification_payload",
      input: {
        package_name: packageName,
        title: redactNotificationText(title),
        text: redactNotificationText(text),
        client_classification: body.client_classification,
        parsed: { ...parsed, raw_text: undefined },
      },
      summary: deliveredToTelegram
        ? "أنشأ اقتراح معاملة موحد وبعت تأكيده على تيليجرام"
        : "أنشأ اقتراح معاملة موحد للتأكيد داخل التطبيق",
    });
  }
  await mark(proposalNeedsClassification ? "ambiguous" : "awaiting_confirmation", "needs_user_approval");

  return new Response(JSON.stringify({
    ok: true,
    status: shouldRetryDelivery
      ? "delivery_retry"
      : proposalNeedsClassification ? "needs_classification" : "awaiting_confirmation",
    classification: proposalNeedsClassification ? "ambiguous" : "completed_transaction",
    proposal_id: proposal.id,
    channel: deliveredToTelegram ? "telegram_and_app" : "app",
    prompt_delivery: promptDelivery,
  }), { headers: CORS_HEADERS });
}
