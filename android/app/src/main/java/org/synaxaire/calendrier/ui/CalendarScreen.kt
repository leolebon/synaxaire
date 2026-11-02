package org.synaxaire.calendrier.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.synaxaire.calendrier.data.AppData
import org.synaxaire.calendrier.engine.CivilDate
import org.synaxaire.calendrier.engine.DateText
import org.synaxaire.calendrier.engine.FastLevel
import org.synaxaire.calendrier.engine.FeastRank
import org.synaxaire.calendrier.engine.LiturgicalDay
import org.synaxaire.calendrier.engine.Loc
import org.synaxaire.calendrier.engine.Paschalion

@Composable
fun CalendarScreen(state: AppState, navigate: Navigate) {
    val p = pal
    val today = CivilDate.today()
    var year by rememberSaveable { mutableIntStateOf(today.year) }
    var month by rememberSaveable { mutableIntStateOf(today.month) }
    val days: List<LiturgicalDay> = remember(year, month, state.calendar, state.language) {
        (1..CivilDate.daysInMonth(year, month)).map { AppData.day(CivilDate(year, month, it), state.calendar) }
    }

    fun shift(delta: Int) {
        var m = month + delta
        var y = year
        if (m < 1) { m = 12; y -= 1 }
        if (m > 12) { m = 1; y += 1 }
        month = m
        year = y
    }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(Loc.t("tab.calendar"), fontFamily = Serif, fontWeight = FontWeight.Bold, fontSize = 28.sp, color = p.ink, modifier = Modifier.weight(1f))
            TextButton(onClick = { year = today.year; month = today.month }) { Text(Loc.t("tab.today"), color = p.burgundy) }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { shift(-1) }) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, null, tint = p.burgundy) }
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(DateText.monthYear(year, month), fontFamily = Serif, fontWeight = FontWeight.SemiBold, fontSize = 22.sp, color = p.ink)
                // year.toString() : jamais de séparateur de milliers.
                SoftText(Loc.t("calendar.pascha", mapOf("y" to year.toString(), "d" to DateText.dayMonth(Paschalion.pascha(year)))), 12)
            }
            IconButton(onClick = { shift(1) }) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = p.burgundy) }
        }

        // Grille du mois (semaine commençant le lundi).
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(p.card)
                .border(1.dp, p.hairline, RoundedCornerShape(18.dp))
                .padding(8.dp),
        ) {
            Row {
                listOf(2, 3, 4, 5, 6, 7, 1).forEach { wd ->
                    Text(
                        DateText.weekdayShort(wd), modifier = Modifier.weight(1f), textAlign = TextAlign.Center,
                        fontSize = 12.sp, fontWeight = FontWeight.Bold, color = if (wd == 1) p.burgundy else p.inkSoft,
                    )
                }
            }
            val blanks = (CivilDate(year, month, 1).weekday + 5) % 7
            val cells: List<LiturgicalDay?> = List(blanks) { null } + days
            cells.chunked(7).forEach { week ->
                Row {
                    for (i in 0 until 7) {
                        val day = week.getOrNull(i)
                        Box(Modifier.weight(1f).height(56.dp)) {
                            if (day != null) DayCell(day, day.civil == today) { navigate(Route.Day(day.civil)) }
                        }
                    }
                }
            }
        }

        Legend()

        SectionCard(Loc.t("calendar.notable")) {
            val notable = days.filter { it.rank >= FeastRank.MAJOR || (it.civil.isSunday && !it.titleIsSaint) }
            if (notable.isEmpty()) SoftText(Loc.t("calendar.noFeast"), 14)
            notable.forEach { day ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { navigate(Route.Day(day.civil)) }
                        .padding(vertical = 6.dp),
                ) {
                    Text(
                        day.civil.day.toString(), fontFamily = Serif, fontWeight = FontWeight.Bold, fontSize = 18.sp,
                        color = day.rank.color(p), textAlign = TextAlign.End, modifier = Modifier.width(30.dp),
                    )
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            day.title, fontFamily = Serif, fontSize = 14.sp, color = p.ink,
                            fontWeight = if (day.rank >= FeastRank.GREAT) FontWeight.SemiBold else FontWeight.Normal,
                        )
                        SoftText(DateText.weekday(day.civil.weekday).replaceFirstChar { it.uppercase() }, 11)
                    }
                }
            }
        }
        VSpace(12)
    }
}

@Composable
private fun DayCell(day: LiturgicalDay, isToday: Boolean, onClick: () -> Unit) {
    val p = pal
    val f = day.fasting.level
    Column(
        Modifier
            .fillMaxSize()
            .padding(1.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(if (f == FastLevel.FAST_FREE) p.gold.copy(alpha = 0.10f) else Color.Transparent)
            .clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            Modifier
                .size(30.dp)
                .clip(CircleShape)
                .background(if (isToday) p.burgundy else Color.Transparent),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                day.civil.day.toString(), fontFamily = Serif, fontSize = 16.sp,
                fontWeight = if (isToday || day.rank >= FeastRank.MAJOR) FontWeight.Bold else FontWeight.Normal,
                color = when {
                    isToday -> Color.White
                    day.rank >= FeastRank.GREAT || day.civil.isSunday -> p.burgundy
                    else -> p.ink
                },
            )
        }
        Box(Modifier.height(9.dp), contentAlignment = Alignment.Center) {
            when {
                day.rank >= FeastRank.GREAT -> Text("☩", fontSize = 9.sp, color = p.burgundy, fontWeight = FontWeight.Bold)
                day.rank >= FeastRank.MAJOR -> Box(Modifier.size(5.dp).clip(CircleShape).background(p.gold))
            }
        }
        Box(
            Modifier
                .padding(horizontal = 8.dp)
                .fillMaxWidth()
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(if (f.isFasting) f.color(p) else Color.Transparent),
        )
    }
}

@Composable
private fun Legend() {
    val p = pal
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            listOf(FastLevel.DAIRY, FastLevel.FISH, FastLevel.WINE_OIL, FastLevel.STRICT).forEach { level ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.width(14.dp).height(4.dp).background(level.color(p)))
                    Spacer(Modifier.width(4.dp))
                    SoftText(level.shortTitle, 11)
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("☩ ", color = p.burgundy, fontSize = 11.sp)
            SoftText(Loc.t("legend.great"), 11)
            Box(Modifier.size(6.dp).clip(CircleShape).background(p.gold))
            SoftText(Loc.t("legend.major"), 11)
            Box(Modifier.width(14.dp).height(10.dp).background(p.gold.copy(alpha = 0.2f)))
            SoftText(Loc.t("legend.fastFree"), 11)
        }
    }
}
