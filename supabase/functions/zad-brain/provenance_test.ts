import { assertEquals } from "jsr:@std/assert@1";
import { txnSourceType } from "./provenance.ts";

Deno.test("a receipt says so; otherwise the channel, from a fixed list", () => {
  assertEquals(txnSourceType("receipt", "telegram"), "receipt");
  assertEquals(txnSourceType(undefined, "telegram"), "telegram");
  assertEquals(txnSourceType(undefined, "voice"), "voice");
  assertEquals(txnSourceType(undefined, "app_chat"), "chat");
  assertEquals(txnSourceType(undefined, "confirm"), "chat");
  // Anything else the caller (or the model) writes is not a source.
  assertEquals(txnSourceType("notification_listener", "app_chat"), "chat");
  assertEquals(txnSourceType("bank", "telegram"), "telegram");
});
