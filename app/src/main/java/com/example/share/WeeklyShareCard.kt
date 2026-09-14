package com.example.share

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.util.Log
import androidx.compose.ui.graphics.toArgb
import androidx.core.content.FileProvider
import com.example.R
import com.example.data.WeekSummary
import com.example.ui.components.ZadShare
import com.example.ui.theme.ZadEmeraldOnDark
import com.example.ui.theme.ZadForestEmerald
import com.example.ui.theme.ZadForestEmeraldDark
import com.example.ui.theme.ZadMustardLight
import java.io.File
import java.io.FileOutputStream

/**
 * صورة «أسبوعي مع زاد» اللي بتتشير على الواتساب/الإنستا (1080×1350، مقاس بوست).
 *
 * متعملة بـ android.graphics مش Compose: لازم تترسم بره أي شاشة (من زرار، في الخلفية) ومن غير
 * ما تظهر. مافيهاش ولا مبلغ — نسبة التغيير، أكتر فئة، والسلاسل بس (شوف [WeekSummary]).
 * RTL: StaticLayout بيطبّق bidi على النص العربي لوحده، والمحاذاة ALIGN_NORMAL = يمين للعربي.
 */
object WeeklyShareCard {
    const val WIDTH = 1080
    const val HEIGHT = 1350

    data class Extras(val challengeStreak: Int?, val tasbihaStreak: Int?)

    fun render(context: Context, week: WeekSummary, extras: Extras): Bitmap {
        val bmp = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val white = android.graphics.Color.WHITE
        val mint = ZadEmeraldOnDark.toArgb()
        val mustard = ZadMustardLight.toArgb()

        val bg = Paint().apply {
            shader = LinearGradient(0f, 0f, WIDTH.toFloat(), HEIGHT.toFloat(),
                ZadForestEmeraldDark.toArgb(), ZadForestEmerald.toArgb(), Shader.TileMode.CLAMP)
        }
        canvas.drawRect(0f, 0f, WIDTH.toFloat(), HEIGHT.toFloat(), bg)
        // دواير ضوء خفيفة — نفس روح لوحة العقل في الرئيسية.
        val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = mint; alpha = 28 }
        canvas.drawCircle(WIDTH * 0.9f, HEIGHT * 0.08f, 320f, glow)
        canvas.drawCircle(WIDTH * 0.05f, HEIGHT * 0.95f, 260f, glow)

        val margin = 96f
        val textWidth = (WIDTH - margin * 2).toInt()
        var y = 140f

        fun text(value: String, sizePx: Float, color: Int, bold: Boolean = false, gapAfter: Float = 24f) {
            val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = color
                textSize = sizePx
                typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            }
            val layout = StaticLayout.Builder.obtain(value, 0, value.length, paint, textWidth)
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setLineSpacing(0f, 1.1f)
                .build()
            canvas.save()
            canvas.translate(margin, y)
            layout.draw(canvas)
            canvas.restore()
            y += layout.height + gapAfter
        }

        text(context.getString(R.string.week_share_title), 64f, white, bold = true, gapAfter = 12f)
        text(context.getString(R.string.week_share_subtitle), 36f, white.withAlpha(180), gapAfter = 72f)

        val pct = week.changePct
        val headline = when {
            pct == null -> context.getString(R.string.week_share_first_week)
            pct < 0 -> context.getString(R.string.week_share_less, -pct)
            pct > 0 -> context.getString(R.string.week_share_more, pct)
            else -> context.getString(R.string.week_share_same)
        }
        text(headline, 88f, if (pct != null && pct > 0) mustard else mint, bold = true, gapAfter = 48f)

        val tone = when (week.tone) {
            WeekSummary.Tone.PROUD -> context.getString(R.string.week_share_tone_proud)
            WeekSummary.Tone.REPROACH -> context.getString(R.string.week_share_tone_reproach)
            WeekSummary.Tone.NEUTRAL -> context.getString(R.string.week_share_tone_neutral)
        }
        text(tone, 48f, white, gapAfter = 64f)

        // صف إحصائيات جوه كروت شفافة
        val rows = buildList {
            week.topCategory?.let { add(context.getString(R.string.week_share_top_category, it)) }
            extras.challengeStreak?.takeIf { it > 0 }?.let { add(context.getString(R.string.week_share_challenge_streak, it)) }
            extras.tasbihaStreak?.takeIf { it > 0 }?.let { add(context.getString(R.string.week_share_tasbiha_streak, it)) }
        }
        val card = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = white; alpha = 26 }
        rows.forEach { row ->
            val top = y - 28f
            canvas.drawRoundRect(RectF(margin - 32f, top, WIDTH - margin + 32f, top + 124f), 36f, 36f, card)
            y += 10f
            text(row, 44f, white, gapAfter = 62f)
        }

        y = HEIGHT - 150f
        text(context.getString(R.string.week_share_footer), 40f, mint, bold = true, gapAfter = 8f)
        text(context.getString(R.string.week_share_cta), 32f, white.withAlpha(170), gapAfter = 0f)
        return bmp
    }

    private fun Int.withAlpha(alpha: Int): Int =
        android.graphics.Color.argb(alpha, android.graphics.Color.red(this), android.graphics.Color.green(this), android.graphics.Color.blue(this))

    /** بيرسم ويحفظ في cache/reports (نفس مسار FileProvider الموجود) ويفتح المشاركة. */
    fun share(context: Context, week: WeekSummary, extras: Extras) {
        try {
            val dir = File(context.cacheDir, "reports").apply { mkdirs() }
            val file = File(dir, "zad_week.png")
            FileOutputStream(file).use { render(context, week, extras).compress(Bitmap.CompressFormat.PNG, 100, it) }
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, "${context.getString(R.string.week_share_title)}\n${ZadShare.appLink(context)}")
                clipData = ClipData.newRawUri(null, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(
                Intent.createChooser(intent, context.getString(R.string.week_share_action))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            )
        } catch (e: Exception) {
            Log.w("WeeklyShareCard", "share failed: ${e.message}")
        }
    }
}
