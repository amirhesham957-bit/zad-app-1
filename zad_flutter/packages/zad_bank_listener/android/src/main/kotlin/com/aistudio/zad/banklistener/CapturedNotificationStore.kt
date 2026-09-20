package com.aistudio.zad.banklistener

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * الإشعارات الملتقطة، على القرص.
 *
 * السبب إنها SQLite مش قناة مباشرة لـ Dart: الـ NotificationListenerService
 * بيشتغل من غير ما التطبيق يكون فاتح أصلاً، وأندرويد بيربطه ويفكّه على مزاجه.
 * لو الالتقاط كان بيبعت لمحرك Flutter، الرسالة اللي توصل والتطبيق مقفول كانت
 * هتضيع — وهي الحالة الطبيعية لرسالة بنك، مش الاستثناء.
 *
 * الجدول ده صندوق وارد، مش مصدر حقيقة: Dart بيسحب منه، يقرّر، ويحطّ اللي
 * يستاهل في طابور الإرسال. المسح بيحصل بعد السحب بنجاح بس.
 */
internal class CapturedNotificationStore(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE $TABLE (
              id           INTEGER PRIMARY KEY AUTOINCREMENT,
              package_name TEXT    NOT NULL,
              title        TEXT    NOT NULL,
              text         TEXT    NOT NULL,
              posted_at    INTEGER NOT NULL
            )
            """.trimIndent()
        )
        // الترتيب الزمني هو ترتيب السحب، فالفهرس عليه مش رفاهية.
        db.execSQL("CREATE INDEX ${TABLE}_posted_at ON $TABLE (posted_at)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // صندوق وارد، مش أرشيف: إشعار ضاع في ترقية أقل ضرراً من ترقية بتفشل
        // وتمنع الالتقاط خالص.
        db.execSQL("DROP TABLE IF EXISTS $TABLE")
        onCreate(db)
    }

    fun insert(packageName: String, title: String, text: String, postedAt: Long) {
        writableDatabase.insert(
            TABLE,
            null,
            ContentValues().apply {
                put("package_name", packageName)
                put("title", title)
                put("text", text)
                put("posted_at", postedAt)
            },
        )
        pruneIfOversized()
    }

    /** أقدم [limit] إشعار، الأقدم الأول. */
    fun peek(limit: Int): List<Map<String, Any?>> {
        val rows = mutableListOf<Map<String, Any?>>()
        readableDatabase.query(
            TABLE,
            arrayOf("id", "package_name", "title", "text", "posted_at"),
            null, null, null, null,
            "posted_at ASC, id ASC",
            limit.toString(),
        ).use { c ->
            while (c.moveToNext()) {
                rows += mapOf(
                    "id" to c.getLong(0),
                    "package_name" to c.getString(1),
                    "title" to c.getString(2),
                    "text" to c.getString(3),
                    "posted_at" to c.getLong(4),
                )
            }
        }
        return rows
    }

    /**
     * بيمسح اللي Dart أكّد إنه استلمه.
     *
     * السحب والمسح خطوتين مش واحدة عن قصد: لو المسح حصل مع القراءة، تطبيق
     * اتقفل بين الاتنين كان هيبلع الإشعار. التكرار بيتعامل معاه الطابور نفسه
     * (نفس الـ id بيصطدم بالمفتاح)، فالتسليم-مرة-على-الأقل هو الاتجاه الصح هنا.
     */
    fun deleteUpTo(ids: List<Long>) {
        if (ids.isEmpty()) return
        val placeholders = ids.joinToString(",") { "?" }
        writableDatabase.delete(
            TABLE,
            "id IN ($placeholders)",
            ids.map { it.toString() }.toTypedArray(),
        )
    }

    fun pending(): Int =
        readableDatabase.rawQuery("SELECT COUNT(*) FROM $TABLE", null).use {
            if (it.moveToFirst()) it.getInt(0) else 0
        }

    /**
     * سقف صلب على حجم الصندوق.
     *
     * التطبيق ممكن يفضل مقفول أسابيع والخدمة شغالة طول الوقت. من غير السقف ده
     * الجدول بيكبر بلا حد على جهاز العميل. الأقدم بيتشال الأول — رسالة بنك عمرها
     * شهر مش هتتكتب دلوقتي على أي حال.
     */
    private fun pruneIfOversized() {
        writableDatabase.execSQL(
            """
            DELETE FROM $TABLE WHERE id NOT IN (
              SELECT id FROM $TABLE ORDER BY posted_at DESC, id DESC LIMIT $MAX_ROWS
            )
            """.trimIndent()
        )
    }

    companion object {
        private const val DB_NAME = "zad_captured_notifications.db"
        private const val DB_VERSION = 1
        private const val TABLE = "captured_notifications"
        private const val MAX_ROWS = 500
    }
}
