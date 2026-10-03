// Small pure decision functions extracted out of the Deno.serve handler purely so
// Task 16.4's tests #11/#12 don't need a live server or a live database to verify.

/** Task 16.3 partial-run idempotency: skip a new daily run if one in the window already mutated data. */
export function hasRecentMutatingRun(runs: Array<{ mutations: unknown }>): boolean {
  return runs.some((r) => Array.isArray(r.mutations) && r.mutations.length > 0);
}

/**
 * بيطبّع `trigger` الجاي من الطلب لقيمة يقبلها `zad_brain_runs_trigger_check`
 * (`daily`/`event`/`chat` بس).
 *
 * ليه: `GeofenceBroadcastReceiver` بيبعت `"geofence_enter"`، والنوع `Trigger` في
 * index.ts كان cast من غير تحقق وقت التشغيل. الإدراج في `zad_brain_runs` كان بيقع على
 * الـCHECK، والخطأ مكانش بيتقرا: `runId` بيبقى undefined، الموديل بيشتغل عادي، وكل
 * تحديث بعد كده (`success`/`queued`) بيطابق صفر صفوف. يعني تشغيلات الجيوفينس كانت
 * **بتختفي من المراقبة كليًا** — لا نجاح ولا فشل. أي قيمة مش معروفة = حدث، وده صح
 * دلاليًا (دخول نطاق محل حدث فعلاً)، ومطابق لما `scope.source` كان بيعمله أصلاً.
 */
export function normalizeBrainTrigger(raw: unknown): "daily" | "event" | "chat" {
  return raw === "daily" || raw === "chat" ? raw : "event";
}

/**
 * عنوان إشعار نتيجة مهمة `agent_tasks`، وهل هي مبادرة من زاد ولا طلب من العميل.
 *
 * كل النتايج كانت بتطلع بعنوان «زاد خلّص مهمة كنت طلبتها» — حتى المهام اللي الماسح
 * الاستباقي كتبها والعميل عمره ماطلبها (ملخص البيت، توقّع الصرف، متابعة الدوا…). ده
 * كذب صغير بيبوّظ ثقة، وبيخبّي إن زاد هو اللي بادر.
 *
 * `reminder` (وهو الافتراضي على العمود) = طلب العميل. أي نوع تاني = مبادرة، ودي اللي
 * بتتبعت لتليجرام كمان (3 من 4 مستخدمين حقيقيين مربوطين، وFCM صفر توكن — يعني قبل كده
 * النتيجة الاستباقية كانت بتقف في قايمة إشعارات جوه التطبيق محدش بيفتحها).
 */
export function agentTaskNotice(kind: string | null | undefined): { title: string; proactive: boolean; voice: boolean } {
  const k = (kind ?? "").trim();
  if (k === "" || k === "reminder") {
    return { title: "زاد خلّص مهمة كنت طلبتها ✅", proactive: false, voice: false };
  }
  const titles: Record<string, string> = {
    home_weekly_digest: "📋 ملخص البيت من زاد",
    spend_forecast: "📈 زاد بيتوقّع مصروف الأسبوع",
    spending_ahead: "⚠️ زاد لاحظ إن الصرف أسرع من الميزانية",
    med_followup: "💊 زاد بيتابع معاك الدوا",
    bill_reminder: "🧾 زاد بيفكّرك بفاتورة قربت",
    warranty_reminder: "🛡️ زاد بيفكّرك بضمان قرب ينتهي",
    listener_gap_alert: "🔔 زاد لاحظ إن إشعارات البنك وقفت",
    goal_review: "🎯 زاد بيتابع هدفك",
    store_arrival: "🛒 زاد لاحظ إنك جنب محل",
    habit_budget: "☕ زاد لاحظ عادة بتتكرر",
    predicted_shortage: "🥛 زاد شايف حاجات هتخلص قريب",
  };
  return { title: titles[k] ?? "💡 زاد لاحظ حاجة تهمّك", proactive: true, voice: VOICE_ALERT_KINDS.has(k) };
}

/**
 * مبادرات حرجة بتتبعت لتليجرام بفويس بصوت زاد مع النص (`voice:true` في realtime_push).
 * خطر مالي بيحتاج تصرّف دلوقتي بس: إشعارات البنك وقفت (يعني صرف مش متسجّل) والصرف أسرع من
 * السقف. الملخصات والتذكيرات لأ — فويس على كل رسالة بيبقى ضوضاء والعميل بيكتمه.
 */
export const VOICE_ALERT_KINDS: ReadonlySet<string> = new Set(["listener_gap_alert", "spending_ahead"]);

/**
 * لو مبادرة مستحقة نوعها مكتوم (رفض العميل من تليجرام، 20260913190000)، بترجّع إمتى تتأجل —
 * آخر `suppress_until` لسه في المستقبل. `null` = نفّذ عادي.
 *
 * ليه تأجيل مش إلغاء: الكتم كان بيتقرا في الماسح بس، ومنفّذ المهام مابيشوفوش. فمتابعة هدف
 * أسبوعية (`goal_review`، مهمة متكررة مش من الماسح) كانت هتتبعت تاني رغم الرفض. والإلغاء كان
 * هيقتل السلسلة المتكررة كلها بعد كتم ٣ أيام بس («عرفت خلاص») — التأجيل لنهاية الكتم بيحترم
 * الرفض ويسيب الهدف عايش. طلبات العميل (`reminder`) عمرها ما بتتأجل بكتم.
 */
export function postponeForSuppression(
  kind: string | null | undefined,
  mutes: Array<{ suppress_until: string | null }>,
  nowMs: number,
): string | null {
  if (!agentTaskNotice(kind).proactive) return null;
  let latest = -Infinity;
  for (const m of mutes) {
    const t = m.suppress_until ? Date.parse(m.suppress_until) : NaN;
    if (Number.isFinite(t) && t > nowMs && t > latest) latest = t;
  }
  return Number.isFinite(latest) ? new Date(latest).toISOString() : null;
}

// ── وصول لمحل (مرحلة ٢ بند ٣) ─────────────────────────────────────────────
// دخول نطاق سوبرماركت/مول/صيدلية كان بيبعت `geofence_enter` لمسار التحليل: نداء موديل
// ورده بيرجع في الـHTTP response والتطبيق بيتجاهله — لا تليجرام ولا رؤية. القايمة هنا
// بتتبني من البيانات مباشرة (قايمة الشراء + المخزون الناقص + الأدوية القربت)، من غير موديل.

export type StoreCategory = "supermarket" | "mall" | "pharmacy";

