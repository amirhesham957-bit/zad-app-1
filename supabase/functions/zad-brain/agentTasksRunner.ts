// م٤.٥ تمريرة ٣ج: منفّذ المهام المستحقة (processDueAgentTasks) من index.ts — نقل صافي، بدون تغيير سلوك.
// اللي عايش في index.ts (buildSnapshot، runTool، برومبتات الشات، accountTimeZone، proactiveTitleFor، MODEL_ROUTINE،
// MAX_AGENT_TURNS) بيتمرر كـdeps من index.ts؛ عشان الملف ده ماينداش index.ts (دورة استيراد).

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";
import { CHAT_TOOLS } from "./chatTools.ts";
import { CONFIRM_REQUIRED_TOOLS, freshContext, type RunContext } from "./validators.ts";
import { callModel, type Turn } from "./callModel.ts";
import {
  agentTaskNotice, agentTaskPushData, attentionDecisions, capPostponeUntil, dailyCapDecision, type HoldCode, outlivesShelf,
  pacingDecision, pacingPriority, PACING_DUPLICATE_HOURS, postponeForQuietHours, postponeForSuppression,
  quietWindowOf, responsiveHourDecision,
} from "./shared.ts";
import { type KindOutcome, LEARN_WINDOW_DAYS, learnedPriority, learnedQuietUntil, outcomesByKind, type Stance, stanceOf } from "./outcomeLearning.ts";
import { deliverPetCall } from "./petCall.ts";
import { deliverRestockLink } from "./restockLink.ts";
import { HABIT_TRIAL_KINDS, habitTrialForTask, habitTrialPush } from "./habitTrialPush.ts";
import { HOUSE_LEARNING_KIND, houseLearningForTask, houseLearningPush } from "./houseLearningPush.ts";
import { sendAgentReport } from "./agentMail.ts";
import { soulBlock } from "./soul.ts";
import { pushToDevice, pushToTelegram } from "./push.ts";
import { UNCOUNTED_MOMENTS } from "./voiceMoments.ts";
import { runWeatherDrift, weatherAlertsEnabled } from "./weatherDrift.ts";
import { noteShown, type ShownChoice, settleIgnoredNotifications, settleOpenedNotifications } from "./banditReward.ts";
import { banditEnabled } from "./banditWiring.ts";
import { recentOutbound } from "../_shared/outbound.ts";
import { proactiveTurn, recordConversation } from "../_shared/conversationLog.ts";

export type AgentTaskDeps = {
  modelRoutine: string;
  maxAgentTurns: number;
  buildSnapshot: (sb: SupabaseClient, userId: string) => Promise<any>;
  buildChatSystemPrompt: (snap: any) => string;
  groqSystemFor: (snap: any) => string;
  runTool: (sb: SupabaseClient, userId: string, name: string, input: any, snap: any, ctx: RunContext, scope: AuditScope) => Promise<string>;
  proactiveTitleFor: (sb: any, userId: string, kind: string | null | undefined, shown?: { choice?: ShownChoice }) => Promise<string>;
  accountTimeZone: (sb: SupabaseClient, userId: string) => Promise<string>;
};

