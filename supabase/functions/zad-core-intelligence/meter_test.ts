import { assert, assertEquals } from "jsr:@std/assert@1";
import { meterFor, openGate, type Rpc, scanCameBackEmpty } from "./meter.ts";

/** A fake database: answers per function name and records every call. */
function fakeRpc(answers: Record<string, { data: unknown; error?: { message: string } }>) {
  const calls: Array<{ fn: string; args: Record<string, unknown> }> = [];
  const rpc: Rpc = (fn, args) => {
    calls.push({ fn, args });
    const a = answers[fn] ?? { data: null };
    return Promise.resolve({ data: a.data, error: a.error ?? null });
  };
  return { rpc, calls };
}

Deno.test("the five scans cost a scan, a voice question costs a voice try, reading aloud and the rest only count", () => {
  for (const a of ["analyze_receipt", "analyze_inventory_image", "analyze_medicine_image", "analyze_document_image", "analyze_statement"]) {
    assertEquals(meterFor(a)?.kind, "scan", a);
    assertEquals(meterFor(a)?.bucket, "vision", a);
  }
  assertEquals(meterFor("voice_agent")?.kind, "voice");
  assertEquals(meterFor("voice_agent")?.bucket, "voice");
  // Reading a reply aloud is free (owner, 2026-10-28): still paced, never charged.
  assertEquals(meterFor("voice_synthesize")?.kind, null);
  assertEquals(meterFor("voice_synthesize")?.bucket, "voice");
  assertEquals(meterFor("meal_suggestions")?.kind, null);
  assertEquals(meterFor("meal_suggestions")?.bucket, "other");
});

Deno.test("health probes and the admin feed keep their own guards; no action is no meter", () => {
  assertEquals(meterFor("provider_health"), null);
  assertEquals(meterFor("voice_selftest"), null);
  assertEquals(meterFor("admin_recent_activity"), null);
  assertEquals(meterFor(undefined), null);
  assertEquals(meterFor(""), null);
});

Deno.test("an empty reading is refunded, a real one is not — each action's own empty shape", () => {
  assert(scanCameBackEmpty("analyze_receipt", { total: 0, category: "", storeName: "", items: [] }));
  assert(!scanCameBackEmpty("analyze_receipt", { total: 85, items: [] }));
  assert(!scanCameBackEmpty("analyze_receipt", { total: 0, items: [{ name: "لبن" }] }));
  assert(scanCameBackEmpty("analyze_inventory_image", { items: [] }));
  assert(!scanCameBackEmpty("analyze_inventory_image", { items: [{ name: "رز" }] }));
  assert(scanCameBackEmpty("analyze_medicine_image", { medicine: null }));
  assert(!scanCameBackEmpty("analyze_medicine_image", { medicine: { name: "بنادول" } }));
  assert(scanCameBackEmpty("analyze_document_image", { document: null, reason: "unreadable" }));
  assert(!scanCameBackEmpty("analyze_document_image", { document: { kind: "prescription" } }));
  assert(scanCameBackEmpty("analyze_statement", { statement: null, reason: "nothing_found" }));
  assert(!scanCameBackEmpty("analyze_statement", { statement: { rows: [{}] } }));
  assert(scanCameBackEmpty("analyze_receipt", { error: "boom" }));
  assert(scanCameBackEmpty("analyze_receipt", null));
  assert(scanCameBackEmpty("voice_agent", { action: "chat", message: "لم أتمكن من فهم الصوت، حاول مرة أخرى.", data: null }));
  assert(scanCameBackEmpty("voice_agent", { action: "chat", message: "", data: null, transcript: "  " }));
  assert(!scanCameBackEmpty("voice_agent", { action: "chat", message: "", data: null, transcript: "صرفت ٥٠ قهوة" }));
});

Deno.test("too fast: 429 with Zad's words, and nothing is charged", async () => {
  const db = fakeRpc({ zad_rate_take: { data: { ok: false, reason: "minute" } } });
  const g = await openGate(db.rpc, "u1", meterFor("analyze_receipt")!);
  assertEquals(g.refusal?.status, 429);
  assertEquals(g.refusal?.body.error, "too_fast");
  assertEquals(db.calls.map((c) => c.fn), ["zad_rate_take"]);
});

