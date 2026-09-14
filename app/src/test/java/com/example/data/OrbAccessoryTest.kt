package com.example.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OrbAccessoryTest {
    @Test
    fun eachFamilyMemberWhoJoinsUnlocksTheNextAccessory() {
        assertTrue(OrbAccessory.NONE.isUnlocked(1))
        assertFalse(OrbAccessory.BOW.isUnlocked(1))
        assertTrue(OrbAccessory.BOW.isUnlocked(2))
        assertEquals(OrbAccessory.GLASSES, OrbAccessory.nextLocked(2))
        assertNull(OrbAccessory.nextLocked(5))
    }

    @Test
    fun unknownStoredValueFallsBackToNone() {
        assertEquals(OrbAccessory.NONE, OrbAccessory.from("rocket"))
        assertEquals(OrbAccessory.CROWN, OrbAccessory.from("crown"))
    }
}
