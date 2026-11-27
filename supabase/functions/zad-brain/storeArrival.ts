// Store/restaurant arrival handling (m4.5 pass3b), moved verbatim from index.ts.
import { isBrokeModeActive } from "../_shared/brokeMode.ts";
import { householdFamilyId, householdFilter } from "../_shared/household.ts";
import { type SavingsAgreement, savingsAgreementFrom } from "../_shared/savingsAgreement.ts";
import { MODEL_ROUTINE, momentChannels } from "./brainConsts.ts";
import { callModel } from "./callModel.ts";
import { CORS_HEADERS } from "./corsHeaders.ts";
import { homeMap } from "./crowdFloor.ts";
import { medicineLow } from "./medicineStock.ts";
import { pushToDevice, pushToTelegram } from "./push.ts";
import { loadRestockJudge } from "./restockJudge.ts";
import { type CheaperHere, type SeenHere, type StoreCategory, buildRestaurantArrivalMessage, buildStoreArrivalMessage, cheaperHereItems, itemKey, localNowContext, normalizeStoreCategory, placeReminderDedupeKey, placesMatchingArrival, sanitizeItemHints, sanitizeStoreName, seenHereItems, storeArrivalBlock, storeArrivalDescription } from "./shared.ts";
import { itemsForStore, storeArrivalTask } from "./storeFit.ts";
import { type StoredDealRow, dealCountry, dealsAtPlace, dealsHere } from "./tasteDeals.ts";
import { processVoiceMoments } from "./voiceMoments.ts";
import { SupabaseClient } from "jsr:@supabase/supabase-js@2";

/**
 * مرحلة ٢ بند ٣ — العميل دخل نطاق سوبرماركت/مول/صيدلية (GeofenceBroadcastReceiver).
 *
 * قبل كده الجهاز كان بيبعت `geofence_enter` لمسار التحليل: نداء موديل كامل، ورده بيرجع في
 * الـHTTP response والتطبيق بيتجاهله — لا تليجرام ولا رؤية، يعني تكلفة من غير أي أثر. هنا
 * القايمة بتتبني من البيانات مباشرة (من غير موديل) وبتتبعت تليجرام فورًا بأزرار الرفض.
 *
 * الهوية من الـJWT بس (زي agent_turn)، والحراسات: الكتم في zad_memory، ومحل واحد كل
 * STORE_ARRIVAL_SAME_STORE_HOURS ساعة، وSTORE_ARRIVAL_DAILY_CAP رسايل في اليوم. كل رسالة
 * بتتسجّل صف agent_tasks (kind=store_arrival, status=done) — للمراقبة، ولأن أزرار الرفض
 * محتاجة معرّف مهمة.
 */