/** ساعات بين رسالتين لنفس المحل، وأقصى عدد رسايل في ٢٤ ساعة — عشان التنقل في مول مايبقاش سبام. */
export const STORE_ARRIVAL_SAME_STORE_HOURS = 6;
export const STORE_ARRIVAL_DAILY_CAP = 3;
const STORE_ARRIVAL_MAX_LISTED = 10;

export function normalizeStoreCategory(raw: unknown): StoreCategory | null {
  const v = String(raw ?? "").trim().toLowerCase();
  return v === "supermarket" || v === "mall" || v === "pharmacy" ? v : null;
}

/** اسم محل أو صنف جاي من الجهاز: نص بس، من غير control chars ولا «»، بطول معقول. */
function cleanText(raw: unknown, max: number): string {
  if (typeof raw !== "string") return "";
  return raw.replace(/[\u0000-\u001f\u007f\u00ab\u00bb]/g, " ").replace(/\s+/g, " ").trim().slice(0, max);
}

/** «لمين؟» — اسم الشخص اللي الدوا/الميعاد ليه، زي ما العميل قاله. null = العميل نفسه. */
/**
 * «ماما» و«أمي» و«والدتي» واحدة — كانوا بيتسجلوا ٣ أشخاص عند العقل (ZAD_SUPER_AGENT.md
 * نقطة ٨). صلة القرابة المعروفة بتتوحّد لاسم واحد؛ أي اسم تاني («سارة»، «عم أحمد») بيفضل
 * زي ما هو.
 */
const KIN: ReadonlyArray<readonly [RegExp, string]> = [
  [/^(ماما|مامتي|امي|أمي|إمي|والدتي|الوالدة|امى|أمى|mama|mom|mum|mother)$/i, "ماما"],
  [/^(بابا|باباي|ابويا|أبويا|ابوي|أبوي|ابي|أبي|والدي|الوالد|papa|dad|father)$/i, "بابا"],
  [/^(تيتا|ستي|ستّي|جدتي|جدّتي|نانا|grandma)$/i, "تيتا"],
  [/^(جدو|جدي|جدّي|grandpa)$/i, "جدو"],
  [/^(مراتي|زوجتي|المدام|wife)$/i, "مراتي"],
  [/^(جوزي|زوجي|husband)$/i, "جوزي"],
];

/** الاسم الواحد لصلة قرابة («أمي» ← «ماما»)، أو null لو الكلمة مش صلة قرابة معروفة. */
export function kinCanonical(word: string): string | null {
  for (const [re, canonical] of KIN) {
    if (re.test(word)) return canonical;
  }
  return null;
}

export function normalizeForPerson(raw: unknown): string | null {
  let name = cleanText(raw, 40);
  if (!name) return null;
  // «لماما» / «لـ ماما» — حرف الجر مش جزء من الاسم (بس قدام صلة قرابة، عشان «لينا» تفضل اسم).
  name = name.replace(/^لـ\s*/, "").replace(/^ل(?=(ماما|بابا|تيتا|جدو|مراتي|جوزي|امي|أمي|ابويا|أبويا|والدتي|والدي)$)/, "").trim();
  if (!name) return null;
  // «أنا»/«ليا» = العميل نفسه، مش شخص تاني اسمه «أنا».
  if (/^(انا|أنا|ليا|لي|نفسي|me|myself)$/i.test(name)) return null;
  for (const [re, canonical] of KIN) {
    if (re.test(name)) return canonical;
  }
  return name;
}

export function sanitizeStoreName(raw: unknown): string {
  return cleanText(raw, 60);
}

/** قايمة الجهاز تلميح بس (ممكن تكون أحدث من السيرفر لو كان أوفلاين) — مقصوصة ومنضّفة. */
export function sanitizeItemHints(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return raw.slice(0, 30).map((x) => cleanText(x, 60)).filter((x) => x.length > 0);
}

/**
 * مفتاح مقارنة للأصناف: «لبن» و«لَبن» و«لبن » نفس الصنف. بيشيل التشكيل والتطويل وبيوحّد
 * الألف والياء والتاء المربوطة — للمقارنة بس، الاسم المعروض بيفضل زي ما العميل كتبه.
 */
