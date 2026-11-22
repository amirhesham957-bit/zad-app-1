import { assertEquals } from "jsr:@std/assert@1";
import {
  DAILY_NOTIFICATION_PUSH_CAP,
  decideNotificationPush,
  notificationText,
  type PushContext,
  validNotificationId,
} from "./notificationPush.ts";

// 12:00 UTC = 14:00 Cairo (UTC+2 in winter): awake. 22:00 UTC = 00:00 Cairo: asleep (default window).
const NOON = Date.UTC(2026, 10, 22, 12, 0, 0);
const NIGHT = Date.UTC(2026, 10, 22, 22, 0, 0);
const base: PushContext = {
  alreadyClaimed: false, tz: "Africa/Cairo", sleepBed: null, sleepWake: null, sentLast24h: 0,
};

Deno.test("awake, fresh, under the cap: send", () => {
  assertEquals(decideNotificationPush(base, NOON), { send: true });
});
Deno.test("same notification twice: duplicate wins over everything", () => {
  assertEquals(decideNotificationPush({ ...base, alreadyClaimed: true }, NIGHT), { send: false, reason: "duplicate" });
});
Deno.test("sleep window blocks (default), and a custom window moves it", () => {
  assertEquals(decideNotificationPush(base, NIGHT), { send: false, reason: "quiet_hours" });
  const lateOwl = { ...base, sleepBed: "02:00:00", sleepWake: "10:00:00" };
  assertEquals(decideNotificationPush(lateOwl, NIGHT), { send: true });
});
Deno.test("daily cap blocks at the cap, not below", () => {
  assertEquals(decideNotificationPush({ ...base, sentLast24h: DAILY_NOTIFICATION_PUSH_CAP - 1 }, NOON), { send: true });
  assertEquals(decideNotificationPush({ ...base, sentLast24h: DAILY_NOTIFICATION_PUSH_CAP }, NOON), { send: false, reason: "daily_cap" });
});
Deno.test("text is the notification itself, nothing added", () => {
  assertEquals(notificationText(" 🛒 ناقصك حاجة ", " لبن عند محل X "), "🛒 ناقصك حاجة\n\nلبن عند محل X");
  assertEquals(notificationText("", "نص بس"), "نص بس");
});
Deno.test("notification id must be a uuid", () => {
  assertEquals(validNotificationId("3f2b8c1e-8a46-4a8e-9a53-0d6c1a2b3c4d"), true);
  assertEquals(validNotificationId("x"), false);
  assertEquals(validNotificationId(5), false);
});
