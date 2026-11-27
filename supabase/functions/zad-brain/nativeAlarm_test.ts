import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1";
import {
  AlarmSender,
  alarmData,
  buildAlarmMessage,
  NATIVE_ALARM_FLAG_OFF_REFUSAL,
  NATIVE_ALARM_TOOL,
  parseNativeAlarmInput,
  setNativeAlarm,
} from "./nativeAlarm.ts";
import { intentToolHints } from "./specialists.ts";

// deno-lint-ignore no-explicit-any
const fakeSb = (rows: { token: string }[] | null, error: unknown = null): any => ({
  from: (t: string) => {
    assertEquals(t, "zad_fcm_tokens");
    const q = { select: () => q, eq: () => q, gt: () => Promise.resolve({ data: rows, error }) };
    return q;
  },
});
const sender = (ok: boolean, sent: { token: string; data: Record<string, string> }[] = [], configured = true): AlarmSender => ({
  configured: () => configured,
  send: (token, data) => {
    sent.push({ token, data });
    return Promise.resolve(ok ? "ok" : "failed");
  },
});
const base = { hour: 6, minute: 30, label: "الفجر" };

Deno.test("v2-2 validation: hour, minute, label, days", () => {
  for (const bad of [{ ...base, hour: 24 }, { ...base, hour: -1 }, { ...base, hour: 1.5 }, { ...base, hour: "6" }, { ...base, minute: 60 }, { ...base, label: " " }, { hour: 1, minute: 1 }, { ...base, days: "mon" }, { ...base, days: [8] }, { ...base, days: ["funday"] }]) {
    assert("error" in parseNativeAlarmInput(bad), JSON.stringify(bad));
  }
  const ok = parseNativeAlarmInput({ ...base, days: ["الجمعة", 1, "sat", 1] });
  assertEquals("value" in ok && ok.value.days, [1, 5, 6]);
  assertEquals("value" in parseNativeAlarmInput(base) && (parseNativeAlarmInput(base) as { value: { days: number[] } }).value.days, []);
});

Deno.test("v2-2 flag off: refuses, never touches db or sender", async () => {
  const sent: { token: string; data: Record<string, string> }[] = [];
  const out = await setNativeAlarm(fakeSb([{ token: "t" }]), "u", base, sender(true, sent), false);
  assertEquals(out, NATIVE_ALARM_FLAG_OFF_REFUSAL);
  assertEquals(sent.length, 0);
});

Deno.test("v2-2 flag off by default: tool absent from CHAT_TOOLS, no intent hint", async () => {
  const prev = Deno.env.get("ZAD_NATIVE_ALARM");
  Deno.env.delete("ZAD_NATIVE_ALARM");
  try {
    const { CHAT_TOOLS } = await import("./chatTools.ts");
    assertFalse(CHAT_TOOLS.some((t) => t.name === "set_native_alarm"));
    assertFalse(intentToolHints("صحيني الساعة ٦").includes("set_native_alarm"));
    Deno.env.set("ZAD_NATIVE_ALARM", "1");
    assert(intentToolHints("صحيني الساعة ٦").includes("set_native_alarm"));
  } finally {
    if (prev === undefined) Deno.env.delete("ZAD_NATIVE_ALARM");
    else Deno.env.set("ZAD_NATIVE_ALARM", prev);
  }
});

Deno.test("v2-2 tool def shape", () => {
  assertEquals(NATIVE_ALARM_TOOL.name, "set_native_alarm");
  assertEquals((NATIVE_ALARM_TOOL.input_schema as { required: string[] }).required, ["hour", "minute", "label"]);
});

Deno.test("v2-2 invalid args return refusal before any send", async () => {
  const sent: { token: string; data: Record<string, string> }[] = [];
  const out = await setNativeAlarm(fakeSb([{ token: "t" }]), "u", { ...base, hour: 99 }, sender(true, sent), true);
  assert(out.startsWith("مرفوض:"));
  assertEquals(sent.length, 0);
});

Deno.test("v2-2 no token -> fallback", async () => {
  const out = JSON.parse(await setNativeAlarm(fakeSb([]), "u", { ...base, days: [1] }, sender(true), true));
  assertEquals(out.status, "fallback_to_inapp_reminder");
  assertEquals(out.reason, "no_active_device");
  assertEquals([out.hour, out.minute, out.label, out.days], [6, 30, "الفجر", [1]]);
  assert(out.instruction.includes("تذكير"));
});

Deno.test("v2-2 fcm not configured -> fallback", async () => {
  const out = JSON.parse(await setNativeAlarm(fakeSb([{ token: "t" }]), "u", base, sender(true, [], false), true));
  assertEquals([out.status, out.reason], ["fallback_to_inapp_reminder", "fcm_not_configured"]);
});

Deno.test("v2-2 token lookup error -> fallback", async () => {
  const out = JSON.parse(await setNativeAlarm(fakeSb(null, { message: "x" }), "u", base, sender(true), true));
  assertEquals(out.reason, "token_lookup_failed");
});

Deno.test("v2-2 send fails for all tokens -> fallback", async () => {
  const out = JSON.parse(await setNativeAlarm(fakeSb([{ token: "a" }, { token: "b" }]), "u", base, sender(false), true));
  assertEquals([out.status, out.reason], ["fallback_to_inapp_reminder", "send_failed"]);
});

Deno.test("v2-2 success: sent status, one send per token, exact data keys", async () => {
  const sent: { token: string; data: Record<string, string> }[] = [];
  const out = JSON.parse(await setNativeAlarm(fakeSb([{ token: "a" }, { token: "b" }]), "u", { ...base, days: ["الخميس", 5] }, sender(true, sent), true));
  assertEquals([out.status, out.devices], ["sent", 2]);
  assertEquals(sent.map((s) => s.token), ["a", "b"]);
  assertEquals(Object.keys(sent[0].data).sort(), ["action", "days", "hour", "label", "minute"]);
  assertEquals(sent[0].data, { action: "SET_NATIVE_ALARM", hour: "6", minute: "30", label: "الفجر", days: "[4,5]" });
});

Deno.test("v2-2 FCM message is data-only with high priority", () => {
  const msg = buildAlarmMessage("tok", alarmData({ ...base, days: [] }));
  assertFalse("notification" in msg.message);
  assertEquals(msg.message.android.priority, "HIGH");
  assertEquals(msg.message.token, "tok");
  for (const v of Object.values(msg.message.data)) assertEquals(typeof v, "string");
});