Deno.test("past the day's cap: 429 daily_cap", async () => {
  const db = fakeRpc({ zad_rate_take: { data: { ok: false, reason: "day" } } });
  const g = await openGate(db.rpc, "u1", meterFor("voice_synthesize")!);
  assertEquals(g.refusal?.body.error, "daily_cap");
});

Deno.test("a scan spends two attempts through consume, keyed on the caller", async () => {
  const db = fakeRpc({
    zad_rate_take: { data: { ok: true } },
    zad_entitlement_consume: { data: { allowed: true, reason: "quota", left: 3, cost: 2 } },
  });
  const g = await openGate(db.rpc, "u1", meterFor("analyze_receipt")!);
  assertEquals(g, { charged: "scan" });
  assertEquals(db.calls[0].args, { p_user: "u1", p_bucket: "vision", p_per_minute: 6, p_per_day: 100 });
  assertEquals(db.calls[1].args, { p_user: "u1", p_kind: "scan", p_tz: "UTC" });
});

Deno.test("not enough attempts: 402 no_attempts with the balance, before any model call", async () => {
  const db = fakeRpc({
    zad_rate_take: { data: { ok: true } },
    zad_entitlement_consume: { data: { allowed: false, reason: "needs_ads_or_upgrade", left: 1, cost: 2 } },
  });
  const g = await openGate(db.rpc, "u1", meterFor("analyze_medicine_image")!);
  assertEquals(g.refusal?.status, 402);
  assertEquals(g.refusal?.body.error, "no_attempts");
  assertEquals((g.refusal?.body.entitlement as { left: number }).left, 1);
});

Deno.test("voice while it is free (unlimited) or a media pass: allowed, nothing to refund", async () => {
  for (const reason of ["unlimited", "media_pass"]) {
    const db = fakeRpc({
      zad_rate_take: { data: { ok: true } },
      zad_entitlement_consume: { data: { allowed: true, reason } },
    });
    assertEquals(await openGate(db.rpc, "u1", meterFor("voice_agent")!), {}, reason);
  }
});

Deno.test("a free voice question within the day's three is charged, so an empty one can be refunded", async () => {
  const db = fakeRpc({
    zad_rate_take: { data: { ok: true } },
    zad_entitlement_consume: { data: { allowed: true, reason: "quota", voice_left: 2, voice_daily: 3 } },
  });
  assertEquals(await openGate(db.rpc, "u1", meterFor("voice_agent")!), { charged: "voice" });
  assertEquals(db.calls[1].args, { p_user: "u1", p_kind: "voice", p_tz: "UTC" });
});

Deno.test("the fourth free voice question: 402 no_voice_today, in Zad's words", async () => {
  const db = fakeRpc({
    zad_rate_take: { data: { ok: true } },
    zad_entitlement_consume: { data: { allowed: false, reason: "voice_daily_cap", voice_daily: 3, voice_left: 0 } },
  });
  const g = await openGate(db.rpc, "u1", meterFor("voice_agent")!);
  assertEquals(g.refusal?.status, 402);
  assertEquals(g.refusal?.body.error, "no_voice_today");
  assert(String(g.refusal?.body.message).includes("٣ في اليوم"));
});

Deno.test("reading a reply aloud never calls consume", async () => {
  const db = fakeRpc({ zad_rate_take: { data: { ok: true } } });
  assertEquals(await openGate(db.rpc, "u1", meterFor("voice_synthesize")!), {});
  assertEquals(db.calls.map((c) => c.fn), ["zad_rate_take"]);
});

Deno.test("text actions only count: no consume call", async () => {
  const db = fakeRpc({ zad_rate_take: { data: { ok: true } } });
  assertEquals(await openGate(db.rpc, "u1", meterFor("spending_insights")!), {});
  assertEquals(db.calls.map((c) => c.fn), ["zad_rate_take"]);
});

Deno.test("the rate table failing lets the call through; the charge failing does not", async () => {
  const rateDown = fakeRpc({
    zad_rate_take: { data: null, error: { message: "down" } },
    zad_entitlement_consume: { data: { allowed: true, reason: "quota" } },
  });
  assertEquals(await openGate(rateDown.rpc, "u1", meterFor("analyze_receipt")!), { charged: "scan" });

  const chargeDown = fakeRpc({
    zad_rate_take: { data: { ok: true } },
    zad_entitlement_consume: { data: null, error: { message: "down" } },
  });
  assertEquals((await openGate(chargeDown.rpc, "u1", meterFor("analyze_receipt")!)).refusal?.status, 503);
});
