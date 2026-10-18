// حارس الجداول اليتيمة (الموجة ٧، ٢٠٢٦-١٠-١١).
//
// فحص ما قبل الإطلاق لقى جداول بيقراها التطبيق أو العقل ومحدش بيكتب فيها — shopping_recommendations من ساعة
// ما zad-market-intelligence اتشالت (2026-09-05)، فالشاشة كانت بتعرض «شغلت كل التوصيات 🎉» على حساب
// عمره ما خد توصية. الكسر ده مابيبانش في البناء ولا في أي تست.
//
// القاعدة: كل جدول في schema.json ليه كاتب واحد على الأقل — insert في SQL (مايجريشن أو دالة)، أو
// insert/upsert من الإيدج فنكشنز أو التطبيق. update ومسح مابيملوش جدول فاضي. اليتامى المعروفين في KNOWN بسببهم؛ يتيم جديد بيفشّل
// البناء. لو جدول اتمسح أو اتكتب له كاتب، شيله من KNOWN (الاختبار التاني بيطلب كده).

import { assertEquals } from "jsr:@std/assert@1";

const ROOT = new URL("../../../", import.meta.url);

/** يتامى معروفين — كل واحد بسببه. */
const KNOWN: Record<string, string> = {
  shopping_recommendations: "كاتبه zad-market-intelligence اتشال 2026-09-05؛ الشاشة بتخبيه لما يفضى. مسحه قرار المالك.",
  shared_grocery_list: "اتقاعد 2026-10-11 (20261011140000): صفوفه المفتوحة اتنقلت لقايمة البيت والتطبيق بطّل يكتب. مسحه قرار.",
  family_typing_status: "كان بيكتبه تطبيق Kotlin؛ Flutter مابيعرضش «بيكتب…». صفّين على الحي من قبل 2026-09-29.",
  user_achievements: "الشاشة بتقراه، والإنجاز بيتفتح من الداتا نفسها (achievements.dart)؛ مفيش كاتب من ساعة Kotlin.",
};

async function readAll(dir: URL, ext: string[], out: string[] = []): Promise<string[]> {
  for await (const e of Deno.readDir(dir)) {
    if (e.name.startsWith(".") || e.name === "build" || e.name === "node_modules") continue;
    const url = new URL(e.name + (e.isDirectory ? "/" : ""), dir);
    if (e.isDirectory) await readAll(url, ext, out);
    else if (ext.some((x) => e.name.endsWith(x)) && !e.name.endsWith("_test.ts") && !e.name.endsWith("_test.dart")) {
      out.push(await Deno.readTextFile(url));
    }
  }
  return out;
}

export function writtenTables(tables: string[], sql: string[], ts: string[], dart: string[]): Set<string> {
  const written = new Set<string>();
  const sqlText = sql.join("\n").replace(/--[^\n]*/g, "");
  for (const t of tables) {
    const q = `"?(?:public\\.)?"?${t}"?\\b`;
    // Something that creates rows: an update or a delete cannot fill an empty table.
    if (new RegExp(`\\b(insert\\s+into|merge\\s+into)\\s+${q}`, "i").test(sqlText)) written.add(t);
    else if (ts.some((f) => new RegExp(`from\\(\\s*["'\`]${t}["'\`]\\s*\\)[\\s\\S]{0,600}?\\.(insert|upsert)\\(`).test(f))) written.add(t);
    else if (dart.some((f) => f.includes(`'${t}'`) && /\.(insert|upsert)\(/.test(f))) written.add(t);
  }
  return written;
}

Deno.test("every table has a writer, or a recorded reason it has none", async () => {
  const schema = JSON.parse(await Deno.readTextFile(new URL("supabase/functions/_schema/schema.json", ROOT)));
  const tables = Object.keys(schema).filter((k) => k !== "_meta");
  const [sql, ts, dart] = await Promise.all([
    readAll(new URL("supabase/migrations/", ROOT), [".sql"]),
    readAll(new URL("supabase/functions/", ROOT), [".ts"]),
    readAll(new URL("zad_flutter/lib/", ROOT), [".dart"]),
  ]);
  const written = writtenTables(tables, sql, ts, dart);
  const orphans = tables.filter((t) => !written.has(t) && !(t in KNOWN)).sort();
  assertEquals(orphans, [], "a table nothing writes — give it a writer, drop it, or record why in KNOWN");
  const stale = Object.keys(KNOWN).filter((t) => written.has(t) || !tables.includes(t)).sort();
  assertEquals(stale, [], "a KNOWN orphan has a writer now, or is gone — take it out of KNOWN");
});

Deno.test("the guard reads writers in all three places", () => {
  const w = writtenTables(
    ["a", "b", "c", "d"],
    ["create function f() as $$ begin insert into public.a (x) values (1); end $$;"],
    [`await sb.from("b").select("id").eq("x", 1);\nawait sb.from("b")\n  .upsert({ x: 2 })`, `await sb.from("d").update({ x: 1 })`],
    ["const t = 'c'; await client.from(t).upsert(row);"],
  );
  assertEquals([...w].sort(), ["a", "b", "c"], "d is only updated — nothing creates its rows");
});
