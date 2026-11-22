import { assertEquals } from "jsr:@std/assert@1";
import { marketFor, productUrl, searchUrl } from "./amazonMarket.ts";

const none = () => undefined;
const env = (vars: Record<string, string>) => (n: string) => vars[n];

Deno.test("EG goes to amazon.eg with zad04-21 by default, and the EG secret overrides the tag", () => {
  assertEquals(marketFor("EG", none), { domain: "www.amazon.eg", tag: "zad04-21" });
  assertEquals(marketFor("eg", none), { domain: "www.amazon.eg", tag: "zad04-21" });
  assertEquals(
    marketFor("EG", env({ AMAZON_ASSOCIATE_TAG_EG: "eg-live-21" })),
    { domain: "www.amazon.eg", tag: "eg-live-21" },
  );
});

Deno.test("SA and unknown countries go to amazon.sa", () => {
  assertEquals(marketFor("SA", none), { domain: "www.amazon.sa", tag: "zad0b-21" });
  assertEquals(marketFor("KW", none), { domain: "www.amazon.sa", tag: "zad0b-21" });
  assertEquals(marketFor(null, none), { domain: "www.amazon.sa", tag: "zad0b-21" });
});

Deno.test("AE with only a domain secret and no tag falls back to amazon.sa", () => {
  assertEquals(
    marketFor("AE", env({ AMAZON_DOMAIN_AE: "www.amazon.ae" })),
    { domain: "www.amazon.sa", tag: "zad0b-21" },
  );
});

Deno.test("AE with both domain and tag secrets uses that domain and tag", () => {
  assertEquals(
    marketFor("AE", env({ AMAZON_DOMAIN_AE: "www.amazon.ae", AMAZON_ASSOCIATE_TAG_AE: "ae-21" })),
    { domain: "www.amazon.ae", tag: "ae-21" },
  );
});

Deno.test("an invalid domain secret is ignored and falls back to amazon.sa", () => {
  assertEquals(
    marketFor("AE", env({ AMAZON_DOMAIN_AE: "evil.com", AMAZON_ASSOCIATE_TAG_AE: "ae-21" })),
    { domain: "www.amazon.sa", tag: "zad0b-21" },
  );
});

Deno.test("searchUrl encodes the Arabic term and appends &tag=", () => {
  assertEquals(
    searchUrl({ domain: "www.amazon.eg", tag: "zad04-21" }, "زيت زيتون"),
    "https://www.amazon.eg/s?k=%D8%B2%D9%8A%D8%AA%20%D8%B2%D9%8A%D8%AA%D9%88%D9%86&tag=zad04-21",
  );
});

Deno.test("productUrl encodes the asin and appends ?tag=", () => {
  assertEquals(
    productUrl({ domain: "www.amazon.sa", tag: "zad0b-21" }, "B0 ABC/1"),
    "https://www.amazon.sa/dp/B0%20ABC%2F1?tag=zad0b-21",
  );
  assertEquals(
    productUrl({ domain: "www.amazon.eg", tag: "zad04-21" }, "B0ABCDEF12"),
    "https://www.amazon.eg/dp/B0ABCDEF12?tag=zad04-21",
  );
});
