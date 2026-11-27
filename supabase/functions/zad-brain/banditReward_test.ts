import { assertEquals } from "jsr:@std/assert@1";
import { chooseArm, seededRng, update } from "../_shared/or/banditTone.ts";
import { banditEnabled } from "./banditWiring.ts";
import { noteShown, rewardEligible, settleIgnoredNotifications, settleOpenedNotifications, unambiguousMember } from "./banditReward.ts";

type Tables = Record<string, Array<Record<string, unknown>>>;

/** سوبابيز مزيّف: بيسجل كل from/rpc، والـrpc بيطبّق نفس منطق الدالة (فتح = +١ نجاح). */
function fakeSb(t: Tables) {
  const calls: string[] = [];
  const rpcs: Array<{ fn: string; args: Record<string, unknown> }> = [];
  const state: Record<string, number> = {};
  const sb = {
    from(table: string) {
      calls.push(table);
      let lo = -Infinity, hi = Infinity;
      const q: any = {
        select: () => q, is: () => q, order: () => q, eq: () => q, in: () => q,
        gte: (col: string, v: string) => { if (col === "shown_at") lo = Date.parse(v); return q; },
        lte: (col: string, v: string) => { if (col === "shown_at") hi = Date.parse(v); return q; },
        limit: () => q,
        then: (res: (v: unknown) => void) =>
          res({
            data: (t[table] ?? []).filter((r) => typeof r.shown_at !== "string" || (Date.parse(r.shown_at) >= lo && Date.parse(r.shown_at) <= hi)),
            error: null,
          }),
      };
      return q;
    },
    rpc(fn: string, args: Record<string, unknown>) {
      rpcs.push({ fn, args });
      if (fn === "zad_bandit_settle_read") {
        const k = `${args.p_user}`;
        state[k] = (state[k] ?? 0) + 1;
        return Promise.resolve({ data: true, error: null });
      }
      return Promise.resolve({ data: true, error: null });
    },
  };
  return { sb, calls, rpcs, state };
}

const adult = { id: "m1", user_id: "u1", kind: "self", birth_year: 1990, archived_at: null };
const shownRow = { notification_id: "n1", user_id: "u1", member_id: "m1", kind: "habit_trial", arm: "warm" };
const base = (): Tables => ({
  zad_bandit_shown: [shownRow],
  app_notifications: [{ id: "n1", is_read: true }],
  zad_household_members: [adult],
  family_members: [],
});

Deno.test("an opened notification rewards the shown arm and moves its posterior", async () => {
  const { sb, rpcs } = fakeSb(base());
  const r = await settleOpenedNotifications(sb, true);
  assertEquals(r, { rewarded: 1, skipped: 0 });
  assertEquals(rpcs, [{ fn: "zad_bandit_settle_read", args: { p_user: "u1", p_notification: "n1" } }]);
  // الـposterior: نجاح واحد للقالب بيرفع احتمال اختياره عن قالب مالوش بيانات
  const approved = ["base", "warm"];
  const after = update({}, { memberId: "m1", age: 35 }, "warm", approved, true);
  assertEquals(after.m1.warm, { successes: 1, failures: 0 });
  let wins = 0;
  const rng = seededRng(3);
  const post = { m1: { warm: { successes: 30, failures: 0 }, base: { successes: 0, failures: 0 } } };
  for (let i = 0; i < 200; i++) if (chooseArm({ memberId: "m1", age: 35 }, approved, post, rng) === "warm") wins++;
  assertEquals(wins > 150, true);
});

Deno.test("not opened (ignored / no signal): nothing is written", async () => {
  const t = base();
  t.app_notifications = [{ id: "n1", is_read: false }];
  const { sb, rpcs } = fakeSb(t);
  assertEquals(await settleOpenedNotifications(sb, true), { rewarded: 0, skipped: 0 });
  assertEquals(rpcs.length, 0);
  t.app_notifications = [];
  assertEquals(await settleOpenedNotifications(fakeSb(t).sb, true), { rewarded: 0, skipped: 0 });
});

