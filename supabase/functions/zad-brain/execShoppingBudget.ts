// m4.5 pass 3: executeTool case bodies moved verbatim out of index.ts (no behavior change).
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";
import type { RunContext } from "./validators.ts";
import type { ToolDeps } from "./execDeps.ts";
import { qtyFromFraction } from "./readingFraction.ts";
import { CONFIRM_REQUIRED_TOOLS } from "./validators.ts";
import { recordAction } from "./audit.ts";
import { commitIntent, DUPLICATE_REPLY, refusalText } from "./commitIntent.ts";
import { inventoryOwnerFilter, pickInventoryRow } from "./inventoryRow.ts";
import { householdFamilyId, householdFilter } from "../_shared/household.ts";

/** Returns undefined when `name` is not one of this file's tools. */
export async function execShoppingBudget(name: string, sb: SupabaseClient, userId: string, input: any, snap: any, ctx: RunContext, scope: AuditScope, deps: ToolDeps): Promise<string | undefined> {
  const { householdName } = deps;
  switch (name) {
    case "add_shopping_item": {
      // Idempotent by (user, item, still-unbought). A blind insert here is how the list in
      // the 2026-08-15 report ended up with "مياه إيلانو" and "بيض" twice each: the same
      // restock ran at 09:12 and again at 17:02, and nothing looked first. The same shape
      // of duplicate comes from the Telegram fallback — when zad-brain fails *after* a
      // write, the bot retries on the old [[ACTION]] path and writes it again.
      const itemName = await householdName(sb, userId, String(input.item_name).trim());
      // قايمة البيت: لو الأم ضافت «لبن» مايتضافش تاني باسم الأب.
      const { data: existing } = await sb.from("zad_shopping_list")
        .select("id,item_name,quantity")
        .or(householdFilter(userId, await householdFamilyId(sb, userId)))
        .eq("is_purchased", false);
      const match = (existing ?? []).find(
        (row: { item_name: string }) => row.item_name.trim().toLowerCase() === itemName.toLowerCase(),
      ) as { id: string; quantity: number } | undefined;

      if (match) {
        // نفس الصنف مطلوب تاني قبل ما يتشترى = كمية أكبر، مش سطر تاني في القايمة. من الباب (م٢.٥) بـid السطر:
        // الصف ممكن يكون باسم فرد تاني في البيت، والجمع على الكمية المقفولة وقت الكتابة.
        const merged = await commitIntent(sb, userId, scope, name, input, "shopping.added", {
          item_id: match.id, item_name: itemName, quantity: Number(input.quantity) || 1,
        });
        if (!merged.ok) return refusalText(merged.reason);
        if (merged.duplicate) return DUPLICATE_REPLY;
        return `"${itemName}" كان في القايمة أصلاً — الكمية بقت ${merged.after}`;
      }

      const added = await commitIntent(sb, userId, scope, name, input, "shopping.added", {
        item_name: itemName, quantity: input.quantity,
      });
      if (!added.ok) return refusalText(added.reason);
      if (added.duplicate) return DUPLICATE_REPLY;
      return "اتضافت لقائمة التسوق";
    }
    case "update_inventory_qty": {
      // Task 30 — لو العميل في عيلة، المخزون مشترك: الصنف ممكن يكون العضو التاني
      // ضافه، فالمطابقة بـfamily_id مش user_id. before.id اتأكد ملكيته/مشاركته هنا،
      // فالـupdate بعدين بيمشي بـid لوحده من غير فلتر user_id تاني (كان هيرفض
      // يلاقي الصف لو مالكه الحقيقي عضو تاني في العيلة).
      const { data: fam } = await sb.from("family_members").select("family_id").eq("user_id", userId).maybeSingle();
      const familyId = (fam as { family_id: string } | null)?.family_id ?? null;
      // المطابقة في inventoryRow.ts: اسم متكرر أو صف العميل من غير family_id كانوا بيرجّعوا
      // «مش موجود» (زرار «خلص» في تليجرام، ٢٠٢٦-٠٩-٢٩).
      const { data: candidates } = await sb.from("zad_inventory")
        .select("id,quantity,user_id,family_id,created_at,restock_mode")
        .eq("item_name", input.item_name).or(inventoryOwnerFilter(userId, familyId));
      const before = pickInventoryRow(candidates as any[], userId, familyId);
      if (!before) return "مرفوض: الصنف مش موجود في مخزون العميل ده — عدّل وحاول تاني.";
      // «دي مش أساسية» (ZAD_PLAN ٣.١٠): على كل صفوف البيت بالاسم ده، عشان القايمة والتشيك-إن يسكتوا عنه.
      if (input.restock_mode === "staple" || input.restock_mode === "occasional") {
        const ids = ((candidates ?? []) as Array<{ id: string }>).map((r) => r.id);
        // من الباب (م٢.٥): حدث لكل صف، والمفتاح فيه الصف عشان الصفوف ماتبانش تكرار لبعض.
        let fresh = 0;
        for (const id of ids) {
          const m = await commitIntent(sb, userId, scope, name, { ...input, item_id: id }, "inventory.restock_mode_set", {
            item_id: id, restock_mode: input.restock_mode,
          });
          if (!m.ok) return refusalText(m.reason);
          if (!m.duplicate) fresh++;
        }
        if (fresh === 0) return DUPLICATE_REPLY;
        ctx.mutationCount++;
        await recordAction(sb, userId, scope, {
          tool: name, input, table: "zad_inventory", targetId: before.id,
          previous: { restock_mode: (before as { restock_mode?: string | null }).restock_mode ?? null },
          next: { restock_mode: input.restock_mode },
        });
        if ((input.new_qty === undefined || input.new_qty === null) && (input.fraction_left === undefined || input.fraction_left === null)) {
          return input.restock_mode === "occasional"
            ? `تمام، «${input.item_name}» بقى من الحاجات اللي بتجيبها كل فترة — مش هعتبره ناقص ولا هفكّرك بيه.`
            : `تمام، «${input.item_name}» بقى من الأساسيات — هفكّرك بيه لما يقرب يخلص.`;
        }
      }
      // «فاضل نصه» (ZAD_PLAN ٣.٩): النسبة بتتحسب هنا من آخر شرا، مش في الموديل.
      if ((input.new_qty === undefined || input.new_qty === null) && typeof input.fraction_left === "number") {
        const { data: lastBuy } = await sb.from("zad_inventory_observations").select("qty")
          .eq("user_id", before.user_id ?? userId).eq("item_name", input.item_name).eq("source", "purchase")
          .order("observed_at", { ascending: false }).limit(1).maybeSingle();
        const full = lastBuy ? Number((lastBuy as { qty: number }).qty) : null;
        const qty = qtyFromFraction(input.fraction_left, full, before.quantity === null ? null : Number(before.quantity));
        if (qty === null) {
          return "مرفوض: مفيش كمية أعرف أحسب منها النسبة — اسأل العميل عن الكمية بالرقم (كام كيلو/كام حبة).";
        }
        input = { ...input, new_qty: qty };
      }
      // الكتابة من الباب الوحيد (م٢.٥): القيود والحدث والصف مع بعض، أو رفض بسبب في zad_guard_events.
      const set = await commitIntent(sb, userId, scope, name, input, "inventory.quantity_set", {
        item_id: before.id, quantity: input.new_qty,
      });
      if (!set.ok) return refusalText(set.reason);
      if (set.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before.quantity, new: set.after });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_inventory", targetId: before.id,
        previous: { quantity: before.quantity }, next: { id: before.id, quantity: set.after },
      });

      // Task 18 Fault B: the quantity write alone left the item in stock_unknown forever, so
      // the brain re-asked about it daily and the answer taught the system nothing. Recording
      // the observation + recomputing the rate is UNCONDITIONAL here — deliberately not a
      // separate tool the model may or may not call, since skipping the optional step is
      // exactly what a 20B model did in the STEP 3 run.
      const { data: obs, error: obsErr } = await sb.rpc("zad_record_observation", {
        p_user: userId, p_item: input.item_name, p_qty: input.new_qty, p_source: "question_answer",
      });
      if (obsErr) {
        // The inventory write already committed; report honestly rather than claiming the
        // rate advanced, so a broken learning loop is visible instead of silent.
        console.error("zad_record_observation failed:", obsErr.message);
        return `اتعدلت الكمية بس معرفتش أسجل الملاحظة للتعلم: ${obsErr.message}`;
      }
      const samples = (obs as any)?.samples ?? 0;
      const rateKnown = (obs as any)?.rate_known === true;
      const perDay = Number((obs as any)?.avg_daily_qty);
      ctx.observations.push({ item: input.item_name, qty: input.new_qty, samples, rateKnown });
      // النص ده بيطلع للعميل كإيصال (✅ في تليجرام) — كلام ليه، مش تعليمات للموديل.
      if (rateKnown) return `اتعدلت الكمية، وبقى عندي معدل استهلاك مؤكد للصنف ده (${samples} قياسات)`;
      if (Number.isFinite(perDay) && perDay > 0) {
        return `اتعدلت الكمية، وبقى عندي تقدير تقريبي: حوالي ${Math.round(perDay * 10) / 10} في اليوم (بيتظبط مع كل مرة)`;
      }
      return `اتعدلت الكمية واتسجلت ملاحظة للتعلم (${samples} قياسات لحد الآن)`;
    }
    case "set_transaction_category": {
      const { data: before } = await sb.from("zad_transactions").select("category,title,merchant_name").eq("id", input.transaction_id).eq("user_id", userId).maybeSingle();
      if (!before) return "مرفوض: المعاملة مش بتاعت العميل ده — عدّل وحاول تاني.";
      const w = await commitIntent(sb, userId, scope, name, input, "money.updated", {
        item_id: input.transaction_id, patch: { category: input.category },
      });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before.category, new: input.category });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_transactions", targetId: input.transaction_id,
        previous: { category: before.category }, next: { category: input.category },
      });
      // ٣.١١: تصحيح الفئة من الشات بيبقى درس (zad_corrections). فشل التسجيل مايلغيش التصحيح.
      const { error: lessonErr } = await sb.rpc("zad_record_correction", {
        p_user: userId, p_kind: "category", p_subject: before.merchant_name || before.title,
        p_wrong: before.category, p_right: input.category, p_source: "chat",
      });
      if (lessonErr) console.error("[corrections] record failed:", lessonErr.message);
      return "اتصنفت المعاملة";
    }
    case "suggest_budget_change": {
      const { error } = await sb.from("zad_insights").upsert({
        user_id: userId, kind: "insight", surface: "home_card", priority: "normal",
        title: "اقتراح تعديل الميزانية", body: input.reason ?? "العقل شايف الميزانية محتاجة تتعدل",
        dedupe_key: `budget_suggestion_${new Date().toISOString().slice(0, 7)}`,
        action_type: "yes_no", status: "pending", updated_at: new Date().toISOString(),
      }, { onConflict: "user_id,dedupe_key" });
      if (error) return `فشل: ${error.message}`;
      return "اقتراح الميزانية اتسجل كرؤية يأكدها العميل — العقل ميغيّرش الرقم لوحده";
    }
    case "merge_duplicate_expense": {
      const { data: dropped } = await sb.from("zad_transactions").select("*").eq("id", input.drop_id).eq("user_id", userId).maybeSingle();
      if (!dropped) return "مرفوض: المعاملة المطلوب حذفها مش بتاعت العميل ده — عدّل وحاول تاني.";
      // من الباب (م٢.٥): الصف كامل في الحدث، وzad_trash بيحفظه للتراجع.
      const merged = await commitIntent(sb, userId, scope, name, input, "money.deleted", { item_id: input.drop_id });
      if (!merged.ok) return refusalText(merged.reason);
      if (merged.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: input.drop_id, new: input.keep_id });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_transactions", targetId: input.drop_id,
        previous: dropped, next: null,
      });
      return "اتدمجت العملية المكررة";
    }
    case "reconcile_cash_balance": {
      // Task 19.5 — "الإجابة تظبط الرصيد مباشرة بإدراج صف transfer تصحيحي، من غير تفصيل".
      // الميكانيزم الوحيد الحالي (zad_cash_balance()/BudgetMath.cashOnHand، Task 19.3/19.4)
      // بيزود الكاش بس مع (transfer + transfer_to=cash)، وبينقصه بس مع (expense + wallet=cash)
      // — فمفيش "transfer للخارج" فعلي يقدر ينقّص الرصيد. تصحيح لأسفل (العميل معاه كاش أقل
      // من المتوقع = صرف حقيقي حصل وماتسجلش) بيتسجل expense/wallet=cash فعلاً، مش transfer —
      // ده الاتجاه المتسق الوحيد مع الصيغة الموجودة، مش خروج عن الطلب.
      const { data: cashData, error: cashErr } = await sb.rpc("zad_cash_balance", { p_user: userId });
      if (cashErr) return `فشل قراءة رصيد الكاش: ${cashErr.message}`;
      const current = Number(cashData ?? 0);
      const delta = input.reported_amount - current;
      if (Math.abs(delta) < 0.01) return "الرصيد اللي قاله العميل مطابق للمحسوب فعلاً — مفيش تصحيح لازم";
      const isIncrease = delta > 0;
      // من الباب (م٢.٥). المفتاح فيه الرصيد المحسوب، فنفس الإجابة بعد ما الرصيد اتغير تسوية جديدة مش تكرار.
      const settled = await commitIntent(sb, userId, scope, name, { ...input, current }, "money.logged", {
        amount: Math.round(Math.abs(delta) * 100) / 100,
        title: "تسوية كاش أسبوعية (تقريبية)",
        category: isIncrease ? "تحويلات" : "أخرى",
        txn_kind: isIncrease ? "transfer" : "expense",
        ...(isIncrease ? { transfer_to: "cash" } : {}),
        wallet: "cash",
      });
      if (!settled.ok) return refusalText(settled.reason);
      if (settled.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: current, new: input.reported_amount });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_transactions", targetId: settled.rowId,
        previous: null, next: { id: settled.rowId, amount: Math.round(Math.abs(delta) * 100) / 100 },
      });
      return `اتسجل تصحيح ${Math.abs(delta).toFixed(2)} (${isIncrease ? "زيادة" : "نقصان"}) عشان الكاش يطابق الرصيد الفعلي`;
    }
    case "confirm_cycle_start": {
      // Task 25 — بعد ما العميل يأكد "أيوة" على سؤال cycle_start_confirm. cycle_anchor
      // بيفضل 'day_of_month' (الافتراضي) دايماً هنا — الاكتشاف هنا بيقترح يوم بس، مش نوع
      // anchor، وده مقصود يفضل بسيط. الحدود نفسها بتتحسب في zad_cycle_bounds() في
      // Postgres، واللي بتحترم last_working_day لو العميل ظبطه من الإعدادات.
      const { data: cycleBefore } = await sb.from("zad_users").select("cycle_start_day").eq("id", userId).maybeSingle();
      // من الباب (م٢.٥).
      const w = await commitIntent(sb, userId, scope, name, input, "settings.cycle_start_set", { day: input.cycle_start_day });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: cycleBefore?.cycle_start_day ?? null, new: input.cycle_start_day });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_users", targetId: userId,
        previous: { cycle_start_day: cycleBefore?.cycle_start_day ?? null }, next: { cycle_start_day: input.cycle_start_day },
      });
      return `اتظبطت دورة الراتب على يوم ${input.cycle_start_day} — كل حساب "متبقي"/"متاح" هيبقى على أساسها من دلوقتي`;
    }
    case "confirm_obligation": {
      // Task 26 — title/amount مش جايين من الموديل، جايين من snap.obligation_detection
      // نفسها (اتحققوا في validateConfirmObligation) عشان الموديل يفضل بس يصنّف kind،
      // مش يعيد كتابة رقم/اسم ممكن يغلط فيه. الصف بيتسجل confirmed=true من الأول —
      // مفيش صف pending وسيط، الاكتشاف والتأكيد بيحصلوا في نداء واحد.
      const det = snap.obligation_detection;
      // بند 32.1 — لو المرشح BNPL (det.provider مضبوط)، total_installments اختياري من
      // كلام العميل بس، مش تخمين. لو قاله، remaining_installments = العدد ده بالظبط —
      // "من دلوقتي فيه كذا قسط باقي" زي ما العميل قاله، مش محاسبة رجعية على قسطين
      // شفناهم فعلاً. لو مقالوش، تفضل provider مسجلة (مفيدة لوحدها) والعددين فاضيين —
      // حالة فاضية شريفة، مش رقم مخترع، ومطابقة الإشعارات الجاية (zad_match_bnpl_obligation)
      // هتنتظر لحد ما يتحددوا.
      const totalInstallments = det.provider && Number.isFinite(input.total_installments) && input.total_installments > 0
        ? Math.round(input.total_installments)
        : null;
      const w = await commitIntent(sb, userId, scope, name, input, "obligation.added", {
        title: det.title, amount: det.amount, kind: input.kind,
        due_day: det.due_day, recurrence: "monthly", auto_detected: true, confirmed: true,
        provider: det.provider, total_installments: totalInstallments,
      });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { title: det.title, amount: det.amount, kind: input.kind } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_obligations", targetId: w.rowId,
        previous: null, next: w.payload.after,
      });
      return `اتسجل الالتزام "${det.title}" (${det.amount}) كـ${input.kind} — هيتحسب في "المتاح" من دلوقتي`;
    }
    // ═══════════════════════════════════════════════════════════
    // المرحلة ٢-ب — أدوات المحادثة. التلاتة الأولانية بيكتبوا على فلوس حقيقية،
    // فمابيوصلوش هنا من حلقة agent_turn خالص (بيتحوّلوا لاقتراح)؛ بيوصلوا هنا بس من
    // agent_confirm بعد ضغطة تأكيد صريحة.
    // ═══════════════════════════════════════════════════════════
    case "allocate_income": {
      // مش في CONFIRM_REQUIRED_TOOLS عن قصد: الأداة دي **مابتخترعش ولا بتغيّر أي مبلغ**،
      // بتسجّل إجابة العميل على سؤال زاد سأله للتو. لو خلّيناها تعدي على دورة تأكيد
      // تانية، العميل هيتسأل مرتين على نفس الحاجة ("الإيداع ده للبيت؟" → "أيوة" →
      // "تأكيد إن الإيداع للبيت؟") — وده بالظبط اللي بيخلي المحادثة تبان غبية.
      // والأثر عكوس: نداء تاني بـ counts مختلفة بيرجّع الرقم زي ما كان.
      const { data: row } = await sb.from("zad_transactions")
        .select("id,title,amount,txn_kind,counts_toward_budget")
        .eq("id", input.transaction_id).eq("user_id", userId).maybeSingle();
      if (!row) return "مرفوض: المعاملة دي مش موجودة عند العميل ده";
      if (row.txn_kind !== "income") {
        return "مرفوض: الأداة دي للإيداعات بس — المصروفات بتتخصم من الرصيد على طول ومحتاجاش قرار";
      }

      const counts = input.counts === true;
      const alloc = await commitIntent(sb, userId, scope, name, input, "money.updated", {
        item_id: row.id, patch: { counts_toward_budget: counts },
      });
      if (!alloc.ok) return refusalText(alloc.reason);
      if (alloc.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: row.counts_toward_budget, new: counts });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_transactions", targetId: row.id,
        previous: { counts_toward_budget: row.counts_toward_budget },
        next: { id: row.id, title: row.title, amount: row.amount, counts_toward_budget: counts },
      });
      // مهم: الرقم **مابيتغيّرش** في الحالتين. بعد الدفتر كل إيداع بيدخل الرصيد ساعة ما
      // يوصل، والعمود ده بقى تسجيل لنية العميل عشان النصيحة تفرّق بين فلوس البيت وفلوس
      // متحطوطة على جنب — مش مفتاح بيشغّل ويطفّي حساب. الرد لازم يقول كده بالظبط، لأن
      // "المتاح زاد بيهم" بقت كدبة: المتاح كان زاد بيهم من الأول.
      return counts
        ? `سجّلت إن ${row.amount} (${row.title}) فلوس بيت. الرصيد زي ما هو — الإيداع كان داخل فيه أصلاً.`
        : `سجّلت إن ${row.amount} (${row.title}) مش فلوس بيت، وهاخد بالي منها في النصيحة. الرصيد زي ما هو — الفلوس موجودة فعلاً.`;
    }

    default:
      return undefined;
  }
}
