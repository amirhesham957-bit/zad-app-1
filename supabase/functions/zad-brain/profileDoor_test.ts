// P2.3: كل سبب رفض ممكن تردّه zad_intent_profile (مايجريشن member_facts) لازم له نص عربي في REASONS،
// وإلا الموديل بيشوف «الكتابة اترفضت» من غير ما يعرف يعدّل. التست بيقرا الحروف 'reason' من نص المايجريشن نفسه.
import { assert, assertStringIncludes } from "jsr:@std/assert@1";
import { refusalText } from "./commitIntent.ts";

const FALLBACK = "الكتابة اترفضت";

Deno.test("every reason the profile door SQL can return has an Arabic REASONS entry", async () => {
  const all = await Deno.readTextFile(new URL("../../migrations/20261128130000_member_facts.sql", import.meta.url));
  // دالة المجال بس (zad_commit_intent اللي بعدها أسبابها اتغطت في تستات تانية).
  const sql = all.slice(all.indexOf("function public.zad_intent_profile"), all.indexOf("function public.zad_commit_intent"));
  const reasons = new Set([...sql.matchAll(/'reason',\s*'([a-z_]+)'/g)].map((m) => m[1]));
  for (const r of ["fact_invalid", "fact_not_found", "inferred_needs_evidence", "bad_source", "member_not_in_household"]) {
    assert(reasons.has(r), `migration should return ${r}`);
  }
  for (const r of reasons) {
    const text = refusalText(r);
    assert(!text.includes(FALLBACK), `no Arabic REASONS entry for ${r}`);
    assertStringIncludes(text, r);
  }
});

Deno.test("P3.1: the fact check-in migration reasons all have Arabic REASONS entries", async () => {
  const all = await Deno.readTextFile(new URL("../../migrations/20261128210000_fact_checkin.sql", import.meta.url));
  const sql = all.slice(all.indexOf("function public.zad_intent_profile"));
  const reasons = new Set([...sql.matchAll(/'reason',\s*'([a-z_]+)'/g)].map((m) => m[1]));
  assert(reasons.has("fact_denied_recently"), "migration should return fact_denied_recently");
  for (const r of reasons) {
    const text = refusalText(r);
    assert(!text.includes(FALLBACK), `no Arabic REASONS entry for ${r}`);
    assertStringIncludes(text, r);
  }
});