export function itemKey(name: string): string {
  return name
    .replace(/[\u064B-\u0652\u0640]/g, "")
    .replace(/[أإآ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

// ── الذاكرة بكيانات وزمن (20261003100000، docs/agent/ZAD_LIVING_BRAIN.md) ─────

/** أنواع zad_memory_entities.kind — نفس الـcheck في الداتابيز. */
export const MEMORY_ENTITY_KINDS = ["person", "place", "item", "org"] as const;
export type MemoryEntityKind = typeof MEMORY_ENTITY_KINDS[number];
export type MemoryEntity = { kind: MemoryEntityKind; name: string; key: string };

/**
 * الكيانات اللي ملاحظة بتشاور عليها، من أداة remember أو سطر ABOUT في الاستخلاص.
 * نفس التوحيد الموجود بالظبط: الشخص عبر [normalizeForPerson] («أمي» = «ماما»، و«أنا» =
 * العميل نفسه ⇒ مش كيان)، والمفتاح [itemKey]. عنصر ناقص أو نوعه مش معروف بيتشال بصمت —
 * الملاحظة نفسها أهم من كياناتها. ٣ بالكتير، من غير تكرار.
 */
export function normalizeMemoryEntities(raw: unknown): MemoryEntity[] {
  if (!Array.isArray(raw)) return [];
  const out: MemoryEntity[] = [];
  const seen = new Set<string>();
  for (const r of raw) {
    if (out.length >= 3) break;
    const item = (r ?? {}) as { kind?: unknown; name?: unknown };
    const kind = String(item.kind ?? "").trim().toLowerCase();
    if (!(MEMORY_ENTITY_KINDS as readonly string[]).includes(kind)) continue;
    const name = kind === "person" ? normalizeForPerson(item.name) : (cleanText(item.name, 60) || null);
    if (!name) continue;
    const key = itemKey(name).slice(0, 60);
    if (!key || seen.has(`${kind}:${key}`)) continue;
    seen.add(`${kind}:${key}`);
    out.push({ kind: kind as MemoryEntityKind, name, key });
  }
  return out;
}

/** أطول مدة لحقيقة «مؤقتة». أبعد من كده = حقيقة دائمة، مش مؤقتة. */
export const MEMORY_MAX_VALIDITY_DAYS = 730;

/**
 * انتهاء حقيقة مؤقتة (zad_memory.valid_until) زي ما الموديل كتبه. «YYYY-MM-DD» = لحد آخر
 * اليوم ده بتوقيت العميل (يعني أول بكرته)، ووقت كامل بيتقري زي [resolveLocalIso]. `null` = مش
 * وقت، أو فات، أو أبعد من سنتين — والمنادي هو اللي يقرر يرفض.
 */
export function resolveValidUntil(raw: unknown, timeZone: string, nowMs: number): string | null {
  const text = String(raw ?? "").trim();
  if (!text) return null;
  const offset = localNowContext(timeZone, new Date(nowMs)).utc_offset;
  let iso: string | null;
  const dateOnly = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
  if (dateOnly) {
    const [y, m, d] = dateOnly.slice(1).map(Number);
    const day = new Date(Date.UTC(y, m - 1, d));
    // «2026-02-30» مش يوم — Date.UTC كانت هتقلبه ٢ مارس من غير ما تقول.
    if (day.getUTCFullYear() !== y || day.getUTCMonth() !== m - 1 || day.getUTCDate() !== d) return null;
    const next = new Date(day.getTime() + 86_400_000).toISOString().slice(0, 10);
    iso = resolveLocalIso(next, offset);
  } else {
    iso = resolveLocalIso(text, offset);
  }
  if (!iso) return null;
  const t = Date.parse(iso);
  if (t <= nowMs || t > nowMs + MEMORY_MAX_VALIDITY_DAYS * 86_400_000) return null;
  return iso;
}

/**
 * نص الرسالة لـ`zad_memory_recall_entities`: [itemKey] للرسالة كلها (عشان «كارفور المعادي»
 * تتطابق كعبارة)، وبعد « | » نسخة كل كلمة فيها متوحّدة: صلة القرابة باسمها الواحد («أمي» ←
 * «ماما»)، ومن غير حرف لازق في أولها («وماما»، «بالقهوة» ← «قهوه»). المطابقة نفسها في
 * الداتابيز على كلمة أو عبارة كاملة.
 */
export function entityRecallText(message: string): string {
  const words = message.replace(/[^\p{L}\p{N}\s]/gu, " ").split(/\s+/).filter(Boolean);
  const base = itemKey(words.join(" "));
  const variant = words.map((w) => {
    let k = itemKey(w);
    // «وبالقهوة» فيها حرفين لازقين. صلة القرابة بتقف التقشير: «بابا» مش «ب» + «ابا».
    for (let i = 0; i < 3; i++) {
      const kin = kinCanonical(k);
      if (kin) return itemKey(kin);
      if (k.length > 3 && /^[وبلف]/.test(k)) k = k.slice(1);
      else break;
    }
    if (k.length > 4 && k.startsWith("ال")) k = k.slice(2);
    return k;
  }).join(" ");
  return (variant === base ? base : `${base} | ${variant}`).slice(0, 1000);
}

// ── وضع السفر (20261003140000، ZAD_LIVING_BRAIN.md الشريحة ٦) ──────────────────

/** أسماء البلاد اللي الناس بتسافرلها أكتر — للقالب الاحتياطي والسناب شوت. غيرها = الكود نفسه. */
const COUNTRY_NAME_AR: Readonly<Record<string, string>> = {
  EG: "مصر", SA: "السعودية", AE: "الإمارات", KW: "الكويت", QA: "قطر", BH: "البحرين", OM: "عُمان",
  JO: "الأردن", LB: "لبنان", IQ: "العراق", SY: "سوريا", YE: "اليمن", PS: "فلسطين", LY: "ليبيا",
  SD: "السودان", MA: "المغرب", TN: "تونس", DZ: "الجزائر", TR: "تركيا", GB: "بريطانيا", US: "أمريكا",
  FR: "فرنسا", DE: "ألمانيا", IT: "إيطاليا", ES: "إسبانيا", GR: "اليونان", CY: "قبرص", MY: "ماليزيا",
  ID: "إندونيسيا", TH: "تايلاند", GE: "جورجيا", AZ: "أذربيجان", RU: "روسيا", CN: "الصين", IN: "الهند",
  PK: "باكستان", MV: "المالديف", CH: "سويسرا", AT: "النمسا", NL: "هولندا", BE: "بلجيكا", CA: "كندا",
};

/** اسم البلد بالعربي، أو الكود لو مش في القايمة. */
export function countryNameAr(code: unknown): string {
  const c = String(code ?? "").trim().toUpperCase();
  return COUNTRY_NAME_AR[c] ?? c;
}

/** بعد المدة دي من غير ما الموبايل يأكد، الرحلة بتتعتبر قديمة ومابتدخلش السناب شوت. */
export const TRAVEL_STALE_DAYS = 45;

/**
 * سياق السفر للسناب شوت: فين ومن إمتى وبلد السوق. `null` = في بلده، أو الرحلة قديمة (الموبايل
 * مابلّغش من ٤٥ يوم — غالباً رجع ومافتحش التطبيق).
 */
export function travelContext(
  row: { travel_country?: string | null; travel_since?: string | null; country?: string | null } | null | undefined,
  nowMs: number,
): { in: string; country_name: string; home: string; since: string; days: number } | null {
  const away = String(row?.travel_country ?? "").trim().toUpperCase();
  const home = String(row?.country ?? "").trim().toUpperCase();
  const since = row?.travel_since ? Date.parse(row.travel_since) : NaN;
  if (!/^[A-Z]{2}$/.test(away) || away === home || !Number.isFinite(since)) return null;
  const days = Math.floor((nowMs - since) / 86_400_000);
  if (days < 0 || days > TRAVEL_STALE_DAYS) return null;
  return { in: away, country_name: countryNameAr(away), home, since: new Date(since).toISOString(), days };
}

/**
 * تذكيرات المكان (20260914007000) — «فكّريني لما أروح الصيدلية». 'any' = أي محل.
 */
export const PLACE_REMINDER_PLACES = ["supermarket", "pharmacy", "mall", "any"] as const;
export type PlaceReminderPlace = typeof PLACE_REMINDER_PLACES[number];

/** أنواع التذكيرات اللي تتقال لما العميل يوصل محل من النوع ده. */
export function placesMatchingArrival(category: StoreCategory): PlaceReminderPlace[] {
  return [category, "any"];
}

/** مفتاح منع التكرار للحظة الصوت: نفس التذكيرات = نفس اللحظة حتى لو الحدث وصل مرتين. */
export function placeReminderDedupeKey(ids: string[]): string {
  return `place_reminder:${[...ids].sort().join(",").slice(0, 400)}`;
}

export function storeArrivalDescription(storeName: string, category: StoreCategory): string {
  return `وصول لـ«${storeName}» (${category})`;
}

/**
 * هل الرسالة دي لازم تتمنع؟ `recent` = مهام store_arrival آخر ٢٤ ساعة للعميل ده.
 * اسم المحل بيتقرا من الوصف اللي `storeArrivalDescription` كتبته.
 */
export function storeArrivalBlock(
  recent: Array<{ created_at: string; task_description: string }>,
  storeName: string,
  nowMs: number,
): "same_store_recently" | "daily_cap" | null {
  const dayAgo = nowMs - 24 * 3_600_000;
  const inDay = recent.filter((r) => Date.parse(r.created_at) >= dayAgo);
  const wanted = itemKey(storeName);
  const windowStart = nowMs - STORE_ARRIVAL_SAME_STORE_HOURS * 3_600_000;
  const sameStore = inDay.some((r) => {
    const m = /«([^»]*)»/.exec(r.task_description ?? "");
    return m !== null && itemKey(m[1]) === wanted && Date.parse(r.created_at) >= windowStart;
  });
  if (sameStore) return "same_store_recently";
  if (inDay.length >= STORE_ARRIVAL_DAILY_CAP) return "daily_cap";
  return null;
}

/**
 * نص الرسالة. الترتيب مقصود: قايمة الشراء الأول (العميل كتبها بنفسه)، بعدين المخزون الناقص،
 * بعدين تلميح الجهاز. `null` = مفيش حاجة ناقصة — ساعتها مابنبعتش خالص بدل رسالة فاضية.
 */
export function buildStoreArrivalMessage(input: {
  storeName: string;
  category: StoreCategory;
  shopping: string[];
  lowStock: string[];
  clientHints: string[];
  seenHere?: SeenHere[];
}): { title: string; body: string; itemCount: number } | null {
  const seen = new Set<string>();
  const items: string[] = [];
  for (const raw of [...input.shopping, ...input.lowStock, ...input.clientHints]) {
    const name = cleanText(raw, 60);
    const key = itemKey(name);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    items.push(name);
  }
  if (items.length === 0) return null;

  const store = sanitizeStoreName(input.storeName) || "محل قريب";
  const title = input.category === "pharmacy"
    ? `💊 أنت جنب «${store}»`
    : input.category === "mall"
      ? `🛍️ أنت في «${store}»`
      : `🛒 أنت جنب «${store}»`;
  const intro = input.category === "pharmacy" ? "أدوية قربت تخلص عندك:" : "ناقص في البيت، لو هتشتري:";
  const listed = items.slice(0, STORE_ARRIVAL_MAX_LISTED).map((i) => `• ${i}`);
  const more = items.length - listed.length;
  const seenLines = (input.seenHere ?? []).slice(0, 5).map((s) => `${cleanText(s.item, 40)} (${agoText(s.hours)})`);
  const body = [
    intro, ...listed, ...(more > 0 ? [`… و${more} كمان`] : []),
    ...(seenLines.length > 0 ? [`👀 اتشاف في محل بنفس الاسم من فواتير عملاء زاد: ${seenLines.join("، ")}`] : []),
  ].join("\n");
  return { title, body, itemCount: items.length };
}

/** صنف ناقص اتشاف في محل بنفس الاسم، وبقاله كام ساعة. */
export interface SeenHere {
  item: string;
  hours: number;
}

/** كام ساعة، بكلام — «من شوية»، «من ٥ ساعات»، «من يومين». */
function agoText(hours: number): string {
  if (hours < 1) return "من شوية";
  const count = (n: number, one: string, two: string, few: string, many: string) =>
    n === 1 ? `من ${one}` : n === 2 ? `من ${two}` : n <= 10 ? `من ${n} ${few}` : `من ${n} ${many}`;
  if (hours < 24) return count(Math.round(hours), "ساعة", "ساعتين", "ساعات", "ساعة");
  return count(Math.round(hours / 24), "يوم", "يومين", "أيام", "يوم");
}

// كلمات بتتشال من اسم المحل قبل المطابقة: «كارفور ماركت» على الفاتورة و«كارفور» من جوجل نفس المحل.
// `\b` في JS مابيعرفش الحروف العربي، فالحدود مسافة أو أول/آخر النص.
const STORE_NOISE = /(?<=^|\s)(سوبر ?ماركت|هايبر ?ماركت|ماركت|سوبر|هايبر|فرع|اكسبريس|supermarket|hypermarket|market|super|hyper|express|branch)(?=\s|$)/giu;

/** اسم المحل للمطابقة: نفس تطبيع itemKey، من غير الكلمات العامة والرموز. */
export function storeKey(name: string): string {
  return itemKey(name).replace(STORE_NOISE, " ").replace(/[^\p{L}\p{N} ]/gu, " ").replace(/\s+/g, " ").trim();
}

/** نفس المحل؟ واحد من الاسمين جوه التاني بعد التطبيع، والأقصر ٣ حروف على الأقل. */
export function sameStore(a: string, b: string): boolean {
  const x = storeKey(a);
  const y = storeKey(b);
  if (!x || !y) return false;
  const [short, long] = x.length <= y.length ? [x, y] : [y, x];
  return short.length >= 3 && long.includes(short);
}

/**
 * الناقص عند العميل اللي اتشاف في محل بنفس الاسم (بلاغات price_index — فواتير اتصوّرت أو
 * أسعار اتكتبت) خلال [maxHours]. الأحدث لكل صنف. «بنفس الاسم» مش «نفس الفرع»: price_index
 * مافيهوش إحداثيات، والرسالة بتقول كده بصراحة.
 */
export function seenHereItems(
  reports: Array<{ item_name: string | null; store_name: string | null; timestamp: string | null }>,
  storeName: string,
  missing: string[],
  nowMs: number,
  maxHours = 72,
): SeenHere[] {
  const out: SeenHere[] = [];
  for (const want of missing) {
    const key = itemKey(want);
    if (key.length < 2) continue;
    let best: number | null = null;
    for (const r of reports) {
      if (!r.item_name || !r.store_name || !r.timestamp) continue;
      if (!sameStore(r.store_name, storeName)) continue;
      const reported = itemKey(r.item_name);
      if (!reported.includes(key) && !key.includes(reported)) continue;
      const hours = (nowMs - Date.parse(r.timestamp)) / 3_600_000;
      if (!(hours >= 0 && hours <= maxHours)) continue;
      if (best === null || hours < best) best = hours;
    }
    if (best !== null) out.push({ item: want, hours: best });
  }
  return out.sort((a, b) => a.hours - b.hours);
}

/**
 * بيحوّل رد `agent_proactive_scan()` لرد الإندبوينت. `ok` = مفيش ولا فشل.
 *
 * `null`/شكل مش متوقع (الدالة لسه `void` قبل ما ميجريشن 20260913161000 توصل) بيتعامل
 * كصفر فشل — نفس سلوك الإندبوينت القديم بالظبط، عشان ترتيب النشر (فانكشن قبل ميجريشن
 * أو العكس) مايكسرش حاجة. أي رقم فشل موجب لازم يطلع `ok: false`.
 */
export function summarizeProactiveScan(raw: unknown): {
  ok: boolean;
  scanned: number;
  failed: number;
  failed_users: number;
  skipped_orphans: number;
  suppressed: number;
  errors: unknown[];
} {
  const r = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : 0);
  const failed = num(r.failed);
  return {
    ok: failed <= 0,
    scanned: num(r.scanned),
    failed,
    failed_users: num(r.failed_users),
    skipped_orphans: num(r.skipped_orphans),
    // مراحل الماسح اتخطّت لأن العميل رفض النوع ده (20260913190000) — مش فشل، بس لازم يبان.
    suppressed: num(r.suppressed),
    errors: Array.isArray(r.errors) ? r.errors : [],
  };
}

/**
 * Task 16.3: on exhausted retries, what to do. `chat` never queues silently — the user
 * is waiting right now, so it gets an honest message instead of a generic {queued:true}
 * with no reply. Every other trigger (daily/event) queues for the drain cron.
 */
export function decideOnBrainFailure(trigger: string): { shouldQueue: boolean; status: number; body: Record<string, unknown> } {
  if (trigger === "chat") {
    return { shouldQueue: false, status: 200, body: { message: "زاد مش قادر يفكر دلوقتي، جرب بعد شوية" } };
  }
  return { shouldQueue: true, status: 200, body: { queued: true } };
}

/**
 * مواعيد الجرعات — التطبيع الحتمي.
 *
 * الأداة كانت بتقول للموديل حرفياً "احسب dose_times من **الوقت الحالي** والفاصل اللي
 * قاله العميل"، والبرومبت مش بيدّي الموديل الوقت الحالي ولا المنطقة الزمنية أصلاً. يعني
 * كان بيخترع نقطة بداية. النتيجة في بيانات الإنتاج (2026-08-16): "سبروفار" مواعيده
 * `02:00,14:00` و"اجمانتين" مواعيده `01:30,13:30` — منبه دوا بيرن الساعة ١:٣٠ بالليل كل
 * يوم. دي مش غلطة تجميلية: المريض بيتصحّى، وغالباً بيقفل المنبه ويرجع ينام، فالجرعة
 * بتتفوّت والالتزام بالعلاج بيقل.
 *
 * التصليح مش برومبت بس — البرومبت اتظبط كمان، بس الحارس هنا حتمي:
 *
 * - أي `HH:MM` مش صالح بيتشال بدل ما يوصل للجدول ويفضل مكسور.
 * - لو مفيش أي ميعاد صالح، بنشتق المواعيد من `daily_dose_count` بمراسي قياسية.
 * - لو أي ميعاد وقع في نافذة النوم (00:00–05:59) **والعميل مانطقش ساعة بعينها**
 *   (`times_explicit` مش true)، بنستبدل الجدول كله بالمرساة القياسية لنفس عدد الجرعات.
 *   الشرط ده مقصود: مريض قال "الساعة ٢ بالليل" فعلاً له الحق ياخد ٢ بالليل.
 */
const DOSE_TIME_ANCHORS: Record<number, string[]> = {
  1: ["09:00"],
  2: ["09:00", "21:00"],
  3: ["08:00", "14:00", "20:00"],
  4: ["08:00", "13:00", "18:00", "23:00"],
  5: ["07:00", "11:00", "15:00", "19:00", "23:00"],
  6: ["06:00", "10:00", "14:00", "18:00", "22:00", "23:59"],
};
const NIGHT_WINDOW_END_MINUTES = 6 * 60; // 06:00

export function normalizeDoseTimes(
  raw: unknown,
  dailyDoseCount?: unknown,
  timesExplicit?: unknown,
): string | null {
  const parsed: string[] = [];
  if (typeof raw === "string") {
    for (const chunk of raw.split(",")) {
      const m = /^\s*(\d{1,2}):(\d{2})\s*$/.exec(chunk);
      if (!m) continue;
      const h = Number(m[1]);
      const min = Number(m[2]);
      // 24:00 is not a clock time; the schema already bans it, but a model that emits it
      // anyway must not land a value LocalTime.parse() will reject on the phone.
      if (!Number.isInteger(h) || !Number.isInteger(min) || h > 23 || min > 59) continue;
      const norm = `${String(h).padStart(2, "0")}:${String(min).padStart(2, "0")}`;
      if (!parsed.includes(norm)) parsed.push(norm);
    }
  }

  const count = Number(dailyDoseCount);
  const wanted = Number.isFinite(count) && count >= 1 && count <= 6
    ? Math.trunc(count)
    : (parsed.length >= 1 ? parsed.length : 0);

  if (parsed.length === 0) {
    if (wanted === 0) return null;
    return (DOSE_TIME_ANCHORS[wanted] ?? DOSE_TIME_ANCHORS[1]).join(",");
  }

  if (timesExplicit === true) return parsed.sort().join(",");

  const hitsNightWindow = parsed.some((t) => {
    const [h, m] = t.split(":").map(Number);
    return h * 60 + m < NIGHT_WINDOW_END_MINUTES;
  });
  if (!hitsNightWindow) return parsed.sort().join(",");

  const anchor = DOSE_TIME_ANCHORS[parsed.length] ?? DOSE_TIME_ANCHORS[wanted] ?? DOSE_TIME_ANCHORS[1];
  return anchor.join(",");
}

/** نافذة "نفس الدفعة" بين إشعارين — لازم تفضل مطابقة لـ interval '15 minutes' في
 *  private.zad_resolve_transaction_proposal_impl (20260913213000). */
export const DUPLICATE_PROPOSAL_WINDOW_MS = 15 * 60 * 1000;

/**
 * من اقتراحات نفس العميل بنفس المبلغ خلال النافذة، أنهي واحد الإشعار الجديد مكرر منه؟
 *
 * البنك بيقول "تم خصم 500 من بطاقتك" وInstaPay بيقول "تم دفع فاتورة الإنترنت 500" —
 * مافيش بينهم ولا كلمة مشتركة، فالمبلغ والوقت هما الإشارة الوحيدة المتاحة. ده سؤال
 * للعميل مش حكم: الاقتراح الجديد بيتعمل عادي وبيتعلّم بس، والتطبيق وتيليجرام بيسألوا
 * "هل دي نفس المعاملة؟".
 *
 * - اتجاه معروف ومختلف (خصم 500 وإيداع 500) = مش نفس الدفعة.
 * - اتجاه مش معروف في أي طرف = ممكن، يتسأل.
 * - الأقدم هو الأصل، مش الأحدث: لو تلات إشعارات لنفس الدفعة، التاني والتالت يشاوروا
 *   على الأول، مش سلسلة (تالت ← تاني ← أول) تتقطع لو التاني اترفض.
 */
export function pickDuplicateProposalSibling(
  siblings: Array<{ id: string; status: string; txn_kind: string | null; transaction_id: string | null; created_at: string }>,
  txnKind: string | null,
): { id: string } | null {
  const candidates = siblings
    .filter((s) =>
      ["awaiting_confirmation", "needs_classification"].includes(s.status) ||
      // متقيد والعميل مسح معاملته بعدين = مابقاش بيعدّ في الرصيد، مش أصل تكرار.
      (s.status === "posted" && s.transaction_id != null)
    )
    .filter((s) => s.txn_kind == null || txnKind == null || s.txn_kind === txnKind)
    .sort((a, b) => Date.parse(a.created_at) - Date.parse(b.created_at));
  return candidates.length > 0 ? { id: candidates[0].id } : null;
}

/** نافذة الدمج التلقائي بين قنوات مختلفة لنفس الدفعة — أضيق من نافذة السؤال (١٥ دقيقة). */
export const CROSS_CHANNEL_TWIN_WINDOW_MS = 5 * 60 * 1000;

/**
 * نفس الدفعة جت من تطبيق تاني؟ ← تتدمج من غير سؤال (٢٠٢٦-٠٩-٢٥).
 *
 * بلاغ: «لما بصرف بيجيلي رسالة ونتفكيشن من البنك وInstaPay — ٣ إشعارات لنفس العملية».
 * [pickDuplicateProposalSibling] كان بيعمل اقتراح لكل واحد ويسأل «هل دي نفس المعاملة؟»
 * — يعني ٣ رسايل على تليجرام لدفعة واحدة.
 *
 * هنا الدمج صامت بس لما الإشارة قوية: **تطبيق مختلف** (SMS مقابل تطبيق البنك مقابل
 * المحفظة)، نفس المبلغ والعملة، اتجاه متوافق، وخلال ٥ دقايق. دفعتين حقيقيتين بنفس
 * المبلغ ورا بعض بتوصلوا من **نفس** القنوات مرتين، فإشعارين من نفس التطبيق مابيتدمجوش
 * هنا — بيفضلوا على السؤال القديم.
 */
export function pickCrossChannelTwin(
  siblings: Array<{
    id: string; status: string; txn_kind: string | null; currency: string | null;
    transaction_id: string | null; created_at: string; package_name: string | null;
  }>,
  incoming: { packageName: string; currency: string | null; txnKind: string | null },
  now: number,
): { id: string; status: string } | null {
  const cur = (v: string | null) => (v ?? "").trim().toUpperCase();
  const twins = siblings
    .filter((s) =>
      ["awaiting_confirmation", "needs_classification"].includes(s.status) ||
      (s.status === "posted" && s.transaction_id != null)
    )
    .filter((s) => s.package_name != null && s.package_name !== incoming.packageName)
    .filter((s) => now - Date.parse(s.created_at) <= CROSS_CHANNEL_TWIN_WINDOW_MS)
    .filter((s) => !cur(s.currency) || !cur(incoming.currency) || cur(s.currency) === cur(incoming.currency))
    .filter((s) => s.txn_kind == null || incoming.txnKind == null || s.txn_kind === incoming.txnKind)
    .sort((a, b) => Date.parse(a.created_at) - Date.parse(b.created_at));
  return twins.length > 0 ? { id: twins[0].id, status: twins[0].status } : null;
}


/**
 * الوقت دلوقتي بتوقيت العميل — للـsnapshot. من غيره «فكّريني بكرة الساعة ٥» كان الموديل
 * بيحسبه من إحساسه بالتاريخ: الـsnapshot كان فيه حدود دورة الميزانية بس، مفيش "النهارده
 * كام والساعة كام" (اتقاس ٢٠٢٦-٠٩-١٤). offset صريح عشان الموديل يكتب starts_at بنفس
 * المنطقة (add_appointment بترفض وقت من غير منطقة).
 */
export function localNowContext(timeZone: string, now: Date = new Date()): {
  iso_local: string; date: string; time: string; weekday: string; utc_offset: string; time_zone: string;
} {
  const tz = (() => {
    try { new Intl.DateTimeFormat("en-US", { timeZone }); return timeZone; } catch { return "UTC"; }
  })();
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-CA", {
      timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hour12: false,
      timeZoneName: "longOffset",
    }).formatToParts(now).map((p) => [p.type, p.value]),
  ) as Record<string, string>;
  const hour = parts.hour === "24" ? "00" : parts.hour;
  const offsetRaw = (parts.timeZoneName ?? "GMT").replace("GMT", "");
  const utcOffset = offsetRaw === "" ? "+00:00" : offsetRaw;
  const date = `${parts.year}-${parts.month}-${parts.day}`;
  const time = `${hour}:${parts.minute}`;
  const weekday = new Intl.DateTimeFormat("ar-EG", { timeZone: tz, weekday: "long" }).format(now);
  return { iso_local: `${date}T${time}:00${utcOffset}`, date, time, weekday, utc_offset: utcOffset, time_zone: tz };
}

