// باب واحد (ZAD_PLAN ٣.٤): الجداول دي ليها كاتب واحد على السيرفر.
//
// كان البوت بيكتب بنفسه في zad_pharmacy_doses و zad_dose_snoozes و zad_memory، فاللي يتسجل من تليجرام
// ممكن يختلف عن اللي العقل يعرفه («البوت قال حاجة والتطبيق حاجة»). دلوقتي:
//   • zad_pharmacy_doses و zad_dose_snoozes — بتتكتب في _shared/doseDoor.ts بس (أو بـRPC زي
//     zad_log_pharmacy_dose_atomic من أي حتة)، والبوت بيوصلها بأداة العقل answer_dose_reminder.
//   • zad_memory — العقل (zad-brain/) و _shared/doseDoor.ts بس. البوت وأي فانكشن تانية بتطلب من العقل.
// التست ده بيقرا كود كل الدوال وبيفشل لو سلسلة `.from("<الجدول>")` فيها insert/upsert/update/delete
// في ملف مش مسموحله. القراية (select) مسموحة من أي حتة.
import { assertEquals } from "jsr:@std/assert@1";

const ROOT = new URL("../", import.meta.url);

const WRITERS: Record<string, (path: string) => boolean> = {
  zad_pharmacy_doses: (p) => p === "_shared/doseDoor.ts",
  zad_dose_snoozes: (p) => p === "_shared/doseDoor.ts",
  zad_memory: (p) => p === "_shared/doseDoor.ts" || p.startsWith("zad-brain/"),
};

async function* sources(dir: URL, prefix = ""): AsyncGenerator<string> {
  for await (const e of Deno.readDir(dir)) {
    const rel = prefix + e.name;
    if (e.isDirectory) {
      if (e.name === "node_modules" || e.name.startsWith(".")) continue;
      yield* sources(new URL(`${e.name}/`, dir), `${rel}/`);
    } else if (e.name.endsWith(".ts") && !e.name.endsWith("_test.ts")) {
      yield rel;
    }
  }
}

/** كل `.from("T")` وبعدها سلسلة لحد أول `;` فيها كتابة. */
export function writesIn(text: string, table: string): number {
  let n = 0;
  const re = new RegExp(`\\.from\\(\\s*["'\`]${table}["'\`]\\s*\\)`, "g");
  for (const m of text.matchAll(re)) {
    const tail = text.slice(m.index! + m[0].length, m.index! + m[0].length + 600);
    const chain = tail.split(";")[0];
    if (/^\s*\.(insert|upsert|update|delete)\s*\(/.test(chain.replace(/\/\/[^\n]*\n/g, "\n"))) n++;
  }
  return n;
}

Deno.test("the detector sees a write chain and ignores a read", () => {
  assertEquals(writesIn(`await sb.from("zad_memory")\n    .insert({ a: 1 });`, "zad_memory"), 1);
  assertEquals(writesIn(`await sb.from("zad_memory").select("id").eq("x", 1);`, "zad_memory"), 0);
  assertEquals(writesIn(`sb.from('zad_dose_snoozes').upsert(rows, { onConflict: "a" })`, "zad_dose_snoozes"), 1);
});

Deno.test("dose, snooze and memory rows have one writer on the server", async () => {
  const offenders: string[] = [];
  for await (const path of sources(ROOT)) {
    const text = await Deno.readTextFile(new URL(path, ROOT));
    for (const [table, allowed] of Object.entries(WRITERS)) {
      const n = writesIn(text, table);
      if (n > 0 && !allowed(path)) offenders.push(`${path}: ${n} write(s) to ${table}`);
    }
  }
  assertEquals(offenders, [], "write through _shared/doseDoor.ts or a zad-brain tool instead");
});
