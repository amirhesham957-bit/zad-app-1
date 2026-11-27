import { assertEquals } from "jsr:@std/assert@1";
import {
  memoryPhraseStore,
  phraseCacheKey,
  pickTemplate,
  proactiveTitle,
} from "./proactiveTemplates.ts";
import { agentTaskNotice } from "./shared.ts";

Deno.test("pickTemplate falls back to the base template for dialects with none", () => {
  const p = pickTemplate("bill_reminder", "SA");
  assertEquals(p.title, agentTaskNotice("bill_reminder").title);
  assertEquals(p.source, "EG");
  assertEquals(pickTemplate("bill_reminder", "EG").source, "EG");
  assertEquals(
    pickTemplate("unknown_kind", "EG").title,
    agentTaskNotice("unknown_kind").title,
  );
});

Deno.test("cache key is per (kind, dialect)", () => {
  assertEquals(
    phraseCacheKey("bill_reminder", "SA"),
    "proactive_phrase:v1:bill_reminder:SA",
  );
  assertEquals(
    phraseCacheKey(" x ", "EG") === phraseCacheKey("x", "SA"),
    false,
  );
});

Deno.test("rephrase runs once per (kind, dialect) and is cached", async () => {
  const store = memoryPhraseStore();
  let calls = 0;
  const re = (b: string, d: string) => {
    calls++;
    return Promise.resolve(`${d}:${b}`);
  };
  const a = await proactiveTitle(store, "bill_reminder", "SA", re);
  const b = await proactiveTitle(store, "bill_reminder", "SA", re);
  assertEquals(a, b);
  assertEquals(calls, 1);
  await proactiveTitle(store, "bill_reminder", "GULF", re);
  assertEquals(calls, 2);
});

Deno.test("base dialect, failure and empty output use the template and store nothing", async () => {
  const store = memoryPhraseStore();
  const base = agentTaskNotice("goal_review").title;
  let calls = 0;
  assertEquals(
    await proactiveTitle(store, "goal_review", "EG", () => {
      calls++;
      return Promise.resolve("x");
    }),
    base,
  );
  assertEquals(calls, 0);
  assertEquals(
    await proactiveTitle(
      store,
      "goal_review",
      "SA",
      () => Promise.reject(new Error("x")),
    ),
    base,
  );
  assertEquals(
    await proactiveTitle(
      store,
      "goal_review",
      "SA",
      () => Promise.resolve("  "),
    ),
    base,
  );
  assertEquals(store.get(phraseCacheKey("goal_review", "SA")), null);
  assertEquals(await proactiveTitle(store, "goal_review", "SA"), base);
});

Deno.test("the agent-task sender takes proactive titles through proactiveTitle (wired, م٤.٤)", async () => {
  const src = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(
    src.includes("proactiveTitleFor(sb, task.user_id, task.kind)"),
    true,
  );
  assertEquals(
    src.includes("proactiveTitle(proactivePhrases, kind, dialect, undefined, tone)"),
    true,
  );
});
