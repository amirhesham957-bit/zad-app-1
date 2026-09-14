package com.example.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.FamilyRestroom
import androidx.compose.material.icons.filled.Hub
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalPharmacy
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Yard
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.R
import com.example.ui.theme.*

/**
 * قسم من أقسام التطبيق — مصدر واحد للرئيسية وشيت "المزيد".
 *
 * الرئيسية كانت بتعرض ٤ اختصارات ثابتة بعرض 132dp في LazyRow، فالرابع كان بيتقص عند
 * حافة الشاشة (ظاهر في لقطة جهاز حقيقي ٢٠٢٦-٠٩-١٤)، وباقي الأقسام ماكانش ليها أي
 * مدخل من الرئيسية. وشيت "المزيد" كان ليه قايمة تانية مكتوبة بإيده. قايمة واحدة هنا
 * بتمنع الاتنين يختلفوا تاني.
 */
internal data class ZadSectionEntry(
    val route: String,
    val icon: ImageVector,
    val labelRes: Int,
    val accent: ZadSectionAccent,
)

/** بالترتيب اللي بيظهر بيه — أول [HOME_SECTIONS_COLLAPSED_COUNT] هما الأكتر استخدامًا. */
internal val zadAppSections: List<ZadSectionEntry> = listOf(
    ZadSectionEntry(ZadRoutes.INVENTORY, Icons.Default.Inventory2, R.string.nav_inventory, ZadSectionAccent.Emerald),
    ZadSectionEntry(ZadRoutes.SHOPPING, Icons.Default.ShoppingCart, R.string.nav_shopping, ZadSectionAccent.Amber),
    ZadSectionEntry(ZadRoutes.FAMILY, Icons.Default.FamilyRestroom, R.string.nav_family, ZadSectionAccent.Violet),
    ZadSectionEntry(ZadRoutes.BUDGET, Icons.Default.BarChart, R.string.nav_budget, ZadSectionAccent.Blue),
    ZadSectionEntry(ZadRoutes.SUBS, Icons.Default.CreditCard, R.string.subscriptions_title, ZadSectionAccent.Indigo),
    ZadSectionEntry(ZadRoutes.PHARMACY, Icons.Default.LocalPharmacy, R.string.nav_pharmacy, ZadSectionAccent.Rose),
    ZadSectionEntry(ZadRoutes.MAINTENANCE, Icons.Default.Build, R.string.nav_maintenance, ZadSectionAccent.Brown),
    ZadSectionEntry(ZadRoutes.TASBIHA, Icons.Default.Yard, R.string.tasbiha_short_label, ZadSectionAccent.Green),
    ZadSectionEntry(ZadRoutes.ASSISTANT, Icons.Default.Psychology, R.string.screen_title_assistant, ZadSectionAccent.Teal),
    ZadSectionEntry(ZadRoutes.KNOWLEDGE_MAP, Icons.Default.Hub, R.string.knowledge_map_title, ZadSectionAccent.Blue),
    ZadSectionEntry(ZadRoutes.NOTIFICATIONS, Icons.Default.Notifications, R.string.notifications_title, ZadSectionAccent.Amber),
    ZadSectionEntry(ZadRoutes.STATEMENT, Icons.Default.ReceiptLong, R.string.statement_import_title, ZadSectionAccent.Slate),
    ZadSectionEntry(ZadRoutes.PREMIUM_PLANS, Icons.Default.Star, R.string.premium_plans_title, ZadSectionAccent.Amber),
    ZadSectionEntry(ZadRoutes.PROFILE, Icons.Default.Person, R.string.screen_title_profile, ZadSectionAccent.Slate),
)

internal const val HOME_SECTIONS_COLUMNS = 4
internal const val HOME_SECTIONS_COLLAPSED_COUNT = 8

/**
 * شبكة كل أقسام التطبيق في الرئيسية: صفين (٨ أقسام) وزرار "كل الأقسام" بيفتح الباقي
 * بحركة. شبكة مش شريط أفقي عن قصد — مفيش عنصر بيتقص عند الحافة، وكل قسم على بعد ضغطة.
 *
 * Column/Row عادي مش LazyVerticalGrid: الشبكة جوه LazyColumn الرئيسية، وlazy grid
 * متداخل من غير ارتفاع ثابت بيرمي "infinity maximum height constraints".
 */
@Composable
fun ZadSectionsGrid(
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier,
    badges: Map<String, Int> = emptyMap(),
) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    val collapsed = remember { zadAppSections.take(HOME_SECTIONS_COLLAPSED_COUNT) }
    val extra = remember { zadAppSections.drop(HOME_SECTIONS_COLLAPSED_COUNT) }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SectionRows(collapsed, badges, onNavigate)

        AnimatedVisibility(
            visible = expanded,
            enter = expandVertically(spring(dampingRatio = 0.85f, stiffness = 380f)) + fadeIn(),
            exit = shrinkVertically(spring(dampingRatio = 0.85f, stiffness = 380f)) + fadeOut(),
        ) {
            SectionRows(extra, badges, onNavigate)
        }

        if (extra.isNotEmpty()) {
            val chevronRotation by animateFloatAsState(
                targetValue = if (expanded) 180f else 0f,
                animationSpec = ZadSprings.Screen,
                label = "sectionsChevron"
            )
            Row(
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .heightIn(min = 44.dp)
                    .clip(RoundedCornerShape(9999.dp))
                    .clickable { expanded = !expanded }
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = if (expanded) stringResource(R.string.home_sections_show_less)
                    else stringResource(R.string.home_sections_show_all, zadAppSections.size),
                    style = Typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    color = primary
                )
                Icon(
                    imageVector = Icons.Default.ExpandMore,
                    contentDescription = null,
                    tint = primary,
                    modifier = Modifier
                        .size(20.dp)
                        .rotate(chevronRotation)
                )
            }
        }
    }
}

@Composable
private fun SectionRows(
    entries: List<ZadSectionEntry>,
    badges: Map<String, Int>,
    onNavigate: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        entries.chunked(HOME_SECTIONS_COLUMNS).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { entry ->
                    SectionTile(
                        entry = entry,
                        badge = badges[entry.route] ?: 0,
                        onClick = { onNavigate(entry.route) },
                        modifier = Modifier.weight(1f)
                    )
                }
                repeat(HOME_SECTIONS_COLUMNS - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun SectionTile(
    entry: ZadSectionEntry,
    badge: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val label = stringResource(entry.labelRes)
    Column(
        modifier = modifier
            .pressableScale()
            .clip(RoundedCornerShape(16.dp))
            .semantics { contentDescription = if (badge > 0) "$label, $badge" else label }
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick
            )
            .padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(contentAlignment = Alignment.Center) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(entry.accent.containerColor)
                    .border(1.dp, entry.accent.contentColor.copy(alpha = 0.20f), RoundedCornerShape(16.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(entry.icon, contentDescription = null, tint = entry.accent.contentColor, modifier = Modifier.size(24.dp))
            }
            if (badge > 0) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .offset(x = 4.dp, y = (-4).dp)
                        .clip(RoundedCornerShape(9999.dp))
                        .background(dangerColor)
                        .border(1.5.dp, surface, RoundedCornerShape(9999.dp))
                        .padding(horizontal = 4.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = if (badge > 99) "99+" else badge.toString(),
                        style = Typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }
            }
        }
        Text(
            text = label,
            style = Typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = textPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
    }
}
