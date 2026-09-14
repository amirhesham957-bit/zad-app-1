package com.example.ui.components

import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * مشاركة إنجازات زاد (تحدي التوفير، أسبوعك، التسبيحة…) — نص + لينك التطبيق. نقطة واحدة
 * عشان كل الكروت اللي «تتشير» تبعت نفس اللينك، ولو القناة اتغيّرت تتغير هنا بس.
 */
object ZadShare {
    fun appLink(context: Context): String = "https://play.google.com/store/apps/details?id=${context.packageName}"

    fun shareText(context: Context, text: String, chooserTitle: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, "$text\n\n${appLink(context)}")
        }
        try {
            context.startActivity(Intent.createChooser(intent, chooserTitle).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            Log.w("ZadShare", "share failed: ${e.message}")
        }
    }
}
