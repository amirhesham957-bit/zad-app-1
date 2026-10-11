import { assertEquals } from "jsr:@std/assert@1";
import { homesIn, medianOf, withoutOutliers } from "./crowdFloor.ts";

Deno.test("the median, and the outliers either side of it", () => {
  assertEquals(medianOf([3, 1, 2]), 2);
  assertEquals(medianOf([4, 1, 2, 3]), 2.5);
  assertEquals(medianOf([]), null);
  // a carton typed as a single pack (300 among ~30), and a slip (3)
  const rows = [30, 31, 29, 300, 3, 32].map((price) => ({ price }));
  assertEquals(withoutOutliers(rows).map((r) => r.price), [30, 31, 29, 32]);
  // two reports: nothing to measure against, kept
  assertEquals(withoutOutliers([{ price: 30 }, { price: 300 }]).length, 2);
});

Deno.test("a family is one home; a report with no owner is no home", () => {
  const homeOf = new Map([["mom", "f:1"], ["dad", "f:1"]]);
  assertEquals(homesIn([{ user_id: "mom" }, { user_id: "dad" }, { user_id: "x" }], homeOf), 2);
  assertEquals(homesIn([{ user_id: null }, { user_id: "x" }, { user_id: "y" }, { user_id: "z" }], homeOf), 3);
});