export async function handleStoreArrival(sb: SupabaseClient, userId: string, body: any): Promise<Response> {
  const json = (payload: Record<string, unknown>, status = 200) =>
    new Response(JSON.stringify(payload), { status, headers: CORS_HEADERS });

  const category = normalizeStoreCategory(body?.category);
  const storeName = sanitizeStoreName(body?.store_name);
  if (!category || !storeName) return json({ ok: false, error: "bad_request" }, 400);

  const nowIso = new Date().toISOString();
  const { data: mutes, error: muteErr } = await sb.from("zad_memory")
    .select("suppress_until").eq("user_id", userId).eq("subject_kind", "store_arrival").gt("suppress_until", nowIso);
  if (muteErr) console.error("[store_arrival] mute lookup failed:", muteErr.message);
  const muted = (mutes ?? []).length > 0;

  if (category === "restaurant") return await restaurantArrival(sb, userId, storeName, muted, body, nowIso, json);

  // تحذير «متفقين نوفّر» في السوبرماركت/المول بس (الدوا مش هدر)، ومش لو العميل كتم رسايل المحلات.
  const agreement = category === "pharmacy" || muted ? null : await loadSavingsAgreement(sb, userId);

  // تذكيرات المكان قبل الكتم وحارس المحل/اليوم: العميل هو اللي طلبها بالاسم، فكتم «رسايل
  // المحلات» مايخفيهاش. الـUPDATE بيرجّع الصفوف اللي حوّلها بس — حدثين ورا بعض مايكرروش.
  // لو فيه تذكيرات والتحذير مستحق، التحذير بيدخل جوه نفس الفويس بدل فويسين ورا بعض.
  const reminderStatus = await firePlaceReminders(sb, userId, category, storeName, agreement);

  if (muted) return json({ ok: true, sent: false, reason: "muted", reminders: reminderStatus });

  const { data: recent, error: recentErr } = await sb.from("agent_tasks")
    .select("created_at,task_description")
    .eq("user_id", userId).eq("kind", "store_arrival")
    .gte("created_at", new Date(Date.now() - 24 * 3_600_000).toISOString());
  if (recentErr) console.error("[store_arrival] recent lookup failed:", recentErr.message);
  const blocked = storeArrivalBlock((recent ?? []) as Array<{ created_at: string; task_description: string }>, storeName, Date.now());
  if (blocked) return json({ ok: true, sent: false, reason: blocked, reminders: reminderStatus });

  let shopping: string[] = [];
  let lowStock: string[] = [];
  let clientHints = sanitizeItemHints(body?.client_items);
  if (category === "pharmacy") {
    const { data: meds, error } = await sb.from("zad_pharmacy_items")
      .select("name,remaining_quantity,daily_dose_count,units_per_dose").eq("user_id", userId);
    if (error) console.error("[store_arrival] pharmacy lookup failed:", error.message);
    // نفس عتبة ملخص البيت (_agent_home_weekly_digest_for_user): ٥ أيام، بس بالوحدات (medicineStock.ts، م٣.٤).
    lowStock = ((meds ?? []) as Array<{ name: string; remaining_quantity: number | null; daily_dose_count: number | null; units_per_dose: number | null }>)
      .filter((m) => medicineLow(m))
      .map((m) => m.name);
  } else {
    // قايمة البيت: اللي الفرد التاني ضافه مطلوب من اللي واقف في المحل كمان.
    const { data: list, error: listErr } = await sb.from("zad_shopping_list")
      .select("item_name").or(householdFilter(userId, await householdFamilyId(sb, userId)))
      .eq("is_purchased", false).limit(50);
    if (listErr) console.error("[store_arrival] shopping lookup failed:", listErr.message);
    shopping = ((list ?? []) as Array<{ item_name: string }>).map((r) => r.item_name);

    // المخزون موحّد مع العيلة (Task 30): الناقص عند العيلة ناقص عند العميل كمان.
    const { data: memberships } = await sb.from("family_members").select("family_id").eq("user_id", userId);
    const familyIds = ((memberships ?? []) as Array<{ family_id: string | null }>)
      .map((m) => m.family_id).filter((id): id is string => !!id);
    let invQuery = sb.from("zad_inventory").select("item_name,quantity,low_stock_threshold,category,restock_mode,restock_cycle_days,created_at").limit(200);
    invQuery = familyIds.length > 0
      ? invQuery.or(`user_id.eq.${userId},family_id.in.(${familyIds.join(",")})`)
      : invQuery.eq("user_id", userId);
    const { data: inv, error: invErr } = await invQuery;
    if (invErr) console.error("[store_arrival] inventory lookup failed:", invErr.message);
    const invRows = (inv ?? []) as Array<{ item_name: string; quantity: number | null; low_stock_threshold: number | null; category: string | null; restock_mode: string | null; created_at: string | null }>;
    // نفس حكم الحلم الليلي (restockJudge.ts): اللي لسه متشري مش «ناقص في البيت».
    const isDue = await loadRestockJudge(sb, userId, familyIds[0] ?? null);
    lowStock = invRows.filter(isDue).map((i) => i.item_name);
    // بند على القايمة والصنف نفسه في المخزن ولسه متشري = اتشرى خلاص؛ مابيتقالش «ناقص». البند نفسه مابيتمسحش.
    const freshInPantry = new Set(invRows.filter((i) => !isDue(i)).map((i) => itemKey(i.item_name)));
    shopping = shopping.filter((n) => !freshInPantry.has(itemKey(n)));
    // عطارة/جزارة/خضري/فرن بياخدوا أصناف قسمهم بس؛ السوبرماركت العادي القايمة كلها (storeFit.ts).
    const categoryByKey = new Map(invRows.map((i) => [itemKey(i.item_name), i.category]));
    const categoryOf = (item: string) => categoryByKey.get(itemKey(item));
    shopping = itemsForStore(storeName, shopping, categoryOf);
    lowStock = itemsForStore(storeName, lowStock, categoryOf);
    clientHints = itemsForStore(storeName, clientHints, categoryOf);
  }

  // «اتشاف هنا»: بلاغات الأسعار (فواتير عملاء زاد) في محل بنفس الاسم آخر ٧٢ ساعة. و«أرخص هنا» (الشريحة ٢٨): آخر سعر
  // هنا (١٤ يوم) قصاد وسيط باقي المحلات (٣٠ يوم) — بعملة العميل بس؛ من غير عملة معروفة مفيش مقارنة أسعار.
  let seenHere: SeenHere[] = [];
  let cheaperHere: CheaperHere[] = [];
  let dealsAtStore: ReturnType<typeof dealsHere> = [];
  if (category !== "pharmacy") {
    const [{ data: me }, { data: profile }] = await Promise.all([
      sb.from("zad_users").select("currency,country,travel_country,travel_since").eq("id", userId).maybeSingle(),
      sb.from("zad_customer_profile").select("city").eq("user_id", userId).maybeSingle(),
    ]);
    const currency = (me as { currency?: string | null } | null)?.currency ?? null;
    // مدينة «ملفي» — البلاغات بقت بتشيل مدينة صاحبها (20261011260000)؛ مدينة تانية مش «هنا».
    const city = (profile as { city?: string | null } | null)?.city ?? null;
    const { data: reports, error: seenErr } = await sb.from("price_index")
      .select("item_name,store_name,timestamp,price,currency,user_id,location")
      .eq("source", "crowdsource").not("store_name", "is", null)
      .gte("timestamp", new Date(Date.now() - 30 * 86_400_000).toISOString())
      .order("timestamp", { ascending: false }).limit(2000);
    if (seenErr) console.error("[store_arrival] seen-here lookup failed:", seenErr.message);
    const rows = (reports ?? []) as Array<{ item_name: string | null; store_name: string | null; timestamp: string | null; price: number | null; currency: string | null; user_id: string | null; location: string | null }>;
    const missing = [...shopping, ...lowStock];
    seenHere = seenHereItems(rows, storeName, missing, Date.now(), 72, city);
    if (currency) {
      const homes = await homeMap(sb, rows.map((r) => r.user_id ?? ""));
      cheaperHere = cheaperHereItems(rows.filter((r) => r.currency === currency), storeName, missing, Date.now(), homes, city);
    }
    // ZAD_PLAN ٤.٩: عرض ساري هنا على حاجة ناقصة — من بلده (أو بلد السفر)، زي عرض الصبح.
    const country = dealCountry(me as { country?: string | null; travel_country?: string | null; travel_since?: string | null } | null, Date.now());
    if (/^[A-Z]{2}$/.test(country) && missing.length > 0) {
      const { data: deals, error: dealsErr } = await sb.from("zad_deals")
        .select("store,item_name,price,price_before,source_kind,source_url,valid_until")
        .eq("country", country).gt("expires_at", nowIso).limit(300);
      if (dealsErr) console.error("[store_arrival] deals lookup failed:", dealsErr.message);
      dealsAtStore = dealsHere(deals as StoredDealRow[] | null, storeName, missing);
    }
  }

  const message = buildStoreArrivalMessage({
    storeName, category, shopping, lowStock, clientHints, seenHere, cheaperHere, dealsHere: dealsAtStore,
  });
  if (!message) return json({ ok: true, sent: false, reason: "nothing_missing", reminders: reminderStatus });

  const task = storeArrivalTask(userId, storeArrivalDescription(storeName, category), message.body, body?.store_lat, body?.store_lon, nowIso);
  const mapUrl = task.map_url ?? undefined;
  const { data: taskRow, error: taskErr } = await sb.from("agent_tasks").insert(task).select("id").single();
  if (taskErr) {
    // من غير الصف ده الحارس (محل/يوم) مابيشوفش الرسالة — فمابنبعتش بدل ما نسبّم.
    console.error("[store_arrival] task insert failed — not sending:", taskErr.message);
    return json({ ok: false, error: "record_failed" }, 500);
  }

  const taskId = (taskRow as { id: string }).id;
  const telegram = await pushToTelegram(
    userId, message.title, message.body, fetch, taskId,
    undefined, undefined, undefined, undefined, undefined, mapUrl,
  );
  console.log(`[store_arrival] ${category} «${storeName}» items=${message.itemCount} → telegram: ${telegram}`);
  // title/body: the phone shows the same message as a notification (Flutter's street alerts).
  return json({
    ok: true, sent: telegram === "delivered", telegram, items: message.itemCount, task_id: taskId, reminders: reminderStatus,
    title: message.title, body: message.body,
  });
}

