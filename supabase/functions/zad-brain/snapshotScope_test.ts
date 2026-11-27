// م٤.٣ (خيار أ) — اللقطة حسب النية: حتمي، من غير موديل. لكل نية المفاتيح اللي محتاجها لسه موجودة، والنواة دايماً،
// وتقدير التوكن (حروف / 3.5) بينزل على الحالات في evals/cases.ts.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { MEMORY_CAP_GENERAL, MEMORY_CAP_SPECIALIST, promptSnapshot, type SnapshotScope } from "./index.ts";
import { mentionsLifeFact, routeSpecialists } from "./specialists.ts";
import { EVAL_CASES } from "./evals/cases.ts";

const tok = (o: unknown) => Math.round(JSON.stringify(o).length / 3.5);
const note = (i: number) => ({
  id: `m${i}`, scope: i < 5 ? "identity" : "preference",
  text: `ملاحظة رقم ${i} عن العيلة: بنحب الأرز المصري وبنشتري من السوبر ماركت القريب كل أسبوع`,
  evidence_count: 2, last_seen: "2026-11-20",
});
const SNAP = {
  currency: "EGP", country: "EG",
  customer: { name: "أحمد", gender: "male", city: "القاهرة", pay_day: 25 },
  budget: 18000, spent: 11250.5, income: 20000, remaining: 6749.5, available: 4300, committed: 2449.5, obligations: 2449.5,
  next_obligation: { title: "الإيجار", amount: 6000, next_due: "2026-12-01" },
  cycle: { start_day: 25, cycle_start: "2026-11-25", cycle_end: "2026-12-24", days_left: 30 },
  byCategory: { food: 4200, transport: 1800, bills: 2600, health: 900, other: 1750 },
  stock_totals: [{ name: "مية", qty: 8 }],
  shopping_list_pending: ["لبن", "عيش", "جبنة", "طماطم"],
  memory: Array.from({ length: 20 }, (_, i) => note(i)),
  medicines: [{ name: "دوا الضغط", for: "أبويا", times: "08:00,20:00", days_left: 4 }],
  appointments: [{ id: "ap1", title: "دكتور الأسنان", at: "2026-11-24T17:00" }],
  family: [{ name: "يوسف", role: "child" }, { name: "منى", role: "spouse" }],
  life_goals: [{ title: "عمرة", progress: 0.3 }],
  now_local: { date: "2026-11-22", time: "09:30", utc_offset: "+02:00" },
  circumstance: { mode: "normal" }, trusted_technicians: [{ name: "سباك" }],
  // بتتشال دايماً (HOUSE_SECTIONS_ON_REQUEST)
  recent_transactions: [{ id: "t" }], stock: [{ id: "s" }],
};
const CORE = ["currency", "country", "customer", "budget", "spent", "income", "remaining", "available", "committed", "obligations",
  "next_obligation", "cycle", "memory", "family", "now_local", "circumstance"];
// المفاتيح المطلوبة لكل نية (فوق النواة).
const NEEDS: Record<string, string[]> = {
  finance: ["byCategory", "life_goals"],
  pantry: ["stock_totals", "shopping_list_pending"],
  pharmacy: ["medicines", "appointments"],
  family: ["medicines", "appointments"],
  home: ["appointments", "trusted_technicians"],
  general: ["byCategory", "life_goals", "stock_totals", "shopping_list_pending", "medicines", "appointments", "trusted_technicians"],
};

Deno.test("م٤.٣ scoped snapshot: core + per-intent required keys stay, on-request keys stay removed", () => {
  for (const [spec, extra] of Object.entries(NEEDS)) {
    const out = promptSnapshot(SNAP, { specialist: spec });
    for (const k of [...CORE, ...extra]) assert(k in out, `${spec}: ${k} missing`);
    assert(!("recent_transactions" in out) && !("stock" in out), `${spec}: on-request keys leaked`);
    assert((out.memory as unknown[]).length <= (spec === "general" ? MEMORY_CAP_GENERAL : MEMORY_CAP_SPECIALIST));
    // ملاحظات الهوية (أول الذاكرة) لسه كلها موجودة.
    assertEquals((out.memory as Array<{ scope: string }>).filter((m) => m.scope === "identity").length, 5);
  }
});

Deno.test("م٤.٣ scoped snapshot: secondary specialist and life-fact widen; no scope = unchanged", () => {
  const sec = promptSnapshot(SNAP, { specialist: "finance", secondary: "pharmacy" });
  assert("medicines" in sec && "byCategory" in sec && !("stock_totals" in sec));
  const life = promptSnapshot(SNAP, { specialist: "finance", lifeFact: true });
  assertEquals((life.memory as unknown[]).length, MEMORY_CAP_GENERAL);
  assertEquals((promptSnapshot(SNAP).memory as unknown[]).length, 20);
  assert("stock_totals" in promptSnapshot(SNAP) && "medicines" in promptSnapshot(SNAP));
});

Deno.test("م٤.٣ scoped snapshot: eval cases shrink, p50 before -> after", () => {
  const before: number[] = [], after: number[] = [];
  const perSpec: Record<string, number> = {};
  for (const c of EVAL_CASES) {
    const { primary, secondary } = routeSpecialists(c.message);
    const scope: SnapshotScope = { specialist: primary, secondary, lifeFact: mentionsLifeFact(c.message) };
    const b = tok(promptSnapshot(SNAP)), a = tok(promptSnapshot(SNAP, scope));
    assert(a <= b);
    before.push(b); after.push(a);
    perSpec[primary] = (perSpec[primary] ?? 0) + 1;
  }
  const p50 = (r: number[]) => [...r].sort((x, y) => x - y)[Math.floor(r.length / 2)];
  console.log(`[م٤.٣ snapshot-scope] cases=${EVAL_CASES.length} by-specialist=${JSON.stringify(perSpec)}\n  snapshot p50 tok before=${p50(before)} after=${p50(after)} saved=${p50(before) - p50(after)}`);
  assert(p50(after) < p50(before));
});
