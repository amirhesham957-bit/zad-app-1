// ساعة اللفة (ZAD_OR_PLAN م٤): المراحل بتتقاس من بداية اللفة، والإجمالي في الآخر.
import { assertEquals } from "jsr:@std/assert@1";
import { turnTimer } from "./index.ts";

Deno.test("turn timer: marks are measured from the start, done adds the total", () => {
  let t = 1_000;
  const clock = turnTimer(() => t);
  t = 1_450;
  clock.lap("snapshot");
  t = 1_500;
  clock.lap("run_started");
  t = 3_700;
  assertEquals(clock.done(), { snapshot_ms: 450, run_started_ms: 500, total_ms: 2_700 });
});
