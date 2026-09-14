package com.example.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** نفس حدود قيد zad_customer_profile — الحفظ من الشاشة مايترفضش. */
class CustomerProfileTest {
    @Test
    fun outOfRangeAndUnknownValuesBecomeNullAndTextIsTrimmed() {
        val p = CustomerProfileOptions.normalized(
            ZadCustomerProfile(preferredName = "  أمير  ", gender = "robot", payDay = 40, kidsCount = 3, dialect = "EG", city = "   ")
        )
        assertEquals("أمير", p.preferredName)
        assertNull(p.gender)
        assertNull(p.payDay)
        assertEquals(3, p.kidsCount)
        assertEquals("EG", p.dialect)
        assertNull(p.city)
    }

    @Test
    fun homeAsksForAnIntroductionUntilNameAndGenderAreKnown() {
        assertTrue(needsIntroduction(null))
        assertTrue(needsIntroduction(ZadCustomerProfile(preferredName = "أمير")))
        assertTrue(needsIntroduction(ZadCustomerProfile(gender = "male", preferredName = "  ")))
        assertFalse(needsIntroduction(ZadCustomerProfile(preferredName = "أمير", gender = "male")))
    }
}
