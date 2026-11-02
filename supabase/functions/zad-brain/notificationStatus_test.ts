// كل حالة بتتكتب في zad_notification_ingest_events لازم تكون في status_check.
// «duplicate_fuzzy» ماكانتش (١/١١): الـPATCH رجع 400 وماحدش شافه، والصف فضل received والإشعار اتعالج تاني.
import { assert } from "jsr:@std/assert@1";

const MIGRATION = new URL("../../migrations/20260816130000_a_notification_asks_before_it_counts.sql", import.meta.url);
const SOURCE = new URL("./index.ts", import.meta.url);

Deno.test("every status written to an ingest event is allowed by its check constraint", async () => {
  const sql = await Deno.readTextFile(MIGRATION);
  const check = sql.match(/check \(status in \(([^)]*)\)\)/);
  assert(check, "status_check not found in the migration");
  const allowed = new Set([...check[1].matchAll(/'([a-z_]+)'/g)].map((m) => m[1]));

  const src = await Deno.readTextFile(SOURCE);
  const written = new Set<string>();
  for (const m of src.matchAll(/\bmark\("([a-z_]+)"/g)) written.add(m[1]);
  for (const m of src.matchAll(/from\("zad_notification_ingest_events"\)\s*\.update\(\{\s*status:\s*"([a-z_]+)"/g)) written.add(m[1]);

  assert(written.size > 0, "no status writes found — the pattern no longer matches index.ts");
  for (const s of written) assert(allowed.has(s), `status "${s}" is not in zad_notification_ingest_events_status_check`);
});
