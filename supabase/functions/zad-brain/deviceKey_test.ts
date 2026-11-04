import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { DEVICE_KEY_HEADER, deviceKeyAllows, hashDeviceKey, resolveDeviceKeyUser } from "./deviceKey.ts";

const KEY = "q0Jb3m4pV7n2c9Xr1sT5uW8yZ0aB3dE6fG9hJ2kL5mN"; // 43 chars, base64url

function req(key?: string): Request {
  const headers = new Headers();
  if (key !== undefined) headers.set(DEVICE_KEY_HEADER, key);
  return new Request("https://x/functions/v1/zad-brain", { method: "POST", headers });
}

Deno.test("the device key opens notification_ingest and nothing else", () => {
  assertEquals(deviceKeyAllows("notification_ingest"), true);
  for (const a of ["agent_turn", "agent_execute", "agent_confirm", "store_arrival", undefined, ""]) {
    assertEquals(deviceKeyAllows(a), false, String(a));
  }
});

Deno.test("the hash is SHA-256 hex, the same the app registers", async () => {
  assertEquals(
    await hashDeviceKey("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});

Deno.test("the account comes from the key's row, looked up by hash", async () => {
  const want = await hashDeviceKey(KEY);
  let asked = "";
  const uid = await resolveDeviceKeyUser(req(KEY), "notification_ingest", (h) => {
    asked = h;
    return Promise.resolve(h === want ? "user-a" : null);
  });
  assertEquals(uid, "user-a");
  assertEquals(asked, want);
});

Deno.test("no key, a malformed key, another action or a failing lookup give no one", async () => {
  const hit = () => Promise.resolve("user-a");
  assertEquals(await resolveDeviceKeyUser(req(), "notification_ingest", hit), null);
  assertEquals(await resolveDeviceKeyUser(req("short"), "notification_ingest", hit), null);
  assertEquals(await resolveDeviceKeyUser(req(KEY + "!"), "notification_ingest", hit), null);
  assertEquals(await resolveDeviceKeyUser(req(KEY), "agent_turn", hit), null);
  assertEquals(
    await resolveDeviceKeyUser(req(KEY), "notification_ingest", () => Promise.reject(new Error("db"))),
    null,
  );
  assertEquals(await resolveDeviceKeyUser(req(KEY), "notification_ingest", () => Promise.resolve(null)), null);
});