// ── ساعات الهدوء (الفجوة ١٠، قرار المالك ٢٠٢٦-٠٩-٢٩) ─────────────────────────
// من ١١ بالليل لـ٧ الصبح بتوقيت سوق العميل، مش توقيت السيرفر. الجرعات مستثناة
// بالكامل؛ المستثنيات التانية جنب كل مستخدم (voiceMoments.ts، processDueAgentTasks).
export const QUIET_START_HOUR = 23;
export const QUIET_END_HOUR = 7;

/** الساعة المحلية (٠-٢٣) جوه الهدوء؟ */
export function isQuietHour(localHour: number): boolean {
  return localHour >= QUIET_START_HOUR || localHour < QUIET_END_HOUR;
}

/** الساعة المحلية دلوقتي في [timeZone]. */
export function localHourIn(timeZone: string, nowMs: number): number {
  return Number(localNowContext(timeZone, new Date(nowMs)).time.slice(0, 2));
}

/**
 * إمتى الهدوء يخلص: ٧ الصبح الجاية بتوقيت العميل، كلحظة UTC. `null` لو الوقت مش هدوء.
 * بعد ١١ بالليل = ٧ بكرة؛ بعد نص الليل = ٧ النهارده.
 */
export function quietEndsAt(timeZone: string, nowMs: number): string | null {
  const local = localNowContext(timeZone, new Date(nowMs));
  const hour = Number(local.time.slice(0, 2));
  if (!isQuietHour(hour)) return null;
  let date = local.date;
  if (hour >= QUIET_START_HOUR) {
    const next = new Date(Date.parse(`${local.date}T00:00:00Z`) + 86_400_000);
    date = next.toISOString().slice(0, 10);
  }
  return resolveLocalIso(`${date}T${String(QUIET_END_HOUR).padStart(2, "0")}:00`, local.utc_offset);
}

