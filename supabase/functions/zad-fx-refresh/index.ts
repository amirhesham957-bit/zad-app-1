// zad-fx-refresh — بيملا `zad_fx_rates` من مزوّد أسعار حي، مرة في اليوم من الكرون.
//
// ليه موجودة: الجدول اتعمل في 2026-08-15 بدفعة بذرة واحدة **منسوخة من الثوابت
// المطبوعة في التطبيق**، ومحدش حدّثه بعدها. يعني الجدول والـAPK بيقولوا نفس الرقم،
// والرقم بيقدم مع الوقت من غير أي إشارة. القياس يوم 2026-09-07: ٨ من ٢٠ عملة منحرفة
// أكتر من ٥٪، وأسوأهم SYP بـ-٩٩٪ (إعادة تقويم) وTRY بـ+٤٣٪.
//
// وليه ماكانش باين: الهاردكودنغ **صحيح تماماً للعملات المربوطة بالدولار** —
// SAR/AED/QAR/JOD/KWD/OMR/BHD كلهم بانحراف ٠٫٠٪. الغلط كله في العائمة.
//
// المزوّد `open.er-api.com` مجاني وبلا مفتاح وبلا حساب (فمش داخل تحت تأجيل
// الحسابات المدفوعة)، وبيغطي العشرين عملة، وبيحدّث يومياً.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { parseProviderPayload, significantMoves } from "./fx.ts";
import { secretMatches } from "../_shared/cronSecret.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PROVIDER_URL = "https://open.er-api.com/v6/latest/USD";
// مفتاح exchangerate-api.com (سر المشروع EXCHANGE_RATE_API_KEY) — أدق وبيتحدّث أكتر من المجاني.
// لو مش موجود أو فشل، بنرجع للمجاني من غير مفتاح؛ الجدول مايقفش على مزوّد واحد.
const EXCHANGE_RATE_API_KEY = Deno.env.get("EXCHANGE_RATE_API_KEY") ?? "";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, content-type, x-fx-cron-secret",
};

// الدالة بتشتغل بـ`verify_jwt = false` عشان الكرون (net.http_post) مابيحملش JWT
// سوبابيز — الحارس في `_shared/cronSecret.ts`.
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });

  if (!(await secretMatches(req.headers.get("X-Fx-Cron-Secret"), "ZAD_FX_CRON_SECRET"))) {
    return json({ error: "unauthorized" }, 401);
  }

  const providers = [
    ...(EXCHANGE_RATE_API_KEY ? [{ name: "exchangerate-api", url: `https://v6.exchangerate-api.com/v6/${encodeURIComponent(EXCHANGE_RATE_API_KEY)}/latest/USD` }] : []),
    { name: "open.er-api", url: PROVIDER_URL },
  ];
  let parsed: ReturnType<typeof parseProviderPayload> = { ok: false, reason: "no provider answered" };
  let provider = "";
  for (const p of providers) {
    try {
      const res = await fetch(p.url, { signal: AbortSignal.timeout(20_000) });
      if (!res.ok) {
        console.error(`fx provider ${p.name} http`, res.status);
        parsed = { ok: false, reason: `${p.name} http ${res.status}` };
        continue;
      }
      parsed = parseProviderPayload(await res.json());
      if (parsed.ok) { provider = p.name; break; }
      console.error(`fx provider ${p.name} payload rejected:`, parsed.reason);
    } catch (error) {
      console.error(`fx provider ${p.name} unreachable:`, (error as Error).message);
      parsed = { ok: false, reason: `${p.name} unreachable` };
    }
  }
  if (provider) console.log(`fx rates from ${provider}`);
  if (!parsed.ok) {
    // مافيش كتابة جزئية خالص — الجدول بيفضل على آخر دفعة سليمة.
    console.error("fx payload rejected:", parsed.reason);
    return json({ error: "payload_rejected", reason: parsed.reason }, 422);
  }

  const sb = createClient(SUPABASE_URL, SERVICE_ROLE);

  const { data: before, error: readErr } = await sb
    .from("zad_fx_rates")
    .select("code, usd_rate");
  if (readErr) {
    console.error("fx read failed:", readErr.message);
    return json({ error: "read_failed" }, 500);
  }
  const previous = new Map<string, number>(
    (before ?? []).map((r) => [r.code as string, Number(r.usd_rate)]),
  );

  const now = new Date().toISOString();
  const { error: writeErr } = await sb
    .from("zad_fx_rates")
    .upsert(
      parsed.rows.map((r) => ({ code: r.code, usd_rate: r.usd_rate, updated_at: now })),
      { onConflict: "code" },
    );
  if (writeErr) {
    console.error("fx write failed:", writeErr.message);
    return json({ error: "write_failed" }, 500);
  }

  const moves = significantMoves(previous, parsed.rows);
  for (const m of moves) {
    console.log(`fx move ${m.code}: ${m.from} → ${m.to} (${m.pct.toFixed(1)}%)`);
  }

  return json({ updated: parsed.rows.length, moves });
});
