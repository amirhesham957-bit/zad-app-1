// «الحليب خلص — جهزتلك لينك أمازون» (صاحب التطبيق، ٢٠٢٦-١٠-١٠).
//
// لما صنف ضروري يخلص من المخزون (الكمية تنزل لصفر)، تريجر على zad_inventory
// (20261011120000_restock_link.sql) بيكتب مهمة restock_link بعد ربع ساعة، وكل صنف يخلص في
// الربع ساعة دي بيتجمع في نفس المهمة. المنفّذ هنا مابيندهش الموديل: الرسالة ثابتة ورخيصة،
// واللينك لازم يوصل زي ما هو بالتاج — موديل ممكن يختصره أو يغيّره.
//
// شروط صاحب التطبيق عشان ماتبقاش إعلان مزعج:
// - الأساسيات بس: حاجات بتخلص وبتتطلب بانتظام (ألبان، قهوة، منظفات…)، مش أي صنف في المخزن.
//   الطازة (خضار، فاكهة، لحمة، عيش، بيض) بتتشرى من تحت البيت مش من أمازون.
// - صياغة خدمة مش إعلان: جملة زي صاحبك، مفيش «عرض» ولا «اشتري الآن».
// وكمان: رسالة واحدة في اليوم بالكتير (التريجر)، ومفيش رسالة لو العميل رجّع الصنف قبل ما
// تتبعت، ولا في وضع الطوارئ (مفيش اقتراح شراء خالص)، والكتم والساعات الهادية زي أي مبادرة.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { marketFor, searchUrl } from "../_shared/amazonMarket.ts";
import { isBrokeModeActive } from "../_shared/brokeMode.ts";
import { normalizeItemName, productFamilyOf } from "./lowStock.ts";

/** كلمات الأساسيات اللي بتتطلب أونلاين — كلمة كاملة من اسم الصنف (بعد «ال»). بيانات مطابقة، مش نص واجهة. */
const ESSENTIAL_WORDS = new Set([
  // ألبان طويلة العمر ومشروبات
  "حليب", "لبن", "قهوه", "بن", "نسكافيه", "كابتشينو", "شاي", "كاكاو", "مياه", "ميه",
  // بقالة جافة
  "رز", "ارز", "سكر", "زيت", "مكرونه", "معكرونه", "دقيق", "ملح", "شوفان", "كورن", "عسل",
  // تنظيف
  "منظف", "منظفات", "مسحوق", "صابون", "كلور", "ديتول", "فلاش", "معطر", "اسفنج", "سلك",
  // عناية شخصية وبيت
  "شامبو", "بلسم", "معجون", "فرشه", "مزيل", "مناديل", "حفاض", "حفاضات", "بامبرز",
  "فوط", "قطن", "شفرات", "لوشن", "اكياس",
]);

/** «سائل غسيل»، «ورق تواليت» — عبارات من كلمتين. */
const ESSENTIAL_PHRASES = ["سائل غسيل", "ورق تواليت", "ورق مطبخ", "غسيل صحون", "معجون اسنان"];

/** فئات بتتطلب كلها: تنظيف وعناية. (الألبان والبقالة فيها طازة، فبتعدّي على الكلمات.) */
const ESSENTIAL_CATEGORIES = new Set(["منظفات", "العنايه", "عنايه", "عنايه شخصيه"]);

/** صنف ضروري بيتطلب من أمازون لما يخلص؟ */
export function isRestockEssential(name: string, category?: string | null): boolean {
  const n = normalizeItemName(name);
  if (!n) return false;
  if (ESSENTIAL_CATEGORIES.has(normalizeItemName(category ?? ""))) return true;
  const family = productFamilyOf(name);
  if (family === "مياه") return true;
  if (ESSENTIAL_PHRASES.some((p) => n.includes(p))) return true;
  return n.split(" ").some((w) => ESSENTIAL_WORDS.has(w.startsWith("ال") && w.length > 3 ? w.slice(2) : w));
}

export interface RestockRow { item_name: string | null; quantity: number | string | null; category?: string | null }

/**
 * الأصناف اللي تستاهل لينك: من أسماء المهمة، اللي لسه خلصانة دلوقتي (كل صفوفها صفر — رجّعها
 * في الربع ساعة = مفيش رسالة) وضرورية. ٣ بالكتير، بترتيب ما خلصت.
 */
export function restockItems(taskNames: string[], pantry: RestockRow[], limit = 3): string[] {
  const byName = new Map<string, RestockRow[]>();
  for (const row of pantry) {
    const key = normalizeItemName(row.item_name ?? "");
    if (!key) continue;
    byName.set(key, [...(byName.get(key) ?? []), row]);
  }
  const out: string[] = [];
  const seen = new Set<string>();
  for (const raw of taskNames) {
    const name = raw.trim();
    const key = normalizeItemName(name);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    const rows = byName.get(key);
    if (!rows?.length) continue; // اتمسح من المخزون — مش عارفين لسه محتاجه ولا لأ.
    if (rows.some((r) => Number(r.quantity) > 0)) continue;
    if (!isRestockEssential(name, rows.find((r) => r.category)?.category)) continue;
    out.push(name);
    if (out.length >= limit) break;
  }
  return out;
}

