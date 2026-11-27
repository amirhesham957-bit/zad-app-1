// m4.5 pass 3: executeTool case bodies moved verbatim out of index.ts (no behavior change).
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";
import type { RunContext } from "./validators.ts";
import type { ToolDeps } from "./execDeps.ts";
import { restorableRow, restoreError, TRASH_DAYS, trashLabel, trashList, type TrashRow } from "./restoreDeleted.ts";
import { crossRate, describeRate, rankDeals, summarizePriceTrend } from "./prices.ts";
import { homeMap } from "./crowdFloor.ts";
import { dismissalNote, type DismissReason, type ShownInsight, matchInsight } from "./appByVoice.ts";
import { localNowContext, itemKey } from "./shared.ts";
import { storeLocationFrom } from "./storeFit.ts";
import { findChatDeals } from "./chatDeals.ts";
import { signalTerms } from "../_shared/dealRelevance.ts";
import { buildMenu, describeMenu, feedbackMap, parseMenuDishes } from "./menuTool.ts";
import { appointmentsBusy, describeGatherings, findGatherings, mergeBusy, parseGatheringInput } from "./gatheringTool.ts";
import { recordAction, writeRows } from "./audit.ts";
import { commitIntent, DUPLICATE_REPLY, refusalText } from "./commitIntent.ts";
import { handoverCard, HANDOVER_DEFAULT_DAYS } from "./handover.ts";
import { daysLeft } from "./documents.ts";
import { householdUserIds, loadRestockVerdicts } from "./restockJudge.ts";
import { type BudgetListRow, budgetCandidates, describeBudgetPlan, latestPaid, planOnBudget, type PricePaid } from "./restockBudget.ts";
import { describeWhereToBuy, type WhereDeal, type WhereReport, WHERE_WINDOW_DAYS, whereToBuy } from "./whereToBuy.ts";
import { describeSafeSpend } from "./safeSpendTool.ts";
import { describeConflicts, parseConflictInput } from "./constraintConflicts.ts";
import { type SpendRow } from "./paydayOdds.ts";
import { describeReorder, parseReorderInput } from "./pharmacyReorderTool.ts";
import { budgetAtStart, circumstanceBudget, circumstanceBudgetLine, circumstanceCost } from "./circumstanceBudget.ts";
import { loadWeather, weatherForSnapshot } from "./weather.ts";
import { dealCountry } from "./tasteDeals.ts";
import { monthlyAverages, monthRunway, projectDecision } from "./decisionImpact.ts";
import { DECISION_OPEN_MAX } from "./decisionReview.ts";
import { monthlyTotals, resilience } from "./longMemory.ts";
import { DECLARED_DEFAULT_DAYS, DECLARED_MAX_DAYS } from "./circumstances.ts";
import { shiftSince } from "./lifeShift.ts";
import { inventoryOwnerFilter } from "./inventoryRow.ts";
import { householdFamilyId, householdFilter } from "../_shared/household.ts";
import { NATIVE_ALARM_FLAG_OFF_REFUSAL, nativeAlarmEnabled, setNativeAlarm } from "./nativeAlarm.ts";