/**
 * «فكّريني لما أروح الصيدلية» — العميل وصل نوع المكان. التذكيرات بتتقفل (done) في نفس الـUPDATE
 * اللي بيرجّعها، وبتتسجّل لحظة صوت place_reminder واحدة وتتعالج في الخلفية: الـreceiver على
 * الموبايل ليه ثواني قليلة، وكتابة الكلام بالموديل ممكن تاخد أكتر.
 */
/** اتفاق التوفير الحالي للعميل (وضع طوارئ / تحدي / ميزانية في خطر) — أي قراءة تفشل = مفيش تحذير. */
async function loadSavingsAgreement(sb: SupabaseClient, userId: string): Promise<(SavingsAgreement & { time_zone: string }) | null> {
  try {
    const [brokeRes, challengeRes, stateRes] = await Promise.all([
      sb.from("zad_broke_mode").select("ends_at,ended_at,daily_cap").eq("user_id", userId).maybeSingle(),
      sb.from("zad_savings_challenges").select("daily_cap,streak").eq("user_id", userId).eq("status", "active").maybeSingle(),
      sb.rpc("zad_budget_state", { p_user: userId }),
    ]);
    const broke = brokeRes.data as { ends_at: string; ended_at: string | null; daily_cap: number | null } | null;
    const state = (stateRes.data ?? {}) as { threat?: string; daily_allowance_left?: number | null; currency?: string | null; timezone?: string | null };
    const agreement = savingsAgreementFrom({
      brokeActive: isBrokeModeActive(broke, Date.now()),
      brokeDailyCap: broke?.daily_cap ?? null,
      challenge: challengeRes.data as { daily_cap: number; streak: number } | null,
      threat: state.threat ?? null,
      dailyAllowanceLeft: state.daily_allowance_left ?? null,
      currency: state.currency ?? null,
    });
    return agreement ? { ...agreement, time_zone: state.timezone ?? "UTC" } : null;
  } catch (e) {
    console.error("[shopping_zone_warning] agreement lookup failed:", (e as Error)?.message);
    return null;
  }
}

