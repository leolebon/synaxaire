package org.synaxaire.calendrier.ui

import android.graphics.Bitmap
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import org.synaxaire.calendrier.data.AppData
import org.synaxaire.calendrier.data.Images
import org.synaxaire.calendrier.data.Orthocal
import org.synaxaire.calendrier.data.SaintProfile
import org.synaxaire.calendrier.data.SaintStory
import org.synaxaire.calendrier.data.Wikipedia
import org.synaxaire.calendrier.engine.CivilDate
import org.synaxaire.calendrier.engine.Commemoration
import org.synaxaire.calendrier.engine.DateText
import org.synaxaire.calendrier.engine.FastSeason
import org.synaxaire.calendrier.engine.FeastRank
import org.synaxaire.calendrier.engine.LiturgicalDay
import org.synaxaire.calendrier.engine.Loc
import org.synaxaire.calendrier.engine.Paschalion

private enum class LoadState { LOADING, LOADED, FAILED }

@Composable
fun DayScreen(date: CivilDate, state: AppState, navigate: Navigate, isToday: Boolean = false) {
    val calendar = state.calendar
    val day = remember(date, calendar, state.language) { AppData.day(date, calendar) }
    var stories by remember(date, calendar) { mutableStateOf<List<SaintStory>>(emptyList()) }
    var load by remember(date, calendar) { mutableStateOf(LoadState.LOADING) }
    var retry by remember { mutableIntStateOf(0) }

    LaunchedEffect(date, calendar, retry) {
        load = LoadState.LOADING
        val s = Orthocal.stories(date, calendar)
        if (s == null) load = LoadState.FAILED else { stories = s; load = LoadState.LOADED }
    }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        if (isToday) {
            Text(Loc.t("tab.today"), fontFamily = Serif, fontWeight = FontWeight.Bold, fontSize = 30.sp, color = pal.ink)
        }
        HeroHeader(day)
        SaintGallery(day, navigate)
        FastingCard(day)
        SaintsCard(day, navigate)
        StoriesCard(stories, load, navigate) { retry++ }
        Footer(day)
        VSpace(12)
    }
}

/** Fiche Wikipédia d'une commémoration, chargée en arrière-plan. */
@Composable
fun rememberProfile(c: Commemoration?, knownTitle: String?): SaintProfile? {
    val lang = Loc.language
    val profile by produceState<SaintProfile?>(null, c, knownTitle, lang) {
        value = if (c == null && knownTitle == null) null else Wikipedia.profile(c, knownTitle, lang)
    }
    return profile
}

@Composable
fun rememberBitmap(url: String?, maxPixel: Int = 500): Bitmap? {
    val bmp by produceState<Bitmap?>(null, url) { value = Images.bitmap(url, maxPixel) }
    return bmp
}

/** Nom dans la langue de l'app : nos noms pour fr/en, Wikipédia pour les autres langues. */
fun localizedName(c: Commemoration, profile: SaintProfile?, short: Boolean = true): String {
    val lang = Loc.language
    if (lang != "fr" && lang != "en" && profile != null && profile.language == lang) return profile.name
    return if (short) c.shortName else c.displayName
}

// ---------------------------------------------------------------------------

