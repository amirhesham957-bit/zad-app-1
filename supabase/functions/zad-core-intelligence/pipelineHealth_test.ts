import { assertEquals } from "jsr:@std/assert@1";
import { bankChannel, packageKind } from "./pipelineHealth.ts";

Deno.test("packageKind: the log names a bucket, never the bank's app", () => {
  assertEquals(packageKind("com.google.android.apps.messaging"), "messaging");
  assertEquals(packageKind("com.android.mms"), "messaging");
  assertEquals(packageKind("com.cib.mobilebanking"), "bank_app");
  assertEquals(packageKind("org.example.game"), "other");
  assertEquals(packageKind(null), "none");
});

Deno.test("bankChannel: counts and a day, no customer text", () => {
  const out = bankChannel(
    {
      list: [
        { package_name: "com.android.mms", client_classification: "ambiguous", status: "processed", created_at: "2026-09-20T10:00:00Z", body: "خصم 500 جنيه" },
        { package_name: "com.android.mms", client_classification: "ambiguous", status: "rejected", rejection_reason: "no amount", created_at: "2026-09-27T21:15:00Z", confirmation_prompt_claimed_at: "2026-09-27T21:15:05Z" },
      ],
    },
    { list: [{ status: "pending", source_type: "notification" }] },
  );
  assertEquals(out.ingested, 2);
  assertEquals(out.last_ingested_day, "2026-09-27");
  assertEquals(out.by_source_class_status, {
    "messaging|ambiguous|processed": 1,
    "messaging|ambiguous|rejected": 1,
  });
  assertEquals(out.top_rejections, { "no amount": 1 });
  assertEquals(out.confirmation_prompts, { "claimed=y|delivered=n": 1 });
  assertEquals(out.proposals_by_status, { "notification|pending": 1 });
  assertEquals(JSON.stringify(out).includes("500"), false);
});