/**
 * «انت جنب المطعم» (ZAD_PLAN ٤.١٨): عروضه السارية من zad_deals بس — مفيش نواقص في مطعم. نفس حارس المحل/اليوم وكتم
 * رسايل المحلات، ومن غير تذكيرات أماكن ولا تحذير التوفير. اتفاق توفير شغال (طوارئ، تحدي، ميزانية في خطر) = ولا كلمة:
 * عرض مطعم عمره ما بيعدّي وضع الطوارئ.
 */
async function restaurantArrival(
  sb: SupabaseClient, userId: string, storeName: string, muted: boolean, body: any, nowIso: string,
  json: (payload: Record<string, unknown>, status?: number) => Response,
): Promise<Response> {
  if (muted) return json({ ok: true, sent: false, reason: "muted" });
  const { data: recent, error: recentErr } = await sb.from("agent_tasks")
    .select("created_at,task_description")
    .eq("user_id", userId).eq("kind", "store_arrival")
    .gte("created_at", new Date(Date.now() - 24 * 3_600_000).toISOString());
  if (recentErr) console.error("[store_arrival] recent lookup failed:", recentErr.message);
  const blocked = storeArrivalBlock((recent ?? []) as Array<{ created_at: string; task_description: string }>, storeName, Date.now());
  if (blocked) return json({ ok: true, sent: false, reason: blocked });
  if (await loadSavingsAgreement(sb, userId)) return json({ ok: true, sent: false, reason: "saving" });

  const { data: me } = await sb.from("zad_users").select("country,travel_country,travel_since").eq("id", userId).maybeSingle();
  const country = dealCountry(me as { country?: string | null; travel_country?: string | null; travel_since?: string | null } | null, Date.now());
  if (!/^[A-Z]{2}$/.test(country)) return json({ ok: true, sent: false, reason: "no_deal" });
  const { data: deals, error: dealsErr } = await sb.from("zad_deals")
    .select("store,item_name,price,price_before,source_kind,source_url,valid_until")
    .eq("country", country).gt("expires_at", nowIso).order("found_at", { ascending: false }).limit(300);
  if (dealsErr) console.error("[store_arrival] deals lookup failed:", dealsErr.message);
  const message = buildRestaurantArrivalMessage(storeName, dealsAtPlace(deals as StoredDealRow[] | null, storeName));
  if (!message) return json({ ok: true, sent: false, reason: "no_deal" });

  const task = storeArrivalTask(userId, storeArrivalDescription(storeName, "restaurant"), message.body, body?.store_lat, body?.store_lon, nowIso);
  const { data: taskRow, error: taskErr } = await sb.from("agent_tasks").insert(task).select("id").single();
  if (taskErr) {
    console.error("[store_arrival] task insert failed — not sending:", taskErr.message);
    return json({ ok: false, error: "record_failed" }, 500);
  }
  const taskId = (taskRow as { id: string }).id;
  const telegram = await pushToTelegram(
    userId, message.title, message.body, fetch, taskId,
    undefined, undefined, undefined, undefined, undefined, task.map_url ?? undefined,
  );
  console.log(`[store_arrival] restaurant «${storeName}» deals=${message.itemCount} → telegram: ${telegram}`);
  return json({ ok: true, sent: telegram === "delivered", telegram, items: message.itemCount, task_id: taskId, title: message.title, body: message.body });
}

