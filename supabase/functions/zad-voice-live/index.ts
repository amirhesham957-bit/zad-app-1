// zad-voice-live — بند 33.1: relay صوتي ريل-تايم بين تطبيق زاد وGemini Live API.
//
// الفكرة: العميل بيفتح WebSocket واحد على الفانكشن دي (بتوكن Supabase حقيقي، نفس أي
// نداء موثّق تاني). الفانكشن بتتحقق من الهوية، بتخصم من رصيد "voice" في entitlement،
// وبعدين بتفتح WebSocket تاني — من عندها هي، بمفتاح سيرفر-سايد — لـGemini Live API
// الحقيقي، وترسل رسالة setup الأولى. من ساعتها، أي فريم بيجي من العميل بيتمرر لجيميناي
// زي ما هو، وأي فريم بيرجع من جيميناي بيتمرر للعميل زي ما هو. المفتاح عمره ما بيوصل
// للكلاينت — ده أهم سبب لوجود الفانكشن دي أصلاً بدل ما التطبيق يكلم Gemini مباشرة.
//
// نطاق 33.1 الأصلي كان النقل ثنائي الاتجاه بس. بند 33.3 (الشخصية/اللهجة) وبند 33.2
// (ربط أدوات zad-brain) اتضافوا فوقه بعدين — systemInstruction وtools في رسالة setup،
// واعتراض رسائل toolCall بدل تمريرها زي ما هي.
//
// 33.2 — قرار العميل 2026-09-01: تأكيد كلامي فوري لأدوات الفلوس، مش زرار (مفيش زرار في
// مكالمة صوتية). التصميم: أدوات CONFIRM_VOICE_TOOLS (نفس CONFIRM_REQUIRED_TOOLS في
// validators.ts) أول toolCall بتوقيعة معينة (اسم+آرجيومنتس) بيرجّع "awaiting_confirmation"
// من غير تنفيذ فعلي — الموديل (بتوجيه persona.ts) بيسأل العميل يتأكد بصوته. لو الموديل
// نادى **نفس** الأداة بنفس البيانات تاني (يعني سمع "أيوه")، دي المرة اللي بتتنفّذ فعلياً.
// التنفيذ نفسه بينده zad-brain's agent_execute (أدوات مباشرة، مطابقة DIRECT_INGRESS_TOOLS
// بالحرف) أو agent_confirm (أدوات الفلوس بعد التأكيد) عبر HTTP بمفتاح الخدمة — مفيش
// تكرار لـrunTool/validators هنا، نفس المسار الآمن اللي الشات المكتوب بيستخدمه بالظبط.
//
// بروتوكول Gemini Live الحقيقي (اتأكد حي 2026-09-01 ضد مفاتيح المشروع، مش من التوثيق):
// - العنوان: wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent
// - التوثيق: باراميتر ?key=<API_KEY> في الرابط نفسه (اتأكد إنه شغال — الهيدر المخصص
//   x-goog-api-key اللي الـSDK الرسمي بيستخدمه مش متاح أصلاً على WebSocket قياسي في
//   Deno/المتصفح، فباراميتر الرابط هو الطريقة الوحيدة الممكنة هنا، ولحسن الحظ شغالة).
// - أول رسالة لازم تتبعت من العميل (هنا: الفانكشن نفسها) هي setup:
//   {"setup":{"model":"models/<name>","generationConfig":{"responseModalities":["AUDIO"]},
//             "systemInstruction":{"parts":[{"text":"..."}]}}}
//   systemInstruction تحقق حي (2026-09-01) إنه sibling لـmodel/generationConfig جوه
//   setup، مش متداخل جوه generationConfig — جرّبتها بنص عربي وردت رسالة حقيقية.
// - الموديلات اللي بتقبل bidiGenerateContent فعلاً على مشروعنا (`client.models.list()`
//   مفلترة بـsupported_actions): gemini-3.1-flash-live-preview،
//   gemini-2.5-flash-native-audio-preview-{09,12}-2025، gemini-3.5-transcribe-live،
//   gemini-3.5-live-translate-preview. اتأكد حي إن responseModalities لازم تكون
//   ["AUDIO"] مش ["TEXT"] على موديلات الصوت — TEXT بيرجع 1007 "combination of response
//   modalities not supported". الافتراضي هنا gemini-3.1-flash-live-preview (جيل 3.x،
//   نفس تفضيل المشروع الموثّق في CLAUDE.md إن 2.5 كتير منها بيتقفل لعملاء جداد).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { buildVoiceSystemInstruction } from "./persona.ts";
import { formatVoiceContext, loadVoiceContext } from "./context.ts";
import { ASK_BRAIN_TOOL_NAME, describeVoiceProposal, isConfirmRequired, VOICE_TOOL_USAGE_INSTRUCTION, VOICE_TOOLS } from "./tools.ts";
import {
  CLOSE_ENTITLEMENT,
  CLOSE_PROVIDER_UNAVAILABLE,
  CLOSE_UNAUTHORIZED,
  clientCloseForUpstream,
  closeReason,
  frameToText,
  liveVoiceFor,
  normalizeClientFrame,
} from "./protocol.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VOICE_LIVE_MODEL = Deno.env.get("ZAD_VOICE_LIVE_MODEL") ?? "gemini-3.1-flash-live-preview";

