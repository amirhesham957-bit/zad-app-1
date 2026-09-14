# Play Console — Background Location declaration

Not a code doc — this is the write-up for the Play Console "App content" →
"Permissions declaration" form for `ACCESS_BACKGROUND_LOCATION`, plus what the
required screen-recording walkthrough needs to show. Submission itself needs
an account with Play Console access, which this session doesn't have — draft
only.

## Feature this permission serves

`LocationAlertsCard` (Home screen) + `GroceryGeofenceManager` +
`GeofenceBroadcastReceiver` + `GeofenceRefreshWorker`. Opt-in proximity
reminders: when the user is near a supermarket or pharmacy, the app checks
their own shortage list (groceries or medication) and sends a notification —
"you're near X, you're low on Y". Off by default (`GroceryGeofenceManager
.isEnabled()` defaults `false`); the user must tap "enable" on the card.

## ⚠️ Scope grew on 2026-09-14 — resubmit the declaration before release

The same opt-in toggle now also powers a second use: **home-return spending
recap**. `HomePlace` learns where home is from a location sample taken between
01:00 and 05:00 (two consistent nights within 150 m), registers one extra
geofence around it (`zad_home`, ENTER/EXIT) inside the same geofencing request,
and when the user returns after 45 min to 18 h away, `PlaceEventWorker` sends
**only the departure time** to the server, which sums that window's expenses and
store arrivals and — if something was spent — sends a spoken recap ("you're back!
where did you go? you spent 350 at Carrefour").

Privacy facts to state in the form and the video:
- Home coordinates never leave the device; the server table `zad_place_visits`
  has no coordinate columns (times, spend total, merchant/store names only).
- Rows are purged after 90 days (`place-visits-retention` cron) and the user can
  delete any row (RLS delete policy).
- Nothing runs unless the user enables location alerts; the disclosure string
  `location_alerts_toggle_hint` was updated in all four locales to mention home
  learning and the spending recap before the runtime prompt.

Updated short description for the form: "Zad reminds users of shortage-list items
when they are near a relevant store, and — only if they turn it on — recognizes
when they return home to recap what they spent while out. Home location is kept on
the device. This requires background location for geofencing."

The video must now also show enabling the toggle, the disclosure text, and a
return-home recap notification.

## Why background (not foreground-only)

The reminder is only useful if it fires without the user having the app
open — the whole point is "you happened to be walking past". Geofence
transition callbacks on Android 10+ (API 29+) require
`ACCESS_BACKGROUND_LOCATION` to fire while the app isn't in the foreground;
there's no foreground-only substitute that preserves this behavior (a
foreground service polling location continuously would need to run
constantly, which is worse for battery and a worse look to reviewers, not
better).

## Play's declaration form — answers

- **Core functionality**: "Yes, background location is required for a core
  feature" — the proximity shopping/medication reminder is what the
  permission exists for; nothing else in the app touches it.
- **Feature description** (short): "Zad reminds users of items on their
  grocery or pharmacy shortage list when they are physically near a relevant
  store, even when the app is closed. This requires background location to
  detect store entry via geofencing."
- **In-app disclosure**: already implemented and satisfies the "must explain
  before the OS runtime prompt" requirement — `LocationAlertsCard`'s hint
  text (`R.string.location_alerts_toggle_hint`) explicitly says "يحتاج إذن
  الموقع في الخلفية" (needs background location permission) before the
  system permission dialog appears. Screenshot this card as the disclosure
  evidence.
- **User control**: the card becomes a toggle row once enabled
  (`ZadSwitch`), letting the user turn the feature off at any time without
  leaving the app; `GroceryGeofenceManager.setEnabled(false)` clears all
  registered geofences immediately.

## Video walkthrough — what to record

1. Fresh install, Home screen, scroll to `LocationAlertsCard` — show it in
   its default (not-yet-enabled) state.
2. Tap "enable" — show the disclosure text visible for a beat before the
   system permission dialogs appear.
3. Grant "Allow all the time" (fine location, then background location) —
   Android's own runtime flow.
4. Card switches to the enabled toggle row.
5. Toggle it off — show the switch flipping and (if visible) that no further
   location access happens.

No other screen or flow in the app touches background location — the video
doesn't need to cover anything beyond this card.
