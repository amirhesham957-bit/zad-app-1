// m4.5 pass 3: executeTool case bodies moved verbatim out of index.ts (no behavior change).
import { ownPriceReply, ownPricesFor } from "./ownPurchasePrice.ts";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";
import type { RunContext } from "./validators.ts";
import type { ToolDeps } from "./execDeps.ts";
import { lowStockToAdd } from "./lowStock.ts";
import { categoryForCharge, doseSlotToSnooze, paidRenewal } from "./appByVoice.ts";
import { mealSuggestionsCachePattern } from "../_shared/recipeCache.ts";
import { buildSupportEmail, DEFAULT_SUPPORT_INBOX, sendSupportEmail } from "../zad-support/email.ts";
import { CONFIRM_REQUIRED_TOOLS } from "./validators.ts";
import { localNowContext, matchMedicineByName, normalizeForPerson, entityRecallText } from "./shared.ts";
import { DOSE_SNOOZE_MINUTES, snoozeDose } from "../_shared/doseDoor.ts";
import { webPrice, webPriceReply } from "./webPrice.ts";
import { recordAction, writeRows } from "./audit.ts";
import { commitIntent, DUPLICATE_REPLY, refusalText } from "./commitIntent.ts";
import { type GatheringMeal, gatheringListRows, gatheringPlan } from "./gathering.ts";
import { type ForwardLedger, simulatePurchase } from "./whatIf.ts";
import { loadRestockJudge } from "./restockJudge.ts";
import { medicinePrice, medicinePriceReply, pricePayload } from "./medicinePrice.ts";
import { emergencyCard, emergencyCountry } from "./emergency.ts";
import { newPollMetadata } from "./familyPolls.ts";
import { householdFamilyId, householdFilter } from "../_shared/household.ts";

