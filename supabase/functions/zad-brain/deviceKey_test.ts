import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  DEVICE_KEY_ACTIONS,
  DEVICE_KEY_HEADER,
  deviceKeyAllows,
  hashDeviceKey,
  resolveDeviceKeyCall,
  resolveDeviceKeyUser,
} from "./deviceKey.ts";

const KEY = "q0Jb3m4pV7n2c9Xr1sT5uW8yZ0aB3dE6fG9hJ2kL5mN"; // 43 chars, base64url

function req(key?: string): Request {
  const headers = new Headers();
  if (key !== undefined) headers.set(DEVICE_KEY_HEADER, key);
  return new Request("https://x/functions/v1/zad-brain", { method: "POST", headers });
}

Deno.test("the device key opens exactly the allow-list and nothing else", () => {
  assertEquals([...DEVICE_KEY_ACTIONS].sort(), ["commute_summary", "notification_ingest", "place_event", "store_arrival"]);
  for (const a of DEVICE_KEY_ACTIONS) assertEquals(deviceKeyAllows(a), true, a);
  for (const a of [
    "agent_turn", "agent_turn_stream", "agent_execute", "agent_confirm", "booking_check", "home_deals",
    "life_event_decide", "deal_signal", "zad_family_zone_event", "daily", undefined, null, "", 5,
  ]) {
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

Deno.test("place actions: the user comes from the key row, never the body", async () => {
  const r = new Request("https://x", {
    method: "POST",
    headers: { [DEVICE_KEY_HEADER]: KEY },
    body: JSON.stringify({ action: "store_arrival", user_id: "victim" }),
  });
  const call = await resolveDeviceKeyCall(r, "store_arrival", () => Promise.resolve("owner"), () => Promise.resolve(true));
  assertEquals(call, { kind: "ok", userId: "owner" });
});

Deno.test("place actions over the hourly limit are limited, other actions skip the counter", async () => {
  const lookup = () => Promise.resolve("owner");
  for (const a of ["store_arrival", "place_event", "commute_summary"]) {
    assertEquals(await resolveDeviceKeyCall(req(KEY), a, lookup, () => Promise.resolve(false)), { kind: "limited" }, a);
  }
  let counted = 0;
  const hit = () => { counted++; return Promise.resolve(false); };
  assertEquals(await resolveDeviceKeyCall(req(KEY), "notification_ingest", lookup, hit), { kind: "ok", userId: "owner" });
  assertEquals(counted, 0);
});

Deno.test("a failing counter, an unknown key or a denied action never opens the door", async () => {
  const lookup = () => Promise.resolve("owner");
  const yes = () => Promise.resolve(true);
  assertEquals(
    await resolveDeviceKeyCall(req(KEY), "place_event", lookup, () => Promise.reject(new Error("db"))),
    { kind: "none" },
  );
  assertEquals(await resolveDeviceKeyCall(req(KEY), "place_event", () => Promise.resolve(null), yes), { kind: "none" });
  assertEquals(await resolveDeviceKeyCall(req(KEY), "agent_turn", lookup, yes), { kind: "none" });
  assertEquals(await resolveDeviceKeyCall(req(), "place_event", lookup, yes), { kind: "none" });
});

Deno.test("index.ts answers 429 and gates place actions through the shared helper", async () => {
  const src = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  for (const marker of ["commuteCall.kind === \"limited\"", "placeCall.kind === \"limited\"", "authCall.kind === \"limited\""]) {
    if (!src.includes(marker)) throw new Error(`missing ${marker}`);
  }
  if (!src.includes("status: 429")) throw new Error("no 429");
});
