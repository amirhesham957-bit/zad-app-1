// عدّادات تشخيص المسارات بعد النشر (٢٠٢٦-٠٩-١٤) — أعداد وحالات وأسماء أخطاء بس.
//
// بلاغ من تجربة حقيقية: «البوت مابيبعتش فويسات التذكير ولا صباح الخير»، «العقل أعمى عن مواعيدي
// ومابينفذش». الكود في الريبو بيقول المسار كامل، واللوجات مش متاحة من الجلسة — فالسؤال «فين وقع؟»
// محتاج رقم مقاس. CI بينادي provider_health بمفتاح service role بعد كل نشر، والنتيجة بتتكتب في
// لوج عام (الريبو عام): **ممنوع** أي نص عميل أو عنوان أو معرّف. الأخطاء بتتقص لحروف ASCII بس
// (نص عربي = كلام عميل غالباً بيتشال)، والمعرّفات والأرقام الطويلة بتتبدل.

// deno-lint-ignore no-explicit-any
type Sb = any;

export function sanitizeError(v: unknown): string {
  return String(v ?? "")
    .replace(/[^\x20-\x7E]/g, "")
    .replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, "<id>")
    .replace(/\d{5,}/g, "<n>")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 90) || "(empty)";
}

export function countBy<T>(rows: T[], key: (r: T) => string, top = 12): Record<string, number> {
  const m = new Map<string, number>();
  for (const r of rows) {
    const k = key(r);
    m.set(k, (m.get(k) ?? 0) + 1);
  }
  return Object.fromEntries([...m.entries()].sort((a, b) => b[1] - a[1]).slice(0, top));
}

async function rows(q: Promise<{ data: unknown; error: { message: string } | null }>): Promise<{ list: Array<Record<string, unknown>>; error?: string }> {
  try {
    const { data, error } = await q;
    if (error) return { list: [], error: sanitizeError(error.message) };
    return { list: (data ?? []) as Array<Record<string, unknown>> };
  } catch (e) {
    return { list: [], error: sanitizeError((e as Error)?.message ?? e) };
  }
}

export async function pipelineHealth(sb: Sb, now = Date.now()): Promise<Record<string, unknown>> {
  const since72h = new Date(now - 72 * 3600_000).toISOString();
  const since7d = new Date(now - 7 * 86400_000).toISOString();

  const since14d = new Date(now - 14 * 86400_000).toISOString();
  const [runs, moments, appts, fallbacks, actions, bindings, profiles, users, fcm, momentsAll] = await Promise.all([
    rows(sb.from("zad_brain_runs").select("trigger,status,error").gte("started_at", since72h).limit(1000)),
    rows(sb.from("zad_voice_moments").select("moment,status,delivery,error").gte("created_at", since72h).limit(1000)),
    rows(sb.from("zad_appointments").select("source,status").limit(1000)),
    rows(sb.from("agent_logs").select("agent_name,status,payload").gte("timestamp", since72h).neq("status", "success").limit(500)),
    rows(sb.from("agent_actions").select("tool_name,source").gte("created_at", since7d).limit(2000)),
    rows(sb.from("telegram_bindings").select("chat_id").not("chat_id", "is", null).limit(1000)),
    rows(sb.from("zad_customer_profile").select("gender,preferred_name,pay_day").limit(1000)),
    rows(sb.from("zad_users").select("country").limit(1000)),
    rows(sb.from("zad_fcm_tokens").select("updated_at").limit(1000)),
    rows(sb.from("zad_voice_moments").select("moment,status").limit(2000)),
  ]);

  const failedRuns = runs.list.filter((r) => r.status === "failed");
  return {
    window: "72h (actions 7d)",
    brain_runs: {
      by_trigger_status: countBy(runs.list, (r) => `${r.trigger}|${r.status}`),
      top_errors: countBy(failedRuns, (r) => sanitizeError(r.error), 6),
      ...(runs.error ? { query_error: runs.error } : {}),
    },
    voice_moments: {
      by_moment_status_channels: countBy(moments.list, (r) => {
        const d = (r.delivery ?? {}) as Record<string, unknown>;
        return `${r.moment}|${r.status}|device=${d.device ?? "-"}|telegram=${d.telegram ?? "-"}|by=${d.composed_by ?? "-"}`;
      }, 20),
      top_errors: countBy(moments.list.filter((r) => r.error), (r) => sanitizeError(r.error), 6),
      ...(moments.error ? { query_error: moments.error } : {}),
    },
    appointments_all_time: {
      by_source_status: countBy(appts.list, (r) => `${r.source}|${r.status}`),
      ...(appts.error ? { query_error: appts.error } : {}),
    },
    agent_log_warnings: {
      by_agent_reason: countBy(fallbacks.list, (r) => {
        const p = (r.payload ?? {}) as Record<string, unknown>;
        return `${r.agent_name}|${p.channel ?? "-"}|${sanitizeError(p.reason ?? r.status)}`;
      }, 10),
      ...(fallbacks.error ? { query_error: fallbacks.error } : {}),
    },
    agent_actions_7d: {
      by_tool_source: countBy(actions.list, (r) => `${r.tool_name}|${r.source}`, 25),
      ...(actions.error ? { query_error: actions.error } : {}),
    },
    telegram_linked_chats: bindings.error ? bindings.error : bindings.list.length,
    users: users.error ? users.error : { total: users.list.length, by_country: countBy(users.list, (u) => String(u.country ?? "null")) },
    // «صباح الخير» الاحتياطية بتختار اللي سجّل دخول أو حدّث توكن FCM آخر ١٤ يوم.
    fcm_tokens: fcm.error ? fcm.error : { total: fcm.list.length, fresh_14d: fcm.list.filter((t) => String(t.updated_at ?? "") > since14d).length },
    voice_moments_all_time: momentsAll.error ? momentsAll.error : countBy(momentsAll.list, (r) => `${r.moment}|${r.status}`, 20),
    customer_profiles: profiles.error ? profiles.error : {
      rows: profiles.list.length,
      with_gender: profiles.list.filter((p) => p.gender).length,
      with_name: profiles.list.filter((p) => p.preferred_name).length,
      with_pay_day: profiles.list.filter((p) => p.pay_day).length,
    },
  };
}