/**
 * مبادرة (مش طلب من العميل) استحقت جوه الهدوء ⇐ تتأجل لـ٧ الصبح بتوقيته. `null` = نفّذ.
 * متابعة الدوا مستثناة زي الجرعات (قرار المالك)، وطلبات العميل (`reminder`) عمرها ما
 * بتتأجل — هو اللي اختار الوقت.
 */
export function postponeForQuietHours(kind: string | null | undefined, timeZone: string, nowMs: number): string | null {
  if (!agentTaskNotice(kind).proactive || (kind ?? "").trim() === "med_followup") return null;
  return quietEndsAt(timeZone, nowMs);
}

/**
 * وقت كتبه الموديل ⇐ لحظة مطلقة بتوقيت العميل (٢٠٢٦-٠٩-١٩).
 *
 * بلاغ: «لخبطة صريحة في التوقيت — بيخلط بين UTC وتوقيت المستخدم المحلي +03:00 / +02:00».
 *
 * السبب: `add_appointment` كان بيعمل `new Date(input.starts_at).toISOString()` على طول.
 * وصف الأداة بيقول للموديل يكتب المنطقة، بس ولا حاجة كانت **بتفرضها**. أول ما الموديل
 * يكتب `2026-09-19T21:00:00` من غير منطقة، جافاسكريبت بتقراها بتوقيت **السيرفر** — وسيرفر
 * سوبابيز على UTC. يعني ميعاد ٩ بالليل في القاهرة بيتخزن ٩ بالليل UTC = ١١ بالليل بتوقيته،
 * وفي الرياض ١٢ بالليل. التذكير بيرن بعد الميعاد بساعتين أو تلاتة، والعميل بيشوف البوت
 * بيقوله ميعاد مختلف عن اللي طلبه. نفس الغلط في `update_appointment` لما يأجّل ميعاد.
 *
 * القاعدة دلوقتي: وقت **بمنطقة صريحة** (Z أو ±HH:MM) بيتحترم زي ما هو — الموديل قال
 * لحظة مطلقة ومفيش لبس. وقت **من غير منطقة** بيتقري بتوقيت العميل هو، مش بتوقيت السيرفر.
 *
 * بيرجع `null` لو النص مش وقت أصلاً — والمنادي بيرفض الأداة بدل ما يكتب `Invalid Date`.
 *
 * @param raw النص زي ما الموديل كتبه.
 * @param utcOffset إزاحة العميل من `localNowContext().utc_offset`، مثال `+03:00`.
 */