async function firePlaceReminders(
  sb: SupabaseClient,
  userId: string,
  category: Exclude<StoreCategory, "restaurant">,
  storeName: string,
  agreement: (SavingsAgreement & { time_zone: string }) | null,
): Promise<string> {
  const { data: fired, error } = await sb.from("zad_place_reminders")
    .update({ status: "done", fired_at: new Date().toISOString(), fired_store: storeName })
    .eq("user_id", userId).eq("status", "open").in("place", placesMatchingArrival(category))
    .select("id,note");
  if (error) {
    console.error("[place_reminder] fire failed:", error.message);
    return "error";
  }
  const rows = (fired ?? []) as Array<{ id: string; note: string }>;
  const localDate = localNowContext(agreement?.time_zone ?? "UTC").date;
  // تحذير مرة واحدة في اليوم مهما دخل كام محل.
  const warnKey = `shop_warn:${localDate}`;
  let savings: Record<string, unknown> | null = null;
  if (agreement) {
    const { data: already } = await sb.from("zad_voice_moments").select("id").eq("user_id", userId).eq("dedupe_key", warnKey).maybeSingle();
    if (!already) {
      const { data: list } = await sb.from("zad_shopping_list").select("item_name")
        .or(householdFilter(userId, await householdFamilyId(sb, userId))).eq("is_purchased", false).limit(20);
      const items = ((list ?? []) as Array<{ item_name: string }>).map((i) => i.item_name);
      savings = { ...agreement, list_count: items.length, list_preview: items.slice(0, 5) };
    }
  }

  if (rows.length === 0) {
    if (!savings) return "none";
    const { error: warnErr } = await sb.from("zad_voice_moments").upsert({
      user_id: userId,
      moment: "shopping_zone_warning",
      facts: { store_name: storeName, category, ...savings },
      dedupe_key: warnKey,
    }, { onConflict: "user_id,dedupe_key", ignoreDuplicates: true });
    if (warnErr) {
      console.error("[shopping_zone_warning] insert failed:", warnErr.message);
      return "error";
    }
    runVoiceMomentsInBackground(sb, userId, `[shopping_zone_warning] ${String(savings.reason)} at «${storeName}»`);
    return "warning";
  }

  const { error: momentErr } = await sb.from("zad_voice_moments").upsert({
    user_id: userId,
    moment: "place_reminder",
    facts: { store_name: storeName, category, notes: rows.slice(0, 5).map((r) => r.note), ...(savings ? { savings } : {}) },
    dedupe_key: placeReminderDedupeKey(rows.map((r) => r.id)),
  }, { onConflict: "user_id,dedupe_key", ignoreDuplicates: true });
  if (savings && !momentErr) {
    // التحذير اتقال جوه التذكير — نسجّل مفتاح اليوم عشان محل تاني النهارده مايكررهوش.
    await sb.from("zad_voice_moments").upsert({
      user_id: userId, moment: "shopping_zone_warning", facts: { merged_into: "place_reminder" },
      dedupe_key: warnKey, status: "skipped", error: "merged into place_reminder",
    }, { onConflict: "user_id,dedupe_key", ignoreDuplicates: true });
  }
  if (momentErr) {
    // التذكير اتقفل ومش هيتقال — نرجّعه مفتوح بدل ما يضيع بصمت.
    console.error("[place_reminder] moment insert failed — reopening:", momentErr.message);
    await sb.from("zad_place_reminders").update({ status: "open", fired_at: null, fired_store: null })
      .in("id", rows.map((r) => r.id));
    return "error";
  }

  runVoiceMomentsInBackground(sb, userId, `[place_reminder] ${rows.length} for «${storeName}»`);
  return `fired:${rows.length}${savings ? "+warning" : ""}`;
}

