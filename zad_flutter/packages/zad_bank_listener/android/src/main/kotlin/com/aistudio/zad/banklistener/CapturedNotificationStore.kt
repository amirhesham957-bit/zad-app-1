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
internal class CapturedNotificationStore private constructor(context: Context) :
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
        createRejected(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // ١ → ٢ بيضيف جدول المرفوض بس: الصندوق ممكن يكون فيه رسالة بنك لسه مابعدتش.
        if (oldVersion == 1) {
            createRejected(db)
            return
        }
        // صندوق وارد، مش أرشيف: إشعار ضاع في ترقية أقل ضرراً من ترقية بتفشل
        // وتمنع الالتقاط خالص.
        db.execSQL("DROP TABLE IF EXISTS $TABLE")
        db.execSQL("DROP TABLE IF EXISTS $REJECTED")
        onCreate(db)
    }

    /**
     * الرسايل اللي فلتر Dart رفضها **والتطبيق مقفول**.
     *
     * سجل المرفوض الحقيقي في Hive جوه التطبيق، ومحرك الخلفية مابيلمسش Hive عن قصد
     * (محرك التطبيق ممكن يفتح نفس الصندوق في نفس اللحظة — `background_delivery.dart`).
     * فالرفض بيتركن هنا، والتطبيق بيسحبه لسجله أول ما يفضّي الصندوق.
     */
    private fun createRejected(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE $REJECTED (
              id       INTEGER PRIMARY KEY AUTOINCREMENT,
              source   TEXT    NOT NULL,
              reason   TEXT    NOT NULL,
              raw_text TEXT    NOT NULL,
              at       INTEGER NOT NULL
            )
            """.trimIndent()
        )
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

    /** يركن رفض واحد. سجل تشخيص مش أرشيف، فالأقدم بيتشال فوق [MAX_REJECTED]. */
    fun insertRejected(source: String, reason: String, rawText: String, at: Long) {
        val db = writableDatabase
        db.insert(
            REJECTED,
            null,
            ContentValues().apply {
                put("source", source)
                put("reason", reason)
                put("raw_text", rawText)
                put("at", at)
            },
        )
        db.execSQL(
            """
            DELETE FROM $REJECTED WHERE id NOT IN (
              SELECT id FROM $REJECTED ORDER BY at DESC, id DESC LIMIT $MAX_REJECTED
            )
            """.trimIndent()
        )
    }

    /**
     * يسلّم المركون كله، الأقدم الأول، ويمسحه — في معاملة واحدة.
     *
     * قراءة ومسح مع بعض، عكس [peek]/[deleteUpTo]: ده سجل تشخيص، وسطر ضاع لو التطبيق
     * وقع في النص أهون من سطر بيتكرر في السجل مع كل فتحة.
     */
    fun takeRejected(): List<Map<String, Any?>> {
        val db = writableDatabase
        val rows = mutableListOf<Map<String, Any?>>()
        db.beginTransaction()
        try {
            db.query(
                REJECTED,
                arrayOf("source", "reason", "raw_text", "at"),
                null, null, null, null,
                "at ASC, id ASC",
            ).use { c ->
                while (c.moveToNext()) {
                    rows += mapOf(
                        "source" to c.getString(0),
                        "reason" to c.getString(1),
                        "raw_text" to c.getString(2),
                        "at" to c.getLong(3),
                    )
                }
            }
            db.delete(REJECTED, null, null)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        return rows
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
        /**
         * نسخة واحدة للعملية كلها.
         *
         * ودي مش تحسين. الـ `SQLiteOpenHelper` بيفتح **اتصال خاص بيه**، والقفل
         * اللي بيسلسل الكتابة قفل على النسخة نفسها — مش على الملف. وهنا في
         * كاتبين في نفس العملية: الخدمة بتكتب `insert` وقت ما الإشعار يوصل،
         * والبلَج-إن بيعمل `peek`/`deleteUpTo` وقت ما Dart يفضّي الصندوق. كل
         * واحد كان ماسك نسخة لوحده، يعني اتصالين على نفس الملف من غير أي شيء
         * يسلسلهم.
         *
         * من غير WAL، الكاتب في SQLite بيقفل الملف على أي قارئ أو كاتب تاني،
         * فالتزامن ده بيرمي `SQLiteDatabaseLockedException`. والخدمة بتمسك
         * `Exception` وتكتب "capture failed" في اللوج — يعني **رسالة البنك
         * بتضيع في سكوت**، وهي بالظبط اللحظة اللي بتحصل فيها: إشعار بيوصل
         * والتطبيق مفتوح بيفضّي الصندوق.
         *
         * نسخة واحدة = اتصال واحد = القفل الداخلي بيسلسل الاتنين.
         */
        @Volatile
        private var instance: CapturedNotificationStore? = null

        /** الصندوق. نسخة واحدة مهما اتنادت. */
        fun get(context: Context): CapturedNotificationStore =
            instance ?: synchronized(this) {
                instance ?: CapturedNotificationStore(context).also { instance = it }
            }

        private const val DB_NAME = "zad_captured_notifications.db"
        private const val DB_VERSION = 2
        private const val TABLE = "captured_notifications"
        private const val MAX_ROWS = 500
        private const val REJECTED = "rejected_notifications"
        private const val MAX_REJECTED = 200
    }
}
