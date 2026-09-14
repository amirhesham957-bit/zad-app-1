package com.example.data

/**
 * ترتيب بستان العيلة اللي بيتشير — مين سبّح أكتر ومين ماشي أطول سلسلة. من [FamilyMemberWithTasbiha]
 * (الترتيب بالنقاط زي شاشة البستان بالظبط)، والسلسلة = أطول سلسلة على شجرة من شجر العضو.
 */
object TasbihaLeaderboard {
    data class Entry(val rank: Int, val name: String, val score: Int, val streakDays: Int)

    fun entries(members: List<FamilyMemberWithTasbiha>, limit: Int = 5): List<Entry> =
        members.sortedByDescending { it.totalScore }
            .take(limit)
            .mapIndexed { i, m ->
                Entry(
                    rank = i + 1,
                    name = m.member.alias.ifBlank { "—" }.take(24),
                    score = m.totalScore,
                    streakDays = m.trees.maxOfOrNull { it.streakDays } ?: 0,
                )
            }

    fun medal(rank: Int): String = when (rank) {
        1 -> "🥇"
        2 -> "🥈"
        3 -> "🥉"
        else -> "$rank"
    }
}