/**
 * لحظات العميل ده تتعالج في الخلفية: الـreceiver على الموبايل ليه ثواني قليلة، وكتابة الكلام
 * بالموديل ممكن تاخد أكتر. من غير EdgeRuntime (تست/محلي) بيستنى عادي.
 */
function runVoiceMomentsInBackground(sb: SupabaseClient, userId: string, label: string): void {
  const work = processVoiceMoments(sb, {
    hasChannel: (uid, o) => momentChannels(sb, uid, o),
    compose: async (system, user) =>
      (await callModel({ model: MODEL_ROUTINE, system, tools: [], history: [{ role: "user", text: user }], maxTokens: 500 })).text,
    pushDevice: (uid, title, text, data, dataOnly) => pushToDevice(sb, uid, title, text, data, dataOnly),
    pushTelegram: (uid, title, text, voice, m, speech, emotion, doseId) => pushToTelegram(uid, title, text, fetch, undefined, voice, m, speech, emotion, doseId),
  }, 5, userId)
    .then((r) => console.log(`${label} → ${JSON.stringify(r)}`))
    .catch((e) => console.error(`${label} processing failed:`, (e as Error)?.message));
  const runtime = (globalThis as { EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void } }).EdgeRuntime;
  if (runtime?.waitUntil) runtime.waitUntil(work);
}
