import { assertEquals } from "jsr:@std/assert@1";
import { dashboardLink, isSheinHost, kocIdIn, offerRow } from "./shein.ts";

const REAL = "https://onelink.shein.com/60/67x9gydalfpz?ismg_ol=4TYBWTPjnSB_01_KOC-C";

Deno.test("the dashboard's own link passes as it is", () => {
  assertEquals(dashboardLink(` ${REAL}\n`), { ok: true, url: REAL });
});

Deno.test("a plain product link is turned away — appending ids to it earns nothing", () => {
  for (const url of [
    "https://ar.shein.com/Floral-Dress-p-123.html",
    "https://www.shein.com/sa/item-p-1.html?aff_id=4559428113&ref_code=B8U6U",
    "https://onelink.shein.com.evil.example/60/abc",
    "https://user:pw@onelink.shein.com/60/abc",
    "https://onelink.shein.com:8443/60/abc",
  ]) {
    assertEquals(dashboardLink(url), { ok: false, reason: "not_a_dashboard_link" }, url);
  }
  assertEquals(dashboardLink("http://onelink.shein.com/60/abc").ok, false);
  assertEquals(dashboardLink("https://onelink.shein.com/../admin").ok, false);
  assertEquals(dashboardLink("not a url").ok, false);
});

Deno.test("the KOC id is read from the landing page as SHEIN served it (11/11)", () => {
  const page =
    `<a href="https://m.shein.com/us/ark/default?onelink=60/67x9gydalfpz&amp;ad_type=KOC&amp;koc_id=4559428113&amp;goods_id=">`;
  assertEquals(kocIdIn(page), "4559428113");
  assertEquals(kocIdIn("koc_id=45594281139999999999999"), null);
  assertEquals(kocIdIn("<html>no id</html>"), null);
});

Deno.test("only SHEIN's own hosts are followed", () => {
  assertEquals(isSheinHost("m.shein.com"), true);
  assertEquals(isSheinHost("shein.com"), true);
  assertEquals(isSheinHost("evilshein.com"), false);
  assertEquals(isSheinHost("shein.com.evil.example"), false);
});

Deno.test("an offer goes to the Gulf only, with a shopper code only when it is one", () => {
  const r = offerRow({ title: " فستان صيفي ", url: REAL, coupon_code: "summer10" });
  assertEquals(r.ok && r.row, {
    network: "shein",
    title: "فستان صيفي",
    affiliate_url: REAL,
    image_url: null,
    raw_url: null,
    coupon_code: "SUMMER10",
    target_countries: ["SA", "AE"],
    category: "fashion_home",
    is_active: true,
  });
  assertEquals(offerRow({ title: "x", url: REAL, target_countries: ["EG"] }), {
    ok: false,
    reason: "bad_countries",
  });
  assertEquals(offerRow({ title: "x", url: REAL, image_url: "http://x.test/a.jpg" }).ok, false);
  assertEquals(offerRow({ title: "x", url: REAL, raw_url: "https://evil.example/p" }).ok, false);
  assertEquals(offerRow({ title: "", url: REAL }).ok, false);
  assertEquals(offerRow({ title: "x", url: "https://ar.shein.com/p-1.html" }), {
    ok: false,
    reason: "not_a_dashboard_link",
  });
});
