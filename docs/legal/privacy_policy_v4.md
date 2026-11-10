# Zad Privacy Policy

**Version 4.0. Last updated: November 10, 2026.**
Developer: AstraLabs. Contact: astralabs.supp@gmail.com

Zad is a household money and home assistant. This policy explains what Zad collects, why, who
processes it, and how you control it. It replaces version 3.1.

## 1. What we collect

**What you enter.** Your account (email or sign-in provider), country and currency, salary day,
budgets, expenses and income, obligations and debts, pantry items, shopping lists, pharmacy items
and dose times, appointments, subscriptions, documents you choose to scan, family chat messages,
family tasks, and what you write or say to Zad's assistant.

**What you allow through permissions** (each is optional and asked for when you first use the
feature):

- **Notification access.** Zad reads the notifications that bank and payment messages arrive in, so
  it can record a purchase for you. Bank messages usually reach your phone inside your messaging
  app's notification, so Zad reads that app's notifications too and keeps only the ones that look
  like a bank or payment message. A notification Zad cannot classify on the phone is sent to our
  server to be classified, and is kept only if it is a transaction. Zad never reads bank logins,
  card numbers, PINs, CVV codes or one-time passwords. It ignores OTP messages.
- **Location.** Used for nearby shops and local prices (one approximate fix when you ask), and, only
  if you turn on store-arrival reminders, **in the background**, so Zad can remind you of your list
  when you arrive at a shop you saved. Background location is used only for those saved places. You
  can turn it off in Zad or in Android settings at any time.
- **Camera and photos.** Used for scanning receipts, pantry items, medicines, documents and
  bank statements that you choose to photograph.
- **Microphone.** Used only while you hold the voice button to speak to Zad.
- **Notifications, exact alarms, battery optimisation exemption.** Used for reminders (doses,
  appointments, bills) and to keep bank-message reading working in the background.

**Collected automatically.** Device model, Android version, app version, crash reports and
diagnostics, approximate usage of features, and your IP address. Crash reports are sent without
personal data or screenshots.

**Advertising data.** On the free plan, Google AdMob collects the advertising ID and device data to
show and measure ads (see section 3).

## 2. How we use it

To run the features you use; to record and categorise your spending; to remind you; to answer you
through the assistant; to keep your family's shared data in sync; to prevent abuse and enforce
usage limits; to fix crashes; to process purchases; and, on the free plan, to show ads. We do not
sell your personal data.

## 3. Who processes your data

| Service | What it does | What it receives |
|---|---|---|
| **Supabase** | Hosting, database, sign-in, server functions | All account data, stored with per-user access rules |
| **Google Gemini API** | Main AI: chat answers, receipt and document reading, bank-message classification, voice | The text, image or audio needed for the request you made |
| **Groq** | Backup AI when Gemini is unavailable; speech-to-text | The text or audio needed for that request |
| **Microsoft Azure Speech** | Backup voice for spoken replies | The reply text to be spoken |
| **Google AdMob** | Ads on the free plan (rewarded and occasional full-screen ads) | Advertising ID, device and usage data, approximate location from IP |
| **Google Play Billing** | Subscriptions and purchases | Purchase details; Zad never sees your card |
| **Firebase Cloud Messaging** | Push notifications | A device token |
| **Sentry** | Crash reporting | Crash data, device and app version, no personal data |
| **Google Places** | Nearby shops | An approximate location when you ask |
| **Tavily, Microsoft Bing, Google Custom Search** | Finding prices, offers and recipes | Product, store and city names. Never your identity |
| **Telegram** | Only if you link Zad's Telegram bot | The messages, photos and voice notes you send the bot, under Telegram's own policy |
| **Amazon Associates and other affiliate programs** | Product suggestions | Nothing from your account. Amazon sees you only if you open its link |

**About the free Gemini API.** Zad uses Google's Gemini API on terms under which Google may use the
content sent to it to improve Google's products, and human reviewers may read it. For that reason
Zad sends only what the request needs, and you should not put information in chat or photos that
you would not want reviewed. See Google's Gemini API terms for details.

Public content Zad reads to suggest recipes and offers (for example public TikTok, Instagram and
YouTube posts found through search) contains none of your data.

## 4. Ads

The free plan shows ads from Google AdMob: rewarded ads you choose to watch for extra messages,
voice or images, and occasional full-screen ads at natural pauses. Paid plans show no ads. Child
accounts and kids mode show no ads at all. Where the law requires it, Google's consent form asks
for your choice before any ad. You can reset or delete your advertising ID in Android settings.

## 5. Family and children

Zad is for adults (18 and over). An adult can create a family and invite members. A parent may add
a **child member**, who signs in to their own account inside the family, and may also turn on
**kids mode** on their own phone, protected by a PIN.

For child members and in kids mode: no ads and no advertising ID. The child sees a reduced app
(tasks, savings challenges, family chat). A parent can view and delete a child's data.

**School zones** (optional): a parent can ask to be told when a child leaves a place the parent set,
such as school, during the hours the parent set. It works only after the **child agrees on their
own phone**. The child's phone shows a permanent notice while it is on, and either side can stop
it. Zad sends only "entered" and "left" events. It does not store the child's route or position.
Zad does not offer location tracking of any adult.

## 6. Retention and deletion

Your data stays while your account is active. To delete your account: **Zad → My account → Delete
account**, or email astralabs.supp@gmail.com with the subject "Delete my account".

After a deletion request your account is closed at once and stops receiving messages. You have
**14 days** to restore it by signing in again. After 14 days, your account and data are erased. A
minimal record that a deletion happened (no amounts and no text) is kept for security. Backups are
overwritten within 30 days. Data that the law requires us to keep is kept only as long as required.

## 7. Security

Data is sent over encrypted connections. Each table on our server is protected by access rules so
that only you, and family members you share with, can read your data. Secret keys stay on the
server and never ship in the app.

## 8. Your rights

You can see and correct your data in the app, export it, withdraw any permission in Android
settings, unlink Telegram, and delete your account. For anything else, email
astralabs.supp@gmail.com. We answer within 30 days.

## 9. Changes

If this policy changes, we will update the date above and tell you in the app before the change
affects you.
