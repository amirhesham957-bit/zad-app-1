// زاد بيتعلم الاستهلاك من الشرا المتكرر (20261111180000): لما مفيش ولا نزلة، المسافة بين شرا والقراية
// اللي قبله بتدي معدل تقريبي. بيتنفذ على Postgres حقيقي — الميجريشن نفسها.
import { assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import { type Db, migration } from "./scanFixture.ts";
import { PGlite } from "npm:@electric-sql/pglite@0.2.17";

const REPURCHASE = "20261111180000_consumption_from_repurchase.sql";
const U = "00000000-0000-0000-0000-000000000001";

async function db(): Promise<Db> {
  const d = new PGlite();
  await d.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema auth;
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    create table public.zad_inventory_observations (
      id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text not null,
      qty numeric not null, observed_at timestamptz not null, source text, created_at timestamptz default now());
    create table public.zad_consumption (
      user_id uuid not null, item_name text not null, avg_daily_qty double precision not null,
      sample_count integer not null, rate_known boolean not null, last_computed_at timestamptz not null,
      primary key (user_id, item_name));
  `);
  await d.exec(await migration(REPURCHASE));
  return d;
}

/** قرايات صنف واحد: [أيام من دلوقتي لورا، الكمية، المصدر]. */
async function observe(d: Db, item: string, seq: Array<[number, number, string]>) {
  for (const [daysAgo, qty, source] of seq) {
    await d.query(
      `insert into public.zad_inventory_observations (user_id, item_name, qty, observed_at, source, created_at)
       values ($1, $2, $3, now() - make_interval(secs => $4::double precision * 86400), $5, clock_timestamp())`,
      [U, item, qty, daysAgo, source],
    );
  }
}

async function recompute(d: Db, item: string) {
  await d.query("select public.zad_recompute_consumption($1, $2)", [U, item]);
  return (await d.query<{ avg_daily_qty: number; sample_count: number; rate_known: boolean }>(
    "select avg_daily_qty, sample_count, rate_known from public.zad_consumption where user_id = $1 and item_name = $2",
    [U, item],
  )).rows[0];
}

Deno.test("milk bought 2 at a time every 3 days, never answered, learns 2/3 a day as an approximate rate", async () => {
  const d = await db();
  // اشترى ٢ من ٩ أيام، و٢ كمان من ٦، و٢ من ٣ — ولا مرة قال إنه خلص.
  await observe(d, "حليب", [[9, 2, "purchase"], [6, 4, "purchase"], [3, 6, "purchase"]]);
  const r = await recompute(d, "حليب");
  assertAlmostEquals(r.avg_daily_qty, 4 / 6, 0.01);
  assertEquals(r.sample_count, 2);
  assertEquals(r.rate_known, false);
});

Deno.test("a real drop wins over the repurchase estimate", async () => {
  const d = await db();
  await observe(d, "مياه", [[10, 4, "purchase"], [6, 8, "purchase"], [5, 6, "question_answer"], [4, 4, "manual"]]);
  const r = await recompute(d, "مياه");
  // النزول بس: ٤ في اليوم (٢ + ٢ على يوم)، مش تقدير الشرا.
  assertEquals(r.sample_count, 2);
  assertEquals(r.avg_daily_qty > 1, true);
});

Deno.test("one purchase, a same-day rescan and an old gap teach nothing", async () => {
  const d = await db();
  await observe(d, "سمن", [[5, 1, "purchase"]]);
  assertEquals(await recompute(d, "سمن"), undefined);
  await observe(d, "توست", [[2, 1, "purchase"], [1.8, 2, "purchase"]]);
  assertEquals(await recompute(d, "توست"), undefined);
  await observe(d, "زيت", [[100, 1, "purchase"], [10, 2, "purchase"]]);
  assertEquals(await recompute(d, "زيت"), undefined);
});

Deno.test("a scanned receipt counts as a purchase; a hand-typed increase does not", async () => {
  const d = await db();
  await observe(d, "عيش", [[8, 5, "camera_ocr"], [4, 10, "camera_ocr"]]);
  assertAlmostEquals((await recompute(d, "عيش")).avg_daily_qty, 5 / 4, 0.01);
  await observe(d, "رز", [[8, 1, "manual"], [4, 3, "manual"]]);
  assertEquals(await recompute(d, "رز"), undefined);
});

Deno.test("a receipt saved twice the same day is not counted as a day's use", async () => {
  const d = await db();
  // دورة حقيقية (٢ على ٤ أيام)، وبعدها نفس الفاتورة اتسجلت تاني بعد ساعتين.
  await observe(d, "لبن رايب", [[10, 2, "purchase"], [6, 4, "purchase"], [5.9, 6, "purchase"]]);
  assertAlmostEquals((await recompute(d, "لبن رايب")).avg_daily_qty, 2 / 4, 0.01);
});