/**
 * موديلات الصوت: فويسات تليجرام وصوت سارة في التطبيق بيستخدموا gemini-2.5-*-preview-tts،
 * وعيلة 2.5 النصية بترجع 404 «مش متاحة لمستخدمين جداد» على المشروع ده. هنا بنسأل الكتالوج
 * عن كل موديل tts/live، وبنجرّب توليد كلمة واحدة بكل موديل tts — حالة HTTP بس.
 */
export async function ttsHealth(keys: string[], fetchImpl: typeof fetch = fetch): Promise<Record<string, unknown>> {
  const key = keys[0];
  if (!key) return { configured: false };
  const out: Record<string, unknown> = {};
  let listed: string[] = [];
  try {
    const res = await fetchImpl("https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000", {
      headers: { "x-goog-api-key": key }, signal: AbortSignal.timeout(8000),
    });
    const body = await res.json();
    listed = ((body?.models ?? []) as Array<{ name?: string }>).map((m) => String(m.name ?? "").replace(/^models\//, ""));
    out.catalog_tts = listed.filter((n) => /tts/i.test(n));
    out.catalog_live_audio = listed.filter((n) => /live|native-audio/i.test(n));
  } catch (e) {
    out.catalog_error = sanitizeError((e as Error)?.message ?? e);
  }
  const candidates = [...new Set(["gemini-2.5-flash-preview-tts", "gemini-2.5-pro-preview-tts", ...listed.filter((n) => /tts/i.test(n))])].slice(0, 6);
  const probe = async (model: string): Promise<[string, string]> => {
    try {
      const res = await fetchImpl(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify({
          contents: [{ parts: [{ text: "Say: hello" }] }],
          generationConfig: {
            responseModalities: ["AUDIO"],
            speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: "Aoede" } } },
          },
        }),
        signal: AbortSignal.timeout(25000),
      });
      if (!res.ok) {
        const t = await res.text();
        return [model, `${res.status} ${sanitizeError(t.match(/"message":\s*"([^"]{0,80})/)?.[1] ?? "")}`];
      }
      const data = await res.json();
      const hasAudio = (data?.candidates?.[0]?.content?.parts ?? []).some((p: { inlineData?: { data?: string } }) => p?.inlineData?.data);
      return [model, hasAudio ? "200 audio" : "200 no_audio"];
    } catch (e) {
      return [model, `threw ${sanitizeError((e as Error)?.message ?? e)}`];
    }
  };
  const probes = Object.fromEntries(await Promise.all(candidates.map(probe)));
  out.generate_probe_key1 = probes;
  return out;
}