export function resolveLocalIso(raw: unknown, utcOffset: string): string | null {
  const text = String(raw ?? "").trim();
  if (!text) return null;
  // فيه منطقة صريحة؟ (Z في الآخر، أو ±HH:MM / ±HHMM / ±HH بعد جزء الوقت)
  const hasZone = /(?:Z|[+-]\d{2}:?\d{2}|[+-]\d{2})$/.test(text) && /\d{2}:\d{2}/.test(text);
  const offset = /^[+-]\d{2}:\d{2}$/.test(utcOffset) ? utcOffset : "+00:00";
  let candidate = text;
  if (!hasZone) {
    const dateOnly = /^\d{4}-\d{2}-\d{2}$/.test(text);
    if (dateOnly) candidate = `${text}T00:00:00${offset}`;
    else if (/^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2})?$/.test(text)) {
      const normalized = text.replace(" ", "T");
      candidate = `${normalized.length === 16 ? `${normalized}:00` : normalized}${offset}`;
    } else return null; // شكل مش متوقع — أحسن نرفض من إننا نخمّن منطقة
  }
  const parsed = new Date(candidate);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

/**
 * مطابقة اسم دوا قاله العميل باسم مسجّل في جدوله — بدون تخمين (٢٠٢٦-٠٩-١٩).
 *
 * بلاغ: «البوت بيولّد أدوية وهمية مش موجودة ولا بيسجّل الجرعة فعلياً».
 *
 * المطابقة القديمة كانت `a.includes(b) || b.includes(a)` على الاسم الخام. مشكلتها
 * الحقيقية مش إنها بتقبل أسماء وهمية — دي بترفضها — المشكلة إنها بتقبل **الدوا الغلط**:
 *  - العميل يقول «خدت الحبة» ⇒ "حبة" جوه "حبة الضغط" **و** "حبوب الحديد" ⇒ أول واحد
 *    في الليستة بيتسجل، واللي اتاخد فعلاً بيفضل مفتوح فالكرون يفضل يزن عليه.
 *  - حرفين زي «د» بيطابقوا أي حاجة.
 *  - «بانادول» و«بندول» مابيطابقوش لأن الألف واللزقة العربية مابتتوحّدش.
 *
 * تسجيل جرعة على الدوا الغلط غلط طبي، مش غلط عرض. فالقاعدة هنا: مطابقة واحدة واضحة
 * أو مفيش. أكتر من مرشّح = `ambiguous` والمنادي بيسأل العميل يحدد، مايختارش بالنيابة عنه.
 */
