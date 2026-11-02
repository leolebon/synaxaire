package org.synaxaire.calendrier.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.synaxaire.calendrier.engine.CivilDate
import org.synaxaire.calendrier.engine.DateText
import org.synaxaire.calendrier.engine.FastCalendar
import org.synaxaire.calendrier.engine.FastLevel
import org.synaxaire.calendrier.engine.FastPeriod
import org.synaxaire.calendrier.engine.FastingRules
import org.synaxaire.calendrier.engine.Loc

@Composable
fun LentScreen(state: AppState) {
    val p = pal
    val today = CivilDate.today()
    val calendar = state.calendar
    var year by remember { mutableIntStateOf(today.year) }
    val expanded = remember { mutableStateListOf<String>() }
    var pendingScroll by remember { mutableStateOf<String?>(null) }
    val periods = remember(year, calendar) { FastCalendar.periods(year, calendar) }
    val todayInfo = remember(calendar) { FastingRules.fasting(today, calendar) }
    val next = remember(calendar) { FastCalendar.currentOrNextLent(today, calendar) }
    val listState = rememberLazyListState()

    // Défilement vers le carême demandé, une fois l'année affichée.
    LaunchedEffect(pendingScroll, periods) {
        val target = pendingScroll ?: return@LaunchedEffect
        val index = periods.indexOfFirst { it.id == target }
        if (index >= 0) {
            listState.animateScrollToItem(index + 3)
            pendingScroll = null
        }
    }

    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Text(Loc.t("lent.title"), fontFamily = Serif, fontWeight = FontWeight.Bold, fontSize = 28.sp, color = p.ink)
        }
        item {
            SectionCard(
                Loc.t("tab.today"),
                Modifier.clickable(enabled = next != null) {
                    next?.let { n ->
                        if (year != n.start.year) year = n.start.year
                        if (n.id !in expanded) expanded.add(n.id)
                        pendingScroll = n.id
                    }
                },
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    FastBadge(todayInfo.level)
                    Text(todayInfo.season.title, color = p.inkSoft, fontSize = 13.sp, modifier = Modifier.weight(1f).padding(start = 8.dp))
                }
                next?.let { n ->
                    val text = if (today in n) {
                        Loc.t("lent.current", mapOf("s" to n.season.title, "d" to DateText.dayMonth(n.end), "n" to (n.end.daysSince(today) + 1).toString()))
                    } else {
                        Loc.t("lent.next", mapOf("s" to n.season.title, "d" to DateText.dayMonth(n.start), "n" to n.start.daysSince(today).toString()))
                    }
                    Text(text, color = p.ink, fontSize = 14.sp)
                    Text(Loc.t("lent.tapHint") + " ▾", color = p.burgundy, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { year -= 1 }) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, null, tint = p.burgundy) }
                Text(
                    Loc.t("lent.year", mapOf("y" to year.toString())), fontFamily = Serif, fontSize = 20.sp, color = p.ink,
                    modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                )
                IconButton(onClick = { year += 1 }) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = p.burgundy) }
            }
        }
        items(periods, key = { it.id }) { period ->
            PeriodCard(period, today in period, period.id in expanded) {
                if (period.id in expanded) expanded.remove(period.id) else expanded.add(period.id)
            }
        }
        item { RulesGuide() }
    }
}

@Composable
private fun PeriodCard(period: FastPeriod, isCurrent: Boolean, open: Boolean, toggle: () -> Unit) {
    val p = pal
    val highlight = isCurrent || open
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(p.card)
            .border(if (highlight) 2.dp else 1.dp, if (highlight) p.burgundy else p.hairline, RoundedCornerShape(18.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(period.season.title, fontFamily = Serif, fontWeight = FontWeight.SemiBold, fontSize = 18.sp,
                    color = if (period.season.isFastFree) p.gold else p.burgundy)
                val days = period.end.daysSince(period.start) + 1
                SoftText(Loc.t("lent.range", mapOf("a" to DateText.dayMonthYear(period.start), "b" to DateText.dayMonthYear(period.end), "n" to days.toString())))
            }
            if (isCurrent) {
                Text(
                    Loc.t("lent.inProgress"), color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.clip(RoundedCornerShape(50)).background(p.burgundy).padding(horizontal = 8.dp, vertical = 4.dp),
                )
            } else if (period.season.isFastFree) {
                Text("🎉")
            }
        }
        val tips = period.season.recommendations
        if (tips.isNotEmpty()) {
            Text(
                (if (open) "▾ " else "▸ ") + Loc.t("rules.recommendations"),
                color = p.burgundy, fontWeight = FontWeight.SemiBold, fontSize = 14.sp,
                modifier = Modifier.clickable(onClick = toggle).padding(vertical = 4.dp),
            )
            AnimatedVisibility(open) { TipsList(tips) }
        }
    }
}

@Composable
private fun RulesGuide() {
    val p = pal
    val levels = listOf(FastLevel.STRICT, FastLevel.WINE_OIL, FastLevel.FISH, FastLevel.DAIRY, FastLevel.NO_FAST)
    SectionCard(Loc.t("lent.guide")) {
        levels.forEachIndexed { i, level ->
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                FastBadge(level)
                Text(level.explanation, color = p.ink, fontSize = 14.sp)
                FoodChips(level)
            }
            if (i < levels.size - 1) HorizontalDivider(color = p.hairline)
        }
        SoftText(Loc.t("lent.guideNote"), 12)
    }
}