// صوت الرد. من غير speechConfig جيميناي بيستخدم صوته الافتراضي (Puck، ذكوري) — وده كان
// السبب الحقيقي إن المكالمة بترد بصوت مش أنثوي رغم إن persona.ts مكتوب فيها "أنتي بنت
// حرة" و"الصوت اللي هينطقك أنثوي شبابي". النص كان صح، الإعداد هو اللي كان ناقص.
// Aoede نفس الصوت اللي zad-core-intelligence/index.ts:932 وvoice-selftest بيستخدموه
// بالظبط، فالمكالمة الحية والردود القصيرة بقى ليهم نفس الصوت بدل صوتين مختلفين.
const VOICE_LIVE_VOICE = Deno.env.get("ZAD_VOICE_LIVE_VOICE") ?? "Aoede";

// اللهجة بتتظبط من systemInstruction (مجرّبة وشغالة). speechConfig.languageCode
// **مش** متأكد منه على موديلات الـnative-audio، وفريم setup مرفوض بيقفل الجلسة بـ1007
// بدل ما يتجاهل الحقل — يعني تجربة غير محسوبة هنا بتكسر الصوت كله. فسايبينه خلف
// متغير بيئة، مقفول افتراضياً: اضبط ZAD_VOICE_LIVE_LANG=ar-EG بعد ما تجرّبه حي.
const VOICE_LIVE_LANG = Deno.env.get("ZAD_VOICE_LIVE_LANG")?.trim() || null;
const GEMINI_LIVE_HOST = "generativelanguage.googleapis.com";
const GEMINI_LIVE_PATH =
  "/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent";

// نفس مسبح zad-brain/zad-core-intelligence بالظبط (ZAD_API_KEY_1..5 مع fallback على
// GEMINI_API_KEY المفرد) — سرّ مشترك عن قصد، مش تصادم أسماء. جلسة صوتية طويلة مالهاش
// نفس منطق إعادة المحاولة عبر المسبح كله بتاع النداءات القصيرة؛ محاولة واحدة بمفتاح
// من الدور، ولو فشلت العميل بيعيد المحاولة (فتبدأ بمفتاح تاني تلقائياً).
const GEMINI_KEY_POOL: string[] = [1, 2, 3, 4, 5]
  .map((n) => Deno.env.get(`ZAD_API_KEY_${n}`))
  .filter((k): k is string => !!k);
if (GEMINI_KEY_POOL.length === 0) {
  const legacy = Deno.env.get("ZAD_API_KEY") || Deno.env.get("GEMINI_API_KEY");
  if (legacy) GEMINI_KEY_POOL.push(legacy);
}
let keyCursor = 0;
function nextGeminiKey(): string | null {
  if (GEMINI_KEY_POOL.length === 0) return null;
  const key = GEMINI_KEY_POOL[keyCursor % GEMINI_KEY_POOL.length];
  keyCursor = (keyCursor + 1) % GEMINI_KEY_POOL.length;
  return key;
}

