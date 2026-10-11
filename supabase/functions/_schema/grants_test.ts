// حارس الصلاحيات (الموجة ٧، ٢٠٢٦-١٠-١١).
//
// Supabase بيدّي anon وauthenticated صلاحية EXECUTE على أي دالة جديدة في public. الغلطة دي حصلت مرتين:
// _agent_spend_forecast_for_user (اتقفلت 20260913162000) و_agent_habit_budget_for_user (اتقفلت
// 20261011130000) — دالة security definer بتاخد p_user ومابتتحققش من auth.uid()، فأي حد معاه الـanon key
// يقدر يناديها على أي حساب.
//
// الاختبار ده بيقرا كل المايجريشنز بالترتيب ويبني آخر حالة لكل دالة في public: آخر تعريف (definer؟ بتاخد
// p_user؟ جسمها فيه auth.uid()؟) ومين ليه EXECUTE بعد كل grant/revoke. القاعدة:
//   دالة security definer في public بتاخد p_user uuid، ولسه anon أو authenticated يقدر يناديها
//   ⇒ لازم جسمها يقرا auth.uid() (يتحقق إن المتصل هو p_user، أو يمرره لـimpl).
// دوال التريجر بره القاعدة (مابتتناديش). لو الاختبار وقع: اقفلها (revoke … from public, anon, authenticated
// + grant service_role) أو اتحقق من auth.uid() جواها.

import { assertEquals } from "jsr:@std/assert@1";

const DIR = new URL("../../migrations/", import.meta.url);

interface Fn {
  definer: boolean;
  takesUser: boolean;
  checksCaller: boolean;
  trigger: boolean;
  exposed: Set<string>;
  file: string;
}

const ROLES = ["anon", "authenticated", "public"];

function rolesIn(list: string): string[] {
  return list.toLowerCase().split(",").map((r) => r.trim()).filter((r) => ROLES.includes(r));
}

/** آخر حالة لكل دالة public من المايجريشنز. */
export function functionStates(files: Array<{ name: string; text: string }>): Map<string, Fn> {
  const fns = new Map<string, Fn>();
  // create function / grant / revoke بالترتيب جوه الملف.
  const stmt = new RegExp(
    String.raw`create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?"?([a-z_][a-z0-9_]*)"?\s*\(([\s\S]*?)\)\s*returns\s+([\s\S]*?)\bas\s+(\$[a-z_]*\$)([\s\S]*?)\4` +
      String.raw`|(grant|revoke)\s+(?:execute|all(?:\s+privileges)?)\s+on\s+function\s+(?:public\.)?([a-z_][a-z0-9_]*)\s*(?:\((?:[^()]|\([^()]*\))*\))?\s+(?:to|from)\s+([a-z_,\s]+?)\s*;`,
    "gi",
  );
  for (const { name, text } of files) {
    // تعليقات السطر بس — مايهمش كلام عن الدوال جوه التعليقات.
    const clean = text.replace(/--[^\n]*/g, "");
    for (const m of clean.matchAll(stmt)) {
      if (m[1]) {
        const fn = m[1].toLowerCase();
        const args = m[2];
        const body = m[5];
        // الإعدادات (security definer) ممكن تيجي قبل أو بعد as $$ — دور في المقطع كله بره الجسم.
        const outside = m[0].replace(body, "");
        const prev = fns.get(fn);
        fns.set(fn, {
          definer: /security\s+definer/i.test(outside),
          takesUser: /\bp_user\s+uuid\b/i.test(args),
          checksCaller: /auth\.uid\(\)/i.test(body),
          trigger: /returns\s+trigger/i.test("returns " + m[3]),
          // أول إنشاء: الافتراضي بتاع Supabase. create or replace لدالة موجودة بيسيب صلاحياتها.
          exposed: prev ? prev.exposed : new Set(ROLES),
          file: name,
        });
      } else if (m[6]) {
        const fn = m[7].toLowerCase();
        const f = fns.get(fn);
        if (!f) continue;
        for (const role of rolesIn(m[8])) {
          if (m[6].toLowerCase() === "grant") f.exposed.add(role);
          else f.exposed.delete(role);
        }
      }
    }
  }
  return fns;
}

export function unguarded(fns: Map<string, Fn>): string[] {
  const out: string[] = [];
  for (const [name, f] of fns) {
    if (!f.definer || !f.takesUser || f.trigger || f.checksCaller) continue;
    if (!f.exposed.has("anon") && !f.exposed.has("authenticated")) continue;
    out.push(`${name} (${f.file}) — callable by ${[...f.exposed].join(", ")}`);
  }
  return out.sort();
}

async function migrations(): Promise<Array<{ name: string; text: string }>> {
  const names: string[] = [];
  for await (const e of Deno.readDir(DIR)) if (e.isFile && e.name.endsWith(".sql")) names.push(e.name);
  names.sort();
  return await Promise.all(names.map(async (name) => ({ name, text: await Deno.readTextFile(new URL(name, DIR)) })));
}

Deno.test("no definer function taking p_user is callable by a client without checking auth.uid()", async () => {
  assertEquals(unguarded(functionStates(await migrations())), []);
});

Deno.test("the guard sees the bug it guards against, and what fixes it", () => {
  const create = `create or replace function public._agent_x_for_user(p_user uuid)
returns void language plpgsql security definer set search_path to 'public'
as $$ begin perform 1; end $$;`;
  assertEquals(unguarded(functionStates([{ name: "a.sql", text: create }])).length, 1);
  // revoked from the clients
  assertEquals(unguarded(functionStates([{ name: "a.sql", text: create },
    { name: "b.sql", text: "revoke execute on function public._agent_x_for_user(uuid) from public, anon, authenticated;" }])), []);
  // revoked from public only: anon keeps Supabase's own grant
  assertEquals(unguarded(functionStates([{ name: "a.sql", text: create },
    { name: "b.sql", text: "revoke all on function public._agent_x_for_user(uuid) from public;" }])).length, 1);
  // a body that checks the caller
  assertEquals(unguarded(functionStates([{ name: "a.sql", text: create.replace("perform 1;", "if auth.uid() <> p_user then raise exception 'x'; end if;") }])), []);
  // a later create or replace keeps the earlier revoke
  assertEquals(unguarded(functionStates([{ name: "a.sql", text: create },
    { name: "b.sql", text: "revoke execute on function _agent_x_for_user(uuid) from anon, authenticated;" },
    { name: "c.sql", text: create }])), []);
  // a type with its own brackets in the signature (vector(768)) is still read
  assertEquals(unguarded(functionStates([{ name: "a.sql", text: create },
    { name: "b.sql", text: "revoke execute on function public._agent_x_for_user(uuid, vector(768), int)\n  from public, anon, authenticated;" }])), []);
  // a trigger function is not called by anyone
  assertEquals(unguarded(functionStates([{ name: "a.sql", text: create.replace("returns void", "returns trigger") }])), []);
});
