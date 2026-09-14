package com.example.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * المولّد الاحتياطي لشيف زاد طلّع على جهاز حقيقي "وجبة منزلية سريعة بـ ماء إيلان".
 * الأصناف هنا منقولة بالحرف من zad_inventory على الإنتاج (٢٠٢٦-٠٩-١٤).
 */
class ChefIngredientsTest {

    private fun item(name: String, category: String?, qty: Int = 1) =
        ZadInventory(itemName = name, category = category, quantity = qty)

    @Test
    fun waterAndDrinksFromProductionAreNotIngredients() {
        listOf(
            "ماء إيلان" to "المشروبات",
            "إزازة ماء" to "المشروبات",
            "كرتونة ماية" to "المشروبات",
            "عبوة مياه" to "المشروبات",
            "مياه إيلانو" to "مشروبات",
        ).forEach { (name, cat) -> assertFalse(name, isCookableIngredient(name, cat)) }
        // حتى لو التصنيف غلط أو فاضي، الاسم لوحده كفاية
        assertFalse(isCookableIngredient("ماء بوفانا", null))
    }

    @Test
    fun containersAndSnacksAreNotIngredients() {
        assertFalse(isCookableIngredient("علبة حفظ طعام وردية", "أخرى"))
        assertFalse(isCookableIngredient("Pringles Mexican Chilli & Lime Flavour", "وجبات خفيفة"))
        assertFalse(isCookableIngredient("برينجلز", null))
    }

    @Test
    fun realGroceriesStayIngredients() {
        listOf(
            "بيض" to "البقالة", "مكرونة" to "البقالة", "فول" to "البقالة", "صلصة" to "البقالة",
            "زيت" to "البقالة", "بصل" to "الخضار", "لبن" to "الألبان", "Cream Cheese" to "الألبان",
        ).forEach { (name, cat) -> assertTrue(name, isCookableIngredient(name, cat)) }
    }

    @Test
    fun genericRecipeNeverNamesWater() {
        val inventory = listOf(
            item("ماء إيلان", "المشروبات"),
            item("كرتونة ماية", "المشروبات"),
            item("بيض", "البقالة"),
            item("بصل", "الخضار"),
            item("علبة حفظ طعام", "أخرى"),
        )
        val recipes = ZadAiRepository.generateDeterministicChefRecipes(inventory)
        recipes.forEach { recipe ->
            assertFalse(recipe.recipeName, recipe.recipeName.contains("ماء") || recipe.recipeName.contains("ماية"))
            recipe.availableIngredientsUsed.forEach { assertTrue(it, isCookableIngredient(it, null)) }
        }
    }

    @Test
    fun fallbackRecipesDoNotClaimIngredientsTheUserLacks() {
        val onlyWater = listOf(item("ماء إيلان", "المشروبات"), item("عبوة مياه", "المشروبات"))
        val recipes = ZadAiRepository.generateDeterministicChefRecipes(onlyWater)
        assertTrue(recipes.isNotEmpty())
        recipes.forEach { assertEquals(recipe(it), emptyList<String>(), it.availableIngredientsUsed) }
    }

    @Test
    fun outOfStockItemsAreIgnored() {
        val inventory = listOf(item("بيض", "البقالة", qty = 0), item("بصل", "الخضار", qty = 0))
        ZadAiRepository.generateDeterministicChefRecipes(inventory).forEach {
            assertEquals(recipe(it), emptyList<String>(), it.availableIngredientsUsed)
        }
    }

    private fun recipe(r: ZadRecipe) = r.recipeName
}
