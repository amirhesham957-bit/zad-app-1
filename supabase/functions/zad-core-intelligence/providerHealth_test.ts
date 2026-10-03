import { assert, assertEquals } from "jsr:@std/assert@1";
import { groqLimitsNote, interestingSecretNames, isServiceRoleToken, providerHealth, tokenSubject, unreadAiKeyNames } from "./providerHealth.ts";

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

Deno.test("the caller's user id comes from the token, so a body user_id can't borrow someone else's name", () => {
  const b64 = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  assertEquals(tokenSubject(`${b64({ alg: "HS256" })}.${b64({ sub: "u-1", role: "authenticated" })}.sig`), "u-1");
  assertEquals(tokenSubject(`${b64({ alg: "HS256" })}.${b64({ role: "anon" })}.sig`), null);
  assertEquals(tokenSubject("sb_publishable_x"), null);
  assertEquals(tokenSubject(null), null);
});

Deno.test("a Groq key's daily and per-minute limits are read from the reply's headers", () => {
  const h = new Headers({
    "x-ratelimit-limit-requests": "1000", "x-ratelimit-remaining-requests": "998",
    "x-ratelimit-limit-tokens": "8000", "x-ratelimit-remaining-tokens": "7990",
  });
  assertEquals(groqLimitsNote(h), "rpd=1000 left=998 tpm=8000 tpm_left=7990");
  assertEquals(groqLimitsNote(new Headers()), undefined);
});

Deno.test("resend: a sending-only key is ok, a bad key is not", async () => {
  const run = (status: number, body: string) =>
    providerHealth(
      (n) => (n === "RESEND_API_KEY" ? "re_x" : undefined),
      [],
      (async (input: string | URL | Request) =>
        String(input).includes("resend.com")
          ? new Response(body, { status })
          : new Response("{}", { status: 200 })) as typeof fetch,
    );
  const restricted = (await run(401, '{"name":"restricted_api_key"}')).resend as Record<string, unknown>;
  assertEquals(restricted.ok, true);
  const bad = (await run(401, '{"name":"validation_error","message":"API key is invalid"}')).resend as Record<string, unknown>;
  assertEquals(bad.ok, false);
});

Deno.test("a Groq/Gemini key under a name no pool reads is reported, the read ones and model names are not", () => {
  assertEquals(
    unreadAiKeyNames([
      "GROQ_API_KEY", "GROQ_API_KEY_7", "ZAD_API_KEY_5", "GEMINI_API_KEY", "ZAD_GROQ_TEXT_MODEL", "SUPABASE_URL",
      "GROK_API_KEY_1", "GROQ_KEY_3", "GROQ_API_KEY_21", "GEMINI_API_KEY_2", "XAI_API_KEY",
    ]),
    ["GEMINI_API_KEY_2", "GROK_API_KEY_1", "GROQ_API_KEY_21", "GROQ_KEY_3", "XAI_API_KEY"],
  );
});
