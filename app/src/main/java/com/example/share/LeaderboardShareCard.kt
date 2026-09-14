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
import com.example.data.TasbihaLeaderboard
import com.example.ui.components.ZadShare
import com.example.ui.theme.ZadEmeraldOnDark
import com.example.ui.theme.ZadForestEmerald
import com.example.ui.theme.ZadForestEmeraldDark
import com.example.ui.theme.ZadMustardLight
import java.io.File
import java.io.FileOutputStream

/**
 * صورة «بستان عيلتنا» — ترتيب التسبيح للعيلة (1080×1350). نفس أسلوب [WeeklyShareCard]:
 * android.graphics بره الشاشة، ولون البراند، والأسماء المستعارة اللي العيلة اختارتها بس.
 */
object LeaderboardShareCard {
    const val WIDTH = 1080
    const val HEIGHT = 1350

    fun render(context: Context, entries: List<TasbihaLeaderboard.Entry>): Bitmap {
        val bmp = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val white = android.graphics.Color.WHITE
        val mint = ZadEmeraldOnDark.toArgb()
        val gold = ZadMustardLight.toArgb()

        canvas.drawRect(0f, 0f, WIDTH.toFloat(), HEIGHT.toFloat(), Paint().apply {
            shader = LinearGradient(0f, 0f, 0f, HEIGHT.toFloat(), ZadForestEmerald.toArgb(), ZadForestEmeraldDark.toArgb(), Shader.TileMode.CLAMP)
        })
        canvas.drawCircle(WIDTH * 0.15f, HEIGHT * 0.06f, 300f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = mint; alpha = 26 })

        val margin = 96f
        var y = 130f
        fun text(value: String, sizePx: Float, color: Int, bold: Boolean, width: Int, x: Float, top: Float, align: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL): Int {
            val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = color; textSize = sizePx; typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            }
            val layout = StaticLayout.Builder.obtain(value, 0, value.length, paint, width).setAlignment(align).build()
            canvas.save(); canvas.translate(x, top); layout.draw(canvas); canvas.restore()
            return layout.height
        }
        val full = (WIDTH - margin * 2).toInt()
        y += text("🌳 " + context.getString(R.string.leaderboard_share_title), 64f, white, true, full, margin, y) + 16f
        y += text(context.getString(R.string.leaderboard_share_subtitle), 36f, white, false, full, margin, y) + 72f

        val rowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = white; alpha = 24 }
        val leadPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = gold; alpha = 60 }
        entries.forEach { e ->
            val rect = RectF(margin - 24f, y, WIDTH - margin + 24f, y + 150f)
            canvas.drawRoundRect(rect, 40f, 40f, if (e.rank == 1) leadPaint else rowPaint)
            // اسم + سلسلة (يمين)، والنقاط (شمال)
            val nameLine = "${TasbihaLeaderboard.medal(e.rank)}  ${e.name}"
            text(nameLine, 50f, white, true, (full * 0.62f).toInt(), WIDTH - margin - full * 0.62f, y + 22f)
            if (e.streakDays > 0) {
                text(context.getString(R.string.leaderboard_share_streak, e.streakDays), 32f, mint, false, (full * 0.62f).toInt(), WIDTH - margin - full * 0.62f, y + 88f)
            }
            text(String.format(java.util.Locale.getDefault(), "%d", e.score), 60f, if (e.rank == 1) gold else white, true, (full * 0.34f).toInt(), margin, y + 40f, Layout.Alignment.ALIGN_OPPOSITE)
            y += 174f
        }

        text(context.getString(R.string.leaderboard_share_cta), 44f, mint, true, full, margin, HEIGHT - 190f)
        text(context.getString(R.string.week_share_cta), 32f, white, false, full, margin, HEIGHT - 120f)
        return bmp
    }

    fun share(context: Context, entries: List<TasbihaLeaderboard.Entry>) {
        if (entries.isEmpty()) return
        try {
            val dir = File(context.cacheDir, "reports").apply { mkdirs() }
            val file = File(dir, "zad_tasbiha_leaderboard.png")
            FileOutputStream(file).use { render(context, entries).compress(Bitmap.CompressFormat.PNG, 100, it) }
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, "${context.getString(R.string.leaderboard_share_cta)}\n${ZadShare.appLink(context)}")
                clipData = ClipData.newRawUri(null, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(
                Intent.createChooser(intent, context.getString(R.string.leaderboard_share_action))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            )
        } catch (e: Exception) {
            Log.w("LeaderboardShareCard", "share failed: ${e.message}")
        }
    }
}