/** أقل نسخة كافية من resolveAuthedUserId (zad-brain/auth.ts) — بدون فرع service-role
 *  عن قصد: جلسة صوتية حية لازم تكون مستخدم حقيقي، مفيش سيناريو cron/بوت هنا.
 *
 *  ⚠️ كان فيه فرع "ضيف": لو التوكن = anon key (موجود جوه الـAPK نفسه)، الفانكشن كانت
 *  بتصدّق هيدر `x-user-id` وتنفّذ أدوات zad-brain بمفتاح الخدمة باسم أي مستخدم يتكتب في
 *  الهيدر ده — يعني أي حد معاه الـAPK يقدر يسجّل مصروفات في حساب غيره. اتشال (٢٠٢٦-٠٩-١٤):
 *  الهوية من JWT المستخدم بس، ومن غير جلسة = إغلاق بـ4401 ورسالة "سجّل دخول". */
async function resolveUserId(req: Request): Promise<string | null> {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.toLowerCase().startsWith("bearer ") ? header.slice(7).trim() : "";
  if (!token) return null;
  try {
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data, error } = await sb.auth.getUser(token);
    return !error && data?.user?.id ? data.user.id : null;
  } catch {
    return null;
  }
}

/** رفض بعد الـupgrade مش قبله: بوابة Supabase بتحوّل أي رد مش 101 على طلب WebSocket
 *  لفشل عام (اتقاس 502 من غير body)، فالعميل ماكانش بيعرف إن السبب رصيد أو تسجيل دخول.
 *  كود الإغلاق التطبيقي بيوصل سليم لأنه جوه اتصال اتفتح فعلاً. */
function rejectAfterUpgrade(req: Request, code: number, reason: string, logDetail: string): Response {
  console.warn(`[voice-live] rejected ${code} ${reason}: ${logDetail}`);
  const { socket, response } = Deno.upgradeWebSocket(req);
  socket.onopen = () => {
    try {
      socket.close(code, closeReason(reason));
    } catch (e) {
      console.error("[voice-live] closing rejected socket failed:", e);
    }
  };
  return response;
}

/** نفس entitlement.ts's consume() بالظبط (zad-brain) — نسخة مقصودة، مفيش استيراد بين
 *  فانكشنز في المشروع ده (كل فانكشن مستقل، نفس نمط zad-telegram-bot's نسخة entitlement.ts
 *  الخاصة بيها). فشل فتح — لو الـRPC نفسه واقع، عميل دافع ميتقفلش بسبب باج في الفوترة. */
async function consumeVoiceEntitlement(
  // deno-lint-ignore no-explicit-any
  sb: any,
  userId: string,
): Promise<{ allowed: boolean; reason: string }> {
  try {
    const { data, error } = await sb.rpc("zad_entitlement_consume", {
      p_user: userId, p_kind: "voice", p_tz: "UTC",
    });
    if (error) {
      console.error("zad_entitlement_consume (voice) failed, failing open:", error.message);
      return { allowed: true, reason: "gate_unavailable" };
    }
    return data as { allowed: boolean; reason: string };
  } catch (e) {
    console.error("zad_entitlement_consume (voice) threw, failing open:", e);
    return { allowed: true, reason: "gate_unavailable" };
  }
}

