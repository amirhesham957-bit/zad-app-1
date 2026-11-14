import { assertEquals } from "jsr:@std/assert@1";
import { foodProfile } from "./foodProfile.ts";

Deno.test("foodProfile: staples, brands and what the home does not eat, at most 8 each", () => {
  const p = foodProfile({
    householdSize: 2,
    staples: ["لبن", "عيش", "لبن"],
    preferences: [
      { item_name: "سمن", kind: "preferred_brand", brand: "شيراتون" },
      { item_name: "زيت", kind: "rejected_brand", brand: "عافية" },
      { item_name: "رنجة", kind: "accidental", brand: null },
    ],
    affinities: [{ term: "تونة", polarity: "dislike", weight: 2 }, { term: "مانجا", polarity: "like", weight: 3 }, { term: "كيوي", polarity: "like", weight: 0.4 }],
  });
  assertEquals(p, { people: 2, staples: ["لبن", "عيش"], brands: ["سمن: شيراتون", "زيت: مش عافية"], avoid: ["تونة"], likes: ["مانجا"] });
  assertEquals(foodProfile({ staples: Array.from({ length: 20 }, (_, i) => `صنف ${i}`), preferences: [], affinities: [] })!.staples!.length, 8);
});

Deno.test("foodProfile: nothing known beyond the head count is no profile at all", () => {
  assertEquals(foodProfile({ householdSize: 3, staples: [], preferences: [], affinities: [] }), null);
  assertEquals(foodProfile({ staples: [], preferences: [], affinities: [] }), null);
});
