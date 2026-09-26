package com.aistudio.zad.banklistener

import android.os.Bundle

/**
 * What the service keeps from a notification, and which apps it never reads.
 *
 * Both are ports of `UnifiedBankListener.kt` in the Kotlin app — the Flutter
 * service had neither, and the gap was measured, not assumed.
 */
internal object NotificationContent {

    /**
     * Apps whose notifications are never money moving in the customer's
     * account: the system, stores, mail, photos, and people talking.
     *
     * This is Kotlin's `ignoredPackages` plus the Telegram forks it missed.
     * `org.telegram` covers the official client but not Telegram X
     * (`org.thunderdog.challegram`), and over the whole of
     * `zad_notification_ingest_events` (34 rows, measured 2026-09-25) **22 came
     * from Telegram X and not one was a transaction**: crypto channel posts
     * ("البيتكوين يصل الي 79,000 دولار" became a 79,000 USD "bank movement"),
     * and — worse — this app's own bot messages, which went back to the server
     * as bank notifications and made it ask "same transaction?" 13 times. The
     * two Google Photos rows in the same table were noise too. Every real bank
     * message came from the SMS app, which is not here and must never be
     * (CLAUDE.md, bank notification channel).
     */
    val IGNORED_PACKAGES: List<String> = listOf(
        "android",
        "com.android.systemui",
        "com.android.settings",
        "com.android.providers",
        "com.android.vending",
        "com.google.android.gms",
        "com.google.android.googlequicksearchbox",
        "com.google.android.apps.nbu.files",
        "com.google.android.youtube",
        "com.google.android.gm",
        "com.google.android.apps.photos",
        "com.whatsapp", "com.instagram.android", "com.facebook",
        "com.twitter", "com.snapchat", "org.telegram",
        // Telegram forks and other chat apps — people and channels, never a bank.
        "org.thunderdog.challegram", "nekox.messenger",
        "com.discord", "org.thoughtcrime.securesms", "com.viber.voip",
        "jp.naver.line.android", "com.zhiliaoapp.musically", "com.ss.android.ugc.trill",
    )

    fun isIgnored(packageName: String, ownPackage: String): Boolean =
        packageName == ownPackage ||
            IGNORED_PACKAGES.any { packageName == it || packageName.startsWith("$it.") }

    /**
     * Title and full body.
     *
     * `android.text` is the collapsed one-line form, and a bank SMS shown by a
     * messaging app is usually cut before the amount there. `bigText` (expanded)
     * and `textLines` (inbox style, one line per message) carry the whole body,
     * so they win when present; `subText` is appended because some banks put the
     * account tail there. Same order as the Kotlin listener.
     */
    fun extract(extras: Bundle): Pair<String, String> {
        val title = extras.getCharSequence("android.title")?.toString().orEmpty()
        val big = extras.getCharSequence("android.bigText")?.toString()
        val lines = extras.getCharSequenceArray("android.textLines")
            ?.joinToString("\n") { it.toString() }
            ?.takeIf { it.isNotBlank() }
        val plain = extras.getCharSequence("android.text")?.toString()
        val sub = extras.getCharSequence("android.subText")?.toString()
        val body = listOfNotNull(
            big?.takeIf { it.isNotBlank() } ?: lines ?: plain,
            sub?.takeIf { it.isNotBlank() && it != plain },
        ).joinToString(" ")
        return title to body
    }
}