@Composable
private fun HeroHeader(day: LiturgicalDay) {
    val p = pal
    val needsLocal = day.titleIsSaint && Loc.language != "fr" && Loc.language != "en"
    val profile = rememberProfile(if (needsLocal) day.primarySaint else null, if (needsLocal) day.primarySaintWikipediaTitle else null)
    val title = if (needsLocal && profile != null && profile.language == Loc.language) profile.name else day.title

    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(DateText.long(day.civil), color = p.inkSoft, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        DateText.churchLabel(day)?.let { SoftText(it, 12) }
        if (day.rank.marks.isNotEmpty()) Text(day.rank.marks, color = day.rank.color(p), fontSize = 14.sp)
        Text(
            title,
            fontFamily = Serif,
            fontWeight = FontWeight.SemiBold,
            fontSize = if (day.isGreatFeast) 24.sp else 21.sp,
            color = if (day.rank >= FeastRank.SUNDAY) day.rank.color(p) else p.ink,
            textAlign = TextAlign.Center,
        )
        day.subtitles.forEach {
            Text(it, fontFamily = Serif, fontStyle = FontStyle.Italic, fontSize = 15.sp, color = p.inkSoft, textAlign = TextAlign.Center)
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FastBadge(day.fasting.level)
            if (day.fasting.season != FastSeason.ORDINARY && day.fasting.season != FastSeason.WEDNESDAY_FRIDAY) {
                SoftText(day.fasting.season.title, 12)
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Galerie des icônes : côte à côte (≤ 3) ou bandeau défilant (> 3)
// ---------------------------------------------------------------------------

data class GalleryItem(val commemoration: Commemoration, val knownTitle: String?)

@Composable
private fun SaintGallery(day: LiturgicalDay, navigate: Navigate) {
    val items = remember(day) {
        buildList {
            val feast = day.feastWikipediaTitle
            if (feast != null && feast != day.primarySaintWikipediaTitle) {
                add(GalleryItem(Commemoration(day.title, day.title), feast))
            }
            day.saints.forEach { add(GalleryItem(it, day.wikipediaTitle(it))) }
        }
    }
    if (items.isEmpty()) return
    if (items.size <= 3) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally)) {
            items.forEach { GalleryCard(it, navigate) }
        }
    } else {
        AutoScrollRow(items, navigate)
    }
}

/** Bandeau qui défile lentement de droite à gauche ; les icônes restent cliquables. */
@Composable
private fun AutoScrollRow(entries: List<GalleryItem>, navigate: Navigate) {
    val listState = rememberLazyListState()
    val step = with(LocalDensity.current) { 48.dp.toPx() }
    LaunchedEffect(entries) {
        while (isActive) {
            try {
                listState.animateScrollBy(step, tween(durationMillis = 2000, easing = LinearEasing))
            } catch (e: CancellationException) {
                if (!isActive) throw e
                delay(2500) // l'utilisateur fait défiler : on reprend un peu après
            }
        }
    }
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        LazyRow(state = listState, horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
            items(count = 100_000) { i -> GalleryCard(entries[i % entries.size], navigate) }
        }
    }
}

@Composable
private fun GalleryCard(item: GalleryItem, navigate: Navigate) {
    val profile = rememberProfile(item.commemoration, item.knownTitle)
    val bmp = rememberBitmap(profile?.imageUrl, 400)
    Column(
        Modifier
            .width(IconSizes.galleryW + 6.dp)
            .clickable { navigate(Route.Saint(item.commemoration, item.knownTitle)) },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        IconFrame(bmp, item.commemoration.initial, IconSizes.galleryW, IconSizes.galleryH, 10.dp)
        Text(
            localizedName(item.commemoration, profile),
            fontFamily = Serif, fontSize = 11.sp, fontWeight = FontWeight.Medium, color = pal.ink,
            textAlign = TextAlign.Center, maxLines = 2, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 6.dp).height(32.dp),
        )
    }
}

// ---------------------------------------------------------------------------

@Composable
private fun FastingCard(day: LiturgicalDay) {
    val p = pal
    val f = day.fasting
    var open by remember { mutableStateOf(false) }
    SectionCard(Loc.t("section.fasting")) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(f.level.title, fontFamily = Serif, fontWeight = FontWeight.SemiBold, fontSize = 19.sp, color = f.level.color(p), modifier = Modifier.weight(1f))
            SoftText(f.season.title, 12, TextAlign.End)
        }
        f.note?.let { Text("ⓘ $it", color = p.burgundy, fontSize = 14.sp, fontWeight = FontWeight.Medium) }
        Text(f.level.explanation, color = p.ink, fontSize = 14.sp)
        FoodChips(f.level)
        if (f.level.isFasting) SoftText(Loc.t("shellfish.note"), 11)
        val tips = f.season.recommendations
        if (tips.isNotEmpty()) {
            Text(
                (if (open) "▾ " else "▸ ") + Loc.t("rec.title", mapOf("s" to f.season.title)),
                color = p.burgundy, fontWeight = FontWeight.SemiBold, fontSize = 14.sp,
                modifier = Modifier.clickable { open = !open }.padding(vertical = 4.dp),
            )
            AnimatedVisibility(open) { TipsList(tips) }
        }
    }
}