Deno.serve(async (req) => {
  if (req.headers.get("upgrade")?.toLowerCase() !== "websocket") {
    return new Response("expected a websocket upgrade request", { status: 400 });
  }

  const userId = await resolveUserId(req);
  if (!userId) {
    return rejectAfterUpgrade(req, CLOSE_UNAUTHORIZED, "unauthorized", "no valid user JWT");
  }

  const geminiKey = nextGeminiKey();
  if (!geminiKey) {
    return rejectAfterUpgrade(req, CLOSE_PROVIDER_UNAVAILABLE, "provider_not_configured", "no Gemini keys in env");
  }

  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const entitlement = await consumeVoiceEntitlement(sb, userId);
  if (!entitlement.allowed) {
    return rejectAfterUpgrade(req, CLOSE_ENTITLEMENT, entitlement.reason || "entitlement_denied", `user ${userId}`);
  }

  // بند 33.3 — نفس مصدر اللهجة اللي buildChatSystemPrompt بيقراه (zad_users.country)،
  // عشان الصوت يتكلم بنفس لهجة العميل اللي الشات المكتوب بيتكلم بيها بالظبط.
  //
  // والسياق معاها: الجلسة الحية كانت بتاخد أدوات كتابة بس، فـ«سجّلي ٥٠ قهوة» تشتغل
  // و«كام فاضل في الميزانية؟» مالهاش مصدر — الصوت كان أحسن حاجة في المنتج وأقلهم معرفة.
  // الفشل هنا مش بيوقّف المكالمة: مكالمة بشخصية وصوت من غير أرقام أحسن من مكالمة
  // مابتفتحش (loadVoiceContext بيقرا ٧ جداول، أي واحد فيهم ممكن يتأخر).
  const [userRow, voiceContext] = await Promise.all([
    (async () => {
      try {
        const { data } = await sb.from("zad_users").select("country").eq("id", userId).maybeSingle();
        return data as { country?: string } | null;
      } catch {
        return null;
      }
    })(),
    (async () => {
      try {
        return formatVoiceContext(await loadVoiceContext(sb, userId));
      } catch (e) {
        console.error("[voice-live] context load failed:", (e as Error)?.message);
        return "";
      }
    })(),
  ]);

  // الشخصية من إعدادات العميل (سارة/كريم/الأليف) — نفس صوت قراءة الإشعارات.
  const liveVoice = liveVoiceFor(new URL(req.url).searchParams.get("voice"), VOICE_LIVE_VOICE);

  const systemInstructionText = [
    buildVoiceSystemInstruction(userRow?.country),
    VOICE_TOOL_USAGE_INSTRUCTION,
    voiceContext,
  ].filter((part) => part && part.length > 0).join("\n\n");

  const { socket: clientSocket, response } = Deno.upgradeWebSocket(req);

  // رسائل العميل اللي وصلت قبل ما اتصال جيميناي يخلص الهاندشيك وياخد setup — بتتراكم
  // هنا وتتبعت بالترتيب أول ما geminiSocket.onopen يشتغل، بدل ما تتفقد.
  let geminiSocket: WebSocket | null = null;
  const pendingFromClient: (string | ArrayBufferLike)[] = [];

  // بند 33.2 — توقيعات toolCall (اسم+آرجيومنتس) لأدوات الفلوس اللي اتسألت للتأكيد
  // في الجلسة دي، لسه مستنية نداء تاني بنفس التوقيعة. Set في الذاكرة، مربوطة بعمر
  // الاتصال — جلسة جديدة = تأكيدات جديدة، مفيش حفظ عبر الجلسات عن قصد.
  const pendingConfirmSignatures = new Set<string>();

  /** بينده zad-brain's agent_execute (أدوات مباشرة) أو agent_confirm (فلوس بعد تأكيد)
   *  عبر HTTP بمفتاح الخدمة — نفس نمط resolveAuthedUserId's service-role bypass
   *  (Authorization: Bearer SERVICE_ROLE_KEY + user_id في الجسم) اللي كل نداء
   *  server-to-server تاني في المشروع ده بيستخدمه. */
  async function callZadBrainTool(
    action: "agent_execute" | "agent_confirm",
    tool: string,
    input: Record<string, unknown>,
  ): Promise<{ ok: boolean; summary: string }> {
    try {
      const res = await fetch(`${SUPABASE_URL}/functions/v1/zad-brain`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": `Bearer ${SERVICE_ROLE_KEY}` },
        body: JSON.stringify({ action, user_id: userId, tool, input, source: "voice" }),
      });
      const data = await res.json().catch(() => ({}));
      const ok = Boolean((data as { ok?: unknown })?.ok);
      const summary = String((data as { summary?: unknown; error?: unknown })?.summary
        ?? (data as { error?: unknown })?.error ?? (ok ? "تم" : "معلش، الأداة دي رفضت التنفيذ."));
      return { ok, summary };
    } catch (e) {
      console.error("zad-voice-live: zad-brain tool call failed:", e);
      return { ok: false, summary: "معلش، حصل خطأ فني وأنا بحاول أنفّذها تاني." };
    }
  }

  /** طلب بكلام العميل لـ agent_turn (كل أدوات العقل) — نفس نداء تليجرام. عمليات الفلوس اللي
   *  العقل يقترحها بتفضل مستنية تأكيد في التطبيق/تليجرام، ودي بتتقال للعميل صراحة. */
  async function askZadBrain(request: string): Promise<{ ok: boolean; summary: string; pending: number }> {
    try {
      const res = await fetch(`${SUPABASE_URL}/functions/v1/zad-brain`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": `Bearer ${SERVICE_ROLE_KEY}` },
        body: JSON.stringify({ action: "agent_turn", user_id: userId, message: request.slice(0, 1200), source: "voice" }),
      });
      const data = await res.json().catch(() => ({})) as { ok?: boolean; reply?: string; proposals?: unknown[] };
      const ok = res.ok && data.ok !== false;
      return {
        ok,
        summary: String(data.reply ?? (ok ? "تم" : "معلش، العقل مقدرش ينفّذ الطلب ده دلوقتي.")).slice(0, 1500),
        pending: Array.isArray(data.proposals) ? data.proposals.length : 0,
      };
    } catch (e) {
      console.error("zad-voice-live: ask_zad_brain failed:", e);
      return { ok: false, summary: "معلش، حصل خطأ وأنا بكلم العقل. جرّب تاني.", pending: 0 };
    }
  }

  /** بترد على toolCall واحدة أو أكتر جوّه نفس الرسالة — Gemini Live بيدّي array. */
  async function handleToolCall(
    functionCalls: Array<{ id: string; name: string; args?: Record<string, unknown> }>,
  ): Promise<void> {
    const responses: Array<{ id: string; name: string; response: Record<string, unknown> }> = [];
    for (const fc of functionCalls) {
      const args = fc.args ?? {};
      if (fc.name === ASK_BRAIN_TOOL_NAME) {
        const brain = await askZadBrain(String(args.request ?? ""));
        responses.push({
          id: fc.id, name: fc.name,
          response: {
            status: brain.ok ? "done" : "failed",
            summary: brain.summary,
            ...(brain.pending > 0 ? { needs_app_confirmation: `${brain.pending} عملية فلوس مستنية تأكيد من التطبيق أو تليجرام` } : {}),
          },
        });
        continue;
      }
      if (isConfirmRequired(fc.name)) {
        const signature = `${fc.name}:${JSON.stringify(args)}`;
        if (!pendingConfirmSignatures.has(signature)) {
          // أول مرة — سؤال بس، مفيش تنفيذ.
          pendingConfirmSignatures.add(signature);
          responses.push({
            id: fc.id, name: fc.name,
            response: { status: "awaiting_confirmation", summary: describeVoiceProposal(fc.name, args) },
          });
          continue;
        }
        // نداء تاني بنفس التوقيعة = العميل قال "أيوه". بننساها فوراً — تكرار لاحق
        // لنفس الأداة والبيانات لازم يتسأل تاني، مش يتنفّذ تاني بصمت.
        pendingConfirmSignatures.delete(signature);
        const result = await callZadBrainTool("agent_confirm", fc.name, args);
        responses.push({
          id: fc.id, name: fc.name,
          response: { status: result.ok ? "done" : "failed", summary: result.summary },
        });
        continue;
      }
      const result = await callZadBrainTool("agent_execute", fc.name, args);
      responses.push({
        id: fc.id, name: fc.name,
        response: { status: result.ok ? "done" : "failed", summary: result.summary },
      });
    }
    if (geminiSocket && geminiSocket.readyState === WebSocket.OPEN) {
      geminiSocket.send(JSON.stringify({ tool_response: { functionResponses: responses } }));
    }
  }

  const closeBoth = (code: number, reason: string) => {
    try {
      if (clientSocket.readyState === WebSocket.OPEN || clientSocket.readyState === WebSocket.CONNECTING) {
        clientSocket.close(code, reason);
      }
    } catch (e) {
      console.error("zad-voice-live: closing client socket failed:", e);
    }
    try {
      if (geminiSocket && (geminiSocket.readyState === WebSocket.OPEN || geminiSocket.readyState === WebSocket.CONNECTING)) {
        geminiSocket.close();
      }
    } catch (e) {
      console.error("zad-voice-live: closing gemini socket failed:", e);
    }
  };

  clientSocket.onopen = () => {
    const geminiUrl =
      `wss://${GEMINI_LIVE_HOST}${GEMINI_LIVE_PATH}?key=${encodeURIComponent(geminiKey)}`;
    geminiSocket = new WebSocket(geminiUrl);
    geminiSocket.binaryType = "arraybuffer";

    geminiSocket.onopen = () => {
      const setup = {
        setup: {
          model: `models/${VOICE_LIVE_MODEL}`,
          generationConfig: {
            responseModalities: ["AUDIO"],
            speechConfig: {
              voiceConfig: { prebuiltVoiceConfig: { voiceName: liveVoice } },
              ...(VOICE_LIVE_LANG ? { languageCode: VOICE_LIVE_LANG } : {}),
            },
          },
          systemInstruction: { parts: [{ text: systemInstructionText }] },
          tools: [{ functionDeclarations: VOICE_TOOLS.map((t) => ({
            name: t.name, description: t.description, parameters: t.parameters,
          })) }],
        },
      };
      geminiSocket!.send(JSON.stringify(setup));
      for (const frame of pendingFromClient) geminiSocket!.send(frame);
      pendingFromClient.length = 0;
    };

    geminiSocket.onmessage = (event) => {
      // بند 33.2 — الرسايل JSON (حتى الصوت جوه inlineData base64)، بس ممكن توصل كفريم
      // binary مش نص (protocol.ts: frameToText). بتتحوّل لنص الأول، عشان الـtoolCall
      // يتعترض في الحالتين، والعميل ياخد دايمًا فريم نصي — مالوش handler للبايتات.
      const text = frameToText(event.data);
      if (text === null) {
        console.warn("[voice-live] dropping non-JSON upstream frame of type", typeof event.data);
        return;
      }
      let parsed: { toolCall?: { functionCalls?: Array<{ id: string; name: string; args?: Record<string, unknown> }> } } | null = null;
      try {
        parsed = JSON.parse(text);
      } catch {
        // مش JSON صالح — نادر جداً في البروتوكول ده، نمررها زي ما هي بدل ما نرميها.
      }
      const calls = parsed?.toolCall?.functionCalls;
      if (Array.isArray(calls) && calls.length > 0) {
        handleToolCall(calls).catch((e) => console.error("zad-voice-live: handleToolCall failed:", e));
        return;
      }
      if (clientSocket.readyState === WebSocket.OPEN) clientSocket.send(text);
    };
    geminiSocket.onerror = (event) => {
      console.error("zad-voice-live: gemini socket error for user", userId, event);
    };
    geminiSocket.onclose = (event) => {
      // سبب جيميناي (حصة، موديل مش متاح، setup مرفوض) كان بيتبدّل بـ1011 عام ويضيع —
      // ده السطر الوحيد اللي بيقول ليه المكالمة وقفت، فبيتسجّل ويوصل للعميل.
      if (event.code !== 1000) {
        console.warn(`[voice-live] upstream closed ${event.code} "${event.reason}" model=${VOICE_LIVE_MODEL} user=${userId}`);
      }
      const out = clientCloseForUpstream(event.code, event.reason);
      closeBoth(out.code, out.reason);
    };
  };

  clientSocket.onmessage = (event) => {
    const frame = typeof event.data === "string" ? normalizeClientFrame(event.data) : event.data;
    if (geminiSocket && geminiSocket.readyState === WebSocket.OPEN) {
      geminiSocket.send(frame);
    } else {
      pendingFromClient.push(frame);
    }
  };
  clientSocket.onerror = (event) => {
    console.error("zad-voice-live: client socket error for user", userId, event);
  };
  clientSocket.onclose = () => {
    try {
      geminiSocket?.close();
    } catch (e) {
      console.error("zad-voice-live: closing gemini socket on client close failed:", e);
    }
  };

  return response;
});
