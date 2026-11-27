// m4.5 pass 3: executeTool case bodies moved verbatim out of index.ts (no behavior change).
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";
import type { RunContext } from "./validators.ts";
import type { ToolDeps } from "./execDeps.ts";
import { medicineHolder, memberNoticeNames, tellMemberMedicineAdded } from "./familyMedicine.ts";
import { normalizeDoseTimes, matchMedicineByName, normalizeForPerson, pharmacyIsRecurring } from "./shared.ts";
import { pickPantryMatch, type PantryRow } from "./pantryMatch.ts";
import { consumeReply, matchConsumeRow, openedNote, openedOnlyReply, openOnly, quantityAfter, usedInRowUnits, type ConsumeRow } from "./consumeItem.ts";
import { recordAction } from "./audit.ts";
import { commitIntent, DUPLICATE_REPLY, refusalText } from "./commitIntent.ts";
import { isServiceLine } from "./serviceLine.ts";
import { pushToDevice, pushToTelegram } from "./push.ts";
import { inventoryOwnerFilter, pickInventoryRow } from "./inventoryRow.ts";
import { householdFamilyId, householdFilter } from "../_shared/household.ts";
import { proactiveTurn, recordConversation } from "../_shared/conversationLog.ts";
import { pharmacyUnit } from "./pharmacyUnit.ts";

