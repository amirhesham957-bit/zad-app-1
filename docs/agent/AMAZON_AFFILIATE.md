# Amazon affiliate — stores, tags, and the «حاجة خلصت» link (2026-10-10)

The owner's request, 2026-10-10: Egypt's customers shop amazon.eg with tag
`zad04-21`; everyone else shops amazon.sa until the other stores are set up;
home shows the shortages side by side, each ordered with a tap; and when an
essential runs out, Zad sends the purchase link itself — as a friend's
service, never as an advert.

## Which store, which tag

| Account country | Store | Tag | Override |
|---|---|---|---|
| `EG` | `www.amazon.eg` | `zad04-21` | `AMAZON_ASSOCIATE_TAG_EG` |
| anything else, or unknown | `www.amazon.sa` | `zad0b-21` | `AMAZON_ASSOCIATE_TAG_SA`, then `AMAZON_ASSOCIATE_TAG` |

- **A tag earns only in its own store.** Associates is a separate programme
  per Amazon store, so store and tag are always chosen together. Never put
  the Saudi tag on an amazon.eg link or the reverse.
- ⚠️ `zad0b-21` is the tag the app always carried on amazon.sa
  (`.env.example`). It was **not** re-confirmed as a registered amazon.sa
  tag on 2026-10-10 — the owner gave only the Egyptian one. Confirm it in the
  amazon.sa Associates dashboard.
- Server: `supabase/functions/_shared/amazonMarket.ts` (`marketFor`,
  `searchUrl`, `productUrl`), read by `amazon-creators-search` and
  `zad-brain`. Project secrets of the names above override the defaults.
- App: `amazonStoreFor` / `amazonTagFor` / `affiliateUrl` /
  `amazonSuggestUrl` in `zad_flutter/lib/shared/affiliate/domain/affiliate.dart`;
  `ZadEnv.amazonAssociateTag` / `amazonAssociateTagEg` read
  `AMAZON_ASSOCIATE_TAG` / `AMAZON_ASSOCIATE_TAG_EG` from `env.json`, with the
  table's values as defaults (an env.json without them still earns).
- **Adding a store later** (e.g. the Emirates): on the server, set both
  `AMAZON_DOMAIN_AE` and `AMAZON_ASSOCIATE_TAG_AE`; one without the other
  stays on amazon.sa on purpose. The app's `amazonStoreFor` needs the same
  country added in code.
- Product links are `https://<store>/dp/<ASIN>?tag=<tag>` for a verified
  ASIN, else a tagged search `https://<store>/s?k=<name>&tag=<tag>` (cannot
  404). The commission covers whatever the customer buys in that session,
  not only the searched item.

## Home: «🛍️ تسوق من أمازون»

`features/home/presentation/home_amazon_strip.dart`. A horizontal row of
cards, one per need — ran out («خلص»), running low («قرب يخلص»), then the
unbought shopping-list lines — at most 10, each with «🛒 اطلبه» (a tagged
search in the account's store). No pictures and no prices: the card names
the need; it does not guess which product or price the store will show (the
old product row was pulled for stock photos and riyal prices shown to Egypt,
b9251dd3). Hidden in وضع الطوارئ. Computed on the phone from the pantry and
the list — no network call on home open.

## «حاجة خلصت» — the link Zad sends

1. `trigger_restock_link_on_run_out` (migration `20261010180000_restock_link.sql`)
   on `zad_inventory`: a quantity going from above zero to zero or below writes
   an `agent_tasks` row, `kind = 'restock_link'`, due 15 minutes later. Items
   that run out in that window join the same row (one name per line). At most
   one sent message per 20 hours; a cancelled one does not count. A failure
   in the trigger is a warning — it never blocks the pantry update.
2. `processDueAgentTasks` (zad-brain) hands that kind to
   `deliverRestockLink` (`zad-brain/restockLink.ts`) — **no model call**: the
   message is fixed and the link must arrive exactly as built. Muting from
   Telegram and quiet hours apply as for every proactive kind.
3. It sends only items that are **still out** at send time (restocked in the
   window = nothing), **essential** (`isRestockEssential`: long-life staples,
   coffee/tea, water, cleaning and personal care; never fresh produce, meat,
   bread, eggs), at most 3; nothing in وضع الطوارئ. With nothing left the task
   is `cancelled`.
4. Delivery: `app_notifications` (the notification center turns each
   `• name: link` line into a «🛒 name على أمازون» button —
   `splitAmazonLinks`), FCM (tap opens home, where the cards are), Telegram
   (text without links, one URL button per item — `amazonButtonRows`), and an
   assistant turn in `zad_chat_turns` so the next chat turn knows what Zad
   offered.

**Not done:** the app's own chat transcript is local to the phone
(`chat_repository.dart`), so the message does not appear *inside* the app's
chat screen — it reaches the customer through the notification, the
notification center and Telegram. Showing server-sent messages in the app
chat is a separate feature.

## Verification (2026-10-10)

- `deno test` zad-brain / zad-telegram-bot / amazon-creators-search / _shared.
- `supabase/sql/tests/restock_link_test.sql` — 10 checks on Postgres 17
  (header has the docker commands); the zero-crossing guard and the
  once-a-day guard were each mutation-checked.
- `flutter analyze`, `flutter test`.
