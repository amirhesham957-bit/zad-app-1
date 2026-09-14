package com.example.ui.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * الرئيسية كانت بتعرض ٤ أقسام بس، وشيت "المزيد" كان ليه قايمة تانية مكتوبة بإيده.
 * التست بيقفل إن القايمة الموحدة فيها كل الأقسام الأساسية، مفيش تكرار، والشبكة المقفولة
 * بتملا صفوف كاملة (مفيش خانة فاضية في آخر صف ظاهر).
 */
class ZadSectionsGridTest {

    @Test
    fun everyRouteAppearsOnce() {
        val routes = zadAppSections.map { it.route }
        assertEquals(routes.size, routes.toSet().size)
    }

    @Test
    fun coversTheMainSectionsOfTheApp() {
        val routes = zadAppSections.map { it.route }.toSet()
        listOf(
            ZadRoutes.INVENTORY, ZadRoutes.SHOPPING, ZadRoutes.FAMILY, ZadRoutes.BUDGET,
            ZadRoutes.SUBS, ZadRoutes.PHARMACY, ZadRoutes.MAINTENANCE, ZadRoutes.TASBIHA,
            ZadRoutes.ASSISTANT, ZadRoutes.KNOWLEDGE_MAP, ZadRoutes.PROFILE,
        ).forEach { assertTrue(it, it in routes) }
    }

    @Test
    fun collapsedGridFillsWholeRows() {
        assertEquals(0, HOME_SECTIONS_COLLAPSED_COUNT % HOME_SECTIONS_COLUMNS)
        assertTrue(zadAppSections.size > HOME_SECTIONS_COLLAPSED_COUNT)
    }
}