/**
 * الرسالة: جملة صاحب، ولينك لكل صنف. اللينكات في سطور «• اسم: لينك» — التطبيق بيحوّل السطور
 * دي لزراير في مركز الإشعارات (amazon_links.dart)، وتليجرام بياخد [plain] من غير لينكات
 * والزراير من [links] (لينك متشفّر بالعربي في نص الرسالة شكله وحش).
 */
export function restockMessage(items: Array<{ name: string; url: string }>): {
  title: string; body: string; plain: string; push: string; links: Array<{ name: string; url: string }>;
} {
  const linkLines = items.map((i) => `• ${i.name}: ${i.url}`).join("\n");
  if (items.length === 1) {
    const [{ name }] = items;
    const plain = `${name} خلص عندك. جهزتلك لينك أمازون لو تحب تطلبه دلوقتي ويوصلك لحد البيت.`;
    return {
      title: `🛒 ${name} خلص`,
      body: `${plain}\n${linkLines}`,
      plain,
      push: `${name} خلص — جهزتلك لينك أمازون لو تحب تطلبه.`,
      links: items,
    };
  }
  const names = items.map((i) => i.name).join("، ");
  const plain = `خلصوا عندك: ${names}. جهزتلك لينكات أمازون لو تحب تطلبهم دلوقتي.`;
  return {
    title: "🛒 حاجات خلصت عندك",
    body: `${plain}\n${linkLines}`,
    plain,
    push: `خلصوا: ${names} — جهزتلك لينكات أمازون لو تحب تطلبهم.`,
    links: items,
  };
}

export interface RestockTask { id: string; user_id: string; task_description: string }

export interface RestockDeps {
  pushDevice: (userId: string, title: string, body: string, data?: Record<string, string>) => Promise<unknown>;
  pushTelegram: (userId: string, title: string, body: string, taskId: string, links: Array<{ name: string; url: string }>) => Promise<unknown>;
  env: (name: string) => string | undefined;
  nowMs?: number;
}

/**
 * ينفّذ مهمة restock_link من غير موديل: يا إما رسالة باللينكات (done)، يا إما مفيش حاجة
 * تستاهل (cancelled — ومابتتحسبش في حد اليوم). الرسالة بتروح مركز الإشعارات وFCM (الضغطة
 * بتفتح الرئيسية، فيها كروت أمازون للنواقص) وتليجرام بأزرار الكتم، وبتتسجّل دور لزاد في
 * المحادثة المشتركة — عشان لو العميل رد «اطلبهولي» العقل يبقى عارف هو قال إيه.
 */
export async function deliverRestockLink(sb: SupabaseClient, task: RestockTask, deps: RestockDeps): Promise<"sent" | "skipped"> {
  const finish = (status: "done" | "cancelled", result: string) =>
    sb.from("agent_tasks").update({ status, result, updated_at: new Date().toISOString() }).eq("id", task.id);
  await sb.from("agent_tasks").update({ status: "running", updated_at: new Date().toISOString() }).eq("id", task.id);

  const [inv, user, broke] = await Promise.all([
    sb.from("zad_inventory").select("item_name,quantity,category").eq("user_id", task.user_id).limit(500),
    sb.from("zad_users").select("country").eq("id", task.user_id).maybeSingle(),
    sb.from("zad_broke_mode").select("ends_at,ended_at").eq("user_id", task.user_id).maybeSingle(),
  ]);
  if (inv.error) throw new Error(`zad_inventory: ${inv.error.message}`);
  if (isBrokeModeActive(broke.data as { ends_at?: string; ended_at?: string } | null, deps.nowMs ?? Date.now())) {
    await finish("cancelled", "وضع الطوارئ: مفيش اقتراح شراء");
    return "skipped";
  }
  const items = restockItems(task.task_description.split("\n"), (inv.data ?? []) as RestockRow[]);
  if (!items.length) {
    await finish("cancelled", "مفيش صنف ضروري لسه خالص");
    return "skipped";
  }
  const market = marketFor((user.data as { country?: string | null } | null)?.country, deps.env);
  const msg = restockMessage(items.map((name) => ({ name, url: searchUrl(market, name) })));

  await finish("done", msg.body);
  const [note, turn] = await Promise.all([
    sb.from("app_notifications").insert({ user_id: task.user_id, title: msg.title, message: msg.body }),
    sb.from("zad_chat_turns").insert({ user_id: task.user_id, role: "assistant", text: msg.body }),
  ]);
  if (note.error) console.error(`[restock_link] app_notifications failed for task ${task.id}:`, note.error.message);
  if (turn.error) console.error(`[restock_link] zad_chat_turns failed for task ${task.id}:`, turn.error.message);
  const [device, telegram] = await Promise.all([
    deps.pushDevice(task.user_id, msg.title, msg.push, { route: "home" }),
    deps.pushTelegram(task.user_id, msg.title, msg.plain, task.id, msg.links),
  ]);
  console.log(`[restock_link] task ${task.id}: ${items.length} item(s) on ${market.domain} → device: ${device}, telegram: ${telegram}`);
  return "sent";
}
