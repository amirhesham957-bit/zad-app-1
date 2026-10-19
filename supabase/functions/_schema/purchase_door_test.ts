// باب شرا واحد (ZAD_PLAN ٣.٦ هـ، docs/agent/ZAD_PURCHASE_DOOR.md): مفيش باب على السيرفر بيكتب
// zad_transactions بإيده غير الأبواب اللي فلوس بس. شرا فيه أصناف بيروح لـzad_record_purchase_service
// (الفلوس والمخزن والصيدلية والأسعار يا كلهم يا ولا حاجة). باب جديد بيعمل insert/upsert مباشر بيوقّع
// الاختبار لحد ما حد يقرر: فلوس بس (يتضاف تحت بسببه)، ولا شرا (يروح للدالة).
import { assertEquals } from "jsr:@std/assert@1";

const ROOT = new URL("../", import.meta.url);

/** ملف → عدد الكتابات المباشرة المسموحة فيه، وليه مفيهاش أصناف. */
const MONEY_ONLY: Record<string, { count: number; why: string }> = {
  // تسوية الكاش (المحسوب ≠ اللي العميل قاله)، وlog_transaction من غير lines.
  "zad-brain/index.ts": { count: 2, why: "تسوية الكاش، ومصروف/دخل من غير أصناف" },
};

const DIRECT = /\.from\(\s*["']zad_transactions["']\s*\)\s*\.(insert|upsert)\(/g;

async function* sources(dir: URL, prefix = ""): AsyncGenerator<[string, string]> {
  for await (const e of Deno.readDir(dir)) {
    if (e.name.startsWith("_") || e.name === "node_modules") continue;
    const rel = prefix + e.name;
    if (e.isDirectory) yield* sources(new URL(e.name + "/", dir), rel + "/");
    else if (e.name.endsWith(".ts") && !e.name.endsWith("_test.ts")) {
      yield [rel, await Deno.readTextFile(new URL(e.name, dir))];
    }
  }
}

Deno.test("باب شرا واحد: كل كتابة مباشرة في zad_transactions على السيرفر باب فلوس بس معروف", async () => {
  const found: Record<string, number> = {};
  for await (const [rel, text] of sources(ROOT)) {
    const n = [...text.matchAll(DIRECT)].length;
    if (n > 0) found[rel] = n;
  }
  const allowed = Object.fromEntries(Object.entries(MONEY_ONLY).map(([f, v]) => [f, v.count]));
  assertEquals(
    found,
    allowed,
    "كتابة مباشرة جديدة في zad_transactions. لو فيها أصناف: zad_record_purchase_service. " +
      "لو فلوس بس: زوّدها في MONEY_ONLY بالسبب.",
  );
});
