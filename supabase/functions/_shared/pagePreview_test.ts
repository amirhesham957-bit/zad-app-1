import { assertEquals } from "jsr:@std/assert@1";
import { previewableUrl, previewImageFrom } from "./pagePreview.ts";

const page = new URL("https://3orood.net/offers/bim");

Deno.test("og:image is the picture, resolved against the page", () => {
  assertEquals(previewImageFrom(`<head><meta property="og:image" content="/img/bim.jpg"></head>`, page), "https://3orood.net/img/bim.jpg");
});

Deno.test("content before property, entities and twitter:image fallback", () => {
  assertEquals(
    previewImageFrom(`<meta content="https://cdn.x.com/a.jpg?w=1&amp;h=2" property="og:image" />`, page),
    "https://cdn.x.com/a.jpg?w=1&h=2",
  );
  assertEquals(previewImageFrom(`<meta name="twitter:image" content="https://cdn.x.com/t.png">`, page), "https://cdn.x.com/t.png");
});

Deno.test("http image is upgraded, a page without one gives null", () => {
  assertEquals(previewImageFrom(`<meta property="og:image" content="http://cdn.x.com/a.jpg">`, page), "https://cdn.x.com/a.jpg");
  assertEquals(previewImageFrom(`<title>x</title>`, page), null);
});

Deno.test("Amazon, Instagram, IPs, localhost and http pages are never fetched", () => {
  for (const u of [
    "https://www.amazon.sa/dp/B07F2XB1V5", "https://amzn.to/abc", "https://www.instagram.com/p/DfH1gEWDeaG/",
    "https://127.0.0.1/x", "https://localhost/x", "http://3orood.net/x", "https://user:pw@3orood.net/x", "not a url",
  ]) assertEquals(previewableUrl(u), null, u);
  assertEquals(previewableUrl("https://www.kheirzaman.com")?.hostname, "www.kheirzaman.com");
});

Deno.test("an Amazon picture declared by another page is not taken either", () => {
  assertEquals(previewImageFrom(`<meta property="og:image" content="https://m.media-amazon.com/images/I/x.jpg">`, page), null);
});
