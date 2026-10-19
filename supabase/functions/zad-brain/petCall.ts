// «زادو جعان ومستنيك 🥺» — الرفيق بينادي العميل باسمه (ZAD_PLAN ٥.٥ ب، ٢٠٢٦-١٠-٢٠).
//
// المهمة بتتحط من zad_enqueue_pet_calls (20261020100000_pet_call.sql) لما الرفيق جعان أو عطشان والعميل
// مش فاتح التطبيق، وبتعدّي على نفس حراس الطابور زي أي مبادرة (الكتم، الهدوء، الساعتين، والمبادرتين في
// اليوم). هنا التسليم: من غير موديل، ورسالة ثابتة بصوت الرفيق — ودود ومستني، وعمره ما بيعاير ولا بيتكلم
// عن فلوس (خطة زاد، «البوت والرفيق»)، والرفيق المهمل بيزعل بس، مابيمرضش (ZAD_COMPANION.md).
//
// الحالة بتتقري تاني قبل الإرسال: العميل ممكن يكون أكّله بين الطابور والتسليم، وساعتها المهمة بتتلغي
// (مابتتحسبش في سقف اليوم).

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { proactiveTurn } from "../_shared/conversationLog.ts";

/** نفس عتبات zad_enqueue_pet_calls: أقل من ربع الشبع أو الري. */
export const HUNGRY_AFTER_MS = 15 * 3_600_000;
export const THIRSTY_AFTER_MS = 630 * 60_000;

export type PetNeed = "hungry" | "thirsty";

/** الرفيق محتاج إيه دلوقتي؟ الجوع قبل العطش، زي الطابور. */
export function petNeedNow(care: { fed_at: string; watered_at: string } | null, nowMs: number): PetNeed | null {
  if (!care) return null;
  const fed = Date.parse(care.fed_at);
  const watered = Date.parse(care.watered_at);
  if (Number.isFinite(fed) && nowMs - fed > HUNGRY_AFTER_MS) return "hungry";
  if (Number.isFinite(watered) && nowMs - watered > THIRSTY_AFTER_MS) return "thirsty";
  return null;
}

/** الرسالة بصوت الرفيق. [name] اسم شخصيته (زادو، بسبوس…). نص واجهة، عربي للإطلاق. */
export function petCallMessage(need: PetNeed, name: string): { title: string; body: string; push: string } {
  const who = name.trim() || "زادو";
  if (need === "hungry") {
    return {
      title: `🥺 ${who} مستنيك`,
      body: `${who} جعان ومستنيك 🥺 لقمة واحدة منك وهيفرح. افتح زاد وأكّله.`,
      push: `${who} جعان ومستنيك 🥺`,
    };
  }
  return {
    title: `💧 ${who} مستنيك`,
    body: `${who} عطشان ومستنيك 💧 شربة مية منك وهيرجع يلعب. افتح زاد واسقيه.`,
    push: `${who} عطشان ومستنيك 💧`,
  };
}

export interface PetCallTask { id: string; user_id: string; task_description: string }

export interface PetCallDeps {
  pushDevice: (userId: string, title: string, body: string, data?: Record<string, string>) => Promise<unknown>;
  pushTelegram: (userId: string, title: string, body: string, taskId: string) => Promise<unknown>;
  nowMs?: number;
}

/** ينفّذ pet_call: «sent» لو اتبعت، «skipped» لو الرفيق مابقاش محتاج (cancelled، مابيتعدّش). */
export async function deliverPetCall(sb: SupabaseClient, task: PetCallTask, deps: PetCallDeps): Promise<"sent" | "skipped"> {
  const finish = (status: "done" | "cancelled", result: string) =>
    sb.from("agent_tasks").update({ status, result, updated_at: new Date().toISOString() }).eq("id", task.id);
  await sb.from("agent_tasks").update({ status: "running", updated_at: new Date().toISOString() }).eq("id", task.id);

  const [care, companion] = await Promise.all([
    sb.from("zad_companion_care").select("fed_at,watered_at").eq("user_id", task.user_id).maybeSingle(),
    sb.from("zad_companion").select("persona").eq("user_id", task.user_id).maybeSingle(),
  ]);
  if (care.error) throw new Error(`zad_companion_care: ${care.error.message}`);
  const need = petNeedNow(care.data as { fed_at: string; watered_at: string } | null, deps.nowMs ?? Date.now());
  if (!need) {
    await finish("cancelled", "الرفيق مابقاش محتاج — العميل اهتم بيه قبل النداء");
    return "skipped";
  }
  let name = "زادو";
  const persona = (companion.data as { persona?: string | null } | null)?.persona;
  if (persona) {
    const { data: item } = await sb.from("zad_companion_items").select("name_ar").eq("id", persona).maybeSingle();
    name = (item as { name_ar?: string | null } | null)?.name_ar ?? name;
  }
  const msg = petCallMessage(need, name);

  await finish("done", msg.body);
  const [note, turn] = await Promise.all([
    sb.from("app_notifications").insert({ user_id: task.user_id, title: msg.title, message: msg.body }),
    sb.from("zad_chat_turns").insert({ user_id: task.user_id, role: "assistant", text: proactiveTurn(msg.title, msg.body) }),
  ]);
  if (note.error) console.error(`[pet_call] app_notifications failed for task ${task.id}:`, note.error.message);
  if (turn.error) console.error(`[pet_call] zad_chat_turns failed for task ${task.id}:`, turn.error.message);
  const [device, telegram] = await Promise.all([
    deps.pushDevice(task.user_id, msg.title, msg.push, { route: "home" }),
    deps.pushTelegram(task.user_id, msg.title, msg.body, task.id),
  ]);
  console.log(`[pet_call] task ${task.id}: ${need} → device: ${device}, telegram: ${telegram}`);
  return "sent";
}
