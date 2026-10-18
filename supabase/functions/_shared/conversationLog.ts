// محادثة واحدة لكل اللي حصل، مش لكل اللي اتكتب في الشات بس (طلب المالك ٢٠٢٦-١٠-١٨: «يكون واعي»).
//
// المقاس: ١٥/١٠ الساعة ٩:٤٨ بالليل العميل بعت صورة دوا على تليجرام، البوت قراها، وبعدها كتب «الدوا
// بعتهولك» — والعقل رد «ورّيني بعت إيه؟ صوّر روشتة». مسار الصور والزراير عمرهم ما كتبوا في
// zad_chat_turns، ومن مبادرات ١٧/١٠ الصبح الخمسة واحدة بس اتكتبت هناك. فزاد كان بيقول كلام وبيشوف
// صور ومايفتكرهمش.
//
// الصور والزراير بتتكتب كدور العميل («[بعت صورة: …]»)، ورد زاد زي ما اتبعت. المبادرات بتتكتب كدور
// زاد ومعاها [PROACTIVE_MARK] — العقل يعرف إنه هو اللي بدأ («زي ما قلتلك الصبح عن البنك»).

// deno-lint-ignore no-explicit-any
type Sb = any;

/** أول رسالة بعتها زاد من نفسه — العقل بيقراها كده في المحادثة. */
export const PROACTIVE_MARK = "(بعتّها من نفسي) ";

/** أقصى عدد مبادرات في شباك المحادثة اللي بيتبعت للعقل، عشان ماتزقّش الكلام الحقيقي برّه. */
export const MAX_PROACTIVE_IN_WINDOW = 3;

const MAX_TEXT = 4000;
const MAX_PROACTIVE_TEXT = 600;

export function proactiveTurn(title: string, body: string): string {
  const t = title.trim(), b = body.trim();
  const text = t && b && !b.startsWith(t) ? `${t}\n${b}` : (b || t);
  return PROACTIVE_MARK + text.slice(0, MAX_PROACTIVE_TEXT);
}

export function isProactiveTurn(text: string): boolean {
  return text.startsWith(PROACTIVE_MARK);
}

/**
 * بيكتب الأدوار بالترتيب (واحد ورا التاني عشان created_at يحفظ الترتيب). عمره ما يرمي — كتابة
 * فاشلة بتتسجل في اللوج والرسالة نفسها بتكون وصلت خلاص.
 */
export async function recordConversation(
  sb: Sb,
  userId: string,
  turns: ReadonlyArray<{ role: "user" | "assistant"; text: string }>,
): Promise<void> {
  try {
    for (const t of turns) {
      const text = t.text.trim().slice(0, MAX_TEXT);
      if (!text) continue;
      const { error } = await sb.from("zad_chat_turns").insert({ user_id: userId, role: t.role, text });
      if (error) {
        console.error("recordConversation failed:", error.message);
        return;
      }
    }
  } catch (e) {
    console.error("recordConversation threw:", e);
  }
}

/**
 * من الأقدم للأحدث: بيسيب آخر [max] مبادرات بس ويشيل الأقدم منهم، والكلام الحقيقي كله زي ما هو.
 */
export function trimProactive<T extends { role: string; text: string }>(turns: T[], max = MAX_PROACTIVE_IN_WINDOW): T[] {
  let keep = max;
  const out: T[] = [];
  for (let i = turns.length - 1; i >= 0; i--) {
    const t = turns[i];
    if (t.role === "assistant" && isProactiveTurn(t.text)) {
      if (keep <= 0) continue;
      keep--;
    }
    out.push(t);
  }
  return out.reverse();
}
