// m4.5 pass 3: executeTool case bodies moved verbatim out of index.ts (no behavior change).
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";
import type { RunContext } from "./validators.ts";
import type { ToolDeps } from "./execDeps.ts";
import { recordAction } from "./audit.ts";
import { commitIntent, DUPLICATE_REPLY, refusalText } from "./commitIntent.ts";
import { type DocumentKind, documentName, KIND_NAMES } from "./documents.ts";

/** Returns undefined when `name` is not one of this file's tools. */
export async function execRecords(name: string, sb: SupabaseClient, userId: string, input: any, snap: any, ctx: RunContext, scope: AuditScope, deps: ToolDeps): Promise<string | undefined> {
  switch (name) {
    case "add_subscription": {
      const title = String(input.title).trim();
      // من الباب (م٢.٥): القيود في SQL، والحدث والصف مع بعض.
      const w = await commitIntent(sb, userId, scope, name, input, "subscription.added", {
        title,
        amount: Math.round(input.amount * 100) / 100,
        renewal_date: input.renewal_date ?? null,
        category: input.category ? String(input.category).trim() : null,
        billing_cycle: input.billing_cycle ?? "MONTHLY",
      });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      const newRow = w.payload.after as any;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { title, amount: input.amount } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_subscriptions", targetId: newRow.id,
        previous: null, next: newRow,
      });
      return `اتضاف اشتراك "${title}"`;
    }
    case "update_subscription": {
      // نفس مبدأ delete_pharmacy_item — البحث بالاسم مش id، الـ snapshot مايدّيش الموديل
      // أي id للاشتراكات.
      const spoken = String(input.title ?? "").trim();
      const { data: subs } = await sb.from("zad_subscriptions").select("*").eq("user_id", userId).eq("is_active", true);
      const rows = (subs ?? []) as Array<{ id: string; title: string; amount: number; renewal_date: string | null }>;
      const match = rows.find((r) => {
        const a = r.title.trim().toLowerCase();
        const b = spoken.toLowerCase();
        return a.includes(b) || b.includes(a);
      });
      if (!match) return `مرفوض: مفيش اشتراك اسمه "${spoken}" عند العميل — عدّل وحاول تاني.`;
      const patch: Record<string, unknown> = {};
      if (input.new_amount !== undefined) patch.amount = Math.round(input.new_amount * 100) / 100;
      if (input.new_renewal_date !== undefined) patch.renewal_date = input.new_renewal_date;
      if (input.is_active !== undefined) patch.is_active = input.is_active;
      if (Object.keys(patch).length === 0) return "مرفوض: مفيش حاجة تتعدل — حدد المبلغ أو تاريخ التجديد أو التفعيل.";
      const w = await commitIntent(sb, userId, scope, name, input, "subscription.updated", { item_id: match.id, patch });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: match, new: patch });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_subscriptions", targetId: match.id,
        previous: match, next: w.payload.after,
      });
      return `اتعدل اشتراك "${match.title}"`;
    }
    case "delete_subscription": {
      const spoken = String(input.title ?? "").trim();
      const { data: subs } = await sb.from("zad_subscriptions").select("*").eq("user_id", userId);
      const rows = (subs ?? []) as Array<{ id: string; title: string }>;
      const match = rows.find((r) => {
        const a = r.title.trim().toLowerCase();
        const b = spoken.toLowerCase();
        return a.includes(b) || b.includes(a);
      });
      if (!match) return `مرفوض: مفيش اشتراك اسمه "${spoken}" عند العميل — عدّل وحاول تاني.`;
      const w = await commitIntent(sb, userId, scope, name, input, "subscription.deleted", { item_id: match.id });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: match, new: null });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_subscriptions", targetId: match.id,
        previous: match, next: null,
      });
      return `اتحذف اشتراك "${match.title}"`;
    }
    case "add_debt": {
      const debtName = String(input.name).trim();
      const w = await commitIntent(sb, userId, scope, name, input, "debt.added", {
        name: debtName,
        remaining_balance: input.remaining_balance,
        minimum_payment: input.minimum_payment ?? 0,
        interest_rate: input.interest_rate ?? 0,
        due_day: input.due_day ?? null,
      });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      const newRow = w.payload.after as any;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { name: debtName, remaining_balance: input.remaining_balance } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_debts", targetId: newRow.id,
        previous: null, next: newRow,
      });
      return `اتضاف دين "${debtName}"`;
    }
    case "update_debt": {
      const spoken = String(input.name ?? "").trim();
      const { data: debts } = await sb.from("zad_debts").select("*").eq("user_id", userId).eq("is_active", true);
      const rows = (debts ?? []) as Array<{ id: string; name: string; remaining_balance: number; minimum_payment: number }>;
      const match = rows.find((r) => {
        const a = r.name.trim().toLowerCase();
        const b = spoken.toLowerCase();
        return a.includes(b) || b.includes(a);
      });
      if (!match) return `مرفوض: مفيش دين اسمه "${spoken}" عند العميل — عدّل وحاول تاني.`;
      const patch: Record<string, unknown> = {};
      if (input.new_remaining_balance !== undefined) patch.remaining_balance = input.new_remaining_balance;
      if (input.new_minimum_payment !== undefined) patch.minimum_payment = input.new_minimum_payment;
      if (Object.keys(patch).length === 0) return "مرفوض: مفيش حاجة تتعدل — حدد الرصيد المتبقي أو الحد الأدنى الشهري.";
      // رصيد صفر يبقى الدين خلص — يتقفل تلقائي بدل ما يفضل معلّق نشط برصيد صفر.
      if ((patch.remaining_balance as number | undefined) === 0) patch.is_active = false;
      const w = await commitIntent(sb, userId, scope, name, input, "debt.updated", { item_id: match.id, patch });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: match, new: patch });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_debts", targetId: match.id,
        previous: match, next: w.payload.after,
      });
      return patch.is_active === false ? `تمام، دين "${match.name}" خلص وقُفل` : `اتعدل دين "${match.name}"`;
    }
    case "delete_debt": {
      const spoken = String(input.name ?? "").trim();
      const { data: debts } = await sb.from("zad_debts").select("*").eq("user_id", userId);
      const rows = (debts ?? []) as Array<{ id: string; name: string }>;
      const match = rows.find((r) => {
        const a = r.name.trim().toLowerCase();
        const b = spoken.toLowerCase();
        return a.includes(b) || b.includes(a);
      });
      if (!match) return `مرفوض: مفيش دين اسمه "${spoken}" عند العميل — عدّل وحاول تاني.`;
      const w = await commitIntent(sb, userId, scope, name, input, "debt.deleted", { item_id: match.id });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: match, new: null });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_debts", targetId: match.id,
        previous: match, next: null,
      });
      return `اتحذف دين "${match.name}"`;
    }
    case "add_obligation": {
      const title = String(input.title).trim();
      const provider = ["تابي", "تمارة", "فاليو"].includes(String(input.provider ?? "").trim())
        ? String(input.provider).trim()
        : null;
      const totalInstallments = provider && Number.isFinite(input.total_installments) && input.total_installments > 0
        ? Math.round(input.total_installments)
        : null;
      const w = await commitIntent(sb, userId, scope, name, input, "obligation.added", {
        title,
        amount: Math.round(input.amount * 100) / 100,
        kind: input.kind,
        recurrence: input.recurrence ?? "monthly",
        due_day: input.due_day ?? null,
        auto_detected: false,
        confirmed: true,
        provider,
        total_installments: totalInstallments,
      });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      const newRow = w.payload.after as any;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { title, amount: input.amount, kind: input.kind } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_obligations", targetId: newRow.id,
        previous: null, next: newRow,
      });
      return `اتضاف الالتزام "${title}" — هيتحسب في "المتاح" من دلوقتي`;
    }
    case "update_obligation": {
      const spoken = String(input.title ?? "").trim();
      const { data: obligs } = await sb.from("zad_obligations").select("*").eq("user_id", userId).eq("active", true);
      const rows = (obligs ?? []) as Array<{ id: string; title: string; amount: number; due_day: number | null }>;
      const match = rows.find((r) => {
        const a = r.title.trim().toLowerCase();
        const b = spoken.toLowerCase();
        return a.includes(b) || b.includes(a);
      });
      if (!match) return `مرفوض: مفيش التزام اسمه "${spoken}" عند العميل — عدّل وحاول تاني.`;
      const patch: Record<string, unknown> = {};
      if (input.new_amount !== undefined) patch.amount = Math.round(input.new_amount * 100) / 100;
      if (input.new_due_day !== undefined) patch.due_day = input.new_due_day;
      if (Object.keys(patch).length === 0) return "مرفوض: مفيش حاجة تتعدل — حدد المبلغ أو يوم الاستحقاق.";
      const w = await commitIntent(sb, userId, scope, name, input, "obligation.updated", { item_id: match.id, patch });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: match, new: patch });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_obligations", targetId: match.id,
        previous: match, next: w.payload.after,
      });
      return `اتعدل الالتزام "${match.title}"`;
    }
    case "delete_obligation": {
      const spoken = String(input.title ?? "").trim();
      const { data: obligs } = await sb.from("zad_obligations").select("*").eq("user_id", userId).eq("active", true);
      const rows = (obligs ?? []) as Array<{ id: string; title: string }>;
      const match = rows.find((r) => {
        const a = r.title.trim().toLowerCase();
        const b = spoken.toLowerCase();
        return a.includes(b) || b.includes(a);
      });
      if (!match) return `مرفوض: مفيش التزام اسمه "${spoken}" عند العميل — عدّل وحاول تاني.`;
      const w = await commitIntent(sb, userId, scope, name, input, "obligation.deactivated", { item_id: match.id });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: match, new: null });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_obligations", targetId: match.id,
        previous: match, next: null,
      });
      return `اتلغى الالتزام "${match.title}"`;
    }
    case "add_maintenance_item": {
      const itemName = String(input.name).trim();
      // من الباب (م٢.٥).
      const w = await commitIntent(sb, userId, scope, name, input, "maintenance.added", {
        name: itemName,
        category: input.category ? String(input.category).trim() : "عام",
        warranty_expiry_date: input.warranty_expiry_date ?? null,
        service_interval_days: input.service_interval_days ?? null,
        estimated_cost: input.estimated_cost ?? 0,
      });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      const newRow = { id: w.rowId, name: itemName };
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { name: itemName } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_maintenance_items", targetId: newRow.id,
        previous: null, next: newRow,
      });
      return `اتضاف "${itemName}" لمتابعة الصيانة`;
    }
    case "update_maintenance_item": {
      const spoken = String(input.name ?? "").trim();
      const { data: items } = await sb.from("zad_maintenance_items").select("*").eq("user_id", userId);
      const rows = (items ?? []) as Array<{ id: string; name: string }>;
      const match = rows.find((r) => {
        const a = r.name.trim().toLowerCase();
        const b = spoken.toLowerCase();
        return a.includes(b) || b.includes(a);
      });
      if (!match) return `مرفوض: مفيش جهاز اسمه "${spoken}" عند العميل — عدّل وحاول تاني.`;
      const patch: Record<string, unknown> = {};
      if (input.last_service_date !== undefined) patch.last_service_date = input.last_service_date;
      if (input.warranty_expiry_date !== undefined) patch.warranty_expiry_date = input.warranty_expiry_date;
      if (Object.keys(patch).length === 0) return "مرفوض: مفيش حاجة تتعدل — حدد تاريخ آخر صيانة أو تاريخ انتهاء الضمان.";
      const w = await commitIntent(sb, userId, scope, name, input, "maintenance.updated", { item_id: match.id, patch });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: match, new: patch });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_maintenance_items", targetId: match.id,
        previous: match, next: { id: match.id, name: match.name },
      });
      return `اتعدل "${match.name}"`;
    }
    case "delete_maintenance_item": {
      const spoken = String(input.name ?? "").trim();
      const { data: items } = await sb.from("zad_maintenance_items").select("*").eq("user_id", userId);
      const rows = (items ?? []) as Array<{ id: string; name: string }>;
      const match = rows.find((r) => {
        const a = r.name.trim().toLowerCase();
        const b = spoken.toLowerCase();
        return a.includes(b) || b.includes(a);
      });
      if (!match) return `مرفوض: مفيش جهاز اسمه "${spoken}" عند العميل — عدّل وحاول تاني.`;
      const w = await commitIntent(sb, userId, scope, name, input, "maintenance.deleted", { item_id: match.id });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: match, new: null });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_maintenance_items", targetId: match.id,
        previous: match, next: null,
      });
      return `اتحذف "${match.name}" من متابعة الصيانة`;
    }
    case "save_document": {
      // حارس المستندات (الشريحة ٣٢): صف واحد لكل (نوع، صاحب، اسم) — التجديد بيعدّل التاريخ.
      const row = {
        user_id: userId,
        kind: String(input.kind) as DocumentKind,
        holder: String(input.holder ?? "").trim(),
        label: String(input.label ?? "").trim(),
        expires_on: String(input.expires_on),
      };
      // من الباب (م٢.٥): الصف القديم (لو موجود) بيرجع في before، والحفظ تاني بيعدّل التاريخ.
      const w = await commitIntent(sb, userId, scope, name, input, "document.saved", {
        kind: row.kind, holder: row.holder, label: row.label, expires_on: row.expires_on,
      });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      const before = (w.payload.before ?? null) as Record<string, unknown> | null;
      const saved = (w.payload.after ?? { id: w.rowId, ...row }) as any;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before ?? null, new: { kind: row.kind, expires_on: row.expires_on } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_documents", targetId: saved.id,
        previous: before ?? null, next: saved,
      });
      return `${before ? "اتعدّل" : "اتسجّل"} ${documentName(row)} — بينتهي ${row.expires_on}. زاد هيفكّر قبلها.`;
    }
    case "delete_document": {
      const kind = String(input.kind) as DocumentKind;
      const holder = String(input.holder ?? "").trim();
      const label = String(input.label ?? "").trim();
      const { data: rows } = await sb.from("zad_documents").select("*").eq("user_id", userId).eq("kind", kind);
      const all = (rows ?? []) as Array<{ id: string; kind: DocumentKind; holder: string; label: string; expires_on: string }>;
      // الاسم بالظبط الأول؛ لو مستند واحد بس من النوع ده ومفيش اسم اتقال، هو المقصود.
      const match = all.find((r) => r.holder === holder && (kind !== "other" || r.label === label)) ??
        (!holder && !label && all.length === 1 ? all[0] : undefined);
      if (!match) {
        return `مرفوض: مش لاقي ${KIND_NAMES[kind]}${holder ? ` بتاع «${holder}»` : ""}. ` +
          (all.length ? `المسجّل: ${all.map((r) => documentName(r)).join("، ")} — اسأل العميل يقصد أنهي.` : "مفيش منه حاجة متسجلة.");
      }
      const w = await commitIntent(sb, userId, scope, name, input, "document.deleted", { item_id: match.id });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: match, new: null });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_documents", targetId: match.id,
        previous: match, next: null,
      });
      return `اتشال ${documentName(match)} من متابعة المستندات`;
    }

    default:
      return undefined;
  }
}