@Composable
private fun SaintsCard(day: LiturgicalDay, navigate: Navigate) {
    val p = pal
    SectionCard(Loc.t("section.saints")) {
        if (day.commemorations.isEmpty()) SoftText(Loc.t("saints.none"), 14)
        day.commemorations.forEachIndexed { index, c ->
            if (c.festal) {
                Text(c.displayName, fontFamily = Serif, fontStyle = FontStyle.Italic, color = p.gold, fontSize = 14.sp, modifier = Modifier.padding(vertical = 6.dp))
            } else {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { navigate(Route.Saint(c, day.wikipediaTitle(c))) }
                        .padding(vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("☩", color = if (c == day.primarySaint) p.burgundy else p.gold, modifier = Modifier.width(22.dp))
                    Text(
                        c.displayName, fontFamily = Serif, fontSize = 15.sp, color = p.ink,
                        fontWeight = if (c == day.primarySaint) FontWeight.SemiBold else FontWeight.Normal,
                        modifier = Modifier.weight(1f),
                    )
                    Text("›", color = p.inkSoft, fontSize = 18.sp)
                }
            }
            if (index < day.commemorations.size - 1) HorizontalDivider(color = p.hairline)
        }
    }
}

@Composable
private fun StoriesCard(stories: List<SaintStory>, load: LoadState, navigate: Navigate, retry: () -> Unit) {
    val p = pal
    SectionCard(Loc.t("section.lives")) {
        when (load) {
            LoadState.LOADING -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CircularProgressIndicator(Modifier.width(18.dp).height(18.dp), strokeWidth = 2.dp, color = p.burgundy)
                SoftText(Loc.t("lives.loading"), 14)
            }
            LoadState.FAILED -> {
                SoftText(Loc.t("lives.failed"), 14)
                TextButton(onClick = retry) { Text(Loc.t("lives.retry"), color = p.burgundy) }
            }
            LoadState.LOADED -> {
                if (stories.isEmpty()) SoftText(Loc.t("lives.empty"), 14)
                stories.forEach { story ->
                    Column(
                        Modifier
                            .fillMaxWidth()
                            .clickable { navigate(Route.Story(story)) }
                            .padding(vertical = 8.dp),
                    ) {
                        Text(story.title, fontFamily = Serif, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, color = p.ink)
                        Text(story.text, fontSize = 13.sp, color = p.inkSoft, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    }
                    HorizontalDivider(color = p.hairline)
                }
                if (stories.isNotEmpty()) SoftText(Loc.t("lives.note"), 11)
            }
        }
    }
}

@Composable
private fun Footer(day: LiturgicalDay) {
    val pd = day.paschaDistance
    val pascha = DateText.dayMonth(Paschalion.pascha(day.civil.year))
    val paschaText = when {
        pd == 0 -> Loc.t("pascha.today")
        pd < 0 -> Loc.t("pascha.future", mapOf("d" to pascha, "n" to (-pd).toString()))
        else -> Loc.t("pascha.past", mapOf("d" to pascha, "n" to (pd + 1).toString()))
    }
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        if (day.tone > 0) SoftText(Loc.t("tone", mapOf("n" to day.tone.toString())), 12)
        SoftText(paschaText, 12)
        SoftText(day.calendar.label, 12)
    }
}
