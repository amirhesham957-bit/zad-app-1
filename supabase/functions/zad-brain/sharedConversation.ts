// One conversation across every channel: the app's chat, its voice sheet and
// Telegram.
//
// The Telegram bot kept its turns in zad_chat_turns and the app kept its own
// on the phone, so each channel talked to a different Zad — tell it something
// by voice and the bot had never heard it (owner, 2026-09-30). The brain now
// writes every app turn to the same table and reads the last turns from it,
// whichever channel they came through; Telegram, which already read the whole
// table, sees the app's turns too.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export type SharedTurn = { role: "user" | "assistant"; text: string };

/** What handleAgentTurn takes (`.slice(-8)`). */
export const SHARED_HISTORY_TURNS = 8;

/** zad_chat_turns rows (newest first) → the brain's history (oldest first). */
export function toSharedHistory(rows: Array<{ role: string; text: string }>): SharedTurn[] {
  return [...rows].reverse()
    .filter((r) => typeof r.text === "string" && r.text.trim())
    .map((r) => ({ role: r.role === "assistant" ? "assistant" as const : "user" as const, text: r.text }));
}

/**
 * The conversation to answer in: the shared one when it has anything, else
 * what the client sent (an account whose app turns were never stored yet, or a
 * failed read — a turn without memory, never a broken one).
 */
export function pickHistory(shared: SharedTurn[] | null, client: SharedTurn[]): SharedTurn[] {
  return shared && shared.length > 0 ? shared.slice(-SHARED_HISTORY_TURNS) : client.slice(-SHARED_HISTORY_TURNS);
}

/** The last turns on any channel, or null when they could not be read. */
export async function loadSharedHistory(sb: SupabaseClient, userId: string): Promise<SharedTurn[] | null> {
  try {
    const { data, error } = await sb.from("zad_chat_turns")
      .select("role,text")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(SHARED_HISTORY_TURNS);
    if (error) {
      console.error("loadSharedHistory failed:", error.message);
      return null;
    }
    return toSharedHistory(data ?? []);
  } catch (e) {
    console.error("loadSharedHistory threw:", e);
    return null;
  }
}

/**
 * Stores one app turn — the customer's words, then Zad's reply — so the other
 * channels hear it. A failed write is logged and the reply still goes out.
 */
export async function recordSharedTurn(sb: SupabaseClient, userId: string, message: string, reply: string): Promise<void> {
  const rows = [
    { user_id: userId, role: "user", text: message.trim().slice(0, 4000) },
    { user_id: userId, role: "assistant", text: reply.trim().slice(0, 4000) },
  ].filter((r) => r.text);
  if (rows.length < 2) return;
  try {
    // One row after the other so created_at keeps the order (a single insert of two
    // rows can stamp them in the same microsecond).
    for (const row of rows) {
      const { error } = await sb.from("zad_chat_turns").insert(row);
      if (error) {
        console.error("recordSharedTurn failed:", error.message);
        return;
      }
    }
  } catch (e) {
    console.error("recordSharedTurn threw:", e);
  }
}

/**
 * What Zad actually said in a turn: the model's words, then the receipts the customer saw
 * («✅ تم تسجيل الميعاد…») and what waits for a tap. A turn whose whole answer was a receipt
 * used to be stored with no reply at all (2026-09-30 22:34, «اصحي كمان دقيقة»), so the next
 * day's questions read it as a request nobody had answered — and carried it out again.
 */
export function spokenRecord(payload: { reply?: unknown; executed?: unknown; proposals?: unknown }): string {
  const lines: string[] = [];
  if (typeof payload.reply === "string" && payload.reply.trim()) lines.push(payload.reply.trim());
  for (const e of Array.isArray(payload.executed) ? payload.executed : []) {
    const summary = (e as { summary?: unknown })?.summary;
    if (typeof summary === "string" && summary.trim()) lines.push(`✅ ${summary.trim()}`);
  }
  for (const p of Array.isArray(payload.proposals) ? payload.proposals : []) {
    const summary = (p as { summary?: unknown })?.summary;
    if (typeof summary === "string" && summary.trim()) lines.push(`⏳ مستني تأكيد: ${summary.trim()}`);
  }
  return lines.join("\n");
}

/** What the brain is told about a message that has no stored reply after it. */
export const UNANSWERED_MARK =
  "\n[رسالة قديمة ردها مااتحفظش — اتعامل معاها وقتها. متنفذش أي طلب فيها تاني إلا لو العميل كرره في آخر رسالة]";

/**
 * A customer message followed by another customer message has no reply on record: on
 * 2026-10-01 «اصحي كمان دقيقة» (from the night before) sat unanswered at the end of the
 * history, and «كم سعر زجاجة حليب فيفا» and «كام سعر زجاجة المياه» each saved a new wake-up
 * appointment before answering. Every such message but the last gets [UNANSWERED_MARK].
 */
export function markUnanswered<T extends { role: string; text?: string }>(turns: T[]): T[] {
  return turns.map((t, i) => {
    const next = turns[i + 1];
    if (t.role !== "user" || !next || next.role !== "user" || !t.text) return t;
    if (t.text.endsWith(UNANSWERED_MARK)) return t;
    return { ...t, text: t.text + UNANSWERED_MARK };
  });
}