Deno.test("flag closed: zero reads and zero writes", async () => {
  const f = fakeSb(base());
  assertEquals(await settleOpenedNotifications(f.sb, false), { rewarded: 0, skipped: 0 });
  assertEquals(f.calls.length, 0);
  assertEquals(f.rpcs.length, 0);
  assertEquals(banditEnabled(() => undefined), false);
});

Deno.test("critical lane kinds never reward, even if shown rows exist", async () => {
  for (const kind of ["med_followup", "health_alert", "safety_alert", "emergency_alert", "severe_weather_alert"]) {
    const t = base();
    t.zad_bandit_shown = [{ ...shownRow, kind }];
    const f = fakeSb(t);
    assertEquals(await settleOpenedNotifications(f.sb, true), { rewarded: 0, skipped: 1 });
    assertEquals(f.rpcs.length, 0);
  }
});

Deno.test("child account and under-18 member are excluded", async () => {
  const kid = base();
  kid.family_members = [{ user_id: "u1" }];
  const a = fakeSb(kid);
  assertEquals(await settleOpenedNotifications(a.sb, true), { rewarded: 0, skipped: 1 });
  assertEquals(a.rpcs.length, 0);

  const minor = base();
  minor.zad_household_members = [{ ...adult, birth_year: new Date().getUTCFullYear() - 16 }];
  const b = fakeSb(minor);
  assertEquals(await settleOpenedNotifications(b.sb, true), { rewarded: 0, skipped: 1 });
  assertEquals(b.rpcs.length, 0);

  assertEquals(rewardEligible("habit_trial", { id: "x", kind: "child" }, false), false);
  assertEquals(rewardEligible("habit_trial", { id: "x", kind: "self", birth_year: 1990 }, false), true);
});

Deno.test("account with more than one member: ambiguous, skipped", async () => {
  const t = base();
  t.zad_household_members = [adult, { id: "m2", user_id: "u1", kind: "adult", birth_year: 1992, archived_at: null }];
  const f = fakeSb(t);
  assertEquals(await settleOpenedNotifications(f.sb, true), { rewarded: 0, skipped: 1 });
  assertEquals(f.rpcs.length, 0);
  assertEquals(unambiguousMember(t.zad_household_members as any), null);
  // فرد تاني متأرشف مابيعملش غموض
  assertEquals(unambiguousMember([adult, { id: "m2", kind: "adult", archived_at: "2026-01-01" }])?.id, "m1");
  // الفرد المسجّل مش هو الفرد الوحيد دلوقتي = تخطي
  const moved = base();
  moved.zad_bandit_shown = [{ ...shownRow, member_id: "other" }];
  const g = fakeSb(moved);
  assertEquals(await settleOpenedNotifications(g.sb, true), { rewarded: 0, skipped: 1 });
});

Deno.test("noteShown goes through the rpc and swallows failures", async () => {
  const f = fakeSb({});
  assertEquals(await noteShown(f.sb, "u1", "n1", { memberId: "m1", kind: "habit_trial", arm: "warm" }), true);
  assertEquals(f.rpcs[0].fn, "zad_bandit_note_shown");
  const boom = { rpc: () => Promise.reject(new Error("down")) };
  assertEquals(await noteShown(boom, "u1", "n1", { memberId: "m1", kind: "k", arm: "a" }), false);
});

Deno.test("a sweep failure never throws", async () => {
  const boom = { from: () => { throw new Error("db down"); }, rpc: () => Promise.resolve({ data: null, error: null }) };
  assertEquals(await settleOpenedNotifications(boom, true), { rewarded: 0, skipped: 0 });
});

// قاعدة الفشل (م٨): إشعار معروض من +٢٤ ساعة وغير مقروء = فشل للقالب.
const NOW = Date.parse("2026-11-27T12:00:00Z");
const hoursAgo = (h: number) => new Date(NOW - h * 3600 * 1000).toISOString();
const failBase = (shownHoursAgo: number, isRead: boolean | null = false): Tables => ({
  zad_bandit_shown: [{ ...shownRow, shown_at: hoursAgo(shownHoursAgo) }],
  app_notifications: [{ id: "n1", is_read: isRead }],
  zad_household_members: [adult],
  family_members: [],
});