/** Returns undefined when `name` is not one of this file's tools. */
export async function execInventoryPharmacy(name: string, sb: SupabaseClient, userId: string, input: any, snap: any, ctx: RunContext, scope: AuditScope, deps: ToolDeps): Promise<string | undefined> {
  const { householdName, tickBoughtLine } = deps;
  switch (name) {
    case "consume_item": {
      // «شربنا ٣ مية» (خطة المخزن الواعي ٢، consumeItem.ts): طرح من مخزن البيت + قراية للتعلّم.
      const said = String(input.item_name ?? "").trim();
      const houseFamily = await householdFamilyId(sb, userId);
      const { data: house, error: houseErr } = await sb.from("zad_inventory")
        .select("id,user_id,item_name,quantity,unit,created_at")
        .or(householdFilter(userId, houseFamily)).limit(500);
      if (houseErr) return `مرفوض: معرفتش أقرا المخزون (${houseErr.message})`;
      const rows = (house ?? []) as Array<ConsumeRow & { user_id: string }>;
      const match = matchConsumeRow(rows.filter((r) => r.user_id === userId), said) ?? matchConsumeRow(rows, said);
      if (!match) return `مرفوض: «${said}» مش في مخزون البيت — اسأل العميل لو عايز يضيفه.`;
      if ("ambiguous" in match) {
        return `مرفوض: «${said}» ممكن يكون: ${match.ambiguous.join("، ")} — اسأل العميل أنهي واحد ونادي تاني بالاسم.`;
      }
      const row = match.row;
      const before = Math.max(0, Number(row.quantity) || 0);
      if (before <= 0) return `«${row.item_name}» متسجل خلصان أصلاً — مفيش حاجة تتطرح.`;
      // «فتحنا علبة لبن» (خطة المخزن ٣، 20261114220000): عمرها بعد الفتح بيتحسب في التريجر من اسمها.
      const opened = input.opened === true;
      // قرار المالك ١٤/١١: العلبة المفتوحة لسه في التلاجة وبتتعد — الفتح لوحده مابينقصش العدد. الموديل كان بيبعت
      // amount 1 لـ«فتحنا علبة لبن»، فلو الرسالة فتح من غير فعل استعمال الكمية صفر مهما بعت.
      const used = opened && openOnly(ctx.said) ? 0 : usedInRowUnits(Number(input.amount) || 0, input.unit, row.item_name);
      // الطرح نفسه في الباب (م٢.٥): بيقف عند صفر على الكمية المقفولة وقت الكتابة، مش على اللي اتقرت فوق.
      const done = await commitIntent(sb, userId, scope, name, input, "inventory.consumed", {
        item_id: row.id, amount: used, ...(opened ? { opened: true } : {}),
      });
      if (!done.ok) return refusalText(done.reason);
      if (done.duplicate) return DUPLICATE_REPLY;
      const after = done.after ?? quantityAfter(before, used);
      // عمر العلبة بعد الفتح بيتحسب في التريجر، فبيتقري بعد الكتابة.
      const { data: written } = await sb.from("zad_inventory").select("id,quantity,opened_at,opened_life_days")
        .eq("id", row.id).maybeSingle();
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: { item: row.item_name, qty: after } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_inventory", targetId: row.id,
        previous: { quantity: row.quantity }, next: written ?? { id: row.id, quantity: after },
      });
      // المعدل متربط بصاحب الصف (نفس add_inventory_item)، فالقراية باسمه حتى لو اللي استهلك فرد تاني.
      // فتح من غير استعمال مش قراية جديدة.
      const { data: obs, error: obsErr } = used <= 0 ? { data: null, error: null } : await sb.rpc("zad_record_observation", {
        p_user: row.user_id ?? userId, p_item: row.item_name, p_qty: after, p_source: "chat_consume",
      });
      if (obsErr) {
        console.error("zad_record_observation failed:", obsErr.message);
      } else {
        ctx.observations.push({
          item: row.item_name, qty: after,
          samples: (obs as any)?.samples ?? 0, rateKnown: (obs as any)?.rate_known === true,
        });
      }
      const lifeRaw = Number((written as { opened_life_days?: number | null } | null)?.opened_life_days);
      const life = Number.isFinite(lifeRaw) && lifeRaw > 0 ? lifeRaw : null;
      if (opened && used <= 0) return openedOnlyReply(row.item_name, row.unit, after, life);
      const reply = consumeReply(row.item_name, row.unit, before, after, input.dish ? String(input.dish).trim() : null);
      return opened ? `${reply}${openedNote(row.item_name, life)}` : reply;
    }
    case "add_inventory_item": {
      const itemName = await householdName(sb, userId, String(input.item_name).trim());
      const unit = input.unit ? String(input.unit).trim() : null;
      // نفس الصنف موجود في مخزن البيت؟ يتزوّد بدل صف تاني جنبه («بلح» مرتين، pantryMatch.ts).
      // صف العميل نفسه الأول، وبعده صف العيلة: «اشتريت لبن» من الأب بيزوّد لبن البيت اللي
      // الأم ضافته، مش صف لبن تاني باسمه. «تراجع» بيعرف البيت (20261011160000).
      const houseFamily = await householdFamilyId(sb, userId);
      const { data: own, error: ownErr } = await sb.from("zad_inventory")
        .select("id,user_id,item_name,quantity,unit,category,expiry_date,created_at")
        .or(householdFilter(userId, houseFamily)).limit(500);
      if (ownErr) console.error("[add_inventory_item] pantry lookup failed:", ownErr.message);
      type HouseRow = PantryRow & { user_id: string; category: string | null; expiry_date: string | null };
      const houseRows = (own ?? []) as HouseRow[];
      const existing = pickPantryMatch(houseRows.filter((r) => r.user_id === userId), itemName, unit) ??
        pickPantryMatch(houseRows, itemName, unit);
      if (existing) {
        const previous = { quantity: existing.quantity, category: existing.category, expiry_date: existing.expiry_date };
        // التزويد من الباب (م٢.٥): inventory.added على نفس الصف بـitem_id، والجمع على الكمية المقفولة وقت الكتابة.
        const merged = await commitIntent(sb, userId, scope, name, input, "inventory.added", {
          item_id: existing.id, item_name: existing.item_name, quantity: Number(input.quantity),
          category: input.category ? String(input.category).trim() : null,
          ...(input.expiry_date ? { expiry_date: input.expiry_date } : {}),
        });
        if (!merged.ok) return refusalText(merged.reason);
        if (merged.duplicate) return DUPLICATE_REPLY;
        const total = merged.after ?? Math.max(existing.quantity ?? 0, 0) + Number(input.quantity);
        ctx.mutationCount++;
        ctx.mutations.push({ tool: name, old: existing.quantity, new: { item: existing.item_name, qty: total } });
        await recordAction(sb, userId, scope, {
          tool: name, input, table: "zad_inventory", targetId: existing.id,
          previous, next: {
            id: existing.id, item_name: existing.item_name, quantity: total,
            category: existing.category ?? (input.category ? String(input.category).trim() : null),
            expiry_date: input.expiry_date ?? existing.expiry_date,
          },
        });
        // معدل الاستهلاك متربط بصاحب الصف (zad_consumption.user_id = zad_inventory.user_id في
        // «هيخلص إمتى؟»)، فالملاحظة باسم صاحب الصف حتى لو اللي اشترى فرد تاني.
        const { error: obsErr } = await sb.rpc("zad_record_observation", {
          p_user: existing.user_id ?? userId, p_item: existing.item_name, p_qty: total, p_source: "chat_add",
        });
        if (obsErr) console.error("zad_record_observation failed:", obsErr.message);
        const tickedMerge = await tickBoughtLine(sb, userId, houseFamily, existing.item_name, scope);
        return `"${existing.item_name}" كان موجود في المخزون — زوّدته ${input.quantity}، بقى ${total}${existing.unit ? ` ${existing.unit}` : ""}` +
          (tickedMerge ? ` — واتشطب "${tickedMerge}" من قايمة التسوق` : "");
      }
      // صف جديد من الباب (م٢.٥).
      const added = await commitIntent(sb, userId, scope, name, input, "inventory.added", {
        item_name: itemName, quantity: input.quantity, unit: unit ?? "حبة",
        category: input.category ? String(input.category).trim() : null,
        ...(input.expiry_date ? { expiry_date: input.expiry_date } : {}),
      });
      if (!added.ok) return refusalText(added.reason);
      if (added.duplicate) return DUPLICATE_REPLY;
      const newRow = { id: added.rowId, item_name: itemName, quantity: added.after ?? input.quantity };
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { item: itemName, qty: input.quantity } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_inventory", targetId: newRow.id,
        previous: null, next: newRow,
      });
      const tickedNew = await tickBoughtLine(sb, userId, houseFamily, itemName, scope);
      const tickedNote = tickedNew ? ` — واتشطب "${tickedNew}" من قايمة التسوق` : "";
      // نفس السبب اللي في update_inventory_qty بالظبط: أي كمية معروفة هي بيانات تعلّم
      // مجانية لمعدل الاستهلاك، والتسجيل هنا غير مشروط مش أداة منفصلة الموديل ممكن
      // ينساها.
      const { data: obs, error: obsErr } = await sb.rpc("zad_record_observation", {
        p_user: userId, p_item: itemName, p_qty: input.quantity, p_source: "chat_add",
      });
      if (obsErr) {
        console.error("zad_record_observation failed:", obsErr.message);
        return `اتضاف "${itemName}" (${input.quantity}) للمخزون${tickedNote}`;
      }
      ctx.observations.push({
        item: itemName, qty: input.quantity,
        samples: (obs as any)?.samples ?? 0, rateKnown: (obs as any)?.rate_known === true,
      });
      return `اتضاف "${itemName}" (${input.quantity}) للمخزون${tickedNote}`;
    }
    case "delete_inventory_item": {
      const itemName = String(input.item_name).trim();
      // Task 30 — نفس منطق update_inventory_qty: المطابقة بـfamily_id لو العميل في
      // عيلة، عشان يقدر يحذف صنف عضو تاني ضافه من المخزون المشترك.
      const { data: fam } = await sb.from("family_members").select("family_id").eq("user_id", userId).maybeSingle();
      const familyId = (fam as { family_id: string } | null)?.family_id ?? null;
      const { data: candidates } = await sb.from("zad_inventory").select("*")
        .eq("item_name", itemName).or(inventoryOwnerFilter(userId, familyId));
      const before = pickInventoryRow(candidates as any[], userId, familyId);
      if (!before) return `مرفوض: مفيش صنف اسمه "${itemName}" في المخزون.`;
      // من الباب (م٢.٥): الحدث شايل الصف كامل، وتريجر zad_trash بيحفظه للتراجع.
      const gone = await commitIntent(sb, userId, scope, name, input, "inventory.deleted", { item_id: before.id });
      if (!gone.ok) return refusalText(gone.reason);
      if (gone.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: null });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_inventory", targetId: before.id, previous: before, next: null });
      return `اتحذف "${itemName}" من المخزون`;
    }
    case "add_pharmacy_item": {
      const medName = String(input.name).trim();
      // سطر فاتورة مش دوا (serviceLine.ts): «توصيل منزلي داخل 600» اتسجل دوا عند المالك ٢٨/١٠.
      if (isServiceLine(medName)) {
        return `مرفوض: «${medName.slice(0, 60)}» سطر رسوم أو توصيل أو حساب في الفاتورة، مش دوا — ماتسجلوش، وماتسألش عن ميعاده.`;
      }
      const doseTimes = normalizeDoseTimes(input.dose_times, input.daily_dose_count, input.times_explicit);

      // Idempotent by (user, medicine name). On 2026-08-15 this account held six pharmacy
      // rows for two medicines — "اجمانتين" and "سبروفار" written three times each inside
      // six minutes (01:24:24, 01:24:50, 01:27:01, 01:30:23), matching the exact minutes
      // the Telegram bot was answering "تعذر تنفيذ الطلب". The turn failed, so the
      // customer retried, and each retry inserted the medicine again. That is not just an
      // untidy list: duplicate rows mean duplicate dose alarms, which is why the phone
      // showed "موعد الدواء" for اجمانتين twice in the same notification shade.
      //
      // Re-adding a medicine the customer already has is a correction, not a second
      // medicine. Fill in whatever the new call knows and leave the rest alone.
      // نفس الدوا لشخصين (ليا ولماما) دوايين مش تكرار — المفتاح الاسم + لمين.
      // «لماما» وماما فرد في العيلة وموافقة على المتابعة ⇒ صيدليتها هي (familyMedicine.ts، قرار المالك ١٣/١١).
      const holder = await medicineHolder(sb, userId, input);
      if ("refused" in holder) return `مرفوض: ${holder.refused}`;
      const medOwner = holder.ownerId;
      const forPerson = holder.forPerson;
      const forMember = holder.memberName ? ` في صيدلية ${holder.memberName}` : "";
      const { data: existingMeds } = await sb.from("zad_pharmacy_items")
        .select("id,name,dosage,dose_times,remaining_quantity,for_person")
        .eq("user_id", medOwner);
      const dupe = (existingMeds ?? []).find(
        (row: { name: string; for_person: string | null }) =>
          row.name.trim().toLowerCase() === medName.toLowerCase() &&
          // Rows saved before names were unified («أمي») still match «ماما».
          (normalizeForPerson(row.for_person) ?? "").toLowerCase() === (forPerson ?? "").toLowerCase(),
      ) as { id: string; dosage: string | null; dose_times: string | null } | undefined;

      if (dupe) {
        const patch: Record<string, unknown> = {};
        if (doseTimes && doseTimes !== dupe.dose_times) patch.dose_times = doseTimes;
        if (input.dosage && !dupe.dosage) patch.dosage = String(input.dosage).trim();
        if (input.quantity != null) patch.remaining_quantity = input.quantity;
        if (typeof input.is_recurring === "boolean") patch.is_recurring = input.is_recurring;
        if (Object.keys(patch).length > 0) {
          // من الباب (م٢.٥): الصف ممكن يكون في صيدلية فرد موافق، والباب بيتأكد من الموافقة بنفسه.
          const u = await commitIntent(sb, userId, scope, name, input, "pharmacy.updated", { item_id: dupe.id, patch });
          if (!u.ok) return refusalText(u.reason);
          if (u.duplicate) return DUPLICATE_REPLY;
          const next = { id: dupe.id, name: medName, dose_times: (u.payload.after as { dose_times?: string | null } | undefined)?.dose_times ?? null };
          ctx.mutationCount++;
          ctx.mutations.push({ tool: name, old: dupe, new: next });
          await recordAction(sb, userId, scope, {
            tool: name, input, table: "zad_pharmacy_items", targetId: dupe.id,
            previous: dupe, next,
          });
          return `"${medName}" كان مسجل أصلاً${forMember || " عندك"} — حدّثت بياناته بدل ما أضيفه تاني`;
        }
        return `"${medName}" مسجل خلاص بنفس البيانات${forMember || " عندك"} — مضفتش نسخة تانية`;
      }

      const normalizedUnit = pharmacyUnit(input.unit);

      // من الباب (م٢.٥). العدد في اليوم بيتحسب في الباب من المواعيد لو موجودة، مش من عدّ الموديل: الاتنين كانوا
      // ممكن يختلفوا (٣ مواعيد وdaily_dose_count 2)، وكل «يكفي كام يوم» على التلفون بيقسم على الرقم ده.
      const recurring = pharmacyIsRecurring(input);
      const made = await commitIntent(sb, userId, scope, name, input, "pharmacy.added", {
        owner_id: medOwner,
        name: medName,
        dosage: input.dosage ? String(input.dosage).trim() : null,
        daily_dose_count: input.daily_dose_count ?? 1,
        dose_times: doseTimes,
        unit: normalizedUnit,
        remaining_quantity: input.quantity ?? 1,
        category: input.category ?? "عام",
        for_person: forPerson,
        ...(recurring == null ? {} : { is_recurring: recurring }),
      });
      if (!made.ok) return refusalText(made.reason);
      if (made.duplicate) return DUPLICATE_REPLY;
      const newRow = { id: made.rowId, name: medName, dose_times: doseTimes };
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { name: medName, dose_times: doseTimes } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_pharmacy_items", targetId: newRow.id,
        previous: null, next: newRow,
      });
      // مفيش AlarmManager على السيرفر — المنبهات بتتفعّل لما التطبيق يعمل sync ويلاقي
      // الدواء الجديد (نفس آلية PharmacyReminderScheduler).
      if (holder.memberName) {
        const notice = memberNoticeNames(input.member_notice, medName);
        if (notice) {
          if (notice.names.length === 1 && notice.names[0] === medName && !doseTimes) notice.untimed.push(medName);
          await tellMemberMedicineAdded(sb, medOwner, userId, notice.names, notice.untimed, {
            recordConversation, proactiveTurn,
            pushToTelegram: (u, t, b) => pushToTelegram(u, t, b),
            pushToDevice: (c, u, t, b) => pushToDevice(c, u, t, b),
          });
        }
        return `اتسجل "${medName}"${forMember} — التذكير هيروح لـ${holder.memberName}، ولو جرعة فاتت هبلغك.` +
          (doseTimes ? ` المواعيد: ${doseTimes}.` : notice ? ` مواعيده لسه — سألت ${holder.memberName} عليها.` : "");
      }
      return doseTimes
        ? `اتسجل "${medName}" — المواعيد: ${doseTimes}. التذكير هيشتغل بعد أول فتح للتطبيق.`
        : `اتسجل "${medName}" في الصيدلية`;
    }
    case "update_pharmacy_item": {
      const spoken = String(input.name).trim().toLowerCase();
      const { data: items } = await sb.from("zad_pharmacy_items").select("*").eq("user_id", userId);
      const before = (items ?? []).find((row: any) => row.name.trim().toLowerCase().includes(spoken) || spoken.includes(row.name.trim().toLowerCase()));
      if (!before) return `مرفوض: مفيش دواء اسمه "${input.name}" في قايمة العميل.`;
      const patch: Record<string, unknown> = {};
      if (input.dosage !== undefined) patch.dosage = String(input.dosage).trim();
      if (input.remaining_quantity !== undefined) patch.remaining_quantity = input.remaining_quantity;
      if (typeof input.is_recurring === "boolean") patch.is_recurring = input.is_recurring;
      if (input.dose_times !== undefined) {
        const normalized = normalizeDoseTimes(input.dose_times, input.daily_dose_count, input.times_explicit);
        if (normalized === null) return `مرفوض: مواعيد الجرعات مش مفهومة — لازم تكون بصيغة HH:MM مفصولة بفاصلة.`;
        patch.dose_times = normalized;
        patch.daily_dose_count = normalized.split(",").length;
      } else if (input.daily_dose_count !== undefined) {
        patch.daily_dose_count = input.daily_dose_count;
      }
      // من الباب (م٢.٥). العدد من المواعيد بيتحسب هناك، فمابيتبعتش معاها.
      if (patch.dose_times !== undefined) delete patch.daily_dose_count;
      const u = await commitIntent(sb, userId, scope, name, input, "pharmacy.updated", { item_id: before.id, patch });
      if (!u.ok) return refusalText(u.reason);
      if (u.duplicate) return DUPLICATE_REPLY;
      const next = (u.payload.after ?? { id: before.id, ...patch }) as Record<string, unknown>;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: next });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_pharmacy_items", targetId: before.id, previous: before, next });
      return `اتعدلت بيانات "${before.name}" ومواعيد التذكير هتتحدث بعد مزامنة التطبيق`;
    }
    case "complete_shopping_item": {
      const itemName = await householdName(sb, userId, String(input.item_name).trim());
      // قايمة البيت: الصنف ممكن يكون الفرد التاني ضافه. لو الاسم متكرر (كل واحد ضافه)، صف العميل
      // الأول — نفس اختيار المخزن (inventoryRow.ts). maybeSingle على اسم متكرر كان بيرجّع «مش موجود».
      const familyId = await householdFamilyId(sb, userId);
      const { data: open } = await sb.from("zad_shopping_list").select("*").or(householdFilter(userId, familyId)).eq("item_name", itemName).eq("is_purchased", false);
      const before = pickInventoryRow(open as any[], userId, familyId);
      if (!before) return `مرفوض: "${itemName}" مش موجود في قائمة التسوق المفتوحة.`;
      const ticked = await commitIntent(sb, userId, scope, name, input, "shopping.completed", { item_id: before.id });
      if (!ticked.ok) return refusalText(ticked.reason);
      if (ticked.duplicate) return DUPLICATE_REPLY;
      const after = { id: before.id, is_purchased: true };
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: after });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_shopping_list", targetId: before.id, previous: before, next: after });
      return `اتشطب "${itemName}" من قائمة التسوق`;
    }
    case "delete_shopping_item": {
      const itemName = await householdName(sb, userId, String(input.item_name).trim());
      const familyId = await householdFamilyId(sb, userId);
      const { data: rows } = await sb.from("zad_shopping_list").select("*").or(householdFilter(userId, familyId)).eq("item_name", itemName);
      const before = pickInventoryRow(rows as any[], userId, familyId);
      if (!before) return `مرفوض: "${itemName}" مش موجود في قائمة التسوق.`;
      // من الباب (م٢.٥): الحدث شايل الصف كامل، وتريجر zad_trash بيحفظه للتراجع.
      const gone = await commitIntent(sb, userId, scope, name, input, "shopping.deleted", { item_id: before.id });
      if (!gone.ok) return refusalText(gone.reason);
      if (gone.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: before, new: null });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_shopping_list", targetId: before.id, previous: before, next: null });
      return `اتحذف "${itemName}" من قائمة التسوق`;
    }
    case "set_market": {
      // من الباب (م٢.٥).
      const w = await commitIntent(sb, userId, scope, name, input, "settings.market_set", { currency: input.currency, country: input.country });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: { currency: snap.currency, country: snap.country }, new: { currency: input.currency, country: input.country } });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_users", targetId: userId,
        previous: { currency: snap.currency, country: snap.country }, next: { currency: input.currency, country: input.country },
      });
      return `اتسجل: البلد ${input.country} والعملة ${input.currency}`;
    }
    case "log_pharmacy_dose": {
      // مكافئ pharmacy_dose في بروتوكول [[ACTION]] القديم، ومرآة
      // ZadCentralBrain.markPharmacyDoseTaken على الكلاينت: سجّل الجرعة، نقّص المتبقي،
      // ولو قرّب يخلص حطه في قائمة التسوق. من غير الأداة دي كان "خدت حبة الضغط" في
      // الشات يرجع كلام بس، لأن مسار الوكيل بيسبق البروتوكول القديم ومابيقعش عليه.
      const spoken = String(input.name ?? "").trim();
      const { data: items } = await sb.from("zad_pharmacy_items")
        .select("id,name,remaining_quantity,unit,daily_dose_count").eq("user_id", userId);
      const rows = (items ?? []) as Array<{ id: string; name: string; remaining_quantity: number; unit: string | null; daily_dose_count: number | null }>;
      // مطابقة صارمة: دوا واحد واضح أو مفيش. تسجيل الجرعة على الدوا الغلط غلط طبي،
      // فالتخمين ممنوع — والرد بيسمّي الأدوية المسجّلة فعلاً عشان الموديل يردّ من
      // الجدول مش من خياله (matchMedicineByName في shared.ts).
      const { item: match, ambiguous } = matchMedicineByName(rows, spoken);
      if (ambiguous) {
        return `مرفوض: "${spoken}" بيطابق أكتر من دوا (${ambiguous.join("، ")}) — اسأل العميل يحدد أنهي واحد بالاسم كامل قبل ما تسجّل.`;
      }
      if (!match) {
        const registered = rows.map((r) => r.name).join("، ");
        return rows.length === 0
          ? `مرفوض: مفيش أي دوا مسجّل في جدول العميل. قوله بالنص: "مفيش دواء مسجل بالاسم ده في جدولك" واعرض عليه يضيفه (add_pharmacy_item). ممنوع تخترع اسم دوا أو جرعة.`
          : `مرفوض: مفيش دواء اسمه "${spoken}" في جدول العميل. الأدوية المسجّلة: ${registered}. قوله "مفيش دواء مسجل بالاسم ده في جدولك" واعرض عليه الأسماء دي بالظبط — ممنوع تخترع اسم.`;
      }

      // من الباب (م٢.٥)، والباب بينادي zad_log_pharmacy_dose_atomic (الكاتب الوحيد للجرعات، one_writer_test).
      const dose = await commitIntent(sb, userId, scope, name, input, "pharmacy.dose_taken", {
        item_id: match.id, taken_at: new Date().toISOString(),
      });
      if (!dose.ok) {
        if (dose.reason === "dose_already_logged") return "الجرعة دي متسجلة قبل كده — الكمية ماتخصمتش تاني";
        console.error("pharmacy.dose_taken refused:", dose.reason);
        return dose.reason.startsWith("rpc:") ? "مرفوض: مقدرتش أسجل الجرعة بأمان — الكمية ماتغيرتش" : refusalText(dose.reason);
      }
      if (dose.duplicate) return "الجرعة دي متسجلة قبل كده — الكمية ماتخصمتش تاني";
      const mutation = { dose_id: dose.payload.dose_id, shopping_added: dose.payload.shopping_added === true };

      const newQty = Number(dose.after ?? match.remaining_quantity ?? 0);
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: match.remaining_quantity, new: newQty });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_pharmacy_items", targetId: match.id,
        previous: { remaining_quantity: match.remaining_quantity },
        next: { remaining_quantity: newQty, dose_id: mutation.dose_id },
      });

      if (mutation.shopping_added === true) {
        return `اتسجلت الجرعة — فاضل ${newQty} ${match.unit ?? ""} بس، فحطيت "${match.name}" في قائمة التسوق`;
      }
      return `اتسجلت جرعة ${match.name} — فاضل ${newQty} ${match.unit ?? ""}`;
    }
    case "delete_pharmacy_item": {
      // W7 — نفس مسار DeletePharmacyItemUseCase على الكلاينت (نفس الجدول، نفس شرط
      // الملكية). البحث بالاسم مش id لنفس سبب log_pharmacy_dose فوق — الـ snapshot
      // مايدّيش الموديل أي id لأدوية الصيدلية.
      const spoken = String(input.name ?? "").trim();
      const { data: items } = await sb.from("zad_pharmacy_items").select("*").eq("user_id", userId);
      const rows = (items ?? []) as Array<{ id: string; name: string }>;
      // نفس المطابقة الصارمة بتاعة log_pharmacy_dose. كانت «جزء من الاسم في أي اتجاه، وأول
      // واحد»: «مضاد» كانت بتمسح «مضاد حيوي» والعميل عنده «مضاد للالتهاب» كمان.
      const { item: match, ambiguous } = matchMedicineByName(rows, spoken);
      if (ambiguous) {
        return `مرفوض: "${spoken}" بيطابق أكتر من دوا (${ambiguous.join("، ")}) — اسأل العميل أنهي واحد بالاسم كامل قبل ما تحذف.`;
      }
      if (!match) {
        return rows.length === 0
          ? `مرفوض: مفيش أي دوا مسجّل في جدول العميل — مفيش حاجة تتحذف. ماتقولش إنك حذفت.`
          : `مرفوض: مفيش دواء اسمه "${spoken}" في جدول العميل. الأدوية المسجّلة: ${rows.map((r) => r.name).join("، ")}. لو قصده واحد منهم نادي تاني بالاسم ده بالظبط، ولو مش واضح اسأله — وماتقولش إنك حذفت.`;
      }
      // من الباب (م٢.٥): الحدث شايل الصف كامل، وتريجر zad_trash بيحفظه للتراجع.
      const gone = await commitIntent(sb, userId, scope, name, input, "pharmacy.deleted", { item_id: match.id });
      if (!gone.ok) return refusalText(gone.reason);
      if (gone.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: match, new: null });
      await recordAction(sb, userId, scope, {
        tool: name, input, table: "zad_pharmacy_items", targetId: match.id,
        previous: match, next: null,
      });
      return `اتحذف "${match.name}" من قايمة الصيدلية`;
    }

    default:
      return undefined;
  }
}
