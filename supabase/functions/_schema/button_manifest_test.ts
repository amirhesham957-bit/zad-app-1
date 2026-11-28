// P1.6a (بوابة ١: «مفيش زرار ظاهر من غير مسار مختبر»). الحارس الرخيص اللي بيشتغل في الـCI من غير داتابيز:
// أي معرّف زرار موجود في الكود (allowed_actions.json، enum فلاتر المولَّد، available_actions في دوال العرض، أو
// ZadViewAction.x مستعمل في الواجهة) لازم يكون في supabase/sql/e2e/button_manifest.json، وكل مدخل مغطّى لازم
// يكون له نوع نية حقيقي وجسم في button_e2e.ts. الـe2e نفسه (Postgres + PostgREST) محلي: run_commit_intent_e2e.sh.
import { assert, assertEquals } from "jsr:@std/assert@1";

const ROOT = new URL("../../../", import.meta.url);
const read = (p: string) => Deno.readTextFile(new URL(p, ROOT));

type Entry = { id: string; status: string; intent_kind: string | null; table: string | null; notification_tested: boolean };
const manifest = (JSON.parse(await read("supabase/sql/e2e/button_manifest.json")) as { actions: Entry[] }).actions;
const manifestIds = manifest.map((a) => a.id).sort();

async function* walk(dir: URL): AsyncGenerator<URL> {
  for await (const e of Deno.readDir(dir)) {
    const u = new URL(e.name + (e.isDirectory ? "/" : ""), dir);
    if (e.isDirectory) yield* walk(u);
    else yield u;
  }
}

Deno.test("manifest ids are unique and the status is one of the three", () => {
  assertEquals(new Set(manifestIds).size, manifestIds.length);
  for (const a of manifest) assert(["covered", "read_only", "no_door"].includes(a.status), `${a.id}: bad status ${a.status}`);
});

Deno.test("manifest = allowed_actions.json (both directions)", async () => {
  const allowed = (JSON.parse(await read("zad_flutter/tool/gen_views/allowed_actions.json")).actions as string[]).sort();
  assertEquals(manifestIds, allowed, "a button id exists in one file but not the other: add it to button_manifest.json (and button_e2e.ts)");
});

Deno.test("manifest = the generated Flutter enum ZadViewAction", async () => {
  const g = await read("zad_flutter/lib/core/generated/zad_views.g.dart");
  const ids = [...g.matchAll(/^\s*\w+\('([a-z_]+)'\)[,;]/gm)].map((m) => m[1]).sort();
  assertEquals(ids, manifestIds);
});

Deno.test("every available_actions id emitted by a SQL view function is in the manifest", async () => {
  const emitted = new Set<string>();
  for await (const f of Deno.readDir(new URL("supabase/migrations/", ROOT))) {
    if (!f.name.endsWith(".sql")) continue;
    const sql = await read(`supabase/migrations/${f.name}`);
    if (!/zad_view_/.test(sql)) continue;
    for (const m of sql.matchAll(/jsonb_build_object\(\s*'id',\s*'([a-z_]+)'\s*,\s*'label'/g)) emitted.add(m[1]);
  }
  assert(emitted.size >= 7, `expected the view functions to emit action ids, found ${[...emitted]}`);
  for (const id of emitted) assert(manifestIds.includes(id), `view function emits "${id}" but it is not in button_manifest.json`);
});

Deno.test("every ZadViewAction.x used in the Flutter UI is in the manifest", async () => {
  const g = await read("zad_flutter/lib/core/generated/zad_views.g.dart");
  const byName = new Map([...g.matchAll(/^\s*(\w+)\('([a-z_]+)'\)[,;]/gm)].map((m) => [m[1], m[2]]));
  for await (const u of walk(new URL("zad_flutter/lib/", ROOT))) {
    if (!u.pathname.endsWith(".dart") || u.pathname.endsWith("zad_views.g.dart")) continue;
    for (const m of (await Deno.readTextFile(u)).matchAll(/ZadViewAction\.(\w+)/g)) {
      if (m[1] === "values" || m[1] === "parse") continue;
      const id = byName.get(m[1]);
      assert(id && manifestIds.includes(id), `${u.pathname} uses ZadViewAction.${m[1]} which is not in button_manifest.json`);
    }
  }
});

Deno.test("covered entries name a real intent kind and have a body in button_e2e.ts", async () => {
  const door = await read("supabase/functions/zad-brain/commitIntent.ts");
  const union = door.slice(door.indexOf("export type IntentKind"), door.indexOf("export type IntentSource"));
  const kinds = new Set([...union.matchAll(/"([a-z_]+\.[a-z_]+)"/g)].map((m) => m[1]));
  const e2e = await read("supabase/sql/e2e/button_e2e.ts");
  for (const a of manifest) {
    if (a.status === "covered") {
      assert(a.intent_kind && kinds.has(a.intent_kind), `${a.id}: intent_kind ${a.intent_kind} is not an IntentKind`);
      assert(e2e.includes(`"${a.id}": async`), `${a.id}: covered in the manifest but button_e2e.ts has no body for it`);
    } else {
      assertEquals(a.intent_kind, null, `${a.id}: ${a.status} must not name an intent kind`);
      assert(!e2e.includes(`"${a.id}": async`), `${a.id}: has an e2e body but the manifest does not say covered`);
    }
  }
});
