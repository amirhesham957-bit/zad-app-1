import { assert, assertEquals } from "jsr:@std/assert@1";
import { interestingSecretNames, isServiceRoleToken, providerHealth } from "./providerHealth.ts";

Deno.test("reports configured/status per provider and never echoes a key", async () => {
  const env: Record<string, string> = {
    LOCATIONIQ_API_KEY: "pk.secret-location",
    ZAD_API_KEY_1: "gem-1", ZAD_API_KEY_2: "gem-2",
    GROQ_API_KEY: "groq-1",
    GOOGLE_MAPS_API_KEY: "maps-secret",
  };
  const seen: string[] = [];
  const fakeFetch = ((url: string) => {
    seen.push(String(url));
    if (String(url).includes("locationiq")) return Promise.resolve(new Response(JSON.stringify([{ name: "x" }, { name: "y" }]), { status: 200 }));
    if (String(url).includes("groq")) return Promise.resolve(new Response("bad key", { status: 401 }));
    return Promise.resolve(new Response("{}", { status: 200 }));
  }) as typeof fetch;
  const report = await providerHealth((n) => env[n], Object.keys(env), fakeFetch);
  const text = JSON.stringify(report);
  assert(!text.includes("pk.secret-location") && !text.includes("gem-1") && !text.includes("maps-secret"));
  assertEquals((report.locationiq as { note?: string }).note, "places=2");
  assertEquals((report.pexels as { configured: boolean }).configured, false);
  assertEquals((report.gemini_pool as unknown[]).length, 2);
  assertEquals((report.groq_pool as Array<{ status: number }>)[0].status, 401);
  assertEquals(report.other_key_like_secret_names, ["GOOGLE_MAPS_API_KEY"]);
});

Deno.test("key-like secret names are picked out so a key saved under an unexpected name shows up", () => {
  assertEquals(interestingSecretNames(["LOCATION_IQ_KEY", "SUPABASE_URL", "PEXELS_API_KEY", "RAPIDAPI_KEY"]), ["LOCATION_IQ_KEY", "PEXELS_API_KEY", "RAPIDAPI_KEY"]);
});

Deno.test("only a service_role token passes the health check gate", () => {
  const b64 = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  assert(isServiceRoleToken(`${b64({ alg: "HS256" })}.${b64({ role: "service_role" })}.sig`, "other"));
  assert(!isServiceRoleToken(`${b64({ alg: "HS256" })}.${b64({ role: "anon" })}.sig`, "other"));
  assert(isServiceRoleToken("sb_secret_x", "sb_secret_x"));
  assert(!isServiceRoleToken(null, "x"));
});
