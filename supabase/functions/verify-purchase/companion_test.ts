import { assertEquals } from "jsr:@std/assert@1";
import { verifyCompanionProduct } from "./companion.ts";

type Grant = { p_user: string; p_product: string; p_order: string };

function run(play: { status?: number; body?: unknown }, grantResult: unknown = { ok: true, item: "felfool" }) {
  const urls: string[] = [];
  const grants: Grant[] = [];
  return {
    urls,
    grants,
    res: verifyCompanionProduct({
      packageName: "com.zad.app", token: "t", productId: "zad_pet_felfool",
      purchaseToken: "tok", userId: "u1", supabaseUrl: "http://x",
      fetcher: (async (url: string) => {
        urls.push(url);
        return new Response(JSON.stringify(play.body ?? {}), { status: play.status ?? 200 });
      }) as typeof fetch,
      grant: async (g) => {
        grants.push(g);
        return { data: grantResult, error: null };
      },
    }),
  };
}

Deno.test("a purchased product is checked as a product, granted on Google's orderId", async () => {
  const r = run({ body: { purchaseState: 0, orderId: "GPA.42" } });
  const res = await r.res;
  assertEquals(res.status, 200);
  assertEquals((await res.json()).kind, "companion");
  assertEquals(r.urls[0].includes("/purchases/products/zad_pet_felfool/tokens/tok"), true);
  assertEquals(r.grants, [{ p_user: "u1", p_product: "zad_pet_felfool", p_order: "GPA.42" }]);
});

Deno.test("pending or cancelled is not granted", async () => {
  for (const state of [1, 2]) {
    const r = run({ body: { purchaseState: state, orderId: "GPA.1" } });
    assertEquals((await r.res).status, 402);
    assertEquals(r.grants.length, 0);
  }
});

Deno.test("Google refusing the token grants nothing", async () => {
  const r = run({ status: 410, body: {} });
  assertEquals((await r.res).status, 402);
  assertEquals(r.grants.length, 0);
});

Deno.test("an order already granted to another account is a 409", async () => {
  const r = run({ body: { purchaseState: 0, orderId: "GPA.7" } }, { ok: false, reason: "token_already_claimed" });
  const res = await r.res;
  assertEquals(res.status, 409);
  assertEquals((await res.json()).valid, false);
});
