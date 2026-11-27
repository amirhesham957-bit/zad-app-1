// m4.5 pass 3: executeTool case bodies moved verbatim out of index.ts (no behavior change).
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";
import type { RunContext } from "./validators.ts";
import type { ToolDeps } from "./execDeps.ts";
import { purchaseToolReply, toolPurchaseLines } from "./purchaseDoor.ts";
import { occurredAtIso } from "./validators.ts";
import { normalizeForPerson } from "./shared.ts";
import { txnSourceType } from "./provenance.ts";
import { recordAction } from "./audit.ts";
import { commitIntent, DUPLICATE_REPLY, refusalText } from "./commitIntent.ts";
import { bankTwinMergedReply } from "./bankTwin.ts";

/** Returns undefined when `name` is not one of this file's tools. */
export async function execTransactions(name: string, sb: SupabaseClient, userId: string, input: any, snap: any, ctx: RunContext, scope: AuditScope, deps: ToolDeps): Promise<string | undefined> {
  switch (name) {
    case "log_transaction": {
      const isExpense = input.txn_kind === "expense";
      // عملية بتاريخ فات (occurred_on): بتتكتب في شهرها. مابتدخلش دمج صف البنك ولا نافذة التكرار
      // (الاتنين عن اللي حصل دلوقتي) ولا باب الشرا (أصناف قديمة مابتملاش مخزن النهارده).
      const occurredAt = occurredAtIso(input.occurred_on, snap?.now_local?.date, snap?.now_local?.utc_offset);
      if (occurredAt === "invalid") return "مرفوض: تاريخ العملية مش مفهوم أو في المستقبل — اسأل العميل حصلت إمتى.";
      const backdated = occurredAt !== null;

      // Idempotent by (user, kind, amount) inside a short window. add_shopping_item and
      // add_pharmacy_item both got this guard; the tool that writes *money* did not, which
      // is the wrong way round. On 2026-08-15 account 20a420a9 ended up with three income
      // rows of 10,000 written inside two minutes (23:46:52, 23:47:42, 23:48:09) — one
      // salary, logged three times, because the turn kept answering "تعذر تنفيذ الطلب"
      // and the customer reasonably retried. The titles differ ("بدون وصف" twice, then
      // "راتب"), so title matching would have missed every one of them; the amount and the
      // kind are what actually repeat.
      //
      // The window is 10 minutes, the same fingerprint life TxDeduplicator uses on the
      // client, so the notification path and the chat path agree on what "again" means.
      //
      // A repeat is never silently dropped and never silently written. Money is the one
      // place where guessing is worst in both directions: swallowing a real second
      // purchase hides spending, and writing a retry inflates it. So the tool refuses and
      // says why, and the agent has to ask. `allow_duplicate` is how the customer's "لأ،
      // دي عملية تانية" gets through — it exists so the answer comes from them, not from
      // a heuristic.
      // صف البنك لنفس الدفعة، لسه من غير فئة (20261102060000): «إيجار شقة 3500» بعد إشعار BDC بـ3500 هو نفس
      // الفلوس — الصف بياخد الاسم والفئة بدل ما الدفعة تتحسب مرتين (حساب المالك ١/١١). الأصناف بتعدّي على
      // باب الشرا وهو بيدمج لوحده؛ الكاش و«دي عملية تانية» مابيتدمجوش.
      if (!backdated && isExpense && input.allow_duplicate !== true && input.wallet !== "cash" && toolPurchaseLines(input.lines).length === 0) {
        const { data: twinId, error: twinErr } = await sb.rpc("zad_bank_twin_service", { p_user: userId, p_amount: input.amount });
        if (twinErr) console.error("[log_transaction] bank twin read failed:", twinErr.message);
        if (!twinErr && typeof twinId === "string") {
          const { data: before } = await sb.from("zad_transactions")
            .select("id,amount,title,category,merchant_name,created_at").eq("id", twinId).eq("user_id", userId).maybeSingle();
          if (before) {
            const title = String(input.title).trim().slice(0, 80);
            const patch: Record<string, unknown> = { title };
            if (input.category) patch.category = String(input.category).trim().slice(0, 40);
            if (input.merchant_name) patch.merchant_name = String(input.merchant_name).trim().slice(0, 80) || null;
            const forPerson = normalizeForPerson(input.for_person);
            if (forPerson) patch.for_person = forPerson;
            // من الباب (م٢.٥): تعديل على صف البنك.
            const w = await commitIntent(sb, userId, scope, name, input, "money.updated", { item_id: twinId, patch });
            if (!w.ok) return refusalText(w.reason);
            if (w.duplicate) return DUPLICATE_REPLY;
            ctx.mutationCount++;
            ctx.mutations.push({ tool: name, old: { title: before.title, category: before.category }, new: patch });
            await recordAction(sb, userId, scope, {
              tool: name, input, table: "zad_transactions", targetId: twinId, previous: before, next: w.payload.after ?? patch,
            });
            return bankTwinMergedReply(String(before.title ?? ""), Number(before.amount), title, String(before.created_at));
          }
        }
      }

      if (!backdated && input.allow_duplicate !== true) {
        const windowStart = new Date(Date.now() - 10 * 60 * 1000).toISOString();
        const { data: recent } = await sb.from("zad_transactions")
          .select("id,title,amount,created_at")
          .eq("user_id", userId)
          .eq("txn_kind", input.txn_kind)
          .gte("created_at", windowStart);
        const amount = Math.round(input.amount * 100) / 100;
        const twin = (recent ?? []).find(
          (row: { amount: number }) => Math.abs(row.amount - amount) < 0.005,
        ) as { id: string; title: string; created_at: string } | undefined;
        if (twin) {
          const minsAgo = Math.max(
            1,
            Math.round((Date.now() - new Date(twin.created_at).getTime()) / 60000),
          );
          return `مرفوض: فيه ${input.txn_kind === "income" ? "إيداع" : "مصروف"} بنفس المبلغ ` +
            `(${amount}) اتسجّل من ${minsAgo} دقيقة باسم "${twin.title}". غالباً دي نفس ` +
            `العملية اتبعتت تاني. اسأل العميل: دي عملية تانية فعلاً ولا نفس اللي فاتت؟ ` +
            `لو أكّد إنها تانية، نادِ الأداة تاني بـ allow_duplicate=true.`;
        }
      }

      // مصروف فيه أصناف = شرا واحد (ZAD_PLAN ٣.٦ د، purchaseDoor.ts): الفلوس والمخزن والصيدلية والأسعار
      // في ترانزاكشن واحدة، فمفيش «الفلوس اتسجلت والأصناف لأ» لو add_inventory_item اتنسى أو وقع.
      const purchaseLines = isExpense && !backdated ? toolPurchaseLines(input.lines) : [];
      if (purchaseLines.length > 0) {
        const amount = Math.round(input.amount * 100) / 100;
        const title = String(input.title).trim().slice(0, 80);
        // من الباب (م٢.٥)، والباب بينادي باب الشرا (zad_record_purchase_service) جوه نفس الترانزاكشن.
        const buy = await commitIntent(sb, userId, scope, name, input, "money.purchase", {
          purchase: {
            id: crypto.randomUUID(), amount, title,
            category: input.category ? String(input.category).trim().slice(0, 40) : null,
            wallet: input.wallet === "cash" ? "cash" : "card",
            source_type: txnSourceType(input.source_type, scope.source),
            merchant_name: input.merchant_name ? String(input.merchant_name).trim().slice(0, 80) || null : null,
            allow_duplicate: input.allow_duplicate === true,
            lines: purchaseLines,
          },
        });
        if (!buy.ok) {
          // رفض باب الشرا نفسه (زي «فيه مصروف بنفس المبلغ») بيرجع بتفاصيله، والرد زي ما كان.
          if (buy.reason.startsWith("purchase_") && buy.detail) {
            return purchaseToolReply(buy.detail, { title, amount }).text;
          }
          if (buy.reason.startsWith("rpc:")) {
            console.error("[log_transaction] purchase door failed:", buy.reason);
            return "مرفوض: الشرا ماتسجلش دلوقتي — ولا حاجة اتكتبت. جرب تاني.";
          }
          return refusalText(buy.reason);
        }
        if (buy.duplicate) return DUPLICATE_REPLY;
        const bought = buy.payload.after as Record<string, unknown> | null;
        const reply = purchaseToolReply(bought, { title, amount });
        if (!reply.ok) return reply.text;
        // باب الشرا (zad_record_purchase_service) مابيعرفش «لمين؟»، فبتتكتب على المعاملة بعده، من الباب برضه.
        const purchaseFor = normalizeForPerson(input.for_person);
        if (purchaseFor && reply.transactionId) {
          const forSet = await commitIntent(sb, userId, scope, name, { input, for_person: purchaseFor }, "money.updated", {
            item_id: reply.transactionId, patch: { for_person: purchaseFor },
          });
          if (!forSet.ok) console.error("[log_transaction] for_person not set:", forSet.reason);
        }
        ctx.mutationCount++;
        ctx.mutations.push({ tool: name, old: null, new: { amount: input.amount, title: input.title, lines: purchaseLines.length } });
        await recordAction(sb, userId, scope, {
          tool: name, input, table: "zad_transactions", targetId: reply.transactionId!,
          previous: null, next: { id: reply.transactionId, amount, title, purchase: bought },
        });
        return reply.text;
      }

      // من الباب (م٢.٥). الباب بيكتب العمودين is_expense وtxn_kind مع بعض دايماً (الكلاينت بيقرا الأول والسيرفر
      // التاني)، و«لمين» على المصروف بس.
      const logged = await commitIntent(sb, userId, scope, name, input, "money.logged", {
        amount: Math.round(input.amount * 100) / 100,
        title: String(input.title).trim().slice(0, 80),
        category: input.category ? String(input.category).trim().slice(0, 40) : null,
        txn_kind: input.txn_kind,
        wallet: input.wallet === "cash" ? "cash" : "card",
        // جت منين (provenance.ts): «receipt» لو اللي نادى قال إنها فاتورة، وإلا القناة.
        source_type: txnSourceType(input.source_type, scope.source),
        // اسم المحل من الفاتورة (تليجرام)، عشان «أرخص هنا» وعادات المحلات يشوفوه.
        merchant_name: input.merchant_name ? String(input.merchant_name).trim().slice(0, 80) || null : null,
        // لمين في البيت (ZAD_PLAN ٥.٣).
        for_person: isExpense ? normalizeForPerson(input.for_person) : null,
        ...(occurredAt ? { created_at: occurredAt } : {}),
      });
      if (!logged.ok) return refusalText(logged.reason);
      if (logged.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { amount: input.amount, title: input.title } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_transactions", targetId: logged.rowId,
        previous: null, next: logged.payload.after ?? { id: logged.rowId },
      });
      return `اتسجلت المعاملة: ${input.title} — ${input.amount}` +
        (occurredAt ? ` بتاريخ ${String(input.occurred_on)} (اتحسبت في شهرها، مش الشهر ده)` : "");
    }
    case "update_transaction": {
      const { data: before } = await sb.from("zad_transactions")
        .select("amount,title,category,txn_kind,for_person").eq("id", input.transaction_id).eq("user_id", userId).maybeSingle();
      if (!before) return "مرفوض: المعاملة مش بتاعت العميل ده — عدّل وحاول تاني.";
      const patch: Record<string, unknown> = {};
      if (input.for_person !== undefined) patch.for_person = normalizeForPerson(input.for_person);
      if (input.amount !== undefined) patch.amount = Math.round(input.amount * 100) / 100;
      if (input.title !== undefined) patch.title = String(input.title).trim().slice(0, 80);
      if (input.category !== undefined) patch.category = String(input.category).trim().slice(0, 40);
      if (input.txn_kind !== undefined) {
        patch.txn_kind = input.txn_kind;
        patch.is_expense = input.txn_kind === "expense";
      }
      // من الباب (م٢.٥). is_expense بيمشي مع النوع هناك.
      delete patch.is_expense;
      const w = await commitIntent(sb, userId, scope, name, input, "money.updated", { item_id: input.transaction_id, patch });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: patch });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_transactions", targetId: input.transaction_id,
        previous: before, next: w.payload.after ?? patch,
      });
      return "اتعدلت المعاملة";
    }
    case "delete_transaction": {
      // الصف كامل: التراجع (zad_agent_undo) بيرجّعه بـjsonb_populate_record، ومن غير user_id كان بيرد
      // ownership_mismatch، فالمعاملة المحذوفة ماكانتش بترجع (ZAD_OR_PLAN م١، ٢٠/١١).
      const { data: before } = await sb.from("zad_transactions")
        .select("*").eq("id", input.transaction_id).eq("user_id", userId).maybeSingle();
      if (!before) return "مرفوض: المعاملة مش بتاعت العميل ده — عدّل وحاول تاني.";
      // من الباب (م٢.٥): الصف كامل في الحدث، وzad_trash بيحفظه للتراجع.
      const gone = await commitIntent(sb, userId, scope, name, input, "money.deleted", { item_id: input.transaction_id });
      if (!gone.ok) return refusalText(gone.reason);
      if (gone.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: null });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_transactions", targetId: input.transaction_id,
        previous: before, next: null,
      });
      return "اتحذفت المعاملة";
    }
    case "set_monthly_limit": {
      // limit_confirmed_at بيتكتب هنا لأن ده فعل مستخدم مباشر بتأكيد صريح — نفس عقد
      // SupabaseRepo.setMonthlyLimit بالظبط. رصيد من غير التاريخ ده بيتقرا "غير مؤكد"
      // وبيخلي شاشة تحديد الرصيد تفضل تطلع فوق رقم موجود فعلاً.
      //
      // العمود اسمه monthly_limit لأسباب تاريخية بس — معناه بقى "الرصيد الابتدائي
      // للدورة" من migration 20260816010000. مش سقف صرف.
      const { data: limitBefore } = await sb.from("zad_users").select("monthly_limit,limit_confirmed_at").eq("id", userId).maybeSingle();
      // من الباب (م٢.٥)، والباب بيكتب limit_confirmed_at معاه.
      const w = await commitIntent(sb, userId, scope, name, input, "money.limit_set", { amount: input.monthly_limit });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: snap.budget ?? null, new: input.monthly_limit });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_users", targetId: userId,
        previous: limitBefore ?? null, next: { monthly_limit: Math.round(input.monthly_limit * 100) / 100 },
      });
      return `اتظبط الرصيد على ${input.monthly_limit}`;
    }
    case "set_category_budget": {
      const category = String(input.category).trim();
      const { data: capBefore } = await sb.from("zad_category_budgets")
        .select("id,category,amount").eq("user_id", userId).eq("category", category).maybeSingle();
      if (input.amount === 0) {
        if (!capBefore) return `مفيش سقف على ${category} أصلاً`;
        // من الباب (م٢.٥): صفر بيشيل السقف.
        const gone = await commitIntent(sb, userId, scope, name, input, "money.category_budget_set", { category, amount: 0 });
        if (!gone.ok) return refusalText(gone.reason);
        if (gone.duplicate) return DUPLICATE_REPLY;
        ctx.mutationCount++;
        ctx.mutations.push({ tool: name, old: capBefore, new: null });
        await recordAction(sb, userId, scope, {
          tool: name, input, table: "zad_category_budgets", targetId: capBefore.id, previous: capBefore, next: null,
        });
        return `اتشال سقف ${category}`;
      }
      const saved = await commitIntent(sb, userId, scope, name, input, "money.category_budget_set", { category, amount: input.amount });
      if (!saved.ok) return refusalText(saved.reason);
      if (saved.duplicate) return DUPLICATE_REPLY;
      const cap = { id: saved.rowId, category, amount: Math.round(input.amount * 100) / 100 };
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: capBefore ?? null, new: cap });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_category_budgets", targetId: saved.rowId, previous: capBefore ?? null, next: cap,
      });
      return `اتحط سقف ${category} على ${input.amount}`;
    }

    default:
      return undefined;
  }
}
