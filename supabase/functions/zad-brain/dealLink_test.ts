// رابط العرض: أفلييت مفحوص بس، وبعده بحث المحل المفحوص، وبعده نص بس.
import { assertEquals } from "jsr:@std/assert@1";
import { amazonTag, asinOf, candidateLink, linksForChat, withAmazonTag, withDealLink } from "./dealLink.ts";

const noEnv = () => undefined;
const answering = (status: number) => (() => Promise.resolve(new Response("", { status }))) as unknown as typeof fetch;

Deno.test("amazon tags come from the secrets, else the app's own", () => {
  assertEquals(amazonTag("EG", noEnv), "zad04-21");
  assertEquals(amazonTag("SA", noEnv), "zad0b-21");
  assertEquals(amazonTag("EG", (k) => k === "ZAD_AMAZON_EG_TAG" ? "mine-21" : undefined), "mine-21");
  assertEquals(amazonTag("AE", noEnv), null);
  // The secrets every other Amazon link reads (_shared/amazonMarket.ts) win.
  assertEquals(amazonTag("EG", (k) => k === "AMAZON_ASSOCIATE_TAG_EG" ? "eg-21" : k === "ZAD_AMAZON_EG_TAG" ? "old-21" : undefined), "eg-21");
  assertEquals(amazonTag("SA", (k) => k === "AMAZON_ASSOCIATE_TAG_SA" ? "sa-21" : undefined), "sa-21");
  // An Egypt tag never lands on amazon.sa and the other way round.
  assertEquals(amazonTag("SA", (k) => k === "AMAZON_ASSOCIATE_TAG_EG" ? "eg-21" : undefined), "zad0b-21");
  assertEquals(amazonTag("EG", (k) => k === "AMAZON_ASSOCIATE_TAG_SA" ? "sa-21" : undefined), "zad04-21");
});

Deno.test("an amazon product link keeps its item and carries the tag", () => {
  assertEquals(asinOf("https://www.amazon.eg/-/ar/dp/B0CHX3QBCH/ref=x"), "B0CHX3QBCH");
  assertEquals(asinOf("https://evil.example/dp/B0CHX3QBCH"), null);
  assertEquals(
    candidateLink({ item: "زيت", store: "Amazon", product_url: "https://www.amazon.eg/dp/B0CHX3QBCH" }, "EG", noEnv),
    { kind: "amazon", url: "https://www.amazon.eg/dp/B0CHX3QBCH?tag=zad04-21" },
  );
  assertEquals(
    candidateLink({ item: "زيت عباد الشمس", store: "أمازون" }, "SA", noEnv)?.url,
    `https://www.amazon.sa/s?k=${encodeURIComponent("زيت عباد الشمس")}&tag=zad0b-21`,
  );
});

Deno.test("a known store gets a search by the full product name; others get nothing", () => {
  const item = "جرين هاوس ملوخية مجمدة - 400 جرام";
  assertEquals(
    candidateLink({ item, store: "كارفور مصر" }, "EG", noEnv),
    { kind: "store_search", url: `https://www.carrefouregypt.com/mafegy/ar/search?keyword=${encodeURIComponent(item)}` },
  );
  assertEquals(candidateLink({ item, store: "noon-express" }, "EG", noEnv), null);
  assertEquals(candidateLink({ item, store: "كارفور" }, "AE", noEnv), null);
});

Deno.test("only a link that answers 200 is sent", async () => {
  type Src = { kind: string; url: string | null; until: string | null } | null;
  const deal: { item: string; store: string; source: Src } = { item: "لسان عصفور مصرية - 350جم", store: "كارفور مصر", source: null };
  assertEquals((await withDealLink(deal, "EG", { fetcher: answering(200), env: noEnv }))?.source?.kind, "store_search");
  assertEquals((await withDealLink(deal, "EG", { fetcher: answering(403), env: noEnv }))?.source, null);
  const failing = (() => Promise.reject(new Error("timeout"))) as unknown as typeof fetch;
  assertEquals((await withDealLink(deal, "EG", { fetcher: failing, env: noEnv }))?.source, null);
});

Deno.test("a deal with its own https source is left alone", async () => {
  const deal = { item: "كبده", store: "أولاد رجب", source: { kind: "instagram", url: "https://www.instagram.com/p/x/", until: null } };
  const never = (() => { throw new Error("no call"); }) as unknown as typeof fetch;
  assertEquals(await withDealLink(deal, "EG", { fetcher: never, env: noEnv }), deal);
});

Deno.test("an amazon link in a reply gets our tag and a clean url (owner's report 10/11)", async () => {
  const reply = "من عيوني يا ميرو، ده لينك [أمازون ناو](https://www.amazon.eg/gp/browse.html?node=21869850031) عشان تطلب اللي ناقصك.";
  assertEquals(
    await linksForChat(reply, { fetcher: answering(200), env: noEnv }),
    "من عيوني يا ميرو، ده لينك أمازون ناو: https://www.amazon.eg/gp/browse.html?node=21869850031&tag=zad04-21 عشان تطلب اللي ناقصك.",
  );
});

Deno.test("someone else's tag is replaced, and a link that does not answer 200 is dropped", async () => {
  assertEquals(withAmazonTag("https://www.amazon.sa/dp/B0CHX3QBCH?tag=other-21", noEnv), "https://www.amazon.sa/dp/B0CHX3QBCH?tag=zad0b-21");
  assertEquals(withAmazonTag("https://evil.example/amazon.eg", noEnv), null);
  assertEquals(
    await linksForChat("اطلبه من [أمازون](https://www.amazon.eg/dp/B0CHX3QBCH) النهارده", { fetcher: answering(503), env: noEnv }),
    "اطلبه من أمازون النهارده",
  );
});

Deno.test("other links only lose their markdown", async () => {
  const never = (() => { throw new Error("no call"); }) as unknown as typeof fetch;
  assertEquals(
    await linksForChat("شوف [الوصفة](https://example.com/r)", { fetcher: never, env: noEnv }),
    "شوف الوصفة: https://example.com/r",
  );
  assertEquals(await linksForChat("مفيش لينكات هنا", { fetcher: never, env: noEnv }), "مفيش لينكات هنا");
});

Deno.test("the bare amazon home page gets the tag too (owner's report 10/11)", async () => {
  assertEquals(
    await linksForChat("ده لينك أمازون: https://www.amazon.eg", { fetcher: answering(200), env: noEnv }),
    "ده لينك أمازون: https://www.amazon.eg/?tag=zad04-21",
  );
});
