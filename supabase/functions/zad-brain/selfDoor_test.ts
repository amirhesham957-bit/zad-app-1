// الإعدادات، الأهداف والتحديات من الباب الوحيد (ZAD_OR_PLAN م٢.٥، ٢٢/١١): كل أداة بتبعت نية لـzad_commit_intent بالنوع
// الصح، مابتكتبش في zad_users ولا agent_goals ولا zad_savings_challenges بإيدها، ورفض الباب بيوصل للموديل بسببه.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { executeTool } from "./index.ts";
import { freshContext } from "./validators.ts";

type Row = Record<string, unknown>;
const RUN = { source: "app_chat", runId: "run-1" } as const;

function fakeDb(door: (intent: Row) => Row, opts: { activeChallenge?: boolean } = {}) {
  const intents: Row[] = [];
  const directWrites: string[] = [];
  const goal = { id: "g1", title: "مصيف", current_value: 0, target_value: 5000, deadline_date: null, progress_kind: "amount" };
  const from = (table: string) => {
    let single = false;
    const b: any = {
      select: () => b, eq: () => b, order: () => b, limit: () => b, gte: () => b,
      maybeSingle: () => ((single = true), b), single: () => ((single = true), b),
      insert: () => (directWrites.push(`${table}.insert`), b),
      upsert: () => (directWrites.push(`${table}.upsert`), b),
      update: () => (directWrites.push(`${table}.update`), b),
      delete: () => (directWrites.push(`${table}.delete`), b),
      then: (ok: (v: unknown) => unknown) => {
        const rows = table === "agent_goals" ? [goal]
          : table === "zad_customer_profile" ? [{ user_id: "u1" }]
          : table === "zad_savings_challenges" ? (opts.activeChallenge ? [{ id: "c0" }] : [])
          : table === "zad_users" ? [{ cycle_start_day: 1, emergency_fund_balance: 100, pet_calls_enabled: true, food_pattern_enabled: false }]
          : [];
        return Promise.resolve({ data: single ? rows[0] ?? null : rows, error: null }).then(ok);
      },
    };
    return b;
  };
  const rpc = (fn: string, args: Row) => {
    if (fn === "zad_commit_intent") {
      intents.push(args.p_intent as Row);
      return Promise.resolve({ data: door(args.p_intent as Row), error: null });
    }
    if (fn === "zad_budget_state") return Promise.resolve({ data: { daily_allowance_left: 200, currency: "EGP" }, error: null });
    return Promise.resolve({ data: { ok: true }, error: null });
  };
  return { sb: { from, rpc } as any, intents, directWrites };
}

const okDoor = (i: Row): Row => ({
  ok: true, duplicate: false, row_id: "r1",
  payload: { ...(i.payload as Row), after: { id: "r1", days_won: 2, best_streak: 3, current_value: 500, target_value: 5000, progress_kind: "amount" } },
});
const SNAP = { now_local: { date: "2026-11-22" } };
const ctx = () => freshContext("u1");
const run = (sb: any, tool: string, input: Row, scope: any = RUN) => executeTool(sb, "u1", tool, input, SNAP, ctx(), scope);

Deno.test("settings tools: each one sends its intent, and none writes zad_users itself", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor);
  await run(sb, "confirm_cycle_start", { cycle_start_day: 25 });
  await run(sb, "set_market", { currency: "SAR", country: "SA" });
  await run(sb, "update_emergency_fund_balance", { new_balance: 1500.555 });
  await run(sb, "set_sleep_window", { bed: "23:30", wake: "07:00" });
  await run(sb, "set_sleep_window", { clear: true });
  await run(sb, "set_app_setting", { setting: "pet_calls", on: false });
  assertEquals(intents.map((i) => [i.kind, i.payload]), [
    ["settings.cycle_start_set", { day: 25 }],
    ["settings.market_set", { currency: "SAR", country: "SA" }],
    ["settings.emergency_fund_set", { balance: 1500.555 }],
    ["settings.sleep_set", { bed: "23:30", wake: "07:00" }],
    ["settings.sleep_cleared", {}],
    ["settings.app_flag_set", { setting: "pet_calls", on: false }],
  ]);
  assertEquals(intents.map((i) => i.source), Array(6).fill("model"));
  assertEquals(directWrites.filter((w) => w.startsWith("zad_users")), []);
});

Deno.test("the profile's pay day syncs the cycle through the door, on its own key", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor);
  await run(sb, "update_customer_profile", { pay_day: 27 });
  const cycle = intents.find((i) => i.kind === "settings.cycle_start_set");
  assertEquals(cycle?.payload, { day: 27 });
  assert(String(cycle?.client_event_id).includes("update_customer_profile:cycle:"));
  assertEquals(directWrites.filter((w) => w.startsWith("zad_users")), []);
});

