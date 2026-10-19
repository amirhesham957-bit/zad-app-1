// «هيخلص إمتى؟» (20261019160000): معدل الاستهلاك من الوقت اللي الصنف كان بيخلص فيه، والحارس بياخد
// التقريبي. بيتنفذ على Postgres حقيقي (scanFixture.ts) — الميجريشن نفسها، مش نصها.
import { assert, assertAlmostEquals, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { addUser, type Db, functionBlock, migration } from "./scanFixture.ts";
import { PGlite } from "npm:@electric-sql/pglite@0.2.17";

const BUSY_TIME = "20261019160000_consumption_busy_time.sql";
const SHORTAGE = "20260930130000_predicted_shortage.sql";

async function db(): Promise<Db> {
  const d = new PGlite();
  await d.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema auth;
    create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    create table public.zad_users (id uuid primary key, country text, currency text);
    create table public.zad_inventory_observations (
      id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text not null,
      qty numeric not null, observed_at timestamptz not null, source text, created_at timestamptz default now());
    create table public.zad_consumption (
      user_id uuid not null, item_name text not null, avg_daily_qty double precision not null,
      sample_count integer not null, rate_known boolean not null, last_computed_at timestamptz not null,
      primary key (user_id, item_name));
    create table public.zad_inventory (
      user_id uuid not null, item_name text not null, quantity numeric not null, low_stock_threshold numeric);
    create table public.zad_shopping_list (user_id uuid, item_name text, is_purchased boolean);
    create table public.price_index (
      item_name text, price numeric, store_name text, "timestamp" timestamptz, currency text, source text);
    create table public.agent_tasks (
      id uuid primary key default gen_random_uuid(), user_id uuid not null, kind text not null,
      task_description text, scheduled_for timestamptz, created_at timestamptz not null default now());
  `);
  // الحارس زي ما اتعمل (بشرط rate_known)، والميجريشن هي اللي بتشيله.
  const shortage = await migration(SHORTAGE);
  await d.exec(shortage.slice(0, shortage.indexOf("create or replace function public._agent_predicted_shortage_for_user(")));
  await d.exec(functionBlock(shortage, "_agent_predicted_shortage_for_user"));
  return d;
}

/** قرايات صنف واحد: [أيام من دلوقتي لورا، الكمية]. */
async function observe(d: Db, user: string, item: string, seq: Array<[number, number]>) {
  for (const [daysAgo, qty] of seq) {
    await d.query(
      `insert into public.zad_inventory_observations (user_id, item_name, qty, observed_at, created_at)
       values ($1, $2, $3, now() - make_interval(secs => $4::double precision * 86400), clock_timestamp())`,
      [user, item, qty, daysAgo],
    );
  }
}

async function rate(d: Db, user: string, item: string) {
  return (await d.query<{ avg_daily_qty: number; sample_count: number; rate_known: boolean }>(
    "select avg_daily_qty, sample_count, rate_known from public.zad_consumption where user_id = $1 and item_name = $2",
    [user, item],
  )).rows[0];
}

const recompute = (d: Db, user: string, item: string) =>
  d.query("select public.zad_recompute_consumption($1, $2)", [user, item]);

Deno.test("a drop counts the time since the quantity last changed, not since the first reading", async () => {
  const d = await db();
  await d.exec(await migration(BUSY_TIME));
  const u = await addUser(d);
  // التوست على الحي: ٢ (قرايتين من غير تغيير)، ١ بعد ٥٫٥٦ يوم، ٠ بعد ١٫٧٢ كمان.
  await observe(d, u, "توست", [[20, 2], [19, 2], [16, 2], [14.44, 1], [12.72, 0]]);
  await recompute(d, u, "توست");
  const r = await rate(d, u, "توست");
  assertAlmostEquals(r.avg_daily_qty, 2 / 7.28, 0.01);
  assertEquals(r.sample_count, 2);
  assertEquals(r.rate_known, false);
});

Deno.test("time spent out of stock before a restock is not consumption", async () => {
  const d = await db();
  await d.exec(await migration(BUSY_TIME));
  const u = await addUser(d);
  // ١ ← ٠ في يوم، ٢٠ يوم خلصان، اشترى ٢، ٢ ← ١ في يومين.
  await observe(d, u, "جبنة", [[30, 1], [29, 0], [9, 0], [9, 2], [7, 1]]);
  await recompute(d, u, "جبنة");
  assertAlmostEquals((await rate(d, u, "جبنة")).avg_daily_qty, 2 / 3, 0.01);
});

Deno.test("a drop after a month with no reading gives no rate, and a stale rate is wiped", async () => {
  const d = await db();
  const u = await addUser(d);
  await observe(d, u, "حليب", [[70, 4], [20, 3]]);
  await d.query(
    `insert into public.zad_consumption values ($1, 'حليب', 0.03, 1, false, now())`, [u],
  );
  await d.exec(await migration(BUSY_TIME)); // الباكفيل بيحسب من جديد
  assertEquals(await rate(d, u, "حليب"), undefined);
});

Deno.test("under twelve hours of use is test data, not a rate", async () => {
  const d = await db();
  await d.exec(await migration(BUSY_TIME));
  const u = await addUser(d);
  await observe(d, u, "مية", [[1, 6], [1 - 3 / 1440, 1]]);
  const out = (await recompute(d, u, "مية")).rows[0] as { zad_recompute_consumption: { avg_daily_qty: number | null } };
  assertEquals(out.zad_recompute_consumption.avg_daily_qty, null);
  assertEquals(await rate(d, u, "مية"), undefined);
});

Deno.test("three drops on two days still make the rate known", async () => {
  const d = await db();
  await d.exec(await migration(BUSY_TIME));
  const u = await addUser(d);
  await observe(d, u, "عيش", [[5, 6], [4, 4], [3, 3], [2, 1]]);
  await recompute(d, u, "عيش");
  const r = await rate(d, u, "عيش");
  assertEquals(r.rate_known, true);
  assertAlmostEquals(r.avg_daily_qty, 5 / 3, 0.01);
});

Deno.test("the shortage guard asks about an approximate rate — before, it never fired", async () => {
  const d = await db();
  const u = await addUser(d);
  await d.query("insert into public.zad_inventory values ($1, 'جبنة', 4, 1)", [u]);
  await d.query(`insert into public.zad_consumption values ($1, 'جبنة', 2, 1, false, now())`, [u]);
  await d.query("select public._agent_predicted_shortage_for_user($1)", [u]);
  assertEquals((await d.query("select 1 from public.agent_tasks")).rows.length, 0);

  // الباكفيل هيمسح الصف (مفيش قرايات)، فالصف بيرجع بعد الميجريشن.
  await d.exec(await migration(BUSY_TIME));
  await d.query(`insert into public.zad_consumption values ($1, 'جبنة', 2, 1, false, now())`, [u]);
  await d.query("select public._agent_predicted_shortage_for_user($1)", [u]);
  const tasks = (await d.query<{ kind: string; task_description: string }>(
    "select kind, task_description from public.agent_tasks where user_id = $1", [u],
  )).rows;
  assertEquals(tasks.length, 1);
  assertEquals(tasks[0].kind, "predicted_shortage");
  assertStringIncludes(tasks[0].task_description, "«جبنة» (فاضل حوالي 2 يوم)");
});

Deno.test("the guard edit stops on an unexpected shape instead of guessing", async () => {
  const d = await db();
  await d.exec(await migration(BUSY_TIME));
  let failed = false;
  try {
    await d.exec(await migration(BUSY_TIME)); // الشرط اتشال خلاص: صفر تطابق
  } catch (e) {
    failed = true;
    assertStringIncludes(String(e), "expected 1");
  }
  assert(failed);
});
