// حارس أسماء الجداول (P0.2): كل `.from('x')` في الـedge functions لازم x يكون جدول/view
// بتعمله المايجريشنز (بعد تطبيقها كلها بالترتيب، يعني بعد الـdrop). `schema_contract_test.ts` بيقارن بلقطة
// `schema.json` اللي بتتحدّث يدوي؛ ده بيقارن بالمايجريشنز نفسها، فجدول اتحذف (زي zad_waste_log في
// 20260905130000) ومحدّش رجّعه بيفشّل البناء بدل ما PostgREST يرجع 42P01 ويتبلع بصمت.

import { assert, assertEquals } from "jsr:@std/assert@1";

const FUNCTIONS = new URL("../", import.meta.url);
const MIGRATIONS = new URL("../../migrations/", import.meta.url);

const NAME = `"?(?:public"?\\."?)?([a-z_][a-z0-9_]*)"?`;

/** الجداول والـviews بعد تطبيق كل المايجريشنز بالترتيب (create يضيف، drop يشيل). */
export function relationsAfter(migrations: Array<{ name: string; sql: string }>): Set<string> {
  const live = new Set<string>();
  for (const m of [...migrations].sort((a, b) => a.name.localeCompare(b.name))) {
    const sql = m.sql.replace(/\/\*[\s\S]*?\*\//g, "").replace(/--[^\n]*/g, "");
    const events: Array<{ at: number; add: boolean; name: string }> = [];
    const create = new RegExp(
      `create\\s+(?:or\\s+replace\\s+)?(?:(?:global\\s+|local\\s+)?(?:temp|temporary|unlogged)\\s+)?(?:materialized\\s+)?(?:table|view)\\s+(?:if\\s+not\\s+exists\\s+)?${NAME}`,
      "gi",
    );
    for (const x of sql.matchAll(create)) events.push({ at: x.index!, add: true, name: x[1] });
    const drop = new RegExp(`drop\\s+(?:materialized\\s+)?(?:table|view)\\s+(?:if\\s+exists\\s+)?((?:${NAME}\\s*,?\\s*)+)`, "gi");
    for (const x of sql.matchAll(drop)) {
      for (const n of x[1].matchAll(new RegExp(NAME, "g"))) events.push({ at: x.index!, add: false, name: n[1] });
    }
    // alter table ... rename to
    const ren = new RegExp(`alter\\s+table\\s+(?:if\\s+exists\\s+)?${NAME}\\s+rename\\s+to\\s+${NAME}`, "gi");
    for (const x of sql.matchAll(ren)) {
      events.push({ at: x.index!, add: false, name: x[1] });
      events.push({ at: x.index!, add: true, name: x[2] });
    }
    events.sort((a, b) => a.at - b.at);
    for (const e of events) e.add ? live.add(e.name) : live.delete(e.name);
  }
  return live;
}

/** كل `.from("x")` على جدول (مش `storage.from` ولا `Array.from`) مع الملف. */
export function fromCalls(files: Array<{ path: string; text: string }>): Array<{ table: string; path: string }> {
  const out: Array<{ table: string; path: string }> = [];
  for (const f of files) {
    const text = f.text.replace(/\/\*[\s\S]*?\*\//g, "").replace(/^\s*\/\/.*$/gm, "");
    for (const m of text.matchAll(/(\bstorage\s*\.\s*|\bArray\s*\.\s*|\bObject\s*\.\s*)?\.?from\s*\(\s*(["'`])([A-Za-z_][A-Za-z0-9_]*)\2\s*\)/g)) {
      if (m[1]) continue;
      out.push({ table: m[3], path: f.path });
    }
  }
  return out;
}

async function readTs(dir: URL, base = "", out: Array<{ path: string; text: string }> = []) {
  for await (const e of Deno.readDir(dir)) {
    if (e.name.startsWith(".") || e.name === "node_modules") continue;
    if (e.isDirectory) await readTs(new URL(e.name + "/", dir), `${base}${e.name}/`, out);
    else if (e.name.endsWith(".ts") && !e.name.endsWith("_test.ts")) {
      out.push({ path: base + e.name, text: await Deno.readTextFile(new URL(e.name, dir)) });
    }
  }
  return out;
}

async function liveRelations(): Promise<Set<string>> {
  const migs: Array<{ name: string; sql: string }> = [];
  for await (const e of Deno.readDir(MIGRATIONS)) {
    if (e.name.endsWith(".sql")) migs.push({ name: e.name, sql: await Deno.readTextFile(new URL(e.name, MIGRATIONS)) });
  }
  return relationsAfter(migs);
}

Deno.test("كل .from('x') في الـedge functions جدول/view موجود بعد كل المايجريشنز", async () => {
  const live = await liveRelations();
  const calls = fromCalls(await readTs(FUNCTIONS));
  assert(calls.length > 50, `الفاحص مالقاش .from كفاية (${calls.length}) — الريجيكس اتكسر؟`);
  const missing = calls.filter((c) => !live.has(c.table));
  assertEquals(
    missing.map((c) => `${c.table} ← ${c.path}`),
    [],
    "قراية/كتابة على جدول مش بتعمله أي مايجريشن (اتحذف؟ اسمه غلط؟)",
  );
});

Deno.test("zad_waste_log موجود بعد المايجريشنز، وvoiceMoments بيقرا منه", async () => {
  const live = await liveRelations();
  assert(live.has("zad_waste_log"), "20260905130000 حذفته؛ 20260913002000 لازم يرجّعه");
  const src = await Deno.readTextFile(new URL("../zad-brain/voiceMoments.ts", import.meta.url));
  assert(/\.from\("zad_waste_log"\)/.test(src));
});

Deno.test("الفاحص نفسه: حذف جدول من غير رجوع بيطلّعه ناقص", () => {
  const live = relationsAfter([
    { name: "1.sql", sql: "create table if not exists public.zad_waste_log (id int); create view v_x as select 1;" },
    { name: "2.sql", sql: "drop table if exists public.zad_waste_log cascade;" },
  ]);
  assert(!live.has("zad_waste_log") && live.has("v_x"));
  const restored = relationsAfter([
    { name: "1.sql", sql: "create table public.zad_waste_log (id int);" },
    { name: "2.sql", sql: "drop table public.zad_waste_log;" },
    { name: "3.sql", sql: "create table if not exists public.zad_waste_log (id int);" },
  ]);
  assert(restored.has("zad_waste_log"));
  const calls = fromCalls([{ path: "a.ts", text: `sb.from("t1"); sb.storage.from("bucket"); Array.from("abc"); x\n.from('t2')` }]);
  assertEquals(calls.map((c) => c.table), ["t1", "t2"]);
});
