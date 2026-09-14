package com.example.data

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * زاد بتعلّق على الفاتورة بهزار بعد ما تتحفظ (zad-brain `moment_event` → `receipt_reaction`).
 * هنا بس بنجهّز الأصناف؛ الاختيار (سناكس/صنف متكرر/أغلى حاجة) والتنضيف والسقف اليومي على
 * السيرفر (`_shared/receiptReaction.ts`). فواتير الصيدلية مابتتعلّقش — الدوا مش هزار.
 */
object ReceiptReaction {
    const val MOMENT = "receipt_reaction"

    fun factsJson(receipt: AiParsedReceipt, currencyCode: String?): String? {
        if (receipt.receiptType == "pharmacy" || receipt.total <= 0 || receipt.items.isEmpty()) return null
        return buildJsonObject {
            put("store", receipt.storeName.take(60))
            put("total", receipt.total)
            put("currency", currencyCode)
            put("items", buildJsonArray {
                receipt.items.take(25).forEach { item ->
                    add(buildJsonObject {
                        put("name", item.name.take(40))
                        put("price", item.price)
                        put("quantity", item.quantity)
                    })
                }
            } as JsonArray)
        }.toString()
    }
}