Deno.test("goal tools: set, cancel, progress, start and stop all go through the door", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor, { activeChallenge: false });
  const out = [];
  out.push(await run(sb, "set_life_goal", { title: "مصيف الصيف", target_value: 5000, unit: "money", deadline_date: "2027-06-01" }));
  out.push(await run(sb, "set_life_goal", { title: "مصيف الصيف", action: "cancel" }));
  out.push(await run(sb, "add_goal_progress", { goal_title: "مصيف", amount: 500 }));
  out.push(await run(sb, "start_savings_challenge", { daily_cap: 150, length_days: 30 }));
  out.push(await run(sb, "stop_savings_challenge", {}));
  assertEquals(intents.map((i) => i.kind), ["goal.set", "goal.cancelled", "goal.progress", "goal.challenge_started", "goal.challenge_stopped"]);
  assertEquals(intents[0].payload, { title: "مصيف الصيف", metric: null, target_value: 5000, deadline_date: "2027-06-01", unit: "money" });
  assertEquals(intents[1].payload, { title: "مصيف الصيف" });
  assertEquals(intents[2].payload, { goal_id: "g1", amount: 500 });
  assertEquals(intents[3].payload, {
    daily_cap: 150, length_days: 30, started_on: "2026-11-22", currency: "EGP", source: "chat",
  });
  assertStringIncludes(out[4], "كسب 2 يوم وأطول سلسلة 3"); // العدادات من حدث الباب
  assertStringIncludes(out[3], "السقف 150");
  assertEquals(directWrites.filter((w) => /^(zad_users|agent_goals|zad_savings_challenges)\./.test(w)), []);
});

Deno.test("a goal without a unit sends no unit, so the door keeps the kind the goal already has", async () => {
  const { sb, intents } = fakeDb(okDoor);
  await run(sb, "set_life_goal", { title: "قراءة كتاب" });
  assertEquals("unit" in (intents[0].payload as Row), false);
});

Deno.test("the dose snooze tool goes through the door with the slot and minutes", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor);
  // الدوا من zad_pharmacy_items: الـfake بيرجّع صفوف فاضية، فالأداة بترفض قبل الباب — الاختبار الحقيقي في doseDoor_test.
  const out = await run(sb, "snooze_pharmacy_dose", { name: "كونكور" });
  assertStringIncludes(out, "مرفوض");
  assertEquals(intents, []);
  assertEquals(directWrites.filter((w) => w.startsWith("zad_dose_snoozes")), []);
});

Deno.test("a door refusal reaches the model with its reason, and nothing is counted", async () => {
  const { sb } = fakeDb(() => ({ ok: false, reason: "challenge_already_active" }));
  const c = ctx();
  const out = await executeTool(sb, "u1", "start_savings_challenge", { daily_cap: 150 }, SNAP, c, RUN);
  assert(out.startsWith("مرفوض") && out.includes("challenge_already_active"), out);
  assertEquals(c.mutationCount, 0);
  const none = await executeTool(fakeDb(() => ({ ok: false, reason: "no_active_challenge" })).sb, "u1", "stop_savings_challenge", {}, SNAP, ctx(), RUN);
  assertEquals(none, "مفيش تحدي شغال أصلاً.");
  const prog = await executeTool(fakeDb(() => ({ ok: false, reason: "goal_not_amount" })).sb, "u1", "add_goal_progress", { goal_title: "مصيف", amount: 5 }, SNAP, ctx(), RUN);
  assert(prog.startsWith("مرفوض") && prog.includes("بالمهام"), prog);
});

Deno.test("the same call twice in one run says so and counts once", async () => {
  const { sb } = fakeDb(() => ({ ok: true, duplicate: true, row_id: "r1" }));
  const c = ctx();
  const out = await executeTool(sb, "u1", "set_app_setting", { setting: "food_pattern", on: true }, SNAP, c, RUN);
  assertStringIncludes(out, "اتنفذ قبل كده");
  assertEquals(c.mutationCount, 0);
});

Deno.test("the nightly dream's key is stable per (night, item) and its source is cron", async () => {
  const { intentKey, intentSource } = await import("./commitIntent.ts");
  const scope = { source: "daily", runId: "dream-2026-11-22" } as const;
  const k1 = await intentKey(scope, "nightly_dream", { input: { night: "2026-11-22" }, line: "لبن" });
  const k2 = await intentKey({ ...scope }, "nightly_dream", { line: "لبن", input: { night: "2026-11-22" } });
  const k3 = await intentKey(scope, "nightly_dream", { input: { night: "2026-11-22" }, line: "عيش" });
  const k4 = await intentKey({ source: "daily", runId: "dream-2026-11-23" }, "nightly_dream", { input: { night: "2026-11-23" }, line: "لبن" });
  assertEquals(k1, k2); // إعادة نفس الليلة = نفس المفتاح = الباب بيرجّعها تكرار
  assert(k1 !== k3 && k1 !== k4 && k1.length <= 100);
  assertEquals(intentSource(scope), "cron");
});
