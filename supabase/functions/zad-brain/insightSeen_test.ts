// zad_mark_insight_seen (20261011293145): التطبيق بيسجّل أول ظهور للكارت — على Postgres حقيقي.
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { addUser, type Db, migration, scanDb } from "./scanFixture.ts";

const SEEN = "20261011293145_insight_seen_at.sql";

async function seenDb(): Promise<Db> {
  const db = await scanDb();
  await db.exec(await migration(SEEN));
  return db;
}

async function card(db: Db, user: string, writtenHoursAgo = 2): Promise<string> {
  const r = await db.query<{ id: string }>(
    `insert into public.zad_insights (user_id, kind, surface, title, body, dedupe_key, created_at, updated_at)
     values ($1, 'insight', 'home_card', 't', 'b', $2, now() - make_interval(hours => $3), now() - make_interval(hours => $3))
     returning id`,
    [user, crypto.randomUUID(), writtenHoursAgo],
  );
  return r.rows[0].id;
}

/** ينادي الدالة كأنه العميل (auth.uid() من الـJWT). */
async function mark(db: Db, as: string | null, id: string, at: string | null): Promise<string | null> {
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [as ?? ""]);
  const r = await db.query<{ s: Date | null }>("select public.zad_mark_insight_seen($1, $2) as s", [id, at]);
  return r.rows[0].s ? new Date(r.rows[0].s).toISOString() : null;
}

async function row(db: Db, id: string) {
  return (await db.query<{ seen_at: Date | null; status: string; updated_at: Date; created_at: Date }>(
    "select seen_at, status, updated_at, created_at from public.zad_insights where id = $1", [id],
  )).rows[0];
}

Deno.test("the first time a card is shown is kept; a later report does not move it", async () => {
  const db = await seenDb();
  const user = await addUser(db);
  const id = await card(db, user);
  const before = await row(db, id);
  const firstAt = new Date(Date.now() - 3_600_000).toISOString();

  assertEquals(await mark(db, user, id, firstAt), firstAt);
  assertEquals(await mark(db, user, id, new Date().toISOString()), firstAt, "second report: still the first");

  const after = await row(db, id);
  assertEquals(after.status, "pending", "status is not touched — the app reads pending");
  assertEquals(after.updated_at.toISOString(), before.updated_at.toISOString(), "«مش مهم ليا» counts from updated_at");
});

Deno.test("the phone's clock is clamped between when the card was written and now", async () => {
  const db = await seenDb();
  const user = await addUser(db);
  const early = await card(db, user, 2);
  const seen = await mark(db, user, early, "2020-01-01T00:00:00Z");
  assertEquals(seen, (await row(db, early)).created_at.toISOString(), "before it existed ⇒ when it was written");

  const future = await card(db, user, 2);
  const s = Date.parse((await mark(db, user, future, "2099-01-01T00:00:00Z"))!);
  assert(Math.abs(s - Date.now()) < 60_000, "in the future ⇒ now");

  const missing = await card(db, user, 2);
  assert(await mark(db, user, missing, null) !== null, "no time sent ⇒ now");
});

Deno.test("only the customer's own card: someone else's is untouched and reads as gone", async () => {
  const db = await seenDb();
  const owner = await addUser(db);
  const other = await addUser(db);
  const id = await card(db, owner);
  assertEquals(await mark(db, other, id, new Date().toISOString()), null);
  assertEquals((await row(db, id)).seen_at, null);
  assertEquals(await mark(db, owner, crypto.randomUUID(), null), null, "a deleted card reads as gone");
});

Deno.test("signed out is refused, and the anon key cannot call it", async () => {
  const db = await seenDb();
  const user = await addUser(db);
  const id = await card(db, user);
  await assertRejects(() => mark(db, null, id, null), Error, "authentication required");
  for (const [role, allowed] of [["anon", false], ["authenticated", true], ["service_role", true]] as const) {
    const r = await db.query<{ ok: boolean }>(
      "select has_function_privilege($1, 'public.zad_mark_insight_seen(uuid,timestamptz)', 'execute') as ok", [role],
    );
    assertEquals(r.rows[0].ok, allowed, role);
  }
});