/** Returns undefined when `name` is not one of this file's tools. */
export async function execStoresPlans(name: string, sb: SupabaseClient, userId: string, input: any, snap: any, ctx: RunContext, scope: AuditScope, deps: ToolDeps): Promise<string | undefined> {
  const { callCoreIntel, addLinesThroughDoor, executeTool, LOCATION_MAX_AGE_MS, MAX_SEARCHES_PER_TURN, HOUSE_SECTIONS_ON_REQUEST } = deps;
  switch (name) {
    case "find_nearby_stores": {
      const { data: prof } = await sb.from("zad_users")
        .select("last_lat,last_lon,last_location_at").eq("id", userId).maybeSingle();
      const p = prof as { last_lat: number | null; last_lon: number | null; last_location_at: string | null } | null;
      if (!p?.last_lat || !p?.last_lon || !p?.last_location_at) {
        return "مفيش موقع محفوظ للعميل — قوله يفعّل «تنبيهات الأماكن» من صفحة البروفايل في التطبيق عشان تعرفي مكانه، ومتخمّنش محل.";
      }
      if (Date.now() - new Date(p.last_location_at).getTime() > LOCATION_MAX_AGE_MS) {
        return "آخر موقع للعميل قديم (أكتر من ١٤ ساعة) — قوله يفتح التطبيق عشان يتحدث، ومتبنيش عليه ترشيح محل.";
      }
      const res = await callCoreIntel("nearby_pois", {
        lat: p.last_lat, lon: p.last_lon,
        tag: input.tag, radius_meters: input.radius_meters ?? 3000,
      }, userId);
      const stores = (res?.stores ?? []) as unknown[];
      if (stores.length === 0) return "مفيش محلات قريبة اتلاقت — متخترعش اسم محل.";
      return JSON.stringify(stores.slice(0, 5));
    }
    case "suggest_product": {
      const { data, error } = await sb.rpc("zad_affiliate_matches", { p_user: userId });
      if (error) return `مقدرتش أجيب الترشيحات: ${error.message}`;
      const rows = (data ?? []) as unknown[];
      if (rows.length === 0) {
        return "مفيش منتج مترشّح مطابق لحاجة محتاجها دلوقتي — متقترحش منتج من عندك.";
      }
      return JSON.stringify(rows.slice(0, 3));
    }
    case "medicine_price": {
      // سعر دوا في بلده (medicinePrice.ts): كاش ٣٠ يوم، وإلا بحث موجّه ببلده وعملته ويتحفظ لو ليه مصدر.
      const name = String(input?.name ?? "").trim().slice(0, 80);
      const { data: u } = await sb.from("zad_users").select("country,currency").eq("id", userId).maybeSingle();
      const me = u as { country?: string | null; currency?: string | null } | null;
      const found = await medicinePrice(sb, {
        name, country: me?.country ?? null, currency: me?.currency ?? null,
        search: (payload) => callCoreIntel("estimate_price", payload, userId),
      }).catch(() => null);
      return medicinePriceReply(found, name);
    }
    case "check_price_online": {
      // ببلد العميل وعملته (pricePayload) — من غيرهم الأسعار بعملة تانية ماكانتش بتتشال.
      const { data: u } = await sb.from("zad_users").select("country,currency").eq("id", userId).maybeSingle();
      const me = u as { country?: string | null; currency?: string | null } | null;
      // الأول: سعر الصنف المسجّل في فواتير العميل نفسه (بنود zad_purchases) — مش بحث نت ولا «التفاصيل مش ظاهرة».
      const wanted = String(input.item_name ?? "").trim();
      if (wanted.length >= 2) {
        const since = new Date(Date.now() - 180 * 86_400_000).toISOString();
        const { data: purchases } = await sb.from("zad_purchases").select("id,lines,created_at,transaction_id")
          .eq("user_id", userId).gte("created_at", since).order("created_at", { ascending: false }).limit(300);
        const rows = (purchases ?? []) as Array<{ lines: unknown; created_at: string; transaction_id: string }>;
        const hit = ownPricesFor(rows, wanted);
        if (hit.length > 0) {
          const ids = rows.filter((r) => ownPricesFor([r], wanted).length > 0).map((r) => r.transaction_id).slice(0, 20);
          const { data: tx } = await sb.from("zad_transactions").select("id,title").in("id", ids);
          const shopById = new Map(((tx ?? []) as Array<{ id: string; title: string | null }>).map((x) => [x.id, x.title]));
          const withShop = rows.map((r) => ({ ...r, shop: shopById.get(r.transaction_id) ?? null }));
          const reply = ownPriceReply(ownPricesFor(withShop, wanted), wanted, me?.currency ?? null);
          if (reply) return reply;
        }
      }
      // بحث موجّه بمصدره، محفوظ ٧ أيام بالبلد والصنف (webPrice.ts، zad_web_prices) — بداية الأسعار قبل الجمهور.
      const found = await webPrice(sb, {
        item: String(input.item_name ?? ""), store: input.store ? String(input.store) : null,
        country: me?.country ?? snap?.country ?? null, currency: me?.currency ?? null,
        search: (payload) => callCoreIntel("estimate_price", payload, userId),
      });
      return webPriceReply(found, String(input.item_name ?? ""));
    }
    case "web_search": {
      // بحث حقيقي عبر نفس بروكسي core-intelligence (DDG server-side). النتايج
      // بترجع بمصادرها — الموديل ملزم يقول المصدر، وpromise-drift هيمسك أي ادعاء.
      // مرتين في الرسالة بالكتير (٢٠٢٦-١٠-٠٢): سؤال واحد عام خد ٧٤ ألف توكن والموديل بيعيد البحث
      // بصيغ تانية. التالتة بتتقاله يجاوب من اللي معاه.
      if ((ctx.counts["web_search"] ?? 0) > MAX_SEARCHES_PER_TURN) {
        return `بحثت مرتين في الرسالة دي. جاوب دلوقتي من النتايج اللي فوق، ولو مافيهاش إجابة قول كده بصراحة وقول اللي تعرفه وإنه من معلوماتك.`;
      }
      const res = await callCoreIntel("web_search", {
        query: input.query ?? "", query_en: input.query_en ?? null, country: snap?.country ?? null,
      }, userId);
      if (!res || res.ok === false) return "مقدرتش أبحث دلوقتي — قول للعميل إن البحث مش متاح مؤقتاً، متختلقش إجابة.";
      const hits = (res as { results?: Array<{ title: string; url: string; snippet: string }> }).results ?? [];
      // اللي اتسأل واللي رجع، لتقرير فحص القبول (مش للموديل): من غير ده «دوّر وغلط» و«ماعرفش يدوّر» شكلهم واحد.
      (ctx.searches ??= []).push({
        query: String(input.query ?? "").slice(0, 120), query_en: input.query_en ? String(input.query_en).slice(0, 120) : null,
        source: String((res as { source?: unknown }).source ?? ""), titles: hits.slice(0, 4).map((h) => String(h.title).slice(0, 80)),
      });
      if (hits.length === 0) {
        // سؤال حي (سعر، خبر النهارده): مفيش رقم من غير مصدر. سؤال ثابت (مين كسب، عاصمة، معلومة):
        // الموديل يعرف كتير — يجاوب ويقول إنها من معلوماته، بدل «مش لاقي» لأسئلة بسيطة.
        return (res as { live?: boolean }).live
          ? "مفيش نتايج بحث للسؤال ده دلوقتي — قول للعميل كده في جملة واحدة، متخترعش رقم، ومتغيّرش الموضوع."
          : "مفيش نتايج من النت دلوقتي. جاوب من معلوماتك لو متأكد، وقول في نفس الجملة إنها من معلوماتك وممكن تكون اتغيّرت. لو مش متأكد قول كده.";
      }
      return JSON.stringify(hits.map((h, i) => `${i + 1}. ${h.title}\n${h.url}\n${h.snippet}`).join("\n\n"));
    }
    case "read_house": {
      const section = String(input.section ?? "");
      if (!HOUSE_SECTIONS_ON_REQUEST.includes(section)) {
        return `مرفوض: الجزء ده مش موجود. الأجزاء: ${HOUSE_SECTIONS_ON_REQUEST.join("، ")}`;
      }
      return JSON.stringify((snap as Record<string, unknown>)?.[section] ?? null).slice(0, 12000);
    }
    case "open_support_ticket": {
      // شكوى لإنسان (٢٠٢٦-١٠-٠١: محادثة الدعم الذكي كانت بترد وبس، وصفر تذاكر اتفتحت من يومها).
      const subject = String(input.subject ?? "").trim().slice(0, 200);
      const message = String(input.message ?? "").trim().slice(0, 8000);
      if (!subject || !message) return "مرفوض: اكتب الموضوع والمشكلة بكلام العميل.";
      const [{ data: who }, { data: turns }] = await Promise.all([
        sb.auth.admin.getUserById(userId),
        sb.from("zad_chat_turns").select("role,text").eq("user_id", userId).order("created_at", { ascending: false }).limit(20),
      ]);
      const contactEmail = who?.user?.email ?? null;
      const conversation = ((turns ?? []) as Array<{ role: string; text: string }>).reverse()
        .map((t) => ({ text: t.text.slice(0, 2000), isUser: t.role === "user" }));
      const { data: row, error } = await sb.from("zad_support_tickets").insert({
        user_id: userId, contact_email: contactEmail, subject, message, conversation, app_version: "agent",
      }).select("id, created_at").single();
      if (error || !row) return `مرفوض: الشكوى ماتحفظتش (${error?.message ?? "?"}) — قول للعميل يجرب زرار «كلّم فريق الدعم».`;
      const emailed = await sendSupportEmail(
        buildSupportEmail({
          id: row.id, userId, contactEmail, subject, message, conversation,
          crashLog: null, appVersion: "agent", device: null, createdAt: row.created_at,
        }),
        Deno.env.get("SUPPORT_INBOX") || DEFAULT_SUPPORT_INBOX,
        Deno.env.get("RESEND_API_KEY"),
        Deno.env.get("SUPPORT_FROM") || "Zad Support <onboarding@resend.dev>",
      );
      if (emailed) await sb.from("zad_support_tickets").update({ emailed_at: new Date().toISOString() }).eq("id", row.id);
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { subject } });
      return contactEmail
        ? `اتفتحت شكوى لفريق الدعم «${subject}»، والرد هيوصل على ${contactEmail}.`
        : `اتفتحت شكوى لفريق الدعم «${subject}». العميل مالوش إيميل في الحساب، فالفريق هيرد عليه جوه التطبيق.`;
    }
    case "gold_price": {
      // سعر الدهب من عناوين أخبار بلد العميل النهارده — رقم مقري بقاعدة، مش من الموديل.
      const res = await callCoreIntel("gold_price", { country: snap?.country ?? null }, userId);
      const quotes = (res?.quotes ?? []) as Array<{ karat: string; price: number; currency: string; source: string; published?: string }>;
      if (!res || quotes.length === 0) {
        return "مالقيتش سعر دهب منشور النهارده في أخبار بلد العميل. نادِ web_search بسؤال «سعر الذهب اليوم» قبل ما تقول إنك مش لاقي.";
      }
      const when = (iso?: string) => iso ? new Date(iso).toLocaleString("ar-EG", { timeZone: snap?.now_local?.time_zone ?? "Africa/Cairo", day: "numeric", month: "long", hour: "numeric", minute: "2-digit" }) : "النهارده";
      const lines = quotes.map((q) => `عيار ${q.karat}: ${q.price.toLocaleString("en-US")} ${q.currency} (المصدر: ${q.source}، ${when(q.published)})`);
      return "سعر الدهب النهارده من الأخبار المنشورة:\n" + lines.join("\n") +
        "\nابدأ ردك بالرقم المطلوب ومصدره ووقته في أول جملة. ده سعر بيع تقريبي من الأخبار، مش سعر محل بعينه.";
    }
    case "family_digest": {
      // الأرقام مجمّعة عن قصد: الأب يشوف "أحمد صرف ٨٠٪ من سقفه"، مش معاملاته واحدة واحدة.
      // ده اللي بيخلي الميزة دي ملخّص عيلة مش أداة مراقبة.
      const { data, error } = await sb.rpc("zad_family_digest", { p_user: userId });
      if (error) return `مقدرتش أقرا ملخّص العيلة: ${error.message}`;
      const d = data as { in_family?: boolean; members?: unknown[] } | null;
      if (!d?.in_family) return "العميل مش منضم لعيلة في التطبيق.";
      return JSON.stringify(d);
    }
    case "weekly_savings_plan": {
      // خطة توفير بأرقام حقيقية: تجميع مصاريف آخر ٢٨ يوم حسب الفئة، ترتيبها،
      // اقتراح خفض ١٥٪ لأكبر ٣ فئات متكررة. الخطة بتتخزن في zad_memory (scope=savings_plan)
      // عشان المتابعة الجاية تقيس الالتزام بالأرقام نفسها — مش كلام عام.
      const followUp = input.follow_up === true;

      if (followUp) {
        const { data: planRows } = await sb.from("zad_memory")
          .select("id,note,confidence,created_at")
          .eq("user_id", userId)
          .eq("scope", "savings_plan")
          .order("created_at", { ascending: false })
          .limit(1);
        const plan = (planRows as Array<{ id: string; note: string; created_at: string }> | null)?.[0];
        if (!plan) return JSON.stringify({ status: "no_previous_plan" });

        // التزام الأسبوع الماضي: مجموع مصاريف الفئات المستهدفة بعد تاريخ الخطة
        const targets = [...plan.note.matchAll(/([^:،]+):\s*خفض\s*(\d+)/g)];
        let spentInTargets = 0;
        for (const [, cat] of targets) {
          const { data: txs } = await sb.from("zad_transactions")
            .select("amount")
            .eq("user_id", userId)
            .eq("category", cat.trim())
            .eq("is_expense", true)
            .gte("created_at", plan.created_at);
          spentInTargets += (txs ?? []).reduce((a, t) => a + Number((t as { amount: number }).amount), 0);
        }
        return JSON.stringify({
          status: "follow_up",
          plan_created_at: plan.created_at,
          plan_summary: plan.note,
          spent_in_target_categories_since_plan: Math.round(spentInTargets * 100) / 100,
          guidance: "قارن المصروف ده بمستهدف الخطة. لو أقل = ملتزم، اشكره وثبّت الخطة. لو أكبر = اسأل عن السبب بدون لوم واقترح تعديل واقعي.",
        });
      }

      // خطة جديدة: تجميع فعلي من المعاملات (٤ أسابيع)، استبعاد الفواتير الثابتة والالتزامات
      const sinceIso = new Date(Date.now() - 28 * 86400000).toISOString();
      const { data: txs, error } = await sb.from("zad_transactions")
        .select("category,amount")
        .eq("user_id", userId)
        .eq("is_expense", true)
        .gte("created_at", sinceIso);
      if (error) return `مقدرتش أقرا مصاريفك: ${error.message}`;

      const FIXED = new Set(["إيجار", "قسط", "فاتورة", "دين", "راتب", "دخل"]);
      const byCategory = new Map<string, number>();
      for (const t of (txs ?? []) as Array<{ category: string | null; amount: number }>) {
        const cat = (t.category ?? "").trim();
        if (!cat || FIXED.has(cat)) continue;
        byCategory.set(cat, (byCategory.get(cat) ?? 0) + Number(t.amount));
      }
      const ranked = [...byCategory.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3);
      if (ranked.length === 0) {
        return JSON.stringify({ status: "insufficient_data", message: "مفيش مصاريف كفاية في آخر ٤ أسابيع لبناء خطة." });
      }

      const currency = snap.currency ?? "";
      const proposals = ranked.map(([cat, total4w]) => {
        const weekly = total4w / 4;
        const cut = Math.round(weekly * 0.15); // خفض ١٥٪ — واقعي مش مبالغ فيه
        return `${cat}: خفض ${cut} ${currency} أسبوعياً (من ${Math.round(weekly)} إلى ${Math.round(weekly - cut)})`;
      });
      const totalWeeklyCut = ranked.reduce((a, [c, t]) => a + Math.round(t / 4 * 0.15), 0);

      // تخزين الخطة عشان المتابعة الأسبوعية تقيس ضدها
      const planNote = `خطة توفير: ${proposals.join("، ")}`;
      await sb.rpc("zad_memory_upsert", {
        p_user: userId, p_scope: "savings_plan", p_note: planNote, p_conf: 0.8,
      });

      return JSON.stringify({
        status: "plan_created",
        period: "آخر ٤ أسابيع",
        top_categories: ranked.map(([cat, total]) => ({ category: cat, spent_4weeks: Math.round(total), weekly_avg: Math.round(total / 4) })),
        proposals,
        total_weekly_cut: totalWeeklyCut,
        monthly_projection: totalWeeklyCut * 4,
        guidance: "اعرض الخطة على العميل بالأرقام دي بالظبط واسأله موافق ولا عايز يعدل فئة. متقولش إنها اتسجلت كالتزام قبل ما يقول موافق.",
      });
    }
    case "forward_ledger": {
      // Deterministic: this is a SQL projection, not an estimate. The point of the tool is
      // that the model stops doing arithmetic on the snapshot in its head — every number
      // below came from zad_forward_ledger walking the next N days one at a time.
      const days = Number(input?.days);
      // «لو اشتريت…» (whatIf.ts): نفس التوقّع، والمبلغ بيتطرح من يوم الشراء لقدام. المدى أطول شوية
      // عشان التزام آخر الدورة يبان.
      const spend = Number(input?.hypothetical_spend);
      const whatIf = Number.isFinite(spend) && spend > 0;
      const horizon = Number.isFinite(days) && days >= 1 ? Math.min(Math.trunc(days), 120) : whatIf ? 45 : 30;
      const { data: ledger, error } = await sb.rpc("zad_forward_ledger", {
        // Same timezone the cycle boundaries were resolved in — projecting in UTC while
        // the app renders in Africa/Cairo is how a day-edge event lands on the wrong day.
        p_user: userId, p_days: horizon, p_tz: snap?.cycle?.timezone ?? "UTC",
      });
      if (error) return `مقدرتش أحسب التوقّع دلوقتي: ${error.message}`;
      if (!ledger) return "مفيش بيانات كفاية أحسب منها توقّع للأيام الجاية.";
      if (!whatIf) return JSON.stringify(ledger);
      const onDate = typeof input?.on_date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(input.on_date) ? input.on_date : null;
      const simulated = simulatePurchase(ledger as ForwardLedger, spend, onDate);
      if (!simulated) return `مقدرتش أحسب الشراء ده: التاريخ ${onDate ?? ""} برّه مدى التوقّع (${horizon} يوم).`;
      return JSON.stringify({ what_if: { ...simulated, label: typeof input?.label === "string" ? input.label.slice(0, 60) : null }, ledger });
    }
    case "start_family_poll": {
      // تصويت عيلة من زاد (familyPolls.ts): بيتحط في شات العيلة باسم زاد، والعيلة كلها بيوصلها إشعار.
      const { data: me } = await sb.from("family_members").select("family_id").eq("user_id", userId).maybeSingle();
      const familyId = (me as { family_id?: string } | null)?.family_id;
      if (!familyId) return "العميل مش في عيلة على زاد — التصويت للعيلات بس. ممكن يعمل عيلة من «عيلتي».";
      const meta = newPollMetadata(input);
      if (!meta) return "مرفوض: التصويت محتاج سؤال (لحد ٢٠٠ حرف) ومن ٢ لـ٦ اختيارات مختلفة (كل واحد لحد ٦٠ حرف).";
      const { error } = await sb.from("chat_messages").insert({
        family_id: familyId, sender_id: "zad_ai", message: `📊 ${meta.question}`,
        message_type: "POLL", metadata: JSON.stringify(meta),
      });
      if (error) return `مقدرتش أبعت التصويت: ${error.message}`;
      ctx.mutationCount++;
      return `اتبعت في شات العيلة: «${meta.question}» (${meta.options.join(" / ")}) — بيتقفل ${meta.closes_at.slice(0, 16).replace("T", " ")} UTC وزاد هيعلن النتيجة.`;
    }
    case "emergency_card": {
      // كارت الطوارئ (emergency.ts): كله قراية من بيانات العميل نفسه — مفيش تشخيص ولا دوا مقترح.
      const person = input?.for_person ? normalizeForPerson(input.for_person) : null;
      const now = Date.now();
      const [meds, doses, appts, family, user, notes] = await Promise.all([
        sb.from("zad_pharmacy_items").select("id,name,dosage,dose_times,remaining_quantity,for_person").eq("user_id", userId),
        sb.from("zad_pharmacy_doses").select("item_id,taken_at,status").eq("user_id", userId)
          .gte("taken_at", new Date(now - 86_400_000).toISOString()),
        sb.from("zad_appointments").select("title,starts_at,kind,for_person").eq("user_id", userId)
          .gte("starts_at", new Date(now - 30 * 86_400_000).toISOString())
          .lte("starts_at", new Date(now + 30 * 86_400_000).toISOString()).order("starts_at", { ascending: true }),
        (async () => {
          const { data: me } = await sb.from("family_members").select("family_id").eq("user_id", userId).maybeSingle();
          if (!(me as { family_id?: string } | null)?.family_id) return [];
          const { data } = await sb.from("family_members").select("alias,role,user_id").eq("family_id", (me as { family_id: string }).family_id);
          return ((data ?? []) as Array<{ alias: string | null; role: string | null; user_id: string | null }>)
            .map((m) => ({ alias: m.alias, role: m.role, is_me: m.user_id === userId }));
        })().catch(() => []),
        sb.from("zad_users").select("country,travel_country,travel_since").eq("id", userId).maybeSingle(),
        person
          ? sb.rpc("zad_memory_recall_entities", { p_user: userId, p_text: entityRecallText(person), p_limit: 5 })
            .then((r) => (r.error ? [] : ((r.data ?? []) as Array<{ note: string }>).map((n) => n.note)), () => [])
          : Promise.resolve([] as string[]),
      ]);
      if (meds.error) return `مقدرتش أجيب الأدوية دلوقتي: ${meds.error.message} — المهم دلوقتي الإسعاف.`;
      return JSON.stringify(emergencyCard({
        person,
        // ٣.١٤: مسافر ⇒ إسعاف البلد اللي هو فيه.
        country: emergencyCountry(user.data as { country?: string | null; travel_country?: string | null; travel_since?: string | null } | null, now),
        medicines: (meds.data ?? []) as Parameters<typeof emergencyCard>[0]["medicines"],
        doses: (doses.data ?? []) as Parameters<typeof emergencyCard>[0]["doses"],
        appointments: (appts.data ?? []) as Parameters<typeof emergencyCard>[0]["appointments"],
        notes, family, now,
      }));
    }
    case "plan_gathering":
    case "add_gathering_to_list": {
      // نمط العزومة (gathering.ts، الشريحة ٣٥): كميات بالفرد، اللي في البيت، ووضع الفلوس — من غير إجمالي مخترع.
      const meal: GatheringMeal = input?.meal === "sweets" ? "sweets" : "meal";
      const timeZone = snap?.cycle?.timezone ?? "UTC";
      // اللي في البيت = مخزن البيت وقايمته، مش بتاع الفرد.
      const householdFamily = await householdFamilyId(sb, userId);
      const [pantry, shopping, user, state, challenge, broke] = await Promise.all([
        sb.from("zad_inventory").select("item_name,quantity,unit").or(householdFilter(userId, householdFamily)).limit(300),
        sb.from("zad_shopping_list").select("item_name").or(householdFilter(userId, householdFamily)).eq("is_purchased", false).limit(100),
        sb.from("zad_users").select("country,currency").eq("id", userId).maybeSingle(),
        sb.rpc("zad_budget_state", { p_user: userId, p_tz: timeZone }),
        sb.from("zad_savings_challenges").select("id").eq("user_id", userId).eq("status", "active").limit(1),
        sb.from("zad_broke_mode").select("ends_at,ended_at").eq("user_id", userId).maybeSingle(),
      ]);
      const u = user.data as { country?: string | null; currency?: string | null } | null;
      const b = broke.data as { ends_at?: string | null; ended_at?: string | null } | null;
      const plan = gatheringPlan({
        people: Number(input.people), meal, country: u?.country ?? null,
        pantry: (pantry.data ?? []) as Array<{ item_name: string; quantity: number | null; unit: string | null }>,
        shopping: ((shopping.data ?? []) as Array<{ item_name: string }>).map((s) => s.item_name),
        available: (state.data as { available?: number | null } | null)?.available ?? null,
        currency: u?.currency ?? null,
        budget: input.budget === undefined || input.budget === null ? null : Number(input.budget),
        savingAgreement: (challenge.data ?? []).length > 0 ||
          Boolean(b && !b.ended_at && b.ends_at && Date.parse(b.ends_at) > Date.now()),
      });
      if (name === "plan_gathering") return JSON.stringify(plan);
      const rows = gatheringListRows(plan, Array.isArray(input.skip) ? input.skip.map(String) : []);
      if (rows.length === 0) return "مفيش حاجة تتضاف — كل سطور العزومة في القايمة أو العميل قال عنده منها.";
      const put = await addLinesThroughDoor(sb, userId, scope, name, input, rows);
      if (put.added.length === 0) return put.refusal ?? DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { rows: put.added.length } });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_shopping_list", targetId: null, previous: null, next: put.added });
      return `اتضاف لقايمة التسوق: ${put.added.map((r) => r.item_name).join("، ")}`;
    }
    case "set_sleep_window": {
      // إيقاع النوم يدوي (الشريحة ٣٧): نفس قواعد zad_set_sleep_window — اليدوي بيكسب المتعلّم، و«امسح» يرجّع ١١–٧.
      if (input?.clear === true) {
        // من الباب (م٢.٥).
        const w = await commitIntent(sb, userId, scope, name, input, "settings.sleep_cleared", {});
        if (!w.ok) return refusalText(w.reason);
        if (w.duplicate) return DUPLICATE_REPLY;
        ctx.mutationCount++;
        return "اتمسحت مواعيد النوم — زاد هيسكت من ١١ بالليل لـ٧ الصبح، ولو التعلّم من قفل الشاشة شغال هيتعلّمها تاني.";
      }
      const bed = String(input.bed), wake = String(input.wake);
      const w = await commitIntent(sb, userId, scope, name, input, "settings.sleep_set", { bed, wake });
      if (!w.ok) return refusalText(w.reason);
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: snap?.sleep ?? null, new: { bed, wake } });
      return `تمام — زاد مش هيبعت تنبيهات مش ضرورية من ${bed} لـ${wake} (الجرعات والطوارئ زي ما هي).`;
    }
    case "mark_subscription_paid": {
      // ZAD_PLAN ١٠.٢(أ): زرار «دفعت» بالكلام — مصروف + التجديد الجاي (appByVoice.ts = markPaid في التطبيق).
      // فلوس ⇒ في CONFIRM_REQUIRED_TOOLS: مابيوصلش هنا غير بعد «أيوه» (agent_confirm).
      const spoken = String(input.title ?? "").trim();
      const { data: subs } = await sb.from("zad_subscriptions")
        .select("id,title,amount,renewal_date,due_day,billing_cycle,category,type,is_active")
        .eq("user_id", userId).eq("is_active", true);
      const rows = (subs ?? []) as Array<{ id: string; title: string; amount: number; renewal_date: string | null; due_day: number | null; billing_cycle: string | null; category: string | null; type: string | null }>;
      const b = spoken.toLowerCase();
      const hits = rows.filter((r) => { const a = r.title.trim().toLowerCase(); return a.includes(b) || b.includes(a); });
      if (hits.length > 1) return `مرفوض: "${spoken}" بيطابق أكتر من اشتراك (${hits.map((h) => h.title).join("، ")}) — اسأله أنهي واحد.`;
      const sub = hits[0];
      if (!sub) return `مرفوض: مفيش اشتراك شغال اسمه "${spoken}". المسجّل: ${rows.map((r) => r.title).join("، ") || "ولا حاجة"}.`;
      const amount = Number(input.amount ?? sub.amount);
      if (!(amount > 0)) return "مرفوض: الاشتراك مالوش مبلغ — اسأله دفع كام وابعته في amount.";
      const today = snap?.now_local?.date ?? new Date().toISOString().slice(0, 10);
      const paid = paidRenewal(sub, today);
      // الدفعة الأول: لو اترفضت (تكرار في ١٠ دقايق) التجديد مايتحركش.
      const logged = await executeTool(sb, userId, "log_transaction", {
        amount, title: sub.title, category: categoryForCharge(sub), txn_kind: "expense",
        ...(input.allow_duplicate === true ? { allow_duplicate: true } : {}),
      }, snap, ctx, scope);
      if (logged.startsWith("مرفوض")) return logged;
      const patch: Record<string, unknown> = { title: paid.title };
      if (paid.next) { patch.renewal_date = paid.next; patch.due_day = Number(paid.next.slice(8, 10)); }
      if (!paid.stillRunning) patch.is_active = false;
      const w = await commitIntent(sb, userId, scope, name, input, "subscription.updated", { item_id: sub.id, patch });
      if (!w.ok) return `الدفعة اتسجلت بس التجديد ماتحركش: ${refusalText(w.reason)}`;
      if (w.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: sub, new: w.payload.after });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_subscriptions", targetId: sub.id, previous: sub, next: w.payload.after });
      return `اتسجلت دفعة "${sub.title}" (${amount})` +
        (paid.stillRunning ? (paid.next ? `، والتجديد الجاي ${paid.next}` : "") : "، ودي كانت آخر قسط — الاشتراك اتقفل");
    }
    case "add_shortages_to_shopping": {
      // ZAD_PLAN ١٠.٢(أ): زرار النواقص بالكلام — نفس حساب الحلم بالليل (lowStockToAdd + restockJudge + اللي على فترات).
      const family = await householdFamilyId(sb, userId);
      const [{ data: pantry }, { data: openShop }, { data: occasional }] = await Promise.all([
        sb.from("zad_inventory").select("item_name, quantity, low_stock_threshold, category, restock_mode, restock_cycle_days, created_at").or(householdFilter(userId, family)),
        sb.from("zad_shopping_list").select("item_name").or(householdFilter(userId, family)).eq("is_purchased", false),
        sb.rpc("zad_occasional_items", { p_user: userId }),
      ]);
      const isDue = await loadRestockJudge(sb, userId, family);
      const toAdd = lowStockToAdd(pantry, (openShop ?? []).map((r: { item_name: string | null }) => r.item_name),
        Array.isArray(occasional) ? (occasional as string[]) : [], isDue);
      if (toAdd.length === 0) return "status=nothing — مفيش نواقص مش على القايمة.";
      // من الباب (م٢.٥)، سطر سطر: السطر المرفوض بيتسجل سببه هناك والباقي بيكمل.
      const put = await addLinesThroughDoor(sb, userId, scope, name, input, toAdd.map((item_name) => ({ item_name, quantity: 1 })));
      if (put.added.length === 0) return put.refusal ?? DUPLICATE_REPLY;
      const items = put.added.map((r) => r.item_name);
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { items } });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_shopping_list", targetId: null, previous: null, next: { items } });
      return `status=added items=${items.join("، ")}`;
    }
    case "snooze_pharmacy_dose": {
      // ZAD_PLAN ١٠.٢(أ): «فكّرني بعدين» بالكلام. الكتابة من doseDoor.ts بس (one_writer_test).
      const spoken = String(input.name ?? "").trim();
      const { data: items } = await sb.from("zad_pharmacy_items").select("id,name,dose_times").eq("user_id", userId);
      const rows = (items ?? []) as Array<{ id: string; name: string; dose_times: string | null }>;
      const { item, ambiguous } = matchMedicineByName(rows, spoken);
      if (ambiguous) return `مرفوض: "${spoken}" بيطابق أكتر من دوا (${ambiguous.join("، ")}) — اسأله أنهي واحد.`;
      if (!item) return `مرفوض: مفيش دوا اسمه "${spoken}". المسجّل: ${rows.map((r) => r.name).join("، ") || "ولا حاجة"}.`;
      const now = localNowContext(snap?.cycle?.timezone ?? "UTC");
      const slot = doseSlotToSnooze(item.dose_times, now, input.dose_time ? String(input.dose_time) : null);
      if (!slot) return `مرفوض: مفيش جرعة ${item.name} قريبة تتأجل (مواعيده: ${item.dose_times || "مش متسجلة"}) — اسأله أنهي ميعاد.`;
      const minutes = Number(input.minutes ?? DOSE_SNOOZE_MINUTES);
      const r = await snoozeDose(sb, userId, item.id, slot, minutes, scope);
      if (!r.ok) return r.refusal ?? `مرفوض: ${r.reason}`;
      if (r.duplicate) return DUPLICATE_REPLY;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { item: item.name, scheduled_at: slot, until: r.until } });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_dose_snoozes", targetId: item.id, previous: null, next: { scheduled_at: slot, snooze_until: r.until } });
      return `status=snoozed — تذكير ${item.name} هيسكت ${minutes} دقيقة ويرن تاني.`;
    }
    case "report_price": {
      // ZAD_PLAN ١٠.٢(أ): «ساهم بسعر» بالكلام — نفس RPC التطبيق بس بنسخة السيرفر (p_user)، والتحقق كله جوه SQL.
      const city = String(input.city ?? snap?.customer?.city ?? "").trim() || null;
      const { data, error } = await sb.rpc("zad_report_price_for", {
        p_user: userId, p_report: crypto.randomUUID(), p_item: String(input.item).trim(), p_price: Number(input.price),
        p_currency: snap?.currency ?? null, p_location: city, p_store: input.store ? String(input.store).trim() : null, p_category: null,
      });
      if (error) return `مرفوض: ${error.message}`;
      const res = (data ?? {}) as { ok?: boolean; reason?: string; duplicate?: boolean };
      if (res.ok !== true) return `مرفوض: ${res.reason ?? "البلاغ ما اتسجلش"}`;
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { item: input.item, price: input.price, store: input.store ?? null } });
      return res.duplicate ? "status=duplicate — البلاغ ده متسجّل قبل كده." : "status=saved — السعر دخل أسعار الجمهور، شكراً ليه.";
    }
    case "clear_place_visits": {
      // ZAD_PLAN ١٠.٢(أ): «مسح الزيارات» من شاشة الذاكرة بالكلام — صفوفه هو بس.
      const { data, error } = await sb.from("zad_place_visits").delete().eq("user_id", userId).select("id");
      if (error) return `مرفوض: ${error.message}`;
      const n = (data ?? []).length;
      if (n === 0) return "status=nothing — مفيش أماكن متسجلة أصلاً.";
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: { visits: n }, new: { visits: 0 } });
      await recordAction(sb, userId, scope, { tool: name, input, table: "zad_place_visits", targetId: null, previous: { visits: n }, next: null });
      return `status=deleted visits=${n}`;
    }
    case "rate_recipe": {
      // ZAD_PLAN ١٠.٢(أ): 👍/👎 بالكلام — نفس rate_recipe في zad-core-intelligence، والكاش بنفس المفتاح (_shared/recipeCache.ts).
      const recipeName = String(input.recipe_name ?? "").trim().slice(0, 120);
      const w = await writeRows(
        sb.from("zad_recipe_feedback").upsert({ user_id: userId, recipe_name: recipeName, liked: input.liked === true }, { onConflict: "user_id,recipe_name" }).select("id"),
        "حفظ رأيه في الوصفة",
      );
      if (!w.ok) return `مرفوض: ${w.reason}`;
      const { error: cacheErr } = await sb.from("ai_response_cache").delete()
        .eq("action", "meal_suggestions").like("cache_key", mealSuggestionsCachePattern(userId));
      if (cacheErr) console.error("[rate_recipe] cache invalidation failed:", cacheErr.message);
      ctx.mutationCount++;
      ctx.mutations.push({ tool: name, old: null, new: { recipe_name: recipeName, liked: input.liked === true } });
      return input.liked === true ? `status=saved — «${recipeName}» عجبه.` : `status=saved — «${recipeName}» مش هتتقترح تاني.`;
    }

    default:
      return undefined;
  }
}
