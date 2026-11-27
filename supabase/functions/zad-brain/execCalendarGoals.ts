// m4.5 pass 3: executeTool case bodies moved verbatim out of index.ts (no behavior change).
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";
import type { RunContext } from "./validators.ts";
import type { ToolDeps } from "./execDeps.ts";
import { formatChefResult, pantryForChef } from "./chef.ts";
import { APPOINTMENT_KINDS, APPOINTMENT_RECURRENCES, PLACE_REMINDER_PLACE_VALUES } from "./validators.ts";
import { resolveLocalIso, normalizeForPerson } from "./shared.ts";
import { brokeModePlan } from "../_shared/brokeMode.ts";
import { suggestChallengeCap } from "../_shared/savingsChallenge.ts";
import { recordAction, writeRows } from "./audit.ts";
import { commitIntent, DUPLICATE_REPLY, refusalText } from "./commitIntent.ts";
import { identityOverwrites, sanitizeProfilePatch } from "../_shared/customerProfile.ts";
import { daysLeft } from "./documents.ts";
import { stepPerWeek } from "./goalPace.ts";
import { appointmentAgenda, type AppointmentRow, matchesAppointmentQuery, searchAppointments } from "./appointmentsQuery.ts";
import { bookingConflicts, bookingQuestion } from "./scheduleGuard.ts";