export interface MedicineMatch<T> {
  /** الصف الوحيد اللي طابق. */
  item?: T;
  /** أكتر من دوا طابق الاسم ده — لازم العميل يوضّح. */
  ambiguous?: string[];
}

/** توحيد عربي بسيط: تشكيل، ألف/ياء/تاء مربوطة، ولزقة "ال" التعريف. */
export function normalizeMedicineName(raw: string): string {
  return raw
    // NFKD بتفكّك «أ» لـ«ا» + همزة فوق، و\p{Mn} بتشيل كل علامة غير متباعدة بعدها
    // (تشكيل، همزة فوق/تحت، ألف خنجرية). مدى مكتوب باليد كان بيقف عند السكون
    // فـ«أوجمنتين» مكانتش بتطابق «اوجمنتين» — وهي نفس الدوا.
    .normalize("NFKD")
    .replace(/\p{Mn}/gu, "")
    .replace(/\u0640/g, "")
    .replace(/[\u0625\u0623\u0622\u0671]/g, "\u0627")
    .replace(/\u0649/g, "\u064A")
    .replace(/\u0624/g, "\u0648")
    .replace(/\u0626/g, "\u064A")
    .replace(/\u0629/g, "\u0647")
    .replace(/^\u0627\u0644/, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

export function matchMedicineByName<T extends { name: string }>(rows: readonly T[], spoken: string): MedicineMatch<T> {
  const needle = normalizeMedicineName(spoken);
  if (needle.length < 3) return {}; // «د»، «حبة» — مش اسم، مايتخمّنش عليه
  const scored = rows.map((row) => {
    const hay = normalizeMedicineName(row.name);
    if (hay === needle) return { row, rank: 0 };
    // كلمة كاملة جوه الاسم («بانادول» في «بانادول اكسترا»)، أو العكس («بانادول اكسترا»
    // والعميل قال الاسم كامل والمسجّل أقصر). اللزقة بتتقارن على حدود الكلمة عشان
    // "حبة" ماتطابقش "حبوب".
    const words = hay.split(" ");
    if (words.includes(needle)) return { row, rank: 1 };
    if (needle.split(" ").includes(hay)) return { row, rank: 1 };
    // بادئة كلمة: «بندو» ⇒ «بندول». ٤ حروف على الأقل عشان ماتبقاش مصادفة.
    if (needle.length >= 4 && words.some((w) => w.startsWith(needle))) return { row, rank: 2 };
    return null;
  }).filter((v): v is { row: T; rank: number } => v !== null);

  if (scored.length === 0) return {};
  const best = Math.min(...scored.map((s) => s.rank));
  const winners = scored.filter((s) => s.rank === best);
  if (winners.length > 1) return { ambiguous: winners.map((w) => w.row.name) };
  return { item: winners[0].row };
}

/**
 * التزام الدوا آخر [days] يوم، للـsnapshot (٢٠٢٦-٠٩-٢٥).
 *
 * العقل كان بيقرا `zad_dose_log` بس — الجدول القديم. كل التسجيل الحالي (زرار تليجرام،
 * `zad_log_pharmacy_dose_atomic`، التطبيق الجديد) بيروح `zad_pharmacy_doses`، فالعقل
 * كان شايف العميل مابياخدش دواه وهو بياخده (المالك: ٢٠ جرعة متسجلة، العقل شايف ١).
 *
 * `zad_pharmacy_doses` فيه بس الجرعات اللي اتجاوب عليها، مش المجدولة، فالمطلوب بيتحسب
 * من `dose_times` بتوقيت الحساب: كل خانة عدّت في النافذة وبعد ما الدوا اتضاف.
 * الجدول القديم فيه صفوف مجدولة، فلو هو اللي أكبر (أدوية قديمة من غير dose_times) بيكسب.
 */
export function doseAdherence(
  items: Array<{ dose_times?: string | null; created_at?: string | null }>,
  answered: Array<{ status?: string | null; scheduled_at?: string | null }>,
  legacy: Array<{ scheduled_at?: string | null; taken_at?: string | null }>,
  utcOffset: string,
  now: Date = new Date(),
  days = 14,
): { scheduled: number; taken: number; skipped: number } | null {
  const windowStart = now.getTime() - days * 86_400_000;
  const offsetMs = (() => {
    const m = /^([+-])(\d{2}):(\d{2})$/.exec(utcOffset);
    return m ? (m[1] === "-" ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3])) * 60_000 : 0;
  })();
  let expected = 0;
  for (const item of items) {
    const created = item.created_at ? Date.parse(item.created_at) : NaN;
    const from = Number.isFinite(created) ? Math.max(windowStart, created) : windowStart;
    const slots = String(item.dose_times ?? "").split(",").map((s) => s.trim())
      .filter((s) => /^([01]?\d|2[0-3]):[0-5]\d$/.test(s));
    for (let d = 0; d <= days; d++) {
      // منتصف ليل اليوم المحلي (d يوم قبل النهارده) بالـUTC.
      const localNow = new Date(now.getTime() + offsetMs);
      const localMidnight = Date.UTC(localNow.getUTCFullYear(), localNow.getUTCMonth(), localNow.getUTCDate() - d);
      for (const s of slots) {
        const [h, m] = s.split(":").map(Number);
        const at = localMidnight + (h * 60 + m) * 60_000 - offsetMs;
        if (at <= now.getTime() && at >= from) expected++;
      }
    }
  }
  const inWindow = (iso?: string | null) => {
    const t = iso ? Date.parse(iso) : NaN;
    return Number.isFinite(t) && t >= windowStart && t <= now.getTime();
  };
  const newRows = answered.filter((r) => inWindow(r.scheduled_at));
  const legacyDue = legacy.filter((r) => inWindow(r.scheduled_at));
  const scheduled = Math.max(expected, legacyDue.length);
  if (scheduled === 0) return null;
  const taken = newRows.filter((r) => r.status === "taken").length + legacyDue.filter((r) => r.taken_at).length;
  return {
    scheduled,
    taken: Math.min(scheduled, taken),
    skipped: newRows.filter((r) => r.status === "skipped").length,
  };
}

/**
 * هل الدوا متجدد (مزمن/مستمر) ولا كورس ليه نهاية — قرار المالك ٢٠٢٦-١٠-٠١: الدوا ينزل قايمة البقالة
 * لوحده لما يقرب يخلص **بس لو متجدد**؛ المضاد الحيوي والعلاج المؤقت لأ. `is_recurring` الصريح من
 * الموديل بيكسب؛ من غيره تصنيف «مزمن» = متجدد؛ وإلا null (الجدول افتراضيه false).
 */
export function pharmacyIsRecurring(input: { is_recurring?: unknown; category?: unknown }): boolean | null {
  if (typeof input.is_recurring === "boolean") return input.is_recurring;
  if (input.category === "مزمن") return true;
  if (input.category === "مضاد حيوي") return false;
  return null;
}
