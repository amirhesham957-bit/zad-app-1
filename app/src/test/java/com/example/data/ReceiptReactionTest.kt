package com.example.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ReceiptReactionTest {
    private val grocery = AiParsedReceipt(
        total = 120.0, category = "سوبرماركت", storeName = "كارفور",
        items = listOf(AiParsedReceiptItem(name = "شيبسي", price = 10.0, quantity = 3.0)),
    )

    @Test
    fun groceryReceiptSendsStoreTotalAndItems() {
        val json = Json.parseToJsonElement(ReceiptReaction.factsJson(grocery, "EGP")!!).jsonObject
        assertEquals("كارفور", json["store"]!!.jsonPrimitive.content)
        assertEquals("EGP", json["currency"]!!.jsonPrimitive.content)
        assertEquals("شيبسي", json["items"]!!.jsonArray[0].jsonObject["name"]!!.jsonPrimitive.content)
    }

    @Test
    fun pharmacyEmptyOrZeroReceiptsGetNoJoke() {
        assertNull(ReceiptReaction.factsJson(grocery.copy(receiptType = "pharmacy"), "EGP"))
        assertNull(ReceiptReaction.factsJson(grocery.copy(items = emptyList()), "EGP"))
        assertNull(ReceiptReaction.factsJson(grocery.copy(total = 0.0), "EGP"))
    }
}
