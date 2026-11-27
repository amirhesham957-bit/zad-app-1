// m4.5 pass 3: executeTool case bodies moved verbatim out of index.ts (no behavior change).
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";
import type { RunContext } from "./validators.ts";
import type { ToolDeps } from "./execDeps.ts";
import { latinDigits } from "./validators.ts";
import { heldMessagesSummary, normalizeForPerson, normalizeMemoryEntities, resolveValidUntil } from "./shared.ts";
import { isDoseAction, muteCheckin, settleDoseReminder } from "../_shared/doseDoor.ts";
import { productNameKey } from "./productIdentity.ts";
import { recordAction, writeRows } from "./audit.ts";
import { insightExpiry } from "./attention.ts";
import { canSeeFamilySpending, visibleSpenders } from "./familyAccess.ts";
import { conflictAction, type HouseholdMember, memberIdFor, memoryTimeRefusal } from "./memoryTime.ts";
import { pendingAnswerable, SENSITIVE_TOPIC_LABEL, type SensitiveTopic, sensitiveTopic } from "./sensitiveMemory.ts";
import { occasionDateLabel, occasionMd, occasionNote, type OccasionKind } from "./occasions.ts";
import { TOOLS } from "./toolDefs.ts";

/** Returns undefined when `name` is not one of this file's tools. */
export async function execInsightsMemory(name: string, sb: SupabaseClient, userId: string, input: any, snap: any, ctx: RunContext, scope: AuditScope, deps: ToolDeps): Promise<string | undefined> {
  const { attachEntities, embedAndLinkNote, liveNoteId, writeMemoryNoteWithLinking, writeSingleCopyMemory } = deps;
  switch (name) {
    case "emit_insight": {
      const kind = input.kind ?? "insight";
      const validUntil = resolveValidUntil(input.valid_until, snap?.now_local?.time_zone ?? "UTC", Date.now());
      const { error } = await sb.from("zad_insights").upsert({
        user_id: userId, kind, surface: input.surface ?? "home_card",
        priority: input.priority ?? "normal", title: input.title, body: input.body,
        dedupe_key: input.dedupe_key, action_type: input.action_type ?? null, about_item: input.about_item ?? null,
        expires_at: insightExpiry(kind, validUntil),
        status: "pending", updated_at: new Date().toISOString(),
      }, { onConflict: "user_id,dedupe_key" });
      if (error) return `فشل الحفظ: ${error.message}`;
      ctx.insightCount++;
      return "تم — الرؤية اتسجلت";
    }
    case "ask_user": {
      const { error } = await sb.from("zad_insights").upsert({
        user_id: userId, kind: "question", surface: input.surface ?? "home_card", priority: "normal",
        title: input.title, body: input.body, dedupe_key: input.dedupe_key,
        action_type: input.answer_type, about_item: input.about_item ?? null,
        status: "pending", updated_at: new Date().toISOString(),
      }, { onConflict: "user_id,dedupe_key" });
      if (error) return `فشل الحفظ: ${error.message}`;
      ctx.insightCount++;
      return "تم — السؤال اتسجل";
    }
    case "family_mediation": {
      // وساطة عائلية — نكتشف ازدواج الصرف بين أفراد العيلة على نفس الفئة
      const hint = String(input.category_hint ?? "").trim();
      const since = new Date(Date.now() - 30 * 86400000).toISOString();
      const { data: fam } = await sb.from("family_members")
        .select("user_id, alias, family_id, role").eq("user_id", userId).maybeSingle();
      if (!fam?.family_id) return "العميل مش منضم لعيلة — الوساطة للعائلات فقط.";
      // Service role reads every member's transactions here, so the role rule RLS would
      // apply has to be applied by hand: a child (or plain member) never sees the others'.
      if (!canSeeFamilySpending(fam.role)) {
        return "الوساطة بتعرض صرف كل فرد في العيلة، ودي لمدير العيلة بس. قول للعميل يطلبها من ولي الأمر.";
      }
      const { data: allMembers } = await sb.from("family_members")
        .select("user_id, alias").eq("family_id", fam.family_id);
      if (!allMembers || allMembers.length < 2) return "العيلة فيها فرد واحد — مفيش حد يتوسّط معاه 😊";
      // بالموافقة بس: صرف أي فرد بيبان لو هو وافق إن الأدمن يتابع مصروفه.
      const { data: grants } = await sb.from("zad_family_shares")
        .select("owner_id").eq("viewer_id", userId).eq("family_id", fam.family_id)
        .eq("scope", "spending").eq("status", "granted");
      const members = visibleSpenders(userId, allMembers as Array<{ user_id: string; alias: string | null }>,
        ((grants ?? []) as Array<{ owner_id: string }>).map((g) => g.owner_id));
      if (members.length < 2) {
        return "محدش من العيلة وافق لسه إنك تتابع مصروفه. اطلب المتابعة من «عيلتي» — وكل فرد بيوافق بنفسه.";
      }
      const ids = members.map((m) => m.user_id);
      let q = sb.from("zad_transactions").select("user_id, amount, category, created_at")
        .eq("is_expense", true).gte("created_at", since).in("user_id", ids);
      if (hint) q = q.ilike("category", `%${hint}%`);
      const { data: tx } = await q;
      if (!tx || tx.length === 0) return `مفيش مصاريف مطابقة آخر ٣٠ يوم${hint ? ` في "${hint}"` : ""}.`;
      // تجميع: فئة → فرد → إجمالي
      const byCatUser: Record<string, Record<string, number>> = {};
      const aliasOf: Record<string, string> = {};
      for (const m of members) aliasOf[m.user_id] = m.alias || "فرد";
      for (const t of tx) {
        const c = t.category ?? "أخرى";
        byCatUser[c] = byCatUser[c] ?? {};
        byCatUser[c][t.user_id] = (byCatUser[c][t.user_id] ?? 0) + Number(t.amount);
      }
      // فئات صرفها أكتر من فرد
      const overlaps = Object.entries(byCatUser).filter(([, users]) => Object.keys(users).length >= 2);
      if (overlaps.length === 0) {
        return `مفيش ازدواج صرف على نفس الفئات بين أفراد العيلة آخر ٣٠ يوم — كل واحد في حتة ✅`;
      }
      const lines = ["🔍 اكتشفت ازدواج صرف على نفس الفئات:"];
      let totalDup = 0;
      for (const [cat, users] of overlaps.slice(0, 3)) {
        const catTotal = Object.values(users).reduce((a2, b2) => a2 + b2, 0);
        totalDup += catTotal;
        const parts = Object.entries(users)
          .sort((a2, b2) => b2[1] - a2[1])
          .map(([uid, amt]) => `${aliasOf[uid]}: ${Math.round(amt)}`);
        lines.push(`• ${cat} (${Math.round(catTotal)}): ${parts.join(" ↔ ")}`);
      }
      lines.push("");
      lines.push(`💡 اقتراح التسوية: اتفقوا مين مسؤول عن الفئة دي، والتاني يرجّع نص مشترياته الأخيرة — أو قسموا الفئات بينكم مرة واحدة بدل الازدواج. الإجمالي المتكرر: ~${Math.round(totalDup)}`);
      return lines.join("\n");
    }

    // باب واحد للجرعة وكتم السؤال (ZAD_PLAN ٣.٤، _shared/doseDoor.ts): زراير تليجرام بتوصل هنا بـagent_execute.
    // مش في TOOLS — الموديل عمره ما يناديهم؛ اللي بيناديهم زرار العميل.
    case "answer_dose_reminder": {
      const momentId = String(input.moment_id ?? "");
      if (!/^[0-9a-fA-F-]{36}$/.test(momentId) || !isDoseAction(input.action)) return "مرفوض: تذكير أو رد مش مفهوم";
      return await settleDoseReminder(sb, userId, momentId, input.action, scope);
    }

    case "mute_checkin": {
      return (await muteCheckin(sb, userId)) ? "تمام، مش هسألك عن المخزون بالليل" : "مرفوض: مقدرتش أحفظ الكتم";
    }

    case "what_i_held_back": {
      const days = Math.min(30, Math.max(1, Math.round(Number(input.days) || 7)));
      const { data, error } = await sb.rpc("zad_held_messages", { p_user: userId, p_days: days });
      if (error) return `مقدرتش أقرا اللي سكتّ عنه دلوقتي: ${error.message}`;
      return `آخر ${days} يوم:\n${heldMessagesSummary((data ?? []) as Array<Record<string, unknown>> as never)}`;
    }

    case "monthly_review": {
      // جلسة المراجعة الشهرية — شخصية مالية بتتطور
      const answers = (input.answers ?? {}) as Record<string, string>;
      const now = new Date();
      const monthKey = now.toISOString().slice(0, 7); // yyyy-MM

      if (!answers.biggest_decision && !answers.next_month_goal) {
        // أول نداء: رجّع الأسئلة الثلاثة + ملخص الأرقام عشان العميل يجاوب واعي
        const since = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
        const { data: monthTx } = await sb.from("zad_transactions")
          .select("amount, category, is_expense").eq("user_id", userId).gte("created_at", since);
        const spent = (monthTx ?? []).filter((t: any) => t.is_expense).reduce((s2: number, t: any) => s2 + Number(t.amount), 0);
        const byCat: Record<string, number> = {};
        for (const t of monthTx ?? []) {
          if (!t.is_expense) continue;
          const c = t.category ?? "أخرى";
          byCat[c] = (byCat[c] ?? 0) + Number(t.amount);
        }
        const topCat = Object.entries(byCat).sort((a, b) => b[1] - a[1])[0];
        return JSON.stringify({
          review_questions: [
            "أكبر قرار مالي أخدته الشهر ده إيه؟",
            `صرفت ${Math.round(spent)} الشهر ده — أكبر فئة كانت "${topCat?.[0] ?? "—"}". لو ترجع بالزمن، هتغيّر حاجة؟`,
            "هدف واحد واقعي للشهر الجاي — إيه هو؟",
          ],
          month_spent: Math.round(spent),
        });
      }

      // الإجابات وصلت → نبني الشخصية المالية
      const traits: string[] = [];
      const decision = String(answers.biggest_decision ?? "");
      const regret = String(answers.biggest_regret ?? "");
      const goal = String(answers.next_month_goal ?? "");
      if (decision.length > 3) traits.push("حاسم");
      if (regret.length > 3) traits.push("بيتعلم من أخطائه");
      if (goal.length > 3) traits.push("له اتجاه واضح");

      // ندم كبير على فئة معينة = "منفق عاطفي" على الفئة دي
      let persona = "مدير متوازن";
      if (regret.includes("طعام") || regret.includes("مطعم") || regret.includes("طلبات")) persona = "منفق عاطفي على الأكل";
      else if (regret.includes("اشتراك")) persona = "ضحية الاشتراكات الصامتة";
      else if (traits.includes("حاسم") && traits.includes("له اتجاه واضح")) persona = "مخطط واثق";

      const personalityNote = `شخصية مالية (${monthKey}): ${persona}. صفات: ${traits.join(", ") || "لسه بنتعرف عليك"}. هدف الشهر الجاي: ${goal || "لسه محددش"}`;
      // zad_memory مفيهاش unique(user_id,scope) عن قصد — الscope فيه أكتر من ملاحظة عادةً
      // (زي "general"/"spending_pattern"). السكوب ده بالذات المفروض نسخة واحدة بس فباستبدلها
      // يدوي بدل onConflict: "user_id,scope" اللي كانت بترمي 42P10 (مفيش constraint تطابقه)
      // ويتبلع بصمت — فالشخصية المالية ما كانتش بتتسجل ولا مرة.
      const { error: personaMemErr } = await writeSingleCopyMemory(
        sb, userId, "financial_persona", personalityNote, 0.9,
      );
      if (personaMemErr) console.error("financial_persona memory write failed:", personaMemErr);

      ctx.counts["monthly_review"] = (ctx.counts["monthly_review"] ?? 0) + 1;
      return `تمت المراجعة ✅\n\nشخصيتك المالية: **${persona}**\n${personalityNote}\n\nهفتكر ده في كل كلامنا جاي — هقولك قبل ما توقع في نفس الفخ.`;
    }
    case "salary_plan": {
      // وضع الراتب وصل — خطة ٣ نقاط من الأرقام الحقيقية:
      // ١- الالتزامات الثابتة الجاية (غير مدفوعة) خلال دورة الراتب
      // ٢- المعدل اليومي الآمن بعد حجزها
      // ٣- أعلى فئة صرف الشهر اللي فات (نقطة انتباه)
      const since = new Date(Date.now() - 35 * 86400000).toISOString();
      // zad_obligations معندهاش name ولا is_paid خالص (الأعمدة الحقيقية: title، active،
      // confirmed) — الكويري القديمة كانت بترمي 42703 على كل نداء، والخطأ ما كانش متفحوص
      // (destructuring بيرمي error) فـ fixedTotal كان بيطلع صفر دايمًا مهما كانت الالتزامات
      // الحقيقية. الالتزام هنا "جاري" لو active+confirmed — الجدول مفيهوش تتبع "اتدفع الشهر
      // ده" منفصل، مجرد التزام متكرر فعّال لحد ما يتلغي.
      const [{ data: obligations }, { data: monthTx }] = await Promise.all([
        sb.from("zad_obligations").select("title,amount,due_date")
          .eq("user_id", userId).eq("active", true).eq("confirmed", true),
        sb.from("zad_transactions").select("amount,category,created_at,is_expense")
          .eq("user_id", userId).gte("created_at", since),
      ]);
      const fixedTotal = (obligations ?? []).reduce((s2: number, o: any) => s2 + Number(o.amount), 0);

      const expenses = (monthTx ?? []).filter((t: any) => t.is_expense);
      const spentLastMonth = expenses.reduce((s2: number, t: any) => s2 + Number(t.amount), 0);
      const byCat: Record<string, number> = {};
      for (const t of expenses) {
        const c = t.category ?? "أخرى";
        byCat[c] = (byCat[c] ?? 0) + Number(t.amount);
      }
      const topCat = Object.entries(byCat).sort((a, b) => b[1] - a[1])[0];

      // الرصيد الحالي من snapshot (متاح بعد الحجوزات)
      const balance = snap.balance?.value ?? null;
      const daysInCycle = 30;
      const safeDaily = balance != null && balance > fixedTotal
        ? Math.round((balance - fixedTotal) / daysInCycle)
        : null;

      const points: string[] = [];
      points.push(`١- التزامات جاية: ${Math.round(fixedTotal)} (${(obligations ?? []).length} التزام غير مدفوع)`);
      if (safeDaily != null && safeDaily > 0) {
        points.push(`٢- بعد حجزهم، معدلك الآمن ${safeDaily}/يوم لباقي الشهر`);
      } else {
        points.push(`٢- ⚠️ الرصيد مش هيغطي الالتزامات — راجعهم قبل ما تصرف`);
      }
      if (topCat && topCat[1] > 0) {
        points.push(`٣- انتبه لـ"${topCat[0]}": صرفت عليه ${Math.round(topCat[1])} آخر شهر — أكبر فئة عندك`);
      }

      const plan = points.join("\n");
      const { error: salaryMemErr } = await writeSingleCopyMemory(
        sb, userId, "salary_plan", plan, 0.95,
      );
      if (salaryMemErr) console.error("salary_plan memory write failed:", salaryMemErr);

      return `💰 الراتب وصل — خطتك للشهر:\n${plan}`;
    }
    case "suggest_challenge": {
      // تحدي توفير شخصي — بيتخزن كتحدي عائلي لو العميل في عيلة، وإلا memory فردية.
      const cat = String(input.category ?? "").trim();
      if (!cat) return "حدد الفئة اللي عايز تتحدى فيها الأول.";
      const pct = Math.min(40, Math.max(15, Number(input.reduction_percent ?? 20)));
      const since = new Date(Date.now() - 28 * 86400000).toISOString();
      const { data: catTx } = await sb.from("zad_transactions")
        .select("amount").eq("user_id", userId)
        .eq("is_expense", true).ilike("category", `%${cat}%`)
        .gte("created_at", since);
      const weeklyAvg = (catTx ?? []).length > 0
        ? (catTx ?? []).reduce((s2: number, t: any) => s2 + Number(t.amount), 0) / 4
        : null;
      if (weeklyAvg == null || weeklyAvg <= 0) {
        return `مفيش مصاريف مسجلة في "${cat}" آخر شهر — سجل شوية مصاريف الأول عشان التحدي يبقى واقعي`;
      }
      const target = Math.round(weeklyAvg * (pct / 100));
      const challengeText = `تحدي "${cat}": قلّل ${cat} ${pct}٪ الأسبوع ده — وفّر ~${target} خلال ٧ أيام`;
      const { data: fam } = await sb.from("family_members").select("family_id").eq("user_id", userId).maybeSingle();
      if (fam?.family_id) {
        await sb.from("family_financial_challenges").insert({
          family_id: fam.family_id,
          challenge_type: "weekly",
          title: challengeText,
          description: `مبني على متوسط صرفك في ${cat}: ${Math.round(weeklyAvg)} أسبوعياً`,
          target_amount: target,
          start_date: new Date().toISOString(),
          end_date: new Date(Date.now() + 7 * 86400000).toISOString(),
        });
      }
      const { error: challengeMemErr } = await writeSingleCopyMemory(
        sb, userId, "active_challenge", challengeText, 0.9,
      );
      if (challengeMemErr) console.error("active_challenge memory write failed:", challengeMemErr);
      ctx.counts["suggest_challenge"] = (ctx.counts["suggest_challenge"] ?? 0) + 1;
      return challengeText + " — التحدي اتسجل وهتابع التزامك تلقائياً";
    }
    case "remember": {
      const scope = input.scope ?? "general";
      // الكيانات والزمن (ZAD_LIVING_BRAIN.md الشريحة ١). الـvalidator اتأكد إن valid_until
      // لو موجود بيتقري ومستقبلي، فـnull هنا = حقيقة دائمة.
      const about = normalizeMemoryEntities(input.about);
      const validUntil = resolveValidUntil(input.valid_until, snap?.now_local?.time_zone ?? "UTC", Date.now());

      // جواب «صح؟» على ملاحظة حساسة اتركنت في لفة قبل كده (sensitiveMemory.ts). الحارس: الصف لازم يكون
      // اتعمل قبل اللفة دي، يعني العقل سأل والعميل ردّ برسالة جديدة — مش ركن وتأكيد في نفس النفس.
      const pendingId = input.pending_id;
      if (pendingId) {
        if (!ctx.heard) return "مرفوض: الملاحظة الحساسة بتتأكد من كلام العميل في الشات بس.";
        const { data: row, error: rowErr } = await sb.from("zad_memory_pending")
          .select("id,scope,note,confidence,family_id,valid_until,about,created_at,resolved_at")
          .eq("id", pendingId).eq("user_id", userId).maybeSingle();
        if (rowErr) return `فشل الحفظ: ${rowErr.message}`;
        if (!row) return "مرفوض: الملاحظة المستنية دي مش موجودة.";
        const state = pendingAnswerable(row, ctx.startedAt ?? Date.now(), Date.now());
        if (state === "same_turn") return "مرفوض: لسه ماسألتش العميل. اسأله «صح؟» واستنى رده في رسالته الجاية.";
        if (state === "resolved") return "الملاحظة دي اتجاوب عليها قبل كده.";
        if (state === "expired") return "مرفوض: السؤال عليها عدّى عليه أكتر من ٣ أيام — لو العميل لسه عايزها، ابدأ بـremember من الأول.";
        const resolve = (resolution: "saved" | "declined") =>
          sb.from("zad_memory_pending").update({ resolution, resolved_at: new Date().toISOString() })
            .eq("id", row.id).is("resolved_at", null);
        if (input.pending_yes !== true) {
          await resolve("declined");
          return "ماتحفظتش — ومتسألش عليها تاني.";
        }
        const saved = await writeMemoryNoteWithLinking(
          sb, userId, row.scope, row.note, row.confidence, row.family_id,
          { validUntil: row.valid_until, about: normalizeMemoryEntities(row.about), confirmed: true },
        );
        if (saved.status === "error") return `فشل الحفظ: ${saved.message}`;
        if (saved.status === "conflict") {
          return "متعارضة مع ملاحظة متخزنة — ماخزنتش حاجة. اسأل العميل أنهي واحدة الصح، وبعدين remember بنفس الملاحظة مع replaces_note_id.";
        }
        await resolve("saved");
        if (saved.status === "expired") return "العميل أكّد، بس الميعاد اللي كانت صحيحة لحده عدّى — ماسجلتهاش.";
        return "اتحفظت بعد ما العميل أكّد";
      }

      // م٩.٢: «رجع الجيم» قبل المعاد — العادة بتشتغل تاني وملاحظة السبب بتتقفل.
      if (input.pause_note_id && !validUntil) {
        const { data: res, error: resErr } = await sb.rpc("zad_memory_resume", { p_user: userId, p_note: input.pause_note_id });
        if (resErr) return `فشل الحفظ: ${resErr.message}`;
        if (!(res as { ok?: boolean })?.ok) return memoryTimeRefusal((res as { reason?: string })?.reason);
        return "رجّعت العادة شغالة، وسبب الإيقاف بقى تاريخ";
      }
      // م٩.٢: «أحمد وقف الجيم أسبوع» — العادة بتتوقف لحد valid_until (مش بتتقفل)، وnote = السبب.
      if (input.pause_note_id && validUntil) {
        if (sensitiveTopic(input.note)) return "مرفوض: السبب فيه تفصيلة حساسة — اكتبه من غيرها («وقف الجيم أسبوع»).";
        const { data: res, error: pauseErr } = await sb.rpc("zad_memory_pause", {
          p_user: userId, p_note: input.pause_note_id, p_until: validUntil, p_reason: input.note,
        });
        if (pauseErr) return `فشل الحفظ: ${pauseErr.message}`;
        if (!(res as { ok?: boolean })?.ok) return memoryTimeRefusal((res as { reason?: string })?.reason);
        return `وقّفت العادة لحد ${validUntil.slice(0, 10)} — بعدها بترجع لوحدها، ومش اتمسحت`;
      }

      // م٩.٢: الحقيقة عن فرد من البيت. الاسم لازم يكون في أفراد البيت، وإلا الحفظ مايحصلش.
      let memberId: string | null = null;
      if (typeof input.member === "string" && input.member.trim()) {
        const { data: members } = await sb.from("zad_household_members")
          .select("id,display_name,kind").eq("user_id", userId).is("archived_at", null).limit(30);
        memberId = memberIdFor(input.member, (members ?? []) as HouseholdMember[]);
        if (!memberId) {
          return `مرفوض: «${input.member}» مش في أفراد البيت. سيب member فاضي واكتب الاسم في about، أو خلّي العميل يضيفه من «البيت».`;
        }
      }
      const tagMember = async (noteId: string | null | undefined) => {
        if (!memberId || !noteId) return;
        const { error } = await sb.rpc("zad_memory_set_member", { p_user: userId, p_note: noteId, p_member: memberId });
        if (error) console.warn("[memory] member not set:", error.message);
      };

      // The customer already settled a conflict this tool reported last turn. The old belief
      // is closed (superseded, not deleted — having been wrong once is evidence too) and the
      // new one inherits its entities; a 'contradicts' link keeps the history visible.
      if (input.replaces_note_id) {
        const { data: resolved, error: resolveErr } = await sb.rpc("zad_memory_resolve_conflict", {
          p_user: userId, p_old_id: input.replaces_note_id, p_scope: scope,
          p_note: input.note, p_conf: input.confidence ?? 0.6,
        });
        if (resolveErr) return `فشل الحفظ: ${resolveErr.message}`;
        if (!(resolved as any)?.ok) return "مرفوض: الملاحظة القديمة اللي بتشاور عليها مش موجودة.";
        const newId = (resolved as { new_id?: string }).new_id;
        if (newId && about.length) await attachEntities(sb, userId, newId, about);
        await tagMember(newId);
        return "سجّلت الجديدة، والقديمة بقت تاريخ (اتقفلت ومربوطة بالجديدة كتناقض)";
      }

      // بند 34.2 — العميل لازم يكون في عيلة فعلاً عشان share_with_family تعمل حاجة.
      // مفيش تخمين — لو مفيش family_id حقيقي، الملاحظة بتتسجل عادية (خاصة) بصمت.
      let shareFamilyId: string | null = null;
      if (input.share_with_family === true) {
        const { data: fam } = await sb.from("family_members").select("family_id").eq("user_id", userId).maybeSingle();
        shareFamilyId = (fam as { family_id: string } | null)?.family_id ?? null;
      }

      // الحساس بيتركن ويتسأل عليه، مايتكتبش (ZAD_PLAN ٥.٣). الكشف ثابت، والموديل يقدر يزود بـsensitive=true.
      const topic: SensitiveTopic | "model" | null = sensitiveTopic(input.note) ?? (input.sensitive === true ? "model" : null);
      if (topic) {
        // برّه الشات (مبادرة، لفة درس مجبرة) مفيش حد يتسأل، فبتتساب زي الاستخلاص الليلي.
        if (!ctx.heard) return "ماحفظتهاش: معلومة حساسة ومفيش حد أسأله «صح؟» دلوقتي.";
        const { data: parked, error: parkErr } = await sb.from("zad_memory_pending").insert({
          user_id: userId, scope, note: input.note, confidence: input.confidence ?? 0.5,
          family_id: shareFamilyId, valid_until: validUntil, about, topic,
        }).select("id").single();
        if (parkErr) return `فشل الحفظ: ${parkErr.message}`;
        const label = topic === "model" ? "خاصة" : SENSITIVE_TOPIC_LABEL[topic];
        return `دي معلومة حساسة (${label}) — ماحفظتهاش. في نفس ردك اسأل العميل سؤال واحد خفيف بكلامه: `
          + `«أفتكر إن ${input.note}؟ صح؟»${shareFamilyId ? " وقوله إنها هتبان لباقي العيلة" : ""}. `
          + `في رسالته الجاية نادِ remember بـpending_id="${(parked as { id: string }).id}" `
          + `وpending_yes = true لو قال آه أو false لو قال لأ، ومتسألش تاني.`;
      }

      const written = await writeMemoryNoteWithLinking(
        sb, userId, scope, input.note, input.confidence ?? 0.5, shareFamilyId, { validUntil, about },
      );
      if (written.status === "error") return `فشل الحفظ: ${written.message}`;
      if (written.status === "sensitive") return "ماحفظتهاش: حساسة."; // الكشف فوق مسكها قبل كده
      if (written.status === "expired") return "مرفوض: الميعاد اللي الحقيقة دي صحيحة لحده عدّى — ماسجلتهاش.";
      const data = written.status;

      // zad_memory_upsert used to read a contradiction as agreement: a near-identical note
      // with the negation flipped cleared the 0.6 merge threshold, overwrote the stored
      // one and RAISED confidence. It now refuses instead, and this is where that refusal
      // turns into a question for the customer rather than a silent pick.
      if (data === "conflict") {
        const { data: clash } = await sb.rpc("zad_memory_conflict", {
          p_user: userId, p_scope: scope, p_note: input.note,
        });
        const existing = clash as { id: string; note: string } | null;
        if (!existing) return "اتحفظت";
        // م٩.١: العميل قالها في الشات دلوقتي ⇒ كلامه الأحدث هو الحسم، والقديمة بتتقفل (مش بتتمسح).
        if (conflictAction(ctx.heard) === "supersede") {
          const { data: resolved, error: resolveErr } = await sb.rpc("zad_memory_resolve_conflict", {
            p_user: userId, p_old_id: existing.id, p_scope: scope, p_note: input.note, p_conf: input.confidence ?? 0.6,
          });
          if (resolveErr) return `فشل الحفظ: ${resolveErr.message}`;
          const newId = (resolved as { ok?: boolean; new_id?: string })?.ok ? (resolved as { new_id?: string }).new_id : null;
          if (newId) {
            if (about.length) await attachEntities(sb, userId, newId, about);
            await tagMember(newId);
            await embedAndLinkNote(sb, userId, scope, input.note, { link: true, noteId: newId });
            return `سجّلت الجديدة، والقديمة («${existing.note}») بقت تاريخ — اتقفلت ومربوطة بالجديدة كتناقض.`;
          }
        }
        return `متعارضة مع ملاحظة متخزنة: "${existing.note}". ماخزنتش حاجة. `
          + `اسأل العميل أنهي واحدة الصح دلوقتي، ولما يرد نادِ remember تاني بنفس الملاحظة `
          + `الجديدة مع replaces_note_id="${existing.id}".`;
      }
      if (memberId) await tagMember(await liveNoteId(sb, userId, scope, input.note));
      if (data === "strengthened") return "الملاحظة موجودة — قوّيتها بدل ما أكررها";
      return validUntil ? `اتحفظت لحد ${validUntil.slice(0, 10)}` : "اتحفظت";
    }
    case "answer_same_product": {
      // «دول نفس الحاجة؟» (productIdentity.ts): الجواب للبيت كله (20261011210000).
      const a = String(input.a).trim();
      const b = String(input.b).trim();
      if (input.same === false) {
        const { data, error } = await sb.rpc("zad_product_not_same_for", { p_user: userId, p_a: a, p_b: b });
        if (error || (data as { ok?: boolean } | null)?.ok === false) {
          return `مرفوض: مقدرتش أسجل الإجابة (${error?.message ?? (data as any)?.reason}).`;
        }
        ctx.mutationCount++;
        return `اتسجّل إن «${a}» و«${b}» حاجتين مختلفين — مش هسأل عنهم تاني.`;
      }
      const keep = input.keep ? String(input.keep).trim() : a;
      const others = [a, b].filter((n) => productNameKey(n) !== productNameKey(keep));
      let pantry = 0, lines = 0;
      for (const other of others) {
        const { data, error } = await sb.rpc("zad_product_merge_for", { p_user: userId, p_keep: keep, p_other: other });
        const r = data as { ok?: boolean; reason?: string; pantry_rows_merged?: number; list_lines_merged?: number } | null;
        if (error || r?.ok === false) return `مرفوض: مقدرتش أدمجهم (${error?.message ?? r?.reason}).`;
        pantry += r?.pantry_rows_merged ?? 0;
        lines += r?.list_lines_merged ?? 0;
      }
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: [a, b], new: keep });
      return `اتسجّل: «${a}» و«${b}» صنف واحد اسمه «${keep}» في البيت كله` +
        (pantry ? ` — اتجمّع ${pantry + 1} صف في المخزن` : "") + (lines ? ` و${lines + 1} سطر في القايمة` : "") +
        `. الاستهلاك هيتحسب عليه كصنف واحد.`;
    }
    case "save_trusted_technician": {
      // «فنيين بثق فيهم» (20261006014219). نفس الرقم مرة تانية = تحديث الاسم/الصنعة، مش صف جديد.
      // الرقم اتحقق في validateSaveTrustedTechnician إن العميل قاله.
      const row = {
        user_id: userId,
        name: String(input.name).trim(),
        trade: String(input.trade),
        phone: latinDigits(String(input.phone)).trim(),
        notes: String(input.notes ?? "").trim().slice(0, 120),
      };
      const w = await writeRows(
        sb.from("zad_trusted_technicians").upsert(row, { onConflict: "user_id,phone" }).select("id,name,trade,phone"),
        "حفظ الفني",
      );
      if (!w.ok) return `مرفوض: ${w.reason}`;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { name: row.name, trade: row.trade } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_trusted_technicians", targetId: (w.rows[0] as { id?: string } | undefined)?.id ?? null,
        previous: null, next: w.rows[0],
      });
      return `اتسجل: ${row.name} في «الصيانة» ← «فنيين بثق فيهم» — رقمه هناك بنقرة وقت الطوارئ.`;
    }
    case "remember_occasion": {
      // المناسبة ملاحظة عادية في الذاكرة ومعاها يومها (20261006000000). الجملة بتتكتب هنا مش من
      // الموديل، والتاريخ اتحقق في validateRememberOccasion. «أنا»/فاضي = العميل نفسه (null).
      const md = occasionMd(input.month, input.day);
      if (!md) return "مرفوض: اليوم ده مش موجود في الشهر ده.";
      const kind: OccasionKind = input.occasion === "anniversary" ? "anniversary" : "birthday";
      const person = normalizeForPerson(input.person);
      const { data: noteId, error } = await sb.rpc("zad_memory_set_occasion", {
        p_user: userId, p_occasion: kind, p_for: person, p_md: md, p_note: occasionNote(kind, person, md),
      });
      if (error) return `فشل الحفظ: ${error.message}`;
      if (person && typeof noteId === "string") {
        await attachEntities(sb, userId, noteId, normalizeMemoryEntities([{ kind: "person", name: person }]));
      }
      const what = kind === "birthday" ? "عيد ميلاد" : "ذكرى جواز";
      return `اتحفظ ${what} ${person ?? "العميل"} يوم ${occasionDateLabel(md)} — هفكّره قبلها بـ٣ أيام الصبح وأهنّي يومها.`;
    }
    case "link_memory": {
      // الدالة نفسها بتتحقق إن الملاحظتين بتوع نفس العميل قبل أي كتابة — العقل شغال
      // بـ service_role وبيتخطى RLS، فـ id مهلوس كان هيقدر يربط ذاكرة عميل بعميل تاني.
      // بنعتمد على الفحص ده مش بنكرره هنا: مصدر حقيقة واحد أأمن من اتنين ممكن يفرقوا.
      const { data, error } = await sb.rpc("zad_memory_link_upsert", {
        p_user: userId,
        p_from: input.from_id,
        p_to: input.to_id,
        p_relation: input.relation,
        p_strength: input.strength ?? 0.5,
      });
      if (error) return `مرفوض: ${error.message}`;
      if (!data) return "مرفوض: الربط مانجحش";
      return "الرابط اتسجل بين الملاحظتين";
    }

    default:
      return undefined;
  }
}
