import { assert, assertEquals } from "jsr:@std/assert@1";
import { readCommute } from "./commute.ts";

const good = { leave: "08:10", back: "17:30", days: [7, 1, 2], samples: 10 };

Deno.test("a valid summary becomes one plain note", () => {
  const r = readCommute(good);
  assert(r && !r.clear);
  assert(r.note.includes("08:10") && r.note.includes("الأحد"));
});

Deno.test("no coordinates can pass through, whatever is sent", () => {
  const r = readCommute({ ...good, lat: 30.1, lon: 31.2, workplace: "x" });
  assert(r && !r.clear);
  assert(!r.note.includes("30.1") && !r.note.includes("x"));
});

Deno.test("what the phone may not claim is refused", () => {
  for (const b of [{ ...good, leave: "25:00" }, { ...good, samples: 3 }, { ...good, days: [] }, { ...good, days: [9] }, { ...good, back: 1730 }, {}]) {
    assertEquals(readCommute(b as Record<string, unknown>), null);
  }
});

Deno.test("turning it off asks to erase", () => assertEquals(readCommute({ clear: true }), { clear: true }));