export async function processDueAgentTasks(sb: SupabaseClient, deps: AgentTaskDeps): Promise<{ processed: number; failed: number; postponed: number }> {
  const { buildSnapshot, buildChatSystemPrompt, groqSystemFor, runTool, proactiveTitleFor, accountTimeZone, modelRoutine: MODEL_ROUTINE, maxAgentTurns: MAX_AGENT_TURNS } = deps;
  // تنبيه الجو الاستباقي: خلف ZAD_WEATHER_ALERTS (مقفول = ولا قراية ولا شبكة). بيسجل لحظات بس، ومابيرميش.
  if (weatherAlertsEnabled()) await runWeatherDrift(sb, { accountTimeZone });
  // م٨.٢: مكافأة الـbandit للإشعارات اللي اتفتحت (ZAD_BANDIT_TONE مقفول = صفر). مابيرميش.
  await settleOpenedNotifications(sb, banditEnabled((k) => Deno.env.get(k)));
  // قاعدة الفشل: إشعار اتعرض من +٢٤ ساعة ولسه مااتقراش = فشل للقالب. بعد المكافأة عشان المقروء ياخد الأولوية. مابيرميش.
  await settleIgnoredNotifications(sb, banditEnabled((k) => Deno.env.get(k)));
  const { data: due } = await sb.from("agent_tasks")
    .select("id,user_id,task_description,goal_id,recurrence,scheduled_for,kind,created_at,held_count")
    .eq("status", "pending")
    .lte("scheduled_for", new Date().toISOString())
    .order("scheduled_for", { ascending: true })
    .limit(20);

  let processed = 0, failed = 0, postponed = 0;
  // منسّق المبادرات (pacingDecision في shared.ts): الأهم الأول، وواحدة كل ساعتين للعميل، والتكرار بيتلغي.
  // [delivered] = اللي اتبعت لكل عميل في آخر ٢٠ ساعة، من الداتابيز ومن اللفة دي.
  type DueTask = { id: string; user_id: string; task_description: string; goal_id: string | null; recurrence: string | null; kind: string | null; scheduled_for: string; created_at: string | null; held_count?: number | null };
  // ٣.٦ «يتعلم من النتيجة»: نتيجة كل نوع مبادرة لكل بيت (zad_kind_outcomes)، مرة في اللفة. فشل = عادي.
  const outcomesByUser = new Map<string, Map<string, KindOutcome>>();
  const outcomesFor = async (userId: string) => {
    let m = outcomesByUser.get(userId);
    if (!m) {
      const { data, error } = await sb.rpc("zad_kind_outcomes", { p_user: userId, p_days: LEARN_WINDOW_DAYS });
      if (error) console.error("[agent_tasks] zad_kind_outcomes failed:", error.message);
      m = outcomesByKind((data ?? []) as Array<Record<string, unknown>>);
      outcomesByUser.set(userId, m);
    }
    return m;
  };
  const stanceFor = async (t: { user_id: string; kind: string | null }) => stanceOf((await outcomesFor(t.user_id)).get(t.kind ?? ""));
  const dueRows = (due ?? []) as DueTask[];
  const stances = new Map<string, Stance>();
  for (const t of dueRows) stances.set(t.id, agentTaskNotice(t.kind).proactive ? await stanceFor(t) : "normal");
  // الأهم الأول؛ وجوه نفس الأهمية، النوع اللي البيت ده بيتعامل معاه قبل اللي بيتجاهله.
  const dueTasks = [...dueRows].sort((a, b) =>
    learnedPriority(pacingPriority(a.kind), stances.get(a.id) ?? "normal") - learnedPriority(pacingPriority(b.kind), stances.get(b.id) ?? "normal"));
  const delivered = new Map<string, Array<{ kind: string | null; at: string }>>();
  // المنسّق ٢: الذاكرة مشتركة (_shared/outbound.ts) — اللحظات الصوتية وسؤال المخزون بيتعدّوا كمان،
  // فمهمة مابتطلعش ورا تحية الصبح أو سؤال المخزون على طول. ردود الشات والجرعات مابتتعدّش.
  const deliveredFor = async (userId: string) => {
    let list = delivered.get(userId) as Array<{ kind: string | null; at: string }> | undefined;
    if (!list) {
      list = await recentOutbound(
        // ٢٤ ساعة مش ٢٠: السقف اليومي (المنسّق ٣) بيعدّ من نص الليل بتوقيته.
        sb, userId, new Date(Date.now() - Math.max(PACING_DUPLICATE_HOURS, 24) * 3_600_000).toISOString(), UNCOUNTED_MOMENTS,
      );
      delivered.set(userId, list);
    }
    return list;
  };
  // المنسّق ٤ (ZAD_PLAN ١.٤): مهام العميل المتأجلة أصلاً، عشان السقف يديله خانة بعدهم مش معاهم.
  const parkedByUser = new Map<string, Array<{ kind: string | null; at: string }>>();
  const parkedFor = async (userId: string) => {
    let list = parkedByUser.get(userId);
    if (!list) {
      const { data, error } = await sb.from("agent_tasks").select("kind,scheduled_for")
        .eq("user_id", userId).eq("status", "pending").gt("scheduled_for", new Date().toISOString());
      if (error) console.error("[agent_tasks] parked lookup failed:", error.message);
      list = ((data ?? []) as Array<{ kind: string | null; scheduled_for: string }>).map((r) => ({ kind: r.kind, at: r.scheduled_for }));
      parkedByUser.set(userId, list);
    }
    return list;
  };
  // م٥.١: قرارات ميزانية الانتباه لكل عميل، مرة في اللفة، على مهامه المستحقة بترتيب dueTasks.
  const planByUser = new Map<string, Map<string, "send" | "defer">>();
  const planFor = async (userId: string, tz: string) => {
    let m = planByUser.get(userId);
    if (!m) {
      m = attentionDecisions(
        dueTasks.filter((t) => t.user_id === userId).map((t) => ({ id: t.id, kind: t.kind, stance: stances.get(t.id) ?? "normal" })),
        await deliveredFor(userId), tz, Date.now(),
      );
      planByUser.set(userId, m);
    }
    return m;
  };
  // ساعات رد كل عميل (zad_engagement_hours)، مرة في اللفة. فشل القراية = null = الافتراضي.
  const engagementByUser = new Map<string, number[] | null>();
  const engagementHoursFor = async (userId: string) => {
    if (!engagementByUser.has(userId)) {
      const { data, error } = await sb.rpc("zad_engagement_hours", { p_user: userId });
      if (error) console.error("[agent_tasks] zad_engagement_hours failed:", error.message);
      engagementByUser.set(userId, Array.isArray(data) ? (data as unknown[]).map((n) => Number(n) || 0) : null);
    }
    return engagementByUser.get(userId) ?? null;
  };
  // أي تأجيل (كتم، هدوء، مسافة، سقف) بيعدّي من هنا: لو الخانة الجديدة بعد عمر المبادرة، بتتشال
  // ويتسجل ليه بدل ما تطلع بكرة بأرقام امبارح. true = اتأجلت.
  // ٣.٥ «الحراس بيتكلموا»: الحارس اللي أجّلها وكام مرة بيتكتبوا في الصف (held_reason، zad_held_messages).
  const park = async (task: DueTask, until: string, reason: HoldCode | "late"): Promise<boolean> => {
    if (outlivesShelf(task.kind, (task.recurrence ?? "once") !== "once", task.created_at, Date.parse(until))) {
      await sb.from("agent_tasks").update({
        status: "cancelled", result: `expired: ${task.kind} found no slot before it went stale (${reason})`,
        updated_at: new Date().toISOString(),
      }).eq("id", task.id);
      console.log(`[agent_tasks] ${task.kind} task ${task.id} expired (${reason}, next slot ${until})`);
      return false;
    }
    const now = new Date().toISOString();
    await sb.from("agent_tasks").update({
      scheduled_for: until, updated_at: now, held_reason: reason, held_count: (task.held_count ?? 0) + 1, held_at: now,
    }).eq("id", task.id);
    (await parkedFor(task.user_id)).push({ kind: task.kind, at: until });
    console.log(`[agent_tasks] ${task.kind} task ${task.id} postponed to ${until} (${reason})`);
    return true;
  };
  for (const task of dueTasks) {
    // اتأخرت لحد ما كلامها قدم (كرون واقف مثلاً): بتتشال من غير ما تتبعت.
    if (agentTaskNotice(task.kind).proactive && outlivesShelf(task.kind, (task.recurrence ?? "once") !== "once", task.created_at, Date.now())) {
      await park(task, new Date().toISOString(), "late");
      continue;
    }
    // الكتم (رفض من تليجرام) كان بيتقرا في الماسح بس — المهام المتكررة زي متابعة الهدف
    // كانت بتعدّيه. التأجيل لنهاية الكتم بيحترم الرفض من غير ما يقتل السلسلة.
    if (agentTaskNotice(task.kind).proactive) {
      const { data: mutes, error: muteErr } = await sb.from("zad_memory")
        .select("suppress_until")
        .eq("user_id", task.user_id)
        .eq("subject_kind", task.kind)
        .gt("suppress_until", new Date().toISOString());
      if (muteErr) console.error(`[agent_tasks] mute lookup failed for task ${task.id}:`, muteErr.message);
      const until = postponeForSuppression(task.kind, (mutes ?? []) as Array<{ suppress_until: string | null }>, Date.now());
      if (until) {
        if (await park(task, until, "muted")) postponed++;
        continue;
      }
      // ٣.٦: نوع البيت ده بيتجاهله (١٠ مرات وأقل من ١٠٪ اتعمل بيه) ⇒ مرة في الأسبوع بالكتير.
      const outcome = (await outcomesFor(task.user_id)).get(task.kind ?? "");
      const sentToday = (await deliveredFor(task.user_id)).filter((d) => d.kind === task.kind).map((d) => Date.parse(d.at));
      const lastOfKind = [outcome?.last_at ? Date.parse(outcome.last_at) : NaN, ...sentToday].filter(Number.isFinite);
      const learnedUntil = learnedQuietUntil(stances.get(task.id) ?? "normal", lastOfKind.length ? Math.max(...lastOfKind) : null, Date.now());
      if (learnedUntil) {
        if (await park(task, learnedUntil, "learned_quiet")) postponed++;
        continue;
      }
      // الفجوة ١٠: مبادرة استحقت بين ١١ بالليل و٧ الصبح بتوقيته بتستنى الصبح، مش بتتلغي.
      // نافذة نومه هو لو معروفة (الشريحة ٣٧)، وإلا ١١–٧.
      const { data: sleep } = await sb.from("zad_users").select("sleep_bed,sleep_wake").eq("id", task.user_id).maybeSingle();
      const quietUntil = postponeForQuietHours(
        task.kind, await accountTimeZone(sb, task.user_id), Date.now(),
        quietWindowOf((sleep as { sleep_bed?: string | null } | null)?.sleep_bed, (sleep as { sleep_wake?: string | null } | null)?.sleep_wake),
      );
      if (quietUntil) {
        if (await park(task, quietUntil, "quiet_hours")) postponed++;
        continue;
      }
      // المنسّق ٥ (ZAD_PLAN ١.٦): الاختيارية تستنى أقرب ساعة العميل بيرد فيها. لو الساعة دي بعد عمرها،
      // بتطلع دلوقتي بدل ما تتشال — الأحسن تتقال في ساعة مش أحسن حاجة من إنها ماتتقالش.
      const fit = responsiveHourDecision(task.kind, await engagementHoursFor(task.user_id), await accountTimeZone(sb, task.user_id), Date.now(),
        quietWindowOf((sleep as { sleep_bed?: string | null } | null)?.sleep_bed, (sleep as { sleep_wake?: string | null } | null)?.sleep_wake));
      if (fit.action === "postpone" && !outlivesShelf(task.kind, (task.recurrence ?? "once") !== "once", task.created_at, Date.parse(fit.until))) {
        if (await park(task, fit.until, "reply_hour")) postponed++;
        continue;
      }
      const pace = pacingDecision(task.kind, (task.recurrence ?? "once") !== "once", await deliveredFor(task.user_id), Date.now());
      if (pace.action === "duplicate") {
        await sb.from("agent_tasks").update({
          status: "cancelled", result: `duplicate: ${task.kind} already sent in the last ${PACING_DUPLICATE_HOURS}h`,
          updated_at: new Date().toISOString(),
        }).eq("id", task.id);
        console.log(`[agent_tasks] ${task.kind} task ${task.id} cancelled (duplicate)`);
        continue;
      }
      if (pace.action === "postpone") {
        if (await park(task, pace.until, "pacing")) postponed++;
        continue;
      }
      // المنسّق ٣: سقف اليوم (اتنين) — الزيادة تاخد خانة بكرة من الصحيان، الأهم الأول.
      const capTz = await accountTimeZone(sb, task.user_id);
      const capWindow = quietWindowOf((sleep as { sleep_bed?: string | null } | null)?.sleep_bed, (sleep as { sleep_wake?: string | null } | null)?.sleep_wake);
      // م٥.١: خطة الميزانية — اللي الخطة أجّلته ياخد خانة بكرة، واللي بعتته بيعدّي على السقف كشبكة أمان.
      const plan = await planFor(task.user_id, capTz);
      const cap = plan.get(task.id) === "defer"
        ? { action: "postpone" as const, until: capPostponeUntil((task.kind ?? "").trim(), capTz, Date.now(), capWindow, await parkedFor(task.user_id)) }
        : dailyCapDecision(task.kind, await deliveredFor(task.user_id), capTz, Date.now(), capWindow, await parkedFor(task.user_id));
      if (cap.action === "postpone") {
        if (await park(task, cap.until, "daily_cap")) postponed++;
        continue;
      }
    }
    // الرفيق بينادي باسمه (petCall.ts): رسالة ثابتة، من غير موديل، وبتتلغي لو اتأكل في النص.
    if (task.kind === "pet_call") {
      try {
        if (await deliverPetCall(sb, task, {
          pushDevice: (uid, title, text, data) => pushToDevice(sb, uid, title, text, data),
          pushTelegram: (uid, title, text, taskId, need) =>
            pushToTelegram(uid, title, text, fetch, taskId, false, undefined, undefined, undefined, undefined, undefined, undefined, need),
        }) === "sent") {
          processed++;
          (await deliveredFor(task.user_id)).push({ kind: task.kind, at: new Date().toISOString() });
        }
      } catch (e) {
        console.error("[pet_call] failed for task", task.id, e);
        await sb.from("agent_tasks").update({ status: "failed", result: String(e), updated_at: new Date().toISOString() }).eq("id", task.id);
        failed++;
      }
      continue;
    }
    // صنف ضروري خلص (restockLink.ts): رسالة ثابتة بلينك أمازون، من غير موديل.
    if (task.kind === "restock_link") {
      try {
        if (await deliverRestockLink(sb, task, {
          pushDevice: (uid, title, text, data) => pushToDevice(sb, uid, title, text, data),
          pushTelegram: (uid, title, text, taskId, links) =>
            pushToTelegram(uid, title, text, fetch, taskId, false, undefined, undefined, undefined, undefined, undefined, links),
          env: (n) => Deno.env.get(n),
        }) === "sent") {
          processed++;
          (await deliveredFor(task.user_id)).push({ kind: task.kind, at: new Date().toISOString() });
        }
      } catch (e) {
        console.error("[restock_link] failed for task", task.id, e);
        await sb.from("agent_tasks").update({ status: "failed", result: String(e), updated_at: new Date().toISOString() }).eq("id", task.id);
        failed++;
      }
      continue;
    }
    await sb.from("agent_tasks").update({ status: "running", updated_at: new Date().toISOString() }).eq("id", task.id);
    try {
      const snap = await buildSnapshot(sb, task.user_id);
      const systemPrompt = soulBlock(snap?.customer?.zad_voice) + buildChatSystemPrompt(snap);
      const groqSystem = groqSystemFor(snap);
      const ctx: RunContext = freshContext(task.user_id);
      const scope: AuditScope = { source: "event", runId: null };
      const history: Turn[] = [{ role: "user", text: task.task_description }];
      let resultText = "";

      for (let turn = 0; turn < MAX_AGENT_TURNS; turn++) {
        const reply = await callModel({ model: MODEL_ROUTINE, system: systemPrompt, tools: CHAT_TOOLS, history, maxTokens: 1200, groqSystem });
        if (reply.text) resultText = reply.text;
        if (reply.toolCalls.length === 0) break;
        history.push({ role: "assistant", text: reply.text || undefined, toolCalls: reply.toolCalls });

        const toolResults: Array<{ id: string; name: string; content: string }> = [];
        for (const call of reply.toolCalls) {
          if (CONFIRM_REQUIRED_TOOLS.includes(call.name)) {
            toolResults.push({
              id: call.id, name: call.name,
              content: "مرفوض: الأداة دي بتلمس فلوس حقيقية ومحتاجة تأكيد صريح من العميل — مفيش عميل حاضر دلوقتي (مهمة مجدولة). قول في ردك إن ده محتاج تأكيده هو لما يفتح التطبيق.",
            });
            continue;
          }
          const result = await runTool(sb, task.user_id, call.name, call.input, snap, ctx, scope);
          toolResults.push({ id: call.id, name: call.name, content: result });
          // تقرير العمل للصندوق حتى من المهام المجدولة — العقل لازم يعرف شغل الأيدجنت اللي حصل وهو مش حاضر.
          if (!result.startsWith("مرفوض:")) {
            await sendAgentReport(
              sb, task.user_id, "brain",
              `نفّذ ${call.name} (مهمة مجدولة)`,
              result.slice(0, 300),
            );
          }
        }
        history.push({ role: "tool", results: toolResults });
      }

      const finalText = resultText.trim() || "خلصت المهمة من غير رد نصي.";
      // تمييز النجاح الحقيقي عن "شغلت بس مقدرتش أنجز": لو في رفض أو أداة محتاجة تأكيد
      // ومالهاش عميل حاضر، المهمة بتتقفل done_with_issue — الtrigger بتاع تقدم الهدف
      // بيتفعل بس على status='done'، فالهدف ماياخدش +1 كاذب.
      const hadIssue = ctx.rejections.length > 0
        || history.some((h: any) => Array.isArray(h.results) && h.results.some((tr: any) =>
          String(tr.content ?? "").startsWith("مرفوض:") || String(tr.content ?? "").includes("محتاج تأكيده")));
      const finalStatus = hadIssue && task.goal_id ? "done_with_issue" : "done";
      await sb.from("agent_tasks").update({
        status: finalStatus, result: finalText, updated_at: new Date().toISOString(),
      }).eq("id", task.id);
      // حلقة الأهداف: المهمة المتكررة بتخلي نفسها دورة جديدة بعد ما تخلص —
      // يومية/أسبوعية/شهرية من وقت الجدولة الأصلي، ونفس الربط بالهدف. الtrigger
      // اللي على status='done' هو اللي بيزود تقدم الهدف (agent_goal_touch_progress).
      const rec = task.recurrence ?? "once";
      if (rec !== "once") {
        const next = new Date(task.scheduled_for);
        if (rec === "daily") next.setDate(next.getDate() + 1);
        else if (rec === "weekly") next.setDate(next.getDate() + 7);
        else if (rec === "monthly") next.setMonth(next.getMonth() + 1);
        if (Number.isFinite(next.getTime())) {
          await sb.from("agent_tasks").insert({
            user_id: task.user_id,
            task_description: task.task_description,
            scheduled_for: next.toISOString(),
            goal_id: task.goal_id,
            recurrence: rec,
            // من غير kind، العمود بيرجع للافتراضي 'reminder': متابعة الهدف كانت هتتحول من الأسبوع
            // التاني لـ«مهمة كنت طلبتها» ومابتروحش تليجرام، والكتم مابيشوفهاش.
            kind: task.kind ?? "reminder",
          });
        }
      }
      // العنوان بيفرّق بين طلب العميل (reminder) ومبادرة زاد — كان «مهمة كنت طلبتها» للكل.
      const baseNotice = agentTaskNotice(task.kind);
      // م٤.٤: عنوان المبادرة بلهجة العميل (قالب اللهجة أو صياغتها المخزنة، وإلا الأساس). طلب العميل مالوش لهجة.
      const shown: { choice?: ShownChoice } = {};
      const notice = baseNotice.proactive
        ? { ...baseNotice, title: await proactiveTitleFor(sb, task.user_id, task.kind, shown) }
        : baseNotice;
      // المحادثة الواحدة: المبادرة بعلامتها (زاد عارف إنه هو اللي بدأ)، وطلب العميل كرد عادي.
      await recordConversation(sb, task.user_id, [{
        role: "assistant",
        text: notice.proactive ? proactiveTurn(notice.title, finalText) : `${notice.title}\n${finalText}`,
      }]);
      if (shown.choice) {
        // م٨.٢: القالب اللي اتعرض لازم نعرف الإشعار بتاعه (مكافأة الفتح). ده مابيحصل غير والفلاج مفتوح.
        const ins = await sb.from("app_notifications").insert({
          user_id: task.user_id, title: notice.title, message: finalText,
        }).select("id").single();
        const nid = (ins as any)?.data?.id;
        if (typeof nid === "string") await noteShown(sb, task.user_id, nid, shown.choice);
      } else {
        await sb.from("app_notifications").insert({
          user_id: task.user_id, title: notice.title, message: finalText,
        });
      }
      // FCM — الإشعار يوصل الجهاز فوراً حتى والتطبيق مقفول (fire-and-forget). تجربة الأسبوعين (٥.٤) بتروح
      // data-only بزرارينها، عشان التطبيق هو اللي يعرضها؛ لو مابقتش مستنية رد بتروح عادي.
      const trial = HABIT_TRIAL_KINDS.has(task.kind ?? "") ? await habitTrialForTask(sb, task.user_id, task.id) : null;
      const learning = task.kind === HOUSE_LEARNING_KIND ? await houseLearningForTask(sb, task.user_id, task.id) : null;
      // «اتعلمت إن» في الملخص الأسبوعي (٥.٢) بنفس الطريقة: data-only بزرارين «صح / مش صح».
      const answerPush = trial ? habitTrialPush(trial, finalText) : learning ? houseLearningPush(learning, finalText) : null;
      if (answerPush) await pushToDevice(sb, task.user_id, notice.title, answerPush.body, answerPush.data, true);
      else await pushToDevice(sb, task.user_id, notice.title, finalText.slice(0, 180), agentTaskPushData(task.kind));
      // المبادرات بتروح تليجرام كمان: من غيرها كانت بتقف في قايمة جوه التطبيق (FCM صفر
      // توكن). الطلبات مابتروحش — العميل غالبًا طلبها من نفس القناة اللي هيشوف ردها فيها.
      if (notice.proactive) {
        const tg = await pushToTelegram(task.user_id, notice.title, finalText, fetch, task.id, notice.voice, task.kind ?? undefined);
        console.log(`[agent_tasks] proactive ${task.kind} for task ${task.id} → telegram: ${tg}`);
      }
      (await deliveredFor(task.user_id)).push({ kind: task.kind, at: new Date().toISOString() });
      processed++;
    } catch (e) {
      console.error("processDueAgentTasks failed for task", task.id, e);
      await sb.from("agent_tasks").update({
        status: "failed", result: String(e), updated_at: new Date().toISOString(),
      }).eq("id", task.id);
      failed++;
    }
  }
  return { processed, failed, postponed };
}