/** Returns undefined when `name` is not one of this file's tools. */
export async function execHouseholdLookups(name: string, sb: SupabaseClient, userId: string, input: any, snap: any, ctx: RunContext, scope: AuditScope, deps: ToolDeps): Promise<string | undefined> {
  const { bumpAffinity } = deps;
  switch (name) {
    case "dismiss_insight": {
      // ZAD_PLAN ١٠.٢(أ): أزرار القفل على الكارت بالكلام — من المعروض عليه بس، بنفس الملاحظة للعقل.
      const { data: pending } = await sb.from("zad_insights").select("id,title,body,about_item")
        .eq("user_id", userId).eq("status", "pending").order("created_at", { ascending: false }).limit(50);
      const rows = (pending ?? []) as ShownInsight[];
      const { row, ambiguous } = matchInsight(rows, String(input.about ?? ""));
      if (ambiguous) return `مرفوض: أكتر من رؤية بالكلام ده (${ambiguous.join("، ")}) — اسأله أنهي واحدة.`;
      if (!row) return `مرفوض: مفيش رؤية معروضة بالكلام ده. المعروض: ${rows.slice(0, 5).map((r) => r.title).filter(Boolean).join("، ") || "ولا حاجة"}.`;
      const reason = input.reason as DismissReason;
      const w = await writeRows(
        sb.from("zad_insights").update({ status: "dismissed", dismiss_reason: reason, updated_at: new Date().toISOString() })
          .eq("id", row.id).eq("user_id", userId).select("id"),
        "قفل الرؤية",
      );
      if (!w.ok) return `مرفوض: ${w.reason}`;
      const note = dismissalNote(reason, row.about_item ?? row.title ?? "");
      const { error: noteErr } = await sb.rpc("zad_memory_upsert", { p_user: userId, p_scope: note.scope, p_note: note.note, p_conf: note.confidence });
      if (noteErr) console.error("[dismiss_insight] note failed:", noteErr.message);
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: { status: "pending" }, new: { status: "dismissed", reason } });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_insights", targetId: row.id, previous: { status: "pending" }, next: { status: "dismissed", dismiss_reason: reason } });
      return `status=dismissed — «${row.title}» اتقفلت.`;
    }
    case "set_app_setting": {
      // ZAD_PLAN ١٠.٢(أ): مفتاح من الإعدادات بالكلام — نفس العمود اللي SettingsRepository بيكتبه.
      const column = input.setting === "pet_calls" ? "pet_calls_enabled" : "food_pattern_enabled";
      const on = input.on === true;
      const { data: before } = await sb.from("zad_users").select(column).eq("id", userId).maybeSingle();
      // من الباب (م٢.٥).
      const w = await commitIntent(sb, userId, scope, name, input, "settings.app_flag_set", { setting: input.setting, on });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before ?? null, new: { [column]: on } });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_users", targetId: userId, previous: before ?? null, next: { [column]: on } });
      const what = input.setting === "pet_calls" ? "نداءات زادو" : "صورة الأكل في الرئيسية";
      return `status=saved ${column}=${on} — ${what} ${on ? "اشتغلت" : "اتقفلت"}، والمفتاح نفسه في الإعدادات لو حب يرجّعها.`;
    }
    case "delete_memory": {
      // ZAD_PLAN ١٠.٢(أ): «انسى» بالكلام زي شاشة الذاكرة. user_id في الشرط: العقل شغال بـservice_role،
      // والـsnapshot فيه ملاحظات أفراد العيلة — دي ماتتمسحش من حساب حد تاني.
      const memoryId = String(input.memory_id);
      const { data: before } = await sb.from("zad_memory").select("id,scope,note,confidence,evidence_count,valid_until")
        .eq("id", memoryId).eq("user_id", userId).maybeSingle();
      if (!before) return "مرفوض: الملاحظة دي مش من ذاكرة العميل نفسه — ماتمسحتش.";
      const w = await writeRows(
        sb.from("zad_memory").delete().eq("id", memoryId).eq("user_id", userId).select("id"),
        "مسح ملاحظة من الذاكرة",
      );
      if (!w.ok) return `مرفوض: ${w.reason}`;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: null });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_memory", targetId: memoryId, previous: before, next: null });
      return `status=deleted — اتنسيت: «${String((before as { note?: string }).note ?? "").slice(0, 80)}»`;
    }
    case "restore_deleted": {
      // ZAD_OR_PLAN م١.٦: من سلة zad_trash. العقل شغال بـservice_role وzad_trash_restore مابيفحصش الملكية من غير
      // auth.uid()، فصف السلة بيتقرا بـuser_id العميل وrestorableRow بيرفض أي حاجة مش بتاعته قبل النداء.
      const SELECT_TRASH = "id,table_name,row_id,user_id,row_data,deleted_at,restored_at";
      const trashId = Number(input.trash_id);
      if (!Number.isInteger(trashId) || trashId <= 0) {
        const { data: rows, error: listErr } = await sb.from("zad_trash").select(SELECT_TRASH)
          .eq("user_id", userId).is("restored_at", null)
          .gte("deleted_at", new Date(Date.now() - TRASH_DAYS * 86_400_000).toISOString())
          .order("deleted_at", { ascending: false }).limit(10);
        if (listErr) return `مرفوض: مقدرتش أقرا السلة (${listErr.message})`;
        return trashList((rows ?? []) as TrashRow[]);
      }
      const { data: trashRow } = await sb.from("zad_trash").select(SELECT_TRASH)
        .eq("id", trashId).eq("user_id", userId).maybeSingle();
      const refused = restorableRow(trashRow as TrashRow | null, userId, Date.now());
      if (refused) return `مرفوض: ${refused}`;
      const t = trashRow as TrashRow;
      const { data: res, error: restoreErr } = await sb.rpc("zad_trash_restore", { p_id: trashId });
      if (restoreErr) return `مرفوض: ${restoreErr.message}`;
      const r = (res ?? {}) as { ok?: boolean; error?: string };
      if (!r.ok) return `مرفوض: ${restoreError(r.error)}`;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: t.row_data });
      await recordAction(sb, userId, scope, { tool: name, input, table: t.table_name, targetId: t.row_id, previous: null, next: t.row_data });
      return `status=restored — رجع ${trashLabel(t)}`;
    }
    case "share_memory_with_family": {
      // ١٠.٢(ج): الكتابة كلها في zad_memory_share_with_family — صاحب الملاحظة بس، ومش حساب طفل، وفي عيلة فيها حد تاني.
      const memoryId = String(input.memory_id);
      const share = input.share === true;
      const { data: before } = await sb.from("zad_memory").select("id,note,family_id")
        .eq("id", memoryId).eq("user_id", userId).maybeSingle();
      if (!before) return "مرفوض: الملاحظة دي مش من ذاكرة العميل نفسه.";
      const { data: res, error: shareErr } = await sb.rpc("zad_memory_share_with_family", {
        p_user: userId, p_memory: memoryId, p_share: share,
      });
      if (shareErr) return `مرفوض: ${shareErr.message}`;
      const r = (res ?? {}) as { ok?: boolean; reason?: string };
      if (!r.ok) {
        const why: Record<string, string> = {
          no_family: "العميل مش في عيلة على زاد — مفيش حد يتشارك معاه.",
          alone: "العيلة فيها العميل لوحده لسه — لما حد ينضم تقدر تشاركها.",
          child: "حساب الطفل مابيشاركش ملاحظاته.",
          unknown_note: "الملاحظة دي مش موجودة أو اتحلّ محلها.",
        };
        return `ماتشاركتش: ${why[r.reason ?? ""] ?? r.reason ?? "سبب مش معروف"}`;
      }
      // new_state مقروء من الداتابيز بعد الكتابة (20260809180000)، مش نسخة متعدلة.
      const { data: after } = await sb.from("zad_memory").select("id,note,family_id")
        .eq("id", memoryId).eq("user_id", userId).maybeSingle();
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: after });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_memory", targetId: memoryId, previous: before, next: after });
      const note = String((before as { note?: string }).note ?? "").slice(0, 80);
      return share
        ? `status=shared — «${note}» بقت معروفة لعقل زاد عند باقي العيلة. قوله إنه يقدر يرجّعها ليه لوحده في أي وقت.`
        : `status=private — «${note}» رجعت ليه لوحده.`;
    }
    case "handover_card": {
      // كارت تسليم الشفت (handover.ts، الشريحة ٣٤): من حساب العميل نفسه بس، للأيام الجاية بتوقيت السوق. صفر توكنز.
      const timeZone = snap?.cycle?.timezone ?? "UTC";
      const today = localNowContext(timeZone).date;
      const days = Number(input?.days) || HANDOVER_DEFAULT_DAYS;
      const until = new Date(Date.now() + (days + 1) * 86_400_000).toISOString();
      // القايمة بس هي اللي للبيت (قرار المالك ٢٠٢٦-١٠-١١)؛ الباقي من حساب العميل زي ما هو.
      const householdFamily = await householdFamilyId(sb, userId);
      const [meds, appts, timetable, state, obligations, shopping, user] = await Promise.all([
        sb.from("zad_pharmacy_items").select("name,dosage,dose_times,remaining_quantity,daily_dose_count,units_per_dose,for_person,is_recurring").eq("user_id", userId),
        sb.from("zad_appointments").select("title,starts_at,kind,for_person").eq("user_id", userId)
          .gte("starts_at", new Date(Date.now() - 86_400_000).toISOString()).lte("starts_at", until).order("starts_at", { ascending: true }).limit(50),
        sb.from("zad_school_timetable").select("person,weekday,period,subject,starts").eq("user_id", userId),
        sb.rpc("zad_budget_state", { p_user: userId, p_tz: timeZone }),
        sb.from("zad_obligations").select("title,amount,due_day").eq("user_id", userId).eq("active", true),
        sb.from("zad_shopping_list").select("item_name").or(householdFilter(userId, householdFamily)).eq("is_purchased", false).limit(20),
        sb.from("zad_users").select("country,currency").eq("id", userId).maybeSingle(),
      ]);
      if (meds.error || appts.error) return `مقدرتش أجمع الكارت دلوقتي: ${(meds.error ?? appts.error)?.message}`;
      const u = user.data as { country?: string | null; currency?: string | null } | null;
      const b = (state.data ?? null) as { daily_allowance_left?: number | null; available?: number | null } | null;
      return JSON.stringify(handoverCard({
        today, timeZone, days, country: u?.country ?? null, currency: u?.currency ?? null,
        medicines: (meds.data ?? []) as Parameters<typeof handoverCard>[0]["medicines"],
        appointments: (appts.data ?? []) as Parameters<typeof handoverCard>[0]["appointments"],
        timetable: (timetable.data ?? []) as Parameters<typeof handoverCard>[0]["timetable"],
        budget: b ? { daily_allowance_left: b.daily_allowance_left ?? null, available: b.available ?? null } : null,
        obligations: (obligations.data ?? []) as Parameters<typeof handoverCard>[0]["obligations"],
        shopping: ((shopping.data ?? []) as Array<{ item_name: string }>).map((s) => s.item_name),
      }));
    }
    case "decision_impact": {
      // قرار كبير على الشهور الجاية (decisionImpact.ts): من متوسط الدخل والصرف الفعلي آخر ٩٠ يوم،
      // ونفس الرصيد اللي forward_ledger بيبدأ منه. حساب حتمي، صفر كوتة.
      const [{ data: txns, error: txErr }, { data: state, error: stateErr }] = await Promise.all([
        sb.from("zad_transactions").select("amount,is_expense,txn_kind,created_at").eq("user_id", userId)
          .gte("created_at", new Date(Date.now() - 95 * 86_400_000).toISOString()).limit(2000),
        sb.rpc("zad_budget_state", { p_user: userId, p_tz: snap?.cycle?.timezone ?? "UTC" }),
      ]);
      if (txErr || stateErr) return `مقدرتش أحسب الأثر دلوقتي: ${(txErr ?? stateErr)?.message}`;
      // تحول قايم (الشريحة ٣٠) ⇒ المتوسط من يومه.
      const avg = monthlyAverages((txns ?? []) as Array<{ amount: number | null; is_expense: boolean | null; txn_kind: string | null; created_at: string }>, Date.now(), shiftSince(snap?.life_shift));
      if (avg.historyDays === 0) return "مفيش حركات كفاية أحسب منها أثر قرار — محتاج دخل ومصاريف متسجلة الأول.";
      const now = new Date();
      const startMatch = /^(\d{4})-(\d{2})$/.exec(String(input?.start_month ?? ""));
      const startOffset = startMatch
        ? (Number(startMatch[1]) - now.getUTCFullYear()) * 12 + (Number(startMatch[2]) - 1 - now.getUTCMonth())
        : 0;
      const impact = projectDecision({
        opening: Number((state as { balance?: number } | null)?.balance ?? 0),
        avgMonthlyIncome: avg.income, avgMonthlySpend: avg.spend, historyDays: avg.historyDays,
        decision: {
          one_time_cost: input?.one_time_cost, monthly_cost: input?.monthly_cost,
          monthly_income_change: input?.monthly_income_change, start_offset: Math.max(0, startOffset),
        },
        months: input?.months, now,
      });
      if (!impact) return "قولّي تكلفة القرار: مبلغ مرة واحدة، أو كل شهر، أو تغيير في الدخل.";
      // «ضروري ولا تهور» (١٠.١ الشريحة ٤هـ): شرا مرة واحدة بياكل كام يوم من باقي الدورة.
      const thisMonth = monthRunway({
        cost: Number(input?.one_time_cost) || 0,
        available: snap?.available, daysLeft: snap?.cycle?.days_left,
        rhythm: snap?.behavior_profile?.shopping?.rhythm ?? null, daysElapsed: snap?.cycle?.days_elapsed,
      });
      return JSON.stringify({
        decision: typeof input?.label === "string" ? input.label.slice(0, 80) : null,
        averages: { monthly_income: avg.income, monthly_spend: avg.spend, history_days: avg.historyDays },
        opening_balance: Number((state as { balance?: number } | null)?.balance ?? 0),
        ...(thisMonth ? { this_month: thisMonth } : {}),
        ...impact,
      });
    }
    case "confirm_life_shift": {
      // الشريحة ٣٠ — جواب العميل على «حصل تغيير في البيت؟». أكّد ⇒ الطبيعي الجديد بيفضل؛ نفى ⇒ التحول بيقفل، والحسابات
      // ترجع تقيس على كل التاريخ.
      if (typeof input?.confirmed !== "boolean") return "مرفوض: confirmed لازم true أو false.";
      const nowIso = new Date().toISOString();
      const { data: row } = await sb.from("zad_life_circumstances").select("id,kind,started_at")
        .eq("user_id", userId).like("kind", "shift_%").is("confirmed", null).is("ended_at", null).gt("ends_at", nowIso)
        .order("created_at", { ascending: false }).limit(1).maybeSingle();
      if (!row) return "مفيش تحول مستني جواب.";
      const r = row as { id: string; kind: string; started_at: string };
      const patch = input.confirmed
        ? { confirmed: true }
        : { confirmed: false, ended_at: nowIso, ends_at: nowIso > r.started_at ? nowIso : r.started_at };
      const { error } = await sb.from("zad_life_circumstances").update(patch).eq("id", r.id).eq("user_id", userId);
      if (error) return `مقدرتش أسجّل الجواب: ${error.message}`;
      ctx.mutationCount++;
      return input.confirmed
        ? "اتسجّل إنه الطبيعي الجديد. اعرض عليه سقف شهر جديد من propose_next_month_budget — هو اللي يوافق."
        : "اتسجّل إنه مش تحول — الحسابات بترجع تقيس على كل التاريخ.";
    }
    case "set_life_circumstance": {
      // الشريحة ٢٩ — العميل قال إن البيت في ظرف (حد عيان، طوارئ) أو امتحانات. مابنخزّنش «إيه الظرف» — النوع والمدة بس.
      const kind = input?.kind === "exams" ? "exams" : input?.kind === "exceptional" ? "exceptional" : null;
      if (!kind) return "مرفوض: kind لازم exceptional أو exams.";
      const days = Math.min(DECLARED_MAX_DAYS, Math.max(1, Math.round(Number(input?.days) || DECLARED_DEFAULT_DAYS)));
      const now = new Date();
      const endsAt = new Date(now.getTime() + days * 86_400_000).toISOString();
      // ZAD_PLAN ٥.٦ — الظرف الطارئ بيحفظ المتاح ساعته (والتكلفة لو قالها)، عشان الباقي يتوزع على الأيام (circumstanceBudget.ts).
      const cost = kind === "exceptional" ? circumstanceCost(input?.cost) : null;
      const replan = (detail: Record<string, unknown>) =>
        kind === "exceptional"
          ? circumstanceBudgetLine(circumstanceBudget({
            detail, available: snap?.available, daysLeft: snap?.cycle?.days_left, cycleEnd: snap?.cycle?.cycle_end ?? null,
          }), snap?.currency)
          : "";
      const { data: active } = await sb.from("zad_life_circumstances").select("id,kind,ends_at,detail")
        .eq("user_id", userId).in("kind", ["exceptional", "exams"]).is("ended_at", null).gt("ends_at", now.toISOString())
        .order("ends_at", { ascending: false }).limit(1).maybeSingle();
      if (active) {
        // نفس الهدوء شغال: نمدّه بس (مانقصّرهوش من غير ما العميل يقول «رجّع»). المتاح ساعة الظرف مايتبدلش، والتكلفة الجديدة تكسب.
        const row = active as { id: string; kind: string; ends_at: string; detail: Record<string, unknown> | null };
        const longer = endsAt > row.ends_at ? endsAt : row.ends_at;
        const detail = { ...(row.detail ?? {}) };
        if (row.kind === "exceptional" && kind === "exceptional") {
          if (!detail.budget_at_start) {
            const start = budgetAtStart(snap);
            if (start) detail.budget_at_start = start;
          }
          if (cost !== null) detail.cost = cost;
        }
        const { error } = await sb.from("zad_life_circumstances").update({ ends_at: longer, detail })
          .eq("id", row.id).eq("user_id", userId);
        if (error) return `مقدرتش أحدّث: ${error.message}`;
        ctx.mutationCount++;
        const line = row.kind === "exceptional" ? replan(detail) : "";
        return `الهدوء شغال لحد ${longer.slice(0, 10)}.${line ? ` ${line}` : ""}`;
      }
      const start = kind === "exceptional" ? budgetAtStart(snap) : null;
      const detail: Record<string, unknown> = {
        ...(start ? { budget_at_start: start } : {}),
        ...(cost !== null ? { cost } : {}),
      };
      const { error } = await sb.from("zad_life_circumstances").insert({
        user_id: userId, kind, source: "customer", started_at: now.toISOString(), ends_at: endsAt,
        ...(Object.keys(detail).length ? { detail } : {}),
      });
      if (error) return `مقدرتش أسجّل: ${error.message}`;
      ctx.mutationCount++;
      const line = replan(detail);
      return `اتسجّل. لحد ${endsAt.slice(0, 10)}: الجرعات والمواعيد والأمان زي ما هم، والباقي يستنى. ` +
        "قوله إنه يقدر يرجّع التنبيهات من الرئيسية أو يقولك «رجّع»." + (line ? ` ${line}` : "");
    }
    case "end_life_circumstance": {
      // نفس zad_circumstance_end اللي زرار الرئيسية بيناديها — بس بهوية السيرفر وللظروف المفتوحة كلها.
      const nowIso = new Date().toISOString();
      const { data: active } = await sb.from("zad_life_circumstances").select("id,started_at,detail")
        .eq("user_id", userId).in("kind", ["exceptional", "exams"]).is("ended_at", null).gt("ends_at", nowIso);
      const rows = (active ?? []) as Array<{ id: string; started_at: string; detail: Record<string, unknown> | null }>;
      if (!rows.length) return "مفيش هدوء شغال — التنبيهات عادية.";
      for (const row of rows) {
        const { error } = await sb.from("zad_life_circumstances").update({
          ended_at: nowIso,
          ends_at: nowIso > row.started_at ? nowIso : row.started_at,
          detail: { ...(row.detail ?? {}), ended_by_customer: true },
        }).eq("id", row.id).eq("user_id", userId);
        if (error) return `مقدرتش أرجّع التنبيهات: ${error.message}`;
      }
      ctx.mutationCount++;
      return "التنبيهات رجعت عادية.";
    }
    case "household_resilience": {
      // الشريحة ٢٧ — الشهور الصعبة اللي فاتت والبيت رجع منها في كام شهر، من حركاته (حتمي، صفر كوتة). بالطلب بس:
      // ٤٠٠ يوم حركات مش حاجة تتقري في كل لقطة.
      const { data: txns, error } = await sb.from("zad_transactions")
        .select("amount,is_expense,txn_kind,created_at").eq("user_id", userId)
        .gte("created_at", new Date(Date.now() - 400 * 86_400_000).toISOString()).limit(10000);
      if (error) return `مقدرتش أقرا التاريخ دلوقتي: ${error.message}`;
      const currentMonth = localNowContext(snap?.cycle?.timezone ?? "UTC").date.slice(0, 7);
      const r = resilience(monthlyTotals((txns ?? []) as Array<{ amount: number | null; is_expense: boolean | null; txn_kind: string | null; created_at: string }>), currentMonth);
      if (!r) {
        return "التاريخ أقل من ٦ شهور كاملة — مفيش صمود أتكلم عنه. ماتقولش أرقام عن «قبل كده»؛ ساعده في الشهر ده بس.";
      }
      return JSON.stringify({
        ...r,
        guidance: r.typical_recovery_months !== null
          ? "قولها كحقيقة من تاريخه («قبل كده عدّيتوا شهر زي ده ورجعتوا في شهرين») — طمأنة مش وعظ ولا وعد. ماتقترحش إلغاء التزام ثابت."
          : r.hard_months.length
          ? "فيه شهور صعبة قبل كده بس البيت لسه مارجعش منها بالكامل — ماتقولش «هترجعوا»؛ ساعده بخطوة واحدة."
          : "مفيش شهر صعب في تاريخه قبل كده — الشهر ده استثناء، وقوله كده لو بيطمّنه.",
      });
    }
    case "log_decision": {
      // الشريحة ٢٦ — قرار اتاخد فعلاً بأرقامه ومتوسطات البيت دلوقتي، عشان المحاسب يراجعه بعد ٣٠ و٩٠ يوم
      // (decisionReview.ts). سؤال افتراضي («لو اشتريت…») مش قرار — الوصف والبرومبت بيقولوا كده.
      const label = typeof input?.label === "string" ? input.label.replace(/\s+/g, " ").trim().slice(0, 80) : "";
      if (!label) return "مرفوض: القرار محتاج اسم بكلام العميل.";
      const oneTime = Math.max(0, Number(input?.one_time_cost) || 0);
      const monthly = Math.max(0, Number(input?.monthly_cost) || 0);
      const incomeChange = Number(input?.monthly_income_change) || 0;
      if (oneTime === 0 && monthly === 0 && incomeChange === 0) {
        return "مرفوض: محتاج تكلفة القرار (مرة واحدة أو كل شهر) أو تغيير في الدخل — من غيرها مفيش حاجة تتراجع.";
      }
      const { data: txns, error: txErr } = await sb.from("zad_transactions")
        .select("amount,is_expense,txn_kind,created_at").eq("user_id", userId)
        .gte("created_at", new Date(Date.now() - 95 * 86_400_000).toISOString()).limit(2000);
      if (txErr) return `مقدرتش أسجّل القرار دلوقتي: ${txErr.message}`;
      // تحول قايم (الشريحة ٣٠) ⇒ المتوسط من يومه.
      const avg = monthlyAverages((txns ?? []) as Array<{ amount: number | null; is_expense: boolean | null; txn_kind: string | null; created_at: string }>, Date.now(), shiftSince(snap?.life_shift));
      if (avg.historyDays === 0) return "مرفوض: مفيش حركات أقيس عليها — المراجعة بعدين هتبقى من غير أساس.";
      const { data: open, error: openErr } = await sb.from("zad_decision_log")
        .select("id,label,decided_at").eq("user_id", userId).lt("reviews", 2)
        .order("decided_at", { ascending: false }).limit(50);
      if (openErr) return `مقدرتش أسجّل القرار دلوقتي: ${openErr.message}`;
      const fields = {
        one_time_cost: oneTime, monthly_cost: monthly, monthly_income_change: incomeChange,
        baseline_income: avg.income, baseline_spend: avg.spend, baseline_days: avg.historyDays,
      };
      // نفس القرار آخر ٣٠ يوم = تصحيح أرقامه، مش قرار تاني.
      const same = ((open ?? []) as Array<{ id: string; label: string; decided_at: string }>).find((d) =>
        itemKey(d.label) === itemKey(label) && Date.now() - Date.parse(d.decided_at) <= 30 * 86_400_000
      );
      if (same) {
        const { error } = await sb.from("zad_decision_log").update(fields).eq("id", same.id).eq("user_id", userId);
        if (error) return `مقدرتش أحدّث القرار: ${error.message}`;
        ctx.mutationCount++;
        return `اتحدّثت أرقام «${label}». هراجعه معاه بعد شهر من يوم القرار وبعد ٣ شهور.`;
      }
      if ((open ?? []).length >= DECISION_OPEN_MAX) return "مرفوض: فيه قرارات كتير مستنية مراجعة — كفاية دول دلوقتي.";
      const { error } = await sb.from("zad_decision_log").insert({ user_id: userId, label, ...fields });
      if (error) return `مقدرتش أسجّل القرار: ${error.message}`;
      ctx.mutationCount++;
      return `اتسجّل «${label}». هراجع معاه بعد شهر وبعد ٣ شهور: الفايض الفعلي قصاد المحسوب.`;
    }
    case "weather_forecast": {
      // الجو لمدينة سمّاها العميل (جوه بلده)، وإلا مكانه في السناب شوت. Open-Meteo من غير مفتاح، وكاش ٣ ساعات.
      const { data: u } = await sb.from("zad_users").select("country").eq("id", userId).maybeSingle();
      const city = String(input?.city ?? "").trim().slice(0, 60);
      const w = await loadWeather(sb, {
        country: (u as { country?: string | null } | null)?.country ?? snap?.country,
        city: city || snap?.customer?.city || null,
        timeZone: snap?.now_local?.time_zone ?? "UTC",
      });
      if (!w) return "مش قادر أجيب الجو دلوقتي — قوله كده بصراحة، وماتخمّنش درجات حرارة.";
      if (city && w.from === "capital") {
        return JSON.stringify({ note: `مالقيتش «${city}» — ده جو ${w.place} (العاصمة)، قوله كده.`, ...weatherForSnapshot(w) });
      }
      return JSON.stringify(weatherForSnapshot(w));
    }
    case "store_location": {
      // «هات اللوكيشن» (الموجة ٣): رابط المحل اللي زاد نبّه عنه، من مهمة store_arrival نفسها. نقطة المحل (مكان
      // عام)، مش مكان العميل. آخر ٧ أيام.
      const { data, error } = await sb.from("agent_tasks").select("task_description,map_url,created_at")
        .eq("user_id", userId).eq("kind", "store_arrival").not("map_url", "is", null)
        .gte("created_at", new Date(Date.now() - 7 * 86_400_000).toISOString())
        .order("created_at", { ascending: false }).limit(20);
      if (error) return `فشل القراية: ${error.message}`;
      const found = storeLocationFrom((data ?? []) as Array<{ task_description: string | null; map_url: string | null; created_at: string }>, input?.store);
      if (!found) {
        return input?.store
          ? `مفيش لوكيشن متسجل لـ«${String(input.store).slice(0, 40)}» آخر ٧ أيام — قوله كده بصراحة، وماتألّفش عنوان.`
          : "مفيش لوكيشن محل متسجل آخر ٧ أيام — قوله كده بصراحة، وماتألّفش عنوان.";
      }
      return JSON.stringify({ store: found.store, map_url: found.map_url, noticed_at: found.at });
    }
    case "home_health_score": {
      // درجة صحة البيت 0-100 — deterministic من 4 محاور: مالية/مخزون/صيدلية/التزامات.
      // الهدف: العميل يشوف "بيته صح قد إيه" كرقم واحد، والعقل يشرح أكبر نقطة ضعف.
      // مصدر الحقول: snap.obligations جاي من zad_budget_state.committed_items (RPC)
      // — شكله { title, amount, kind, next_due }. لو الـ RPC غيّر shape، الـ guard
      // تحت يخلي الدرجة ترجع unknown بدل 100 كاذبة بصمت.
      const obligations = Array.isArray(snap?.obligations) ? snap.obligations as any[] : null;
      if (obligations === null) {
        return JSON.stringify({
          score: null, grade: "مجهول", issues: [],
          message: "مش قادر أحسب درجة البيت دلوقتي — بيانات الميزانية ناقصة. جرب تاني بعدين.",
        });
      }
      let score = 100;
      const issues: string[] = [];
      // المالية: متاح سالب أو قريب من الصفر = أخطر
      const available = Number(snap?.available ?? snap?.remaining ?? 0);
      if (available <= 0) { score -= 40; issues.push("المتاح خلص أو بالسالب"); }
      else if (available < (snap?.budget ?? 0) * 0.1) { score -= 20; issues.push("المتاح أقل من ١٠٪ من الميزانية"); }
      // المخزون
      const lowStock = (snap?.upcoming ?? []).filter((u: any) => u.type === "low_stock").length
        ?? ((snap?.stock ?? []) as any[]).filter((s) => s.daysLeft <= 2).length;
      if (lowStock >= 5) { score -= 15; issues.push(`${lowStock} أصناف هتخلص`); }
      else if (lowStock >= 1) { score -= 7; issues.push(`${lowStock} أصناف قربت تخلص`); }
      // الصيدلية
      const medsLow = (snap?.upcoming ?? []).filter((u: any) => u.type === "medication_low").length;
      if (medsLow >= 1) { score -= 15; issues.push(`${medsLow} أدوية قربت تخلص`); }
      // التزامات متأخرة
      const nowMs = Date.now();
      const overdue = obligations.filter((o) => o.next_due && new Date(o.next_due).getTime() < nowMs).length;
      if (overdue >= 1) { score -= 10 * Math.min(overdue, 3); issues.push(`${overdue} التزامات متأخرة`); }
      const grade = score >= 85 ? "ممتاز" : score >= 65 ? "كويس" : score >= 45 ? "محتاج انتباه" : "خطر";
      return JSON.stringify({
        score, grade,
        issues,
        message: `درجة صحة بيتك ${score} من ١٠٠ (${grade})${issues.length ? " — أهم حاجة: " + issues[0] : "، كل حاجة تمام"}`,
      });
    }
    case "propose_next_month_budget": {
      // اقتراح ميزانية الشهر الجاي مبنية على متوسط ٣ شهور فعلية + تعديل بالتزامات معروفة.
      // مقترح بس زي suggest_budget_change — العميل هو اللي يأكد.
      const { data: monthly, error } = await sb.rpc("zad_monthly_spend", { p_user: userId });
      if (error || !Array.isArray(monthly) || monthly.length < 2) {
        return "مفيش تاريخ صرف كفاية (محتاج شهرين على الأقل) — جرب بعد شوية.";
      }
      const spends = (monthly as Array<{ month: string; total: number }>).slice(0, 3).map((m) => m.total);
      // تحول قايم في المصاريف (الشريحة ٣٠): الطبيعي الجديد (الأسبوع × ٣٠/٧) بدل متوسط ٣ شهور نصهم قبل التحول.
      const spendShift = ((snap?.life_shift ?? []) as Array<{ kind: string; detail?: { after_weekly?: number } }>)
        .find((r) => r.kind === "shift_spending" && Number(r.detail?.after_weekly) > 0);
      const avg = spendShift
        ? Number(spendShift.detail!.after_weekly) * 30 / 7
        : spends.reduce((a, b) => a + b, 0) / spends.length;
      const committed = ((snap?.obligations ?? []) as Array<{ amount?: number }>)
        .reduce((a, o) => a + (Number(o.amount) || 0), 0);
      const suggested = Math.ceil((avg * 1.05 + committed) / 50) * 50; // هامش ٥٪ + تقريب لـ٥٠
      return JSON.stringify({
        suggested_budget: suggested,
        basis: spendShift
          ? `الطبيعي الجديد من يوم التحول (${Math.round(avg)} في الشهر) + التزامات ثابتة: ${committed}`
          : `متوسط آخر ${spends.length} شهور: ${Math.round(avg)} + التزامات ثابتة: ${committed}`,
        guidance: "اعرضه للعميل كرقم مقترح وسببه، واسأله موافق. متسجلش حاجة غير بعد موافقته.",
      });
    }
    case "query_family": {
      const { data: membership } = await sb.from("family_members")
        .select("family_id").eq("user_id", userId).maybeSingle();
      const familyId = (membership as { family_id: string } | null)?.family_id;
      if (!familyId) return "العميل مش منضم لعيلة في التطبيق — مفيش أفراد أو أولاد مسجلين.";
      const { data: members, error } = await sb.from("family_members")
        .select("role,alias,balance,savings_goal").eq("family_id", familyId).limit(20);
      if (error) return `مقدرتش أقرا بيانات العيلة: ${error.message}`;
      const rows = (members ?? []) as Array<{ role: string | null; alias: string | null; balance: number | null; savings_goal: number | null }>;
      const kids = rows.filter((m) => m.role === "child");
      const detail = rows.map((m) => {
        const label = (m.alias ?? "").trim() || (m.role === "child" ? "طفل" : "فرد");
        const roleText = m.role === "child" ? "طفل" : m.role === "admin" ? "ولي أمر" : "فرد";
        return `${label} (${roleText}${m.balance != null ? `، رصيده ${m.balance}` : ""})`;
      }).join("، ");
      return `العيلة فيها ${rows.length} فرد منهم ${kids.length} أطفال: ${detail}`;
    }

    // ─── Market Intelligence Tools ───────────────────────────────────────
    case "fetch_current_exchange_rate": {
      const { from_currency, to_currency } = input;
      if (!from_currency || !to_currency) return "المفروض تحط from_currency و to_currency";
      const from = String(from_currency).toUpperCase().slice(0, 3);
      const to = String(to_currency).toUpperCase().slice(0, 3);
      const { data: fx, error } = await sb.from("zad_fx_rates").select("code, usd_rate, updated_at").in("code", [from, to]);
      if (error) return "مقدرتش أقرا أسعار الصرف دلوقتي — قول للعميل كده، ماتخمّنش رقم.";
      return describeRate(from, to, crossRate(fx, from, to));
    }

    case "check_price_trend": {
      const { item_name } = input;
      if (!item_name) return "المفروض تحط item_name";
      const days = Math.min(90, Math.max(1, Number(input.days) || 30));
      const since = new Date(Date.now() - days * 86400000).toISOString();
      // بعملة العميل بس — price_index فيه بلاغات من كل الأسواق.
      const { data: prices, error } = await sb
        .from("price_index")
        .select("price, timestamp, user_id")
        .ilike("item_name", `%${String(item_name).trim()}%`)
        .eq("currency", snap?.currency ?? "")
        .gte("timestamp", since)
        .order("timestamp", { ascending: false })
        .limit(200);
      if (error) return "مقدرتش أقرا الأسعار دلوقتي — قول للعميل كده.";
      const trendHomes = await homeMap(sb, ((prices ?? []) as Array<{ user_id: string | null }>).map((r) => r.user_id ?? ""));
      return summarizePriceTrend(prices, String(item_name).trim(), days, snap?.currency ?? "", trendHomes);
    }
    case "area_trends": {
      // ترندات السوق بشرط ٥ بيوت (20260930010000) — الحد جوه SQL، مش هنا ولا في الموديل.
      const days = Math.min(60, Math.max(7, Number(input?.days) || 14));
      const { data, error } = await sb.rpc("zad_area_trends", { p_user: userId, p_days: days });
      if (error) return `مقدرتش أقرا ترندات المنطقة: ${error.message}`;
      return JSON.stringify(data);
    }

    case "set_item_preference": {
      // ZAD_PLAN ١٠.١ الشريحة ٤د: صف في zad_item_preferences (البيت كله بيشوفه)، مش ملاحظة حرة.
      const item = String(input?.item_name ?? "").trim().slice(0, 80);
      const kind = String(input?.kind ?? "");
      const brand = String(input?.brand ?? "").trim().slice(0, 60);
      const { data, error } = await sb.rpc("zad_set_item_preference", {
        p_item: item, p_kind: kind, p_brand: brand || null, p_user: userId,
      });
      if (error) return `فشل الحفظ: ${error.message}`;
      const r = data as { ok?: boolean; reason?: string; marked_occasional?: number };
      if (!r?.ok) {
        return r?.reason === "brand_needed" ? "مرفوض: preferred_brand وrejected_brand محتاجين brand." : `مرفوض: ${r?.reason ?? "refused"}`;
      }
      if (kind === "accidental") {
        return `اتسجّل إن ${item} اتجاب صدفة — مش هيدخل النواقص ولا قايمة الشرا${(r.marked_occasional ?? 0) > 0 ? "، وصفّه في المخزن بقى «على فترات»" : ""}.`;
      }
      return kind === "preferred_brand" ? `اتسجّل: ${item} ⇐ ${brand} (عروض الصبح بتمشي عليه).` : `اتسجّل: ${item} مش ${brand}.`;
    }

    case "find_deals": {
      const store = String(input?.store ?? "").trim().slice(0, 60);
      const item = String(input?.item_name ?? "").trim().slice(0, 60);
      // العميل طلبها بنفسه: بتعلّي العروض دي بعد كده.
      for (const t of signalTerms(item, store)) await bumpAffinity(sb, userId, "like", t, 0.6);
      return await findChatDeals(sb, userId, store, item);
    }

    case "restock_on_budget": {
      const budget = Number(input?.budget);
      if (!Number.isFinite(budget) || budget <= 0 || budget > 1_000_000) return "مرفوض: budget لازم رقم موجب بعملة العميل.";
      const currency = snap?.currency ?? "";
      const familyId = await householdFamilyId(sb, userId);
      const users = await householdUserIds(sb, userId, familyId);
      const [verdictOf, invRes, listRes, paidRes] = await Promise.all([
        loadRestockVerdicts(sb, userId, familyId),
        sb.from("zad_inventory").select("item_name,category,quantity,low_stock_threshold,restock_mode,restock_cycle_days,created_at")
          .or(inventoryOwnerFilter(userId, familyId)).limit(300),
        sb.from("zad_shopping_list").select("item_name,estimated_price")
          .or(householdFilter(userId, familyId)).eq("is_purchased", false).limit(100),
        sb.from("price_index").select("item_name,price,timestamp").in("user_id", users).eq("currency", currency)
          .order("timestamp", { ascending: false }).limit(500),
      ]);
      if (invRes.error || listRes.error) return "مقدرتش أقرا المخزن أو القايمة دلوقتي — قول للعميل كده.";
      const inventory = ((invRes.data ?? []) as Array<Parameters<typeof verdictOf>[0] & { item_name: string | null }>)
        .map((row) => ({ item_name: row.item_name, verdict: verdictOf(row) }));
      // فشل قراية الأسعار = كل حاجة «محتاج سعره»، مش رقم مخترع.
      const paid = latestPaid(paidRes.error ? [] : (paidRes.data ?? []) as PricePaid[]);
      const plan = planOnBudget(budgetCandidates(inventory, (listRes.data ?? []) as BudgetListRow[], paid), budget);
      return describeBudgetPlan(plan, currency);
    }

    case "plan_menu": {
      // م٥.٢: منيو الأسبوع على ميزانية (menuTool.ts فوق _shared/or/menuPlan.ts). الأطباق والأسعار من العميل.
      const budget = Number(input?.budget);
      const days = Number(input?.days);
      if (!Number.isFinite(budget) || budget <= 0 || budget > 1_000_000) return "مرفوض: budget لازم رقم موجب بعملة العميل.";
      if (!Number.isInteger(days) || days < 1 || days > 14) return "مرفوض: days لازم عدد صحيح من ١ لـ١٤.";
      const parsed = parseMenuDishes(input?.dishes);
      if ("error" in parsed) return parsed.error;
      const { data: fbRows } = await sb.from("zad_recipe_feedback").select("recipe_name,liked").eq("user_id", userId).limit(300);
      const maxRepeat = Math.min(7, Math.max(1, Math.floor(Number(input?.max_repeat) || 1)));
      const menu = await buildMenu(parsed.dishes, feedbackMap(fbRows ?? []), { days, budget, maxRepeat });
      const costs = new Map([...menu.names].map(([id, n]) => [id, parsed.dishes.find((d) => d.name === n)?.cost ?? 0]));
      return describeMenu(menu, costs, snap?.currency ?? "");
    }

    case "check_medicine_reorder": {
      // م٣.٤: رصيد الدوا ونقطة إعادة الطلب بأيام التوريد وميعاد الجرعة الجاية (pharmacyReorderTool.ts). قراءة بس.
      const parsed = parseReorderInput(input);
      if ("error" in parsed) return parsed.error;
      const { data: meds } = await sb.from("zad_pharmacy_items")
        .select("name,for_person,remaining_quantity,daily_dose_count,units_per_dose,dose_times").eq("user_id", userId).limit(100);
      return describeReorder(meds ?? [], parsed.value, new Date().toISOString(), snap?.now_local?.time_zone ?? "UTC");
    }

    case "set_native_alarm": {
      // v2-2: منبّه النظام عبر FCM data-only (nativeAlarm.ts). الفلاج مقفول ⇒ رفض. مابيكتبش في أي جدول.
      if (!nativeAlarmEnabled()) return NATIVE_ALARM_FLAG_OFF_REFUSAL;
      return await setNativeAlarm(sb, userId, input);
    }

    case "plan_gathering_time": {
      // م٥.٢: أحسن وقت تقعد فيه العيلة سوا (gatheringTool.ts). المشغول من كلام العميل بس.
      const parsed = parseGatheringInput(input);
      if ("error" in parsed) return parsed.error;
      const today = snap?.now_local?.date ?? new Date().toISOString().slice(0, 10);
      // م٥.٢: مواعيد العميل الفعلية بتتقرا service-side بـuser_id بتاعه بس، وفشل القراية = كلام العميل بس (احتياطي).
      let apptBusy: ReturnType<typeof appointmentsBusy> = [];
      try {
        const tz = snap?.now_local?.time_zone ?? snap?.cycle?.timezone ?? "UTC";
        const from = new Date(`${today}T00:00:00Z`).getTime() - 86_400_000;
        const { data: appts, error: apptErr } = await sb.from("zad_appointments").select("title,starts_at,for_person")
          .eq("user_id", userId).eq("status", "upcoming")
          .gte("starts_at", new Date(from).toISOString()).lt("starts_at", new Date(from + 9 * 86_400_000).toISOString()).limit(200);
        if (!apptErr) apptBusy = appointmentsBusy(appts ?? [], parsed.value.members, today, tz);
      } catch { /* احتياطي */ }
      const v = { ...parsed.value, busy: mergeBusy(apptBusy, parsed.value.busy) };
      return describeGatherings(findGatherings(v), v, today, apptBusy.length);
    }

    case "safe_daily_spend": {
      // م٣.٥: مصروف النهارده الآمن + احتمال الوصول للقبض (safeSpendTool.ts). المتاح والأيام من zad_budget_state.
      const timeZone = snap?.cycle?.timezone ?? "UTC";
      const [state, txns] = await Promise.all([
        sb.rpc("zad_budget_state", { p_user: userId, p_tz: timeZone }),
        sb.from("zad_transactions").select("amount,is_expense,txn_kind,created_at,linked_obligation_id").eq("user_id", userId)
          .gte("created_at", new Date(Date.now() - 30 * 86_400_000).toISOString()).limit(2000),
      ]);
      if (state.error || txns.error) return "مقدرتش أقرا ميزانيتك أو حركاتك دلوقتي — قول للعميل كده.";
      return describeSafeSpend(state.data as Parameters<typeof describeSafeSpend>[0], (txns.data ?? []) as SpendRow[], localNowContext(timeZone).date, timeZone);
    }

    case "check_constraint_conflicts": {
      // م٥: كاشف تعارض القيود — قراءة بس (constraintConflicts.ts). كل تعارض معاه مصدره.
      const timeZone = snap?.cycle?.timezone ?? "UTC";
      const today = localNowContext(timeZone).date;
      const parsed = parseConflictInput(input, today);
      if ("error" in parsed) return parsed.error;
      const [state, obl, debts, subs, meds, appts] = await Promise.all([
        sb.rpc("zad_budget_state", { p_user: userId, p_tz: timeZone }),
        sb.from("zad_obligations").select("id,title,amount,due_day,due_date").eq("user_id", userId).eq("active", true).limit(200),
        sb.from("zad_debts").select("id,name,minimum_payment,due_day").eq("user_id", userId).eq("is_active", true).limit(200),
        sb.from("zad_subscriptions").select("id,title,amount,renewal_date,due_day").eq("user_id", userId).eq("is_active", true).limit(200),
        sb.from("zad_pharmacy_items").select("id,name,for_person,remaining_quantity,daily_dose_count,units_per_dose").eq("user_id", userId).limit(100),
        sb.from("zad_appointments").select("id,title,starts_at,expected_cost,status").eq("user_id", userId).eq("status", "upcoming")
          .gte("starts_at", new Date(Date.now() - 86_400_000).toISOString()).limit(300),
      ]);
      if (state.error || obl.error || debts.error || subs.error || meds.error || appts.error) return "مقدرتش أقرا التزاماتك أو ميزانيتك دلوقتي — قول للعميل كده.";
      return describeConflicts(parsed.value, {
        today, timeZone,
        budget: state.data as Parameters<typeof describeConflicts>[1]["budget"],
        obligations: obl.data ?? [], debts: debts.data ?? [], subscriptions: subs.data ?? [],
        pharmacy: meds.data ?? [], appointments: appts.data ?? [],
      });
    }

    case "where_to_buy": {
      // «ألاقيه فين بسعر كويس؟» — صنف واحد: عروض المحلات + فواتير عملاء زاد في مدينته (whereToBuy.ts، أرضية ٣ بيوت).
      const item = String(input?.item_name ?? "").trim().slice(0, 60);
      if (item.length < 2) return "المفروض تحط item_name";
      const currency = snap?.currency ?? "";
      const [{ data: me }, { data: profile }] = await Promise.all([
        sb.from("zad_users").select("country,travel_country,travel_since").eq("id", userId).maybeSingle(),
        sb.from("zad_customer_profile").select("city").eq("user_id", userId).maybeSingle(),
      ]);
      const country = dealCountry(me as { country?: string | null; travel_country?: string | null; travel_since?: string | null } | null, Date.now());
      const [{ data: reports, error: repErr }, { data: deals }] = await Promise.all([
        sb.from("price_index").select("item_name,store_name,price,timestamp,user_id,location")
          .eq("source", "crowdsource").eq("currency", currency).not("store_name", "is", null)
          .gte("timestamp", new Date(Date.now() - WHERE_WINDOW_DAYS * 86_400_000).toISOString())
          .order("timestamp", { ascending: false }).limit(1500),
        /^[A-Z]{2}$/.test(country)
          ? sb.from("zad_deals").select("store,item_name,price,price_before,valid_until")
            .eq("country", country).gt("expires_at", new Date().toISOString()).limit(400)
          : Promise.resolve({ data: [] as WhereDeal[] }),
      ]);
      if (repErr) return "مقدرتش أقرا الأسعار دلوقتي — قول للعميل كده.";
      const rows = (reports ?? []) as WhereReport[];
      const homes = await homeMap(sb, rows.map((r) => r.user_id ?? ""));
      const city = (profile as { city?: string | null } | null)?.city ?? null;
      return describeWhereToBuy(whereToBuy(item, rows, (deals ?? []) as WhereDeal[], Date.now(), homes, city), currency);
    }

    case "get_nearby_deals": {
      const { item_category } = input;
      if (!item_category) return "المفروض تحط item_category";
      const threshold = Math.max(0, Number(input.savings_threshold) || 10);
      const { data: deals, error } = await sb
        .from("price_index")
        .select("item_name, price, location, store_name, user_id")
        .eq("item_category", item_category)
        .eq("currency", snap?.currency ?? "")
        .gte("timestamp", new Date(Date.now() - 7 * 86400000).toISOString())
        .limit(300);
      if (error) return "مقدرتش أقرا الأسعار دلوقتي — قول للعميل كده.";
      const dealHomes = await homeMap(sb, ((deals ?? []) as Array<{ user_id: string | null }>).map((r) => r.user_id ?? ""));
      return rankDeals(deals, String(item_category), threshold, snap?.currency ?? "", dealHomes);
    }

    default:
      return undefined;
  }
}