/** Returns undefined when `name` is not one of this file's tools. */
export async function execCalendarGoals(name: string, sb: SupabaseClient, userId: string, input: any, snap: any, ctx: RunContext, scope: AuditScope, deps: ToolDeps): Promise<string | undefined> {
  const { callCoreIntel, clashCandidates, appointmentMemory } = deps;
  switch (name) {
    case "update_emergency_fund_balance": {
      const { data: before } = await sb.from("zad_users").select("emergency_fund_balance").eq("id", userId).maybeSingle();
      // من الباب (م٢.٥): الباب بيقرّب لقرشين.
      const w = await commitIntent(sb, userId, scope, name, input, "settings.emergency_fund_set", { balance: input.new_balance });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before?.emergency_fund_balance ?? null, new: input.new_balance });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_users", targetId: userId,
        previous: before ?? null, next: { emergency_fund_balance: Math.round(input.new_balance * 100) / 100 },
      });
      return `اتظبط رصيد صندوق الطوارئ على ${input.new_balance}`;
    }
    case "suggest_recipes": {
      // قراءة بس — مفيش كتابة. المخزون من الـsnapshot (نفس اللي العقل شايفه)، والشيف نفسه
      // في zad-core-intelligence. فشل النداء بيترجع كجملة صريحة، مش وصفات من الموديل.
      const items = pantryForChef(snap?.stock);
      if (!items) {
        return "المخزون فاضي في التطبيق، فشيف زاد مش هيقدر يقترح من اللي في البيت. اقترح على العميل يسجّل "
          + "اللي عنده (أو يصوّره: app_command screen=camera) الأول.";
      }
      const result = await callCoreIntel("meal_suggestions", { items }, userId);
      if (!result) return "شيف زاد مش متاح دلوقتي — قول للعميل يجرب تاني بعد شوية، وماتقترحش وصفات من عندك.";
      return formatChefResult(result, snap?.currency ?? "");
    }
    case "app_command": {
      // أمر واجهة بس — مفيش أي كتابة في الداتابيز هنا. الأمر بيرجع للكلاينت جوه رد
      // agent_turn (agentAppCommands) وZadViewModel هو اللي بينفذه محلياً: يفتح الشاشة،
      // يجهّز الفورم، أو يظلّل العنصر. الـ audit بيسجل الأمر كقراءة.
      const cmd = { screen: input.screen, action: input.action, highlight_name: input.highlight_name ?? null };
      ctx.observations.push({ item: `app_command:${input.screen}:${input.action}`, qty: 0, samples: 1, rateKnown: true });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_brain_runs", targetId: userId,
        previous: null, next: cmd,
      });
      return `اتنفّذ أمر التطبيق: ${input.action} على شاشة ${input.screen}` +
        (cmd.highlight_name ? ` (${cmd.highlight_name})` : "");
    }
    case "learn_skill": {
      // كتابة في zad_skills عبر الـ RPC — upsert بالمفتاح: موجودة تتقوّى بدل ما تتكرر.
      const { data: outcome, error } = await sb.rpc("zad_skill_upsert", {
        p_user: userId,
        p_key: String(input.skill_key),
        p_note: String(input.note).trim(),
        p_conf: 0.6,
      });
      if (error) return `مرفوض: فشل حفظ المهارة — ${error.message}`;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { skill_key: input.skill_key, note: input.note } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_skills", targetId: null,
        previous: null, next: { skill_key: input.skill_key },
      });
      return outcome === "strengthened"
        ? "قوّيت مهارة موجودة بدل ما أكررها"
        : "اتعلمت مهارة جديدة — هتفضل معايا في المحادثات الجاية";
    }
    case "add_appointment": {
      const title = String(input.title).trim();
      // بتوقيت العميل، مش بتوقيت السيرفر — resolveLocalIso بيشرح ليه ده كان بيزحلق
      // كل ميعاد ساعتين/تلاتة. الرفض هنا أحسن من ميعاد في وقت غلط: تذكير دوا في وقت
      // غلط أسوأ من إنه مايتسجلش.
      const startsAt = resolveLocalIso(input.starts_at, snap?.now_local?.utc_offset ?? "+00:00");
      if (!startsAt) return "مرفوض: الوقت مش مفهوم — اكتبه ISO بالمنطقة الزمنية (مثال 2026-09-19T17:00:00+03:00) أو اسأل العميل الساعة بالظبط.";
      const tz = snap?.now_local?.time_zone ?? "UTC";
      // ٨ج.٥: المراجعة قبل الحجز — تعارض، شغل، نوم، جرعة متكررة ⇒ سؤال واحد بدل ميعاد غلط. فشل القراية = يتحجز.
      if (input.confirm_conflict !== true) {
        const conflicts = bookingConflicts({
          title, startsAt, kind: input.kind, recurrence: String(input.recurrence ?? "once"),
          forPerson: normalizeForPerson(input.for_person), timeZone: tz,
          existing: await clashCandidates(sb, userId, startsAt),
          workSchedule: snap?.customer?.work_schedule, sleep: snap?.sleep, medicines: snap?.medicines,
        });
        if (conflicts.length) return bookingQuestion(conflicts);
      }
      // من الباب (م٢.٥): الحساب (الوقت بتوقيت العميل، «لمين»، المصدر) هنا، والقيود والكتابة في الباب.
      const w = await commitIntent(sb, userId, scope, name, input, "appointment.added", {
          title,
          kind: APPOINTMENT_KINDS.includes(String(input.kind)) ? String(input.kind) : "personal",
          starts_at: startsAt,
          place_label: input.place_label ? String(input.place_label).trim().slice(0, 120) : null,
          // الافتراضي في الوقت نفسه: ٣٠ كان بيطلّع «فكّرني كمان ١٠ دقايق» فوراً (قياس ٢٠٢٦-٠٩-١٥).
          remind_minutes_before: Number.isInteger(input.remind_minutes_before) ? input.remind_minutes_before : 0,
          recurrence: APPOINTMENT_RECURRENCES.includes(String(input.recurrence)) ? String(input.recurrence) : "once",
          source: scope.source === "telegram" ? "telegram" : scope.source === "voice" ? "voice" : "chat",
          for_person: normalizeForPerson(input.for_person),
          // اللي العميل قاله بس (validateAddAppointment) — zad_budget_state بتحجزه لحد الميعاد.
          expected_cost: input.expected_cost == null ? null : Math.round(Number(input.expected_cost) * 100) / 100,
      });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      const after = (w.payload.after ?? {}) as { title?: string; starts_at?: string; expected_cost?: number | null };
      const row = {
        id: String(w.rowId), title: after.title ?? title, starts_at: after.starts_at ?? startsAt,
        expected_cost: after.expected_cost ?? null,
      };
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { title, starts_at: startsAt } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_appointments", targetId: row.id, previous: null, next: row,
      });
      const when = new Date(row.starts_at).toLocaleString("ar-EG", { timeZone: tz, weekday: "long", hour: "numeric", minute: "2-digit" });
      const repeat = String(input.recurrence) === "hourly" ? " وبعدها كل ساعة" : "";
      const reserved = row.expected_cost ? ` وحجزت ${row.expected_cost} من المتاح لحد الميعاد.` : "";
      const recalled = await appointmentMemory(sb, userId, [title, input.place_label, input.for_person]);
      return `تم تسجيل الميعاد «${title}» ${when}${repeat} — هفكّره بصوتي ${Number(input.remind_minutes_before) > 0 ? "قبلها" : "في وقته"}.${reserved}${recalled}`;
    }
    case "update_appointment": {
      const id = String(input.appointment_id).trim();
      const { data: before } = await sb.from("zad_appointments").select("*").eq("id", id).eq("user_id", userId).maybeSingle();
      if (!before) return "مرفوض: الميعاد ده مش موجود في مواعيد العميل";
      const patch: Record<string, unknown> = { updated_at: new Date().toISOString() };
      if (input.status !== undefined) patch.status = input.status;
      if (input.starts_at !== undefined) {
        const moved = resolveLocalIso(input.starts_at, snap?.now_local?.utc_offset ?? "+00:00");
        if (!moved) return "مرفوض: الوقت الجديد مش مفهوم — اكتبه ISO بالمنطقة الزمنية أو اسأل العميل الساعة بالظبط.";
        patch.starts_at = moved;
      }
      if (input.title !== undefined) patch.title = String(input.title).trim().slice(0, 160);
      // ٨ج.٣: المكان والتكرار ووقت التذكير — من غير كده «خليه كل أسبوع» كانت مسح وإضافة.
      if (input.place_label !== undefined) {
        patch.place_label = input.place_label === null || String(input.place_label).trim() === ""
          ? null
          : String(input.place_label).trim().slice(0, 120);
      }
      if (input.recurrence !== undefined) patch.recurrence = String(input.recurrence);
      if (input.remind_minutes_before !== undefined) patch.remind_minutes_before = Number(input.remind_minutes_before);
      if (input.expected_cost !== undefined) {
        patch.expected_cost = input.expected_cost === null ? null : Math.round(Number(input.expected_cost) * 100) / 100;
      }
      const b = before as { title: string; starts_at: string; kind?: string | null; for_person?: string | null; recurrence?: string | null; status?: string | null };
      // ٨ج.٥: نفس مراجعة add_appointment **قبل** التعديل — الوقت أو التكرار أو الاسم (دوا؟) أو رجوعه upcoming بيغيّر
      // التعارض. خلّص/اتلغى مابيتراجعش. فشل القراية = يتعدّل.
      const status = typeof patch.status === "string" ? patch.status : b.status ?? "upcoming";
      const retimed = patch.starts_at !== undefined || patch.recurrence !== undefined || patch.title !== undefined ||
        (patch.status === "upcoming" && b.status !== "upcoming");
      if (retimed && status === "upcoming" && input.confirm_conflict !== true) {
        const startsAt = typeof patch.starts_at === "string" ? patch.starts_at : b.starts_at;
        const conflicts = bookingConflicts({
          title: typeof patch.title === "string" ? patch.title : b.title, startsAt, kind: b.kind,
          recurrence: typeof patch.recurrence === "string" ? patch.recurrence : b.recurrence ?? "once",
          forPerson: b.for_person ?? null, timeZone: snap?.now_local?.time_zone ?? "UTC",
          existing: await clashCandidates(sb, userId, startsAt), excludeId: id,
          workSchedule: snap?.customer?.work_schedule, sleep: snap?.sleep, medicines: snap?.medicines,
        });
        if (conflicts.length) return bookingQuestion(conflicts, "update_appointment");
      }
      // updated_at بيحطه الباب.
      const { updated_at: _stamp, ...doorPatch } = patch;
      const w = await commitIntent(sb, userId, scope, name, input, "appointment.updated", { item_id: id, patch: doorPatch });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      const a = (w.payload.after ?? {}) as Record<string, unknown>;
      const changed = { id: a.id, title: a.title, starts_at: a.starts_at, status: a.status, expected_cost: a.expected_cost };
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: patch });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_appointments", targetId: id, previous: before, next: changed,
      });
      const cost = changed.expected_cost as number | null | undefined;
      const reserved = input.expected_cost === undefined ? "" : cost ? ` وحجزت ${cost} من المتاح لحد الميعاد.` : " وشلت الحجز.";
      return `تم تعديل الميعاد «${b.title}».${reserved}`;
    }
    case "delete_appointment": {
      // حذف حقيقي (٨ج.٣) — «الغيه» لسه update_appointment بـcancelled؛ ده لـ«امسحه خالص» أو ميعاد اتسجل غلط.
      const id = String(input.appointment_id).trim();
      const { data: before } = await sb.from("zad_appointments").select("*").eq("id", id).eq("user_id", userId).maybeSingle();
      if (!before) return "مرفوض: الميعاد ده مش موجود في مواعيد العميل — دوّر عليه بـfind_appointments وماتقولش إنك مسحته.";
      const w = await commitIntent(sb, userId, scope, name, input, "appointment.deleted", { item_id: id });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: null });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_appointments", targetId: id, previous: before, next: null,
      });
      return `اتمسح الميعاد «${(before as { title: string }).title}» من المواعيد ومش هيفكّره بيه تاني.`;
    }
    case "find_appointments": {
      // ٨ج.٣: من الجدول نفسه، مش من appointments في الـsnapshot (١٤ يوم و٣٠ صف بس).
      const tz = snap?.now_local?.time_zone ?? "UTC";
      const query = input.query == null ? "" : String(input.query).trim();
      const cols = "id,title,kind,starts_at,place_label,remind_minutes_before,recurrence,for_person,expected_cost,status";
      if (query && !input.from) {
        const statuses = input.include_past ? ["upcoming", "done", "cancelled"] : ["upcoming"];
        const { data, error } = await sb.from("zad_appointments").select(cols)
          .eq("user_id", userId).in("status", statuses).order("starts_at", { ascending: true }).limit(300);
        if (error) return `مقدرتش أقرا المواعيد دلوقتي (${error.message}) — قول للعميل كده وماتخمّنش.`;
        const hits = searchAppointments((data ?? []) as AppointmentRow[], query, tz, Date.now()).slice(0, 20);
        return hits.length === 0
          ? `مفيش ميعاد في جدول العميل فيه «${query}». قوله كده بالظبط، وماتخترعش ميعاد.`
          : JSON.stringify({ time_zone: tz, matches: hits });
      }
      const from = String(input.from);
      const to = input.to ? String(input.to) : from;
      const lo = new Date(Date.parse(`${from}T00:00:00Z`) - 86_400_000).toISOString();
      const hi = new Date(Date.parse(`${to}T00:00:00Z`) + 2 * 86_400_000).toISOString();
      const { data, error } = await sb.from("zad_appointments").select(cols).eq("user_id", userId)
        .or(`and(status.eq.upcoming,recurrence.neq.once),and(starts_at.gte."${lo}",starts_at.lt."${hi}")`)
        .order("starts_at", { ascending: true }).limit(300);
      if (error) return `مقدرتش أقرا المواعيد دلوقتي (${error.message}) — قول للعميل كده وماتخمّنش.`;
      const agenda = appointmentAgenda((data ?? []) as AppointmentRow[], from, to, tz)
        .filter((a) => (input.include_past || a.status === "upcoming") && (!query || matchesAppointmentQuery(a.title, a.place, a.for_person, query)));
      return agenda.length === 0
        ? `مفيش مواعيد في جدول العميل من ${from} لـ${to}${query ? ` فيها «${query}»` : ""}. لو بيسأل عن يومه جاوب كمان من مواعيد الأدوية لو فيه.`
        : JSON.stringify({ time_zone: tz, from, to, appointments: agenda.slice(0, 60) });
    }
    case "start_savings_challenge": {
      const { data: existing } = await sb.from("zad_savings_challenges").select("id,started_on,daily_cap")
        .eq("user_id", userId).eq("status", "active").maybeSingle();
      if (existing) return "مرفوض: عنده تحدي شغال بالفعل — شجّعه يكمّله أو اسأله لو عايز يقفله الأول (stop_savings_challenge).";
      let cap = input.daily_cap === undefined || input.daily_cap === null ? null : Math.round(Number(input.daily_cap));
      const { data: stateRaw } = await sb.rpc("zad_budget_state", { p_user: userId });
      const state = (stateRaw ?? {}) as { daily_allowance_left?: number | null; currency?: string | null };
      if (cap === null) {
        const since = new Date(Date.now() - 30 * 86_400_000).toISOString();
        const { data: spendRows } = await sb.from("zad_transactions").select("amount,counts_toward_budget")
          .eq("user_id", userId).eq("txn_kind", "expense").gte("created_at", since).limit(1000);
        const total = ((spendRows ?? []) as Array<{ amount: number; counts_toward_budget: boolean | null }>)
          .filter((r) => r.counts_toward_budget !== false)
          .reduce((a, r) => a + Math.abs(Number(r.amount) || 0), 0);
        cap = suggestChallengeCap({ avgDailySpend: total > 0 ? total / 30 : null, dailyAllowanceLeft: state.daily_allowance_left ?? null });
      }
      if (cap === null) return "مرفوض: مفيش صرف ولا رصيد أحسب منه سقف — اسأله «عايز تصرف كام في اليوم بالظبط؟»";
      const lengthDays = Number.isInteger(input.length_days) ? Number(input.length_days) : 30;
      const startedOn = String(snap?.now_local?.date ?? new Date().toISOString().slice(0, 10));
      // من الباب (م٢.٥): تحدي نشط واحد بس، ورفضه بسببه.
      const w = await commitIntent(sb, userId, scope, name, input, "goal.challenge_started", {
        daily_cap: cap, length_days: lengthDays, started_on: startedOn, currency: state.currency ?? null,
        source: scope.source === "telegram" ? "telegram" : scope.source === "voice" ? "voice" : "chat",
      });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      const row = { id: w.rowId, started_on: startedOn, daily_cap: cap, length_days: lengthDays };
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { daily_cap: cap, length_days: lengthDays } });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_savings_challenges", targetId: row.id, previous: null, next: row });
      const cur = state.currency ? ` ${state.currency}` : "";
      return `تم — بدأ تحدي ${lengthDays} يوم توفير النهارده: السقف ${cap}${cur} في اليوم.`;
    }
    case "stop_savings_challenge": {
      // من الباب (م٢.٥): الصف قبل وبعد في الحدث، والعدادات مابتتلمسش.
      const w = await commitIntent(sb, userId, scope, name, input, "goal.challenge_stopped", {});
      if (!w.ok) return w.reason === "no_active_challenge" ? "مفيش تحدي شغال أصلاً." : refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      const after = (w.payload.after ?? {}) as { days_won?: number; best_streak?: number };
      const row = { id: w.rowId, days_won: Number(after.days_won ?? 0), best_streak: Number(after.best_streak ?? 0) };
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: { status: "active" }, new: { status: "abandoned" } });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_savings_challenges", targetId: row.id, previous: null, next: row });
      return `تم إيقاف التحدي — كسب ${row.days_won} يوم وأطول سلسلة ${row.best_streak}.`;
    }
    case "update_customer_profile": {
      const { patch } = sanitizeProfilePatch(input as Record<string, unknown>);
      const { data: before } = await sb.from("zad_customer_profile").select("*").eq("user_id", userId).maybeSingle();
      const clash = identityOverwrites(before as Record<string, string | null> | null, patch);
      if (clash.length > 0 && input.confirm_overwrite !== true) {
        const was = clash.map((k) => `${k}=«${(before as Record<string, string>)[k]}»`).join("، ");
        return `مرفوض: متسجّل قبل كده ${was} وماغيّرتوش. لو بيهزر أو بيتقمص شخصية، جاريه في الهزار وكمّل بالمسجّل؛ ` +
          `لو بيصحح بجد اسأله يأكد، وبعد تأكيده ابعت نفس الحقل مع confirm_overwrite=true.`;
      }
      const w = await writeRows(
        sb.from("zad_customer_profile").upsert({
          user_id: userId, ...patch,
          updated_by: scope.source === "telegram" ? "telegram" : scope.source === "voice" ? "voice" : "chat",
          updated_at: new Date().toISOString(),
        }, { onConflict: "user_id" }).select("user_id"),
        "تحديث ملف العميل",
      );
      if (!w.ok) return `مرفوض: ${w.reason}`;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: patch });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_customer_profile", targetId: userId, previous: before, next: patch });
      // يوم القبض واحد: الميزانية بتعد عليه. قبل كده الملف كان بيقول ٣٠ والدورة ١٦ (٢٠٢٦-١٠-٠١).
      // الشهري بس — المرتب الأسبوعي أو اليومي مالوش يوم في الشهر.
      const payDay = Number((patch as { pay_day?: unknown }).pay_day);
      const frequency = (patch as { pay_frequency?: unknown }).pay_frequency ?? (before as { pay_frequency?: unknown } | null)?.pay_frequency;
      if (Number.isInteger(payDay) && payDay >= 1 && payDay <= 31 && (frequency == null || frequency === "monthly")) {
        // من الباب (م٢.٥). مفتاحه لوحده (":cycle") عشان مايتصادمش مع كتابة الملف نفسها.
        const cyc = await commitIntent(sb, userId, scope, `${name}:cycle`, input, "settings.cycle_start_set", { day: payDay });
        if (!cyc.ok) console.error("[update_customer_profile] cycle_start_day sync refused:", cyc.reason);
      }
      return `status=saved fields=${Object.keys(patch).join(",")}`;
    }
    case "set_broke_mode": {
      const src = scope.source === "telegram" ? "telegram" : scope.source === "voice" ? "voice" : "chat";
      if (input.active === false) {
        const w = await writeRows(
          sb.from("zad_broke_mode").update({ ended_at: new Date().toISOString(), updated_at: new Date().toISOString() })
            .eq("user_id", userId).is("ended_at", null).select("user_id"),
          "الخروج من وضع الطوارئ",
        );
        if (!w.ok) return `مرفوض: ${w.reason}`;
        ctx.mutationCount++;
        ctx.mutations.push({ tool: name, old: { active: true }, new: { active: false } });
        await recordAction(sb, userId, scope, { tool: name, input, table: "zad_broke_mode", targetId: userId, previous: null, next: { active: false } });
        return w.rows.length ? "تم — خرجنا من وضع الطوارئ ورجعت الاقتراحات العادية. مبروك إنك عدّيتها 🎉" : "وضع الطوارئ مكانش شغال أصلاً.";
      }
      const { data: stateRaw } = await sb.rpc("zad_budget_state", { p_user: userId });
      const state = (stateRaw ?? {}) as { available?: number | null; limit_confirmed?: boolean; days_left?: number; cycle_end?: string | null; currency?: string | null };
      const plan = brokeModePlan({
        cashLeft: input.cash_left === undefined || input.cash_left === null ? null : Number(input.cash_left),
        available: typeof state.available === "number" ? state.available : null,
        limitConfirmed: state.limit_confirmed === true,
        daysLeft: typeof state.days_left === "number" ? state.days_left : null,
        cycleEnd: state.cycle_end ?? null,
        nowMs: Date.now(),
      });
      const nowIso = new Date().toISOString();
      const w = await writeRows(
        sb.from("zad_broke_mode").upsert({
          user_id: userId, started_at: nowIso, ends_at: plan.ends_at, ended_at: null,
          cash_left: plan.cash_left, daily_cap: plan.daily_cap, currency: state.currency ?? null,
          source: src, updated_at: nowIso,
        }, { onConflict: "user_id" }).select("user_id,ends_at,daily_cap"),
        "تفعيل وضع الطوارئ",
      );
      if (!w.ok) return `مرفوض: ${w.reason}`;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: plan });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_broke_mode", targetId: userId, previous: null, next: plan });
      const cur = state.currency ? ` ${state.currency}` : "";
      return plan.daily_cap === null
        ? `تم تفعيل وضع الطوارئ لمدة ${plan.days_left} يوم: وقفت اقتراحات الشراء والوصفات بقت من اللي في البيت بس. مش عارفة معاه كام — اسأله «معاك كام لآخر الشهر؟» عشان أحسب مصروف اليوم.`
        : `تم تفعيل وضع الطوارئ: معاه ${Math.round(plan.cash_left ?? 0)}${cur} لـ${plan.days_left} يوم = ${plan.daily_cap}${cur} في اليوم بالظبط. وقفت اقتراحات الشراء، والوصفات من اللي في البيت بس.`;
    }
    case "add_place_reminder": {
      const note = String(input.note).trim().slice(0, 200);
      const place = PLACE_REMINDER_PLACE_VALUES.includes(String(input.place)) ? String(input.place) : "any";
      const w = await writeRows(
        sb.from("zad_place_reminders").insert({
          user_id: userId,
          note,
          place,
          source: scope.source === "telegram" ? "telegram" : scope.source === "voice" ? "voice" : "chat",
        }).select("id,place,note"),
        "تسجيل تذكير المكان",
      );
      if (!w.ok) return `مرفوض: ${w.reason}`;
      const row = w.rows[0] as { id: string; place: string; note: string };
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { note, place } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_place_reminders", targetId: row.id, previous: null, next: row,
      });
      const where = place === "pharmacy" ? "أول ما توصل صيدلية" : place === "supermarket" ? "أول ما توصل سوبرماركت" : place === "mall" ? "أول ما توصل مول" : "أول ما توصل أي محل";
      return `تم — هفكّره بصوتي بـ«${note}» ${where}. (محتاج تنبيهات الموقع مفعّلة في الإعدادات.)`;
    }
    case "cancel_place_reminder": {
      const id = String(input.reminder_id).trim();
      const { data: before } = await sb.from("zad_place_reminders").select("*").eq("id", id).eq("user_id", userId).maybeSingle();
      if (!before) return "مرفوض: التذكير ده مش موجود عند العميل";
      const w = await writeRows(
        sb.from("zad_place_reminders").update({ status: "cancelled" }).eq("id", id).eq("user_id", userId).select("id,note,status"),
        "إلغاء تذكير المكان",
      );
      if (!w.ok) return `مرفوض: ${w.reason}`;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: { status: "cancelled" } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_place_reminders", targetId: id, previous: before, next: w.rows[0],
      });
      return `تم إلغاء تذكير «${(before as { note: string }).note}».`;
    }
    case "schedule_task": {
      // حلقة الأهداف — لو المهمة دي جزء من هدف، اربطها. الهدف لازم يكون للعميل نفسه.
      let goalId: string | null = null;
      if (input.goal_title) {
        const { data: goal } = await sb.from("agent_goals")
          .select("id").eq("user_id", userId).eq("title", String(input.goal_title).trim()).maybeSingle();
        goalId = (goal as { id: string } | null)?.id ?? null;
      }
      const rec = ["daily", "weekly", "monthly"].includes(String(input.recurrence)) ? String(input.recurrence) : "once";
      const w = await writeRows(
        sb.from("agent_tasks").insert({
          user_id: userId,
          task_description: String(input.task_description).trim(),
          scheduled_for: new Date(input.run_at).toISOString(),
          goal_id: goalId,
          recurrence: rec,
        }).select("id,scheduled_for"),
        "جدولة المهمة",
      );
      if (!w.ok) return `مرفوض: ${w.reason}`;
      const newRow = w.rows[0] as any;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { task_description: input.task_description, run_at: input.run_at } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "agent_tasks", targetId: newRow.id,
        previous: null, next: newRow,
      });
      const when = new Date(newRow.scheduled_for).toLocaleString("ar-EG", { timeZone: "UTC", hour: "2-digit", minute: "2-digit", day: "numeric", month: "short" });
      return `تمام، هعمل ده الساعة ${when} وهبعتلك النتيجة`;
    }
    case "add_goal_progress": {
      const goalTitle = String(input.goal_title).trim();
      const { data: goal } = await sb.from("agent_goals").select("id,title,current_value,target_value,deadline_date,progress_kind")
        .eq("user_id", userId).eq("title", goalTitle).eq("status", "active").maybeSingle();
      if (!goal) return `مرفوض: مفيش هدف نشط اسمه «${goalTitle}».`;
      // من الباب (م٢.٥)، وهو اللي بينادي zad_goal_add_progress.
      const prog = await commitIntent(sb, userId, scope, name, input, "goal.progress", {
        goal_id: (goal as { id: string }).id, amount: Number(input.amount),
      });
      if (!prog.ok) return refusalText(prog.reason);
      if (prog.duplicate) return DUPLICATE_REPLY;
      // new_state مقروء من الداتابيز بعد الكتابة (20260809180000).
      const { data: after } = await sb.from("agent_goals").select("id,title,current_value,target_value,deadline_date,progress_kind")
        .eq("id", (goal as { id: string }).id).eq("user_id", userId).maybeSingle();
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: goal, new: after });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "agent_goals", targetId: (goal as { id: string }).id, previous: goal, next: after,
      });
      const a = (after ?? goal) as { current_value: number; target_value: number | null; deadline_date: string | null };
      const step = stepPerWeek(a);
      return `status=recorded — «${goalTitle}» بقى ${Number(a.current_value)} من ${Number(a.target_value ?? 0)}.` +
        (step !== null ? ` الباقي على الأسبوع: ${step} لحد ${a.deadline_date}.` : Number(a.current_value) >= Number(a.target_value ?? Infinity) ? " وصل الهدف 🎉 — هنّيه." : "");
    }
    case "set_life_goal": {
      const title = String(input.title).trim();
      const action = String(input.action ?? "add");
      if (action === "cancel") {
        // من الباب (م٢.٥).
        const w = await commitIntent(sb, userId, scope, name, input, "goal.cancelled", { title });
        if (!w.ok) return refusalText(w.reason);
        if (w.duplicate) return DUPLICATE_REPLY;
        ctx.mutationCount++;
        ctx.mutations.push({ tool: name, old: { title, status: "active" }, new: { title, status: "cancelled" } });
        return `تمام، الهدف «${title}» اتلغى`;
      }
      const deadline = input.deadline_date != null && String(input.deadline_date).trim() !== ""
        ? String(input.deadline_date).slice(0, 10)
        : null;
      // من الباب (م٢.٥). ١٠.٢(د): money = مبلغ بيتحرك بكلام العميل بس؛ count = عدد مهام. غايب = زي ما هو (والجديد tasks).
      const w = await commitIntent(sb, userId, scope, name, input, "goal.set", {
        title,
        metric: input.metric != null ? String(input.metric).trim() : null,
        target_value: input.target_value != null ? Number(input.target_value) : null,
        deadline_date: deadline,
        ...(input.unit === "money" || input.unit === "count" ? { unit: input.unit } : {}),
      });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      const goalAfter = (w.payload.after ?? {}) as Record<string, unknown>;
      const gRow = {
        id: w.rowId, current_value: goalAfter.current_value, target_value: goalAfter.target_value,
        deadline_date: goalAfter.deadline_date, progress_kind: goalAfter.progress_kind,
      } as any;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { title, metric: input.metric ?? null } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "agent_goals", targetId: gRow.id,
        previous: null, next: gRow,
      });
      // ١٠.٢(د): المتابعة الأسبوعية من السيرفر لأي هدف من الشات — مش مستنية إن الموديل يفتكر schedule_task
      // (اتقاس ١٣/١١: هدفين من الشات من غير ولا متابعة).
      const { error: reviewErr } = await sb.rpc("zad_goal_ensure_review", { p_user: userId, p_goal: gRow.id });
      if (reviewErr) console.error("[set_life_goal] weekly review not scheduled:", reviewErr.message);
      const followUp = reviewErr ? "" : " والمتابعة الأسبوعية اتجدولت.";
      if (gRow.progress_kind === "amount") {
        const step = stepPerWeek(gRow);
        return `تمام، هدف «${title}» اتسجل كمبلغ.${followUp}` +
          (step !== null ? ` الخطوة: ${step} في الأسبوع لحد ${gRow.deadline_date} — قولهاله.` : "") +
          " لما يقول حط كام، سجّله بـadd_goal_progress.";
      }
      return `تمام، هدف «${title}» اتسجل.${followUp} لو ليه أجزاء، فكّكه لمهام بـ schedule_task واربطها بـ goal_title.`;
    }

    default:
      return undefined;
  }
}
