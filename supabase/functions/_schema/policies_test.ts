// حارس السياسات المفتوحة (البند ٠.٧، ٢٠٢٦-١٠-١٨).
//
// مايجريشن 20260831140000 عمل سياسات insert باسم "*_server_write" بـ`with check (true)` على أمل إن
// السيرفر بس هو اللي يكتب. ده مش بيحصل: service_role بيتخطى RLS أصلاً ومش محتاج سياسة، والسياسة من
// غير `to` بتروح لـpublic — يعني أي حد معاه الـanon key يقدر يدخّل صفوف باسم أي مستخدم. اتنين منهم
// (shopping_recommendations، user_achievements) فضلوا عايشين لحد 20261018230000.
//
// الاختبار بيقرا المايجريشنز بالترتيب ويبني آخر حالة لسياسات public (create/drop policy، drop table)،
// والقاعدة: سياسة كتابة (insert/update/delete/all) شرطها `true` لازم تكون `to service_role` بس.
// سياسات القراءة المفتوحة (أسعار الصرف، كتالوج الرفيق) مقصودة ومش جوه القاعدة.

import { assertEquals } from "jsr:@std/assert@1";

const DIR = new URL("../../migrations/", import.meta.url);

interface Policy {
  table: string;
  cmd: string;
  roles: string[];
  open: boolean;
  file: string;
}

const ident = String.raw`(?:public\.)?"?([a-z_][a-z0-9_]*)"?`;

/** آخر حالة لكل سياسة public من المايجريشنز، بمفتاح table/policy. */
export function policyStates(files: Array<{ name: string; text: string }>): Map<string, Policy> {
  const out = new Map<string, Policy>();
  const stmt = new RegExp(
    String.raw`create\s+policy\s+"?([^"\n]+?)"?\s+on\s+${ident}([^;]*);` +
      String.raw`|drop\s+policy\s+(?:if\s+exists\s+)?"?([^"\n]+?)"?\s+on\s+${ident}\s*;` +
      String.raw`|drop\s+table\s+(?:if\s+exists\s+)?${ident}`,
    "gi",
  );
  for (const { name, text } of files) {
    const clean = text.replace(/--[^\n]*/g, "");
    for (const m of clean.matchAll(stmt)) {
      if (m[1]) {
        const table = m[2].toLowerCase();
        const rest = m[3].toLowerCase();
        const cmd = /\bfor\s+(select|insert|update|delete|all)\b/.exec(rest)?.[1] ?? "all";
        const to = /\bto\s+([a-z_,\s]+?)(?=\s+(?:using|with)\b|$)/.exec(rest.trim());
        const roles = to ? to[1].split(",").map((r) => r.trim()).filter(Boolean) : ["public"];
        const open = /(?:using|with\s+check)\s*\(\s*true\s*\)/.test(rest);
        out.set(`${table}/${m[1]}`, { table, cmd, roles, open, file: name });
      } else if (m[4]) {
        out.delete(`${m[5].toLowerCase()}/${m[4]}`);
      } else if (m[6]) {
        const table = m[6].toLowerCase();
        for (const key of [...out.keys()]) if (key.startsWith(`${table}/`)) out.delete(key);
      }
    }
  }
  return out;
}

export function openWrites(states: Map<string, Policy>): string[] {
  const out: string[] = [];
  for (const [key, p] of states) {
    if (!p.open || p.cmd === "select") continue;
    if (p.roles.every((r) => r === "service_role")) continue;
    out.push(`${key} (${p.file}) — ${p.cmd} to ${p.roles.join(", ")}`);
  }
  return out.sort();
}

async function migrations(): Promise<Array<{ name: string; text: string }>> {
  const names: string[] = [];
  for await (const e of Deno.readDir(DIR)) if (e.isFile && e.name.endsWith(".sql")) names.push(e.name);
  names.sort();
  return await Promise.all(names.map(async (name) => ({ name, text: await Deno.readTextFile(new URL(name, DIR)) })));
}

Deno.test("no write policy lets a client write any row (check true)", async () => {
  assertEquals(openWrites(policyStates(await migrations())), []);
});

Deno.test("the policy guard sees the bug it guards against, and what fixes it", () => {
  const bad = `create policy "x_server_write" on public.x\n  for insert with check (true);`;
  assertEquals(openWrites(policyStates([{ name: "a.sql", text: bad }])).length, 1);
  // dropped later
  assertEquals(openWrites(policyStates([{ name: "a.sql", text: bad },
    { name: "b.sql", text: `drop policy if exists "x_server_write" on public.x;` }])), []);
  // table dropped later
  assertEquals(openWrites(policyStates([{ name: "a.sql", text: bad },
    { name: "b.sql", text: `drop table if exists public.x cascade;` }])), []);
  // service_role only is fine
  assertEquals(openWrites(policyStates([{ name: "a.sql", text: bad.replace("for insert", "for insert to service_role") }])), []);
  // to authenticated is still open
  assertEquals(openWrites(policyStates([{ name: "a.sql", text: bad.replace("for insert", "for insert to authenticated") }])).length, 1);
  // an owner check is fine, an open read is fine
  assertEquals(openWrites(policyStates([{ name: "a.sql", text: bad.replace("(true)", "(auth.uid() = user_id)") }])), []);
  assertEquals(openWrites(policyStates([{ name: "a.sql", text: `create policy r on x for select using (true);` }])), []);
});