Deno.test("failure: unread after 24h is recorded as a failure through the rpc", async () => {
  const { sb, rpcs } = fakeSb(failBase(25));
  assertEquals(await settleIgnoredNotifications(sb, true, NOW), { failed: 1, skipped: 0 });
  assertEquals(rpcs, [{ fn: "zad_bandit_settle_failure", args: { p_user: "u1", p_notification: "n1" } }]);
  // الـposterior: فشل واحد بيقلّل فرصة القالب قدام قالب جديد
  const after = update({}, { memberId: "m1", age: 35 }, "warm", ["base", "warm"], false);
  assertEquals(after.m1.warm, { successes: 0, failures: 1 });
});

Deno.test("failure: not before 24h", async () => {
  const { sb, rpcs } = fakeSb(failBase(23));
  assertEquals(await settleIgnoredNotifications(sb, true, NOW), { failed: 0, skipped: 0 });
  assertEquals(rpcs.length, 0);
});

Deno.test("failure: read in time is never failed (it rewards instead)", async () => {
  const t = failBase(25, true);
  const f = fakeSb(t);
  assertEquals(await settleIgnoredNotifications(f.sb, true, NOW), { failed: 0, skipped: 0 });
  assertEquals(f.rpcs.length, 0);
  assertEquals(await settleOpenedNotifications(f.sb, true, NOW), { rewarded: 1, skipped: 0 });
  assertEquals(f.rpcs.map((r) => r.fn), ["zad_bandit_settle_read"]);
});

Deno.test("failure: already settled rows are not even read", async () => {
  // الاستعلام بيفلتر settled_at is null؛ الفيك مابيرجّعش حاجة لو الجدول فاضي من المفتوح
  const t = failBase(25);
  t.zad_bandit_shown = [];
  const f = fakeSb(t);
  assertEquals(await settleIgnoredNotifications(f.sb, true, NOW), { failed: 0, skipped: 0 });
  assertEquals(f.rpcs.length, 0);
  // إشعار اتمسح: مفيش إشارة
  const gone = failBase(25);
  gone.app_notifications = [];
  const g = fakeSb(gone);
  assertEquals(await settleIgnoredNotifications(g.sb, true, NOW), { failed: 0, skipped: 0 });
  assertEquals(g.rpcs.length, 0);
});

Deno.test("failure: flag closed is a no-op (zero reads, zero writes)", async () => {
  const f = fakeSb(failBase(30));
  assertEquals(await settleIgnoredNotifications(f.sb, false, NOW), { failed: 0, skipped: 0 });
  assertEquals(f.calls.length, 0);
  assertEquals(f.rpcs.length, 0);
});

Deno.test("failure: same exclusions as the reward (critical, child, minor, ambiguous)", async () => {
  const crit = failBase(30);
  crit.zad_bandit_shown = [{ ...shownRow, kind: "med_followup", shown_at: hoursAgo(30) }];
  const kid = failBase(30);
  kid.family_members = [{ user_id: "u1" }];
  const minor = failBase(30);
  minor.zad_household_members = [{ ...adult, birth_year: new Date().getUTCFullYear() - 16 }];
  const multi = failBase(30);
  multi.zad_household_members = [adult, { id: "m2", user_id: "u1", kind: "adult", birth_year: 1992, archived_at: null }];
  for (const t of [crit, kid, minor, multi]) {
    const f = fakeSb(t);
    assertEquals(await settleIgnoredNotifications(f.sb, true, NOW), { failed: 0, skipped: 1 });
    assertEquals(f.rpcs.length, 0);
  }
});

Deno.test("failure: rpc error is skipped, and a sweep failure never throws", async () => {
  const f = fakeSb(failBase(30));
  const errSb = { ...f.sb, rpc: () => Promise.resolve({ data: null, error: { message: "x" } }) };
  assertEquals(await settleIgnoredNotifications(errSb, true, NOW), { failed: 0, skipped: 1 });
  const boom = { from: () => { throw new Error("db down"); }, rpc: () => Promise.resolve({ data: null, error: null }) };
  assertEquals(await settleIgnoredNotifications(boom, true, NOW), { failed: 0, skipped: 0 });
});
