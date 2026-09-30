// zad-support — a complaint or support request from the app, for a person to
// answer. Saves the ticket (RLS-scoped table, service role here) and emails it
// to the support inbox (SUPPORT_INBOX, default astralabs.supp@gmail.com) via
// Resend (RESEND_API_KEY; sender SUPPORT_FROM, default onboarding@resend.dev,
// which Resend delivers only to the Resend account's own address — sign up
// with the inbox, or verify a domain and set SUPPORT_FROM).
//
// The caller is resolved from their own JWT; a user_id in the body is ignored.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { buildSupportEmail, DEFAULT_SUPPORT_INBOX, sendSupportEmail } from "./email.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "apikey, x-client-info, Content-Type, Authorization",
  "Content-Type": "application/json",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: cors });
const str = (v: unknown, max: number): string | null =>
  typeof v === "string" && v.trim() ? v.trim().slice(0, max) : null;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: caller } = token ? await admin.auth.getUser(token) : { data: { user: null } };
    const user = caller?.user;
    if (!user) return json({ error: "unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const subject = str(body?.subject, 200);
    const message = str(body?.message, 8000);
    if (!subject || !message) return json({ error: "subject_and_message_required" }, 400);
    const conversation = Array.isArray(body?.conversation)
      ? body.conversation
        .filter((m: unknown) => typeof (m as { text?: unknown })?.text === "string")
        .slice(-40)
        .map((m: { text: string; isUser?: unknown }) => ({ text: m.text.slice(0, 2000), isUser: m.isUser === true }))
      : null;

    const { data: row, error } = await admin.from("zad_support_tickets").insert({
      user_id: user.id,
      contact_email: user.email ?? null,
      subject,
      message,
      conversation,
      crash_log: str(body?.crash_log, 60000),
      app_version: str(body?.app_version, 40),
      device: str(body?.device, 120),
    }).select("id, created_at").single();
    if (error || !row) {
      console.error(`[Support] insert failed: ${error?.message}`);
      return json({ error: "save_failed" }, 500);
    }

    const email = buildSupportEmail({
      id: row.id,
      userId: user.id,
      contactEmail: user.email ?? null,
      subject,
      message,
      conversation,
      crashLog: str(body?.crash_log, 60000),
      appVersion: str(body?.app_version, 40),
      device: str(body?.device, 120),
      createdAt: row.created_at,
    });
    const emailed = await sendSupportEmail(
      email,
      Deno.env.get("SUPPORT_INBOX") || DEFAULT_SUPPORT_INBOX,
      Deno.env.get("RESEND_API_KEY"),
      Deno.env.get("SUPPORT_FROM") || "Zad Support <onboarding@resend.dev>",
    );
    if (emailed) await admin.from("zad_support_tickets").update({ emailed_at: new Date().toISOString() }).eq("id", row.id);
    return json({ ok: true, ticket_id: row.id, emailed });
  } catch (e) {
    console.error(`[Support] ${String((e as Error)?.message ?? e).slice(0, 300)}`);
    return json({ error: "internal" }, 500);
  }
});
