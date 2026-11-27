import { assertEquals } from "jsr:@std/assert@1";
import { seededRng } from "../_shared/or/banditTone.ts";
import {
  APPROVED_VARIANTS,
  banditEnabled,
  type BanditStore,
  chooseTone,
  CRITICAL_KINDS,
} from "./banditWiring.ts";
import { memoryPhraseStore, proactiveTitle } from "./proactiveTemplates.ts";
import { agentTaskNotice } from "./shared.ts";

const V = { habit_trial: { warm: "تجربة صغيرة يا حبيبي؟" } };
const BASE = agentTaskNotice("habit_trial").title;

function store(
  byMember: Record<string, Record<string, { successes: number; failures: number }>>,
  fail = false,
) {
  const loads: string[] = [];
  const s: BanditStore = {
    load(_u, m) {
      loads.push(m);
      if (fail) return Promise.reject(new Error("db down"));
      return Promise.resolve(byMember[m] ?? {});
    },
    record: () => Promise.resolve(),
  };
  return { s, loads };
}

Deno.test("no approved variants shipped yet: the bandit can only ever pick the base", async () => {
  assertEquals(Object.keys(APPROVED_VARIANTS).length, 0);
  const { s } = store({});
  assertEquals(await chooseTone(s, "u", { memberId: "m" }, "habit_trial", BASE, seededRng(1)), null);
});

Deno.test("choice is per member: each member's own posterior decides", async () => {
  const { s } = store({
    a: { warm: { successes: 60, failures: 0 }, base: { successes: 0, failures: 60 } },
    b: { warm: { successes: 0, failures: 60 }, base: { successes: 60, failures: 0 } },
  });
  const pa = await chooseTone(s, "u", { memberId: "a", age: 40 }, "habit_trial", BASE, seededRng(7), V);
  const pb = await chooseTone(s, "u", { memberId: "b", age: 40 }, "habit_trial", BASE, seededRng(7), V);
  assertEquals(pa?.armId, "warm");
  assertEquals(pa?.title, V.habit_trial.warm);
  assertEquals(pb?.armId, "base");
  assertEquals(pb?.title, BASE);
});

Deno.test("under-18 and child mode never get an experiment (and the store is not even read)", async () => {
  const { s, loads } = store({ m: { warm: { successes: 99, failures: 0 } } });
  assertEquals(await chooseTone(s, "u", { memberId: "m", age: 17 }, "habit_trial", BASE, seededRng(1), V), null);
  assertEquals(
    await chooseTone(s, "u", { memberId: "m", age: 40, isChild: true }, "habit_trial", BASE, seededRng(1), V),
    null,
  );
  assertEquals(loads.length, 0);
});

Deno.test("critical lane (medicine/health, safety/emergency, severe weather) is outside any choice", async () => {
  const { s, loads } = store({ m: { warm: { successes: 99, failures: 0 } } });
  for (const k of ["med_followup", "health_alert", "safety_alert", "emergency_alert", "severe_weather_alert"]) {
    assertEquals(CRITICAL_KINDS.has(k), true, k);
    const v = { [k]: { warm: "x" } };
    assertEquals(await chooseTone(s, "u", { memberId: "m", age: 40 }, k, "base", seededRng(1), v), null, k);
  }
  assertEquals(loads.length, 0);
});

Deno.test("non-critical kinds (bills, warranty, budget, goals, restock) are open to tone change", () => {
  for (const k of ["bill_reminder", "warranty_reminder", "spending_ahead", "habit_budget", "goal_review", "spend_forecast", "restock_link"]) {
    assertEquals(CRITICAL_KINDS.has(k), false, k);
  }
});

Deno.test("read failure falls back to the base template (null)", async () => {
  const { s } = store({}, true);
  assertEquals(await chooseTone(s, "u", { memberId: "m", age: 40 }, "habit_trial", BASE, seededRng(1), V), null);
});

Deno.test("flag is closed by default and only 1/true/on opens it", () => {
  assertEquals(banditEnabled(() => undefined), false);
  assertEquals(banditEnabled(() => ""), false);
  assertEquals(banditEnabled(() => "0"), false);
  assertEquals(banditEnabled(() => "1"), true);
  assertEquals(banditEnabled(() => "true"), true);
});

Deno.test("proactiveTitle without a tone chooser (flag closed) behaves exactly as before", async () => {
  const st = memoryPhraseStore();
  assertEquals(await proactiveTitle(st, "habit_trial", "EG"), BASE);
  const st2 = memoryPhraseStore();
  const re = (b: string, d: string) => Promise.resolve(`${d}:${b}`);
  assertEquals(await proactiveTitle(st2, "habit_trial", "SA", re), `SA:${BASE}`);
  assertEquals(await proactiveTitle(st2, "habit_trial", "SA", re), `SA:${BASE}`);
});

Deno.test("proactiveTitle with a tone chooser: pick wins, null or throw falls to old path, nothing cached", async () => {
  const st = memoryPhraseStore();
  assertEquals(await proactiveTitle(st, "habit_trial", "EG", undefined, () => Promise.resolve("warm")), "warm");
  assertEquals(st.get("proactive_phrase:v1:habit_trial:EG"), null);
  assertEquals(await proactiveTitle(st, "habit_trial", "EG", undefined, () => Promise.resolve(null)), BASE);
  assertEquals(await proactiveTitle(st, "habit_trial", "EG", undefined, () => Promise.reject(new Error("x"))), BASE);
});

Deno.test("sender wires the bandit behind the flag only", async () => {
  const src = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(src.includes("banditEnabled((k) => Deno.env.get(k)) ?"), true);
  assertEquals(src.includes("proactiveTitle(proactivePhrases, kind, dialect, undefined, tone)"), true);
});
