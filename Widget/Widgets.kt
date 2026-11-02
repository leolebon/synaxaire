package org.synaxaire.calendrier.widget

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.action.Action
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontFamily
import androidx.glance.text.FontStyle
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withTimeoutOrNull
import org.synaxaire.calendrier.data.AppData
import org.synaxaire.calendrier.data.Images
import org.synaxaire.calendrier.data.Settings
import org.synaxaire.calendrier.data.Wikipedia
import org.synaxaire.calendrier.engine.CivilDate
import org.synaxaire.calendrier.engine.DateText
import org.synaxaire.calendrier.engine.FastLevel
import org.synaxaire.calendrier.engine.FastSeason
import org.synaxaire.calendrier.engine.FeastRank
import org.synaxaire.calendrier.engine.Loc
import org.synaxaire.calendrier.ui.MainActivity

// ---------------------------------------------------------------------------
// Données préparées pour les widgets
// ---------------------------------------------------------------------------

private val PARCHMENT = Color(0xFFF7F1E3)
private val CARD = Color(0xFFFFFBF2)
private val BURGUNDY = Color(0xFF7A1F2B)
private val GOLD = Color(0xFFA8801E)
private val INK = Color(0xFF2B1D16)
private val INK_SOFT = Color(0xFF6E5B4E)

private fun fastColor(level: FastLevel): Color = when (level) {
    FastLevel.NO_FAST -> Color(0xFF4F7A4A)
    FastLevel.FAST_FREE -> Color(0xFFB8862B)
    FastLevel.DAIRY -> Color(0xFFC49A2C)
    FastLevel.FISH -> Color(0xFF2F6690)
    FastLevel.WINE_OIL -> Color(0xFF8E2C48)
    FastLevel.STRICT -> Color(0xFF4B3B6B)
}

data class WidgetSaint(val name: String, val initial: String, val image: Bitmap?)

data class WidgetDay(
    val weekday: String,
    val dayNumber: String,
    val month: String,
    val dateLine: String,
    val menologion: String?,
    val title: String,
    val titleColor: Color,
    val subtitle: String?,
    val saints: List<String>,
    val fastLevel: FastLevel,
    val fastTitle: String,
    val fastShort: String,
    val season: String?,
    val note: String?,
    val initial: String,
    val image: Bitmap?,
    val gallery: List<WidgetSaint>,
)

object WidgetData {
    suspend fun load(context: Context, heroImage: Boolean, galleryCount: Int): WidgetDay {
        AppData.init(context)
        val settings = Settings(context)
        Loc.language = settings.language
        val lang = Loc.language
        val today = CivilDate.today()
        val day = AppData.day(today, settings.calendar)

        var image: Bitmap? = null
        var title = day.title
        if (heroImage) {
            val known = day.feastWikipediaTitle ?: day.primarySaintWikipediaTitle
            val profile = withTimeoutOrNull(15_000) {
                Wikipedia.profile(if (day.feastWikipediaTitle != null) null else day.primarySaint, known, lang)
                    ?: day.primarySaint?.let { Wikipedia.profile(it, null, lang) }
            }
            image = withTimeoutOrNull(10_000) { Images.bitmap(profile?.imageUrl, 300) }
            if (day.titleIsSaint && lang != "fr" && lang != "en" && profile != null && profile.language == lang) title = profile.name
        }

        val gallery: List<WidgetSaint> = if (galleryCount <= 0) emptyList() else coroutineScope {
            day.saints.take(galleryCount).map { c ->
                async {
                    val profile = withTimeoutOrNull(15_000) { Wikipedia.profile(c, day.wikipediaTitle(c), lang) }
                    val bmp = withTimeoutOrNull(10_000) { Images.bitmap(profile?.imageUrl, 200) }
                    val name = if (lang != "fr" && lang != "en" && profile != null && profile.language == lang) profile.name else c.shortName
                    WidgetSaint(name, c.initial, bmp)
                }
            }.awaitAll()
        }

        val rankColor = when (day.rank) {
            FeastRank.PASCHA, FeastRank.GREAT, FeastRank.SUNDAY -> BURGUNDY
            FeastRank.MAJOR -> GOLD
            FeastRank.HOLY_WEEK -> Color(0xFF3B2A4D)
            else -> INK
        }
        val season = day.fasting.season.takeIf { it != FastSeason.ORDINARY && it != FastSeason.WEDNESDAY_FRIDAY }?.title
        return WidgetDay(
            weekday = DateText.weekday(today.weekday).uppercase(),
            dayNumber = today.day.toString(),
            month = DateText.monthGenitive(today.month),
            dateLine = DateText.weekday(today.weekday).replaceFirstChar { it.uppercase() } + " " + DateText.dayMonth(today),
            menologion = DateText.churchLabel(day),
            title = title,
            titleColor = rankColor,
            subtitle = day.subtitles.firstOrNull(),
            saints = day.saints.map { it.shortName }.filter { it != day.title }.take(4),
            fastLevel = day.fasting.level,
            fastTitle = day.fasting.level.title,
            fastShort = day.fasting.level.shortTitle,
            season = season,
            note = day.fasting.note,
            initial = day.primarySaint?.initial ?: "☦",
            image = image,
            gallery = gallery,
        )
    }
}

object WidgetUpdater {
    suspend fun updateAll(context: Context) {
        SynaxaireWidget().updateAll(context)
        SaintsWidget().updateAll(context)
    }
}

// ---------------------------------------------------------------------------
// Éléments communs
// ---------------------------------------------------------------------------

private fun style(color: Color, size: Int, weight: FontWeight = FontWeight.Normal, serif: Boolean = false, italic: Boolean = false, center: Boolean = false) =
    TextStyle(
        color = ColorProvider(color),
        fontSize = size.sp,
        fontWeight = weight,
        fontStyle = if (italic) FontStyle.Italic else FontStyle.Normal,
        fontFamily = if (serif) FontFamily.Serif else null,
        textAlign = if (center) TextAlign.Center else TextAlign.Start,
    )

@Composable
private fun Icon(image: Bitmap?, initial: String, w: Int, h: Int) {
    if (image != null) {
        Image(
            provider = ImageProvider(image),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = GlanceModifier.size(w.dp, h.dp).cornerRadius(8.dp),
        )
    } else {
        Box(
            GlanceModifier.size(w.dp, h.dp).cornerRadius(8.dp).background(BURGUNDY),
            contentAlignment = Alignment.Center,
        ) {
            Text(initial, style = style(Color(0xFFD4AF37), (w * 0.4f).toInt(), FontWeight.Bold, serif = true))
        }
    }
}

@Composable
private fun FastPill(d: WidgetDay, compact: Boolean) {
    val c = fastColor(d.fastLevel)
    Box(GlanceModifier.cornerRadius(10.dp).background(c.copy(alpha = 0.15f)).padding(horizontal = 6.dp, vertical = 2.dp)) {
        Text(if (compact) d.fastShort else d.fastTitle, style = style(c, if (compact) 11 else 13, FontWeight.Bold), maxLines = 1)
    }
}

/** Ouvre l'application quand on touche le widget. */
private fun openApp(context: Context): Action =
    actionStartActivity(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))

// ---------------------------------------------------------------------------
// Widget « Synaxaire » : petit, moyen, grand (s'adapte à la taille)
// ---------------------------------------------------------------------------

class SynaxaireWidget : GlanceAppWidget() {
    companion object {
        val SMALL = DpSize(110.dp, 110.dp)
        val MEDIUM = DpSize(250.dp, 110.dp)
        val LARGE = DpSize(250.dp, 250.dp)
    }

    override val sizeMode = SizeMode.Responsive(setOf(SMALL, MEDIUM, LARGE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = WidgetData.load(context, heroImage = true, galleryCount = 0)
        val open = openApp(context)
        provideContent { SynaxaireContent(data, open) }
    }
}

@Composable
private fun SynaxaireContent(d: WidgetDay, open: Action) {
    val size = LocalSize.current
    Box(
        GlanceModifier.fillMaxSize().cornerRadius(18.dp).background(PARCHMENT).clickable(open).padding(12.dp),
    ) {
        when {
            size.height >= 240.dp && size.width >= 240.dp -> LargeContent(d)
            size.width >= 240.dp -> MediumContent(d)
            else -> SmallContent(d)
        }
    }
}

@Composable
private fun SmallContent(d: WidgetDay) {
    Column(GlanceModifier.fillMaxSize()) {
        Row(GlanceModifier.fillMaxWidth()) {
            Column(GlanceModifier.defaultWeight()) {
                Text(d.weekday, style = style(BURGUNDY, 9, FontWeight.Bold), maxLines = 1)
                Text(d.dayNumber, style = style(INK, 26, FontWeight.Bold, serif = true))
                Text(d.month, style = style(INK_SOFT, 11, serif = true), maxLines = 1)
            }
            Icon(d.image, d.initial, 42, 56)
        }
        Spacer(GlanceModifier.defaultWeight())
        Text(d.title, style = style(d.titleColor, 12, FontWeight.Medium, serif = true), maxLines = 3)
        Spacer(GlanceModifier.height(4.dp))
        FastPill(d, compact = true)
    }
}

@Composable
private fun MediumContent(d: WidgetDay) {
    Row(GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
        Icon(d.image, d.initial, 78, 104)
        Spacer(GlanceModifier.width(12.dp))
        Column(GlanceModifier.defaultWeight()) {
            Text(d.dateLine, style = style(BURGUNDY, 12, FontWeight.Bold), maxLines = 1)
            Text(d.title, style = style(d.titleColor, 15, FontWeight.Medium, serif = true), maxLines = 3)
            (d.subtitle ?: d.saints.firstOrNull())?.let {
                Text(it, style = style(INK_SOFT, 11, italic = true, serif = true), maxLines = 1)
            }
            Spacer(GlanceModifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                FastPill(d, compact = true)
                d.season?.let {
                    Spacer(GlanceModifier.width(6.dp))
                    Text(it, style = style(INK_SOFT, 10), maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun LargeContent(d: WidgetDay) {
    Column(GlanceModifier.fillMaxSize()) {
        Row(GlanceModifier.fillMaxWidth()) {
            Icon(d.image, d.initial, 96, 128)
            Spacer(GlanceModifier.width(12.dp))
            Column(GlanceModifier.defaultWeight()) {
                Text(d.weekday, style = style(BURGUNDY, 10, FontWeight.Bold), maxLines = 1)
                Text(d.dayNumber + " " + d.month, style = style(INK, 22, FontWeight.Bold, serif = true), maxLines = 1)
                d.menologion?.let { Text(it, style = style(INK_SOFT, 10), maxLines = 1) }
                Text(d.title, style = style(d.titleColor, 15, FontWeight.Medium, serif = true), maxLines = 4)
                d.subtitle?.let { Text(it, style = style(INK_SOFT, 11, italic = true, serif = true), maxLines = 2) }
            }
        }
        if (d.saints.isNotEmpty()) {
            Spacer(GlanceModifier.height(8.dp))
            Text(Loc.t("widget.alsoCelebrated"), style = style(GOLD, 9, FontWeight.Bold))
            d.saints.forEach { Text("☩ $it", style = style(INK, 12, serif = true), maxLines = 1) }
        }
        Spacer(GlanceModifier.defaultWeight())
        Column(GlanceModifier.fillMaxWidth().cornerRadius(12.dp).background(CARD).padding(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                FastPill(d, compact = false)
                d.season?.let {
                    Spacer(GlanceModifier.width(8.dp))
                    Text(it, style = style(INK_SOFT, 10), maxLines = 1)
                }
            }
            d.note?.let { Text(it, style = style(BURGUNDY, 11, FontWeight.Medium), maxLines = 2) }
            Text(d.fastLevel.explanation, style = style(INK, 11), maxLines = 3)
        }
    }
}

class SynaxaireWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = SynaxaireWidget()
}

// ---------------------------------------------------------------------------
// Widget « Saints du jour » : mosaïque d'icônes
// ---------------------------------------------------------------------------

class SaintsWidget : GlanceAppWidget() {
    companion object {
        val MEDIUM = DpSize(250.dp, 110.dp)
        val LARGE = DpSize(250.dp, 250.dp)
    }

    override val sizeMode = SizeMode.Responsive(setOf(MEDIUM, LARGE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = WidgetData.load(context, heroImage = false, galleryCount = 6)
        val open = openApp(context)
        provideContent { SaintsContent(data, open) }
    }
}

@Composable
private fun SaintsContent(d: WidgetDay, open: Action) {
    val large = LocalSize.current.height >= 240.dp
    val tiles = d.gallery.take(if (large) 6 else 3)
    Column(GlanceModifier.fillMaxSize().cornerRadius(18.dp).background(PARCHMENT).clickable(open).padding(12.dp)) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(d.dateLine, style = style(BURGUNDY, 12, FontWeight.Bold), maxLines = 1, modifier = GlanceModifier.defaultWeight())
            FastPill(d, compact = true)
        }
        if (large) {
            Text(d.title, style = style(d.titleColor, 14, FontWeight.Medium, serif = true), maxLines = 2)
        }
        Spacer(GlanceModifier.height(6.dp))
        tiles.chunked(3).forEach { row ->
            Row(GlanceModifier.fillMaxWidth()) {
                row.forEach { s ->
                    Column(GlanceModifier.defaultWeight(), horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(s.image, s.initial, 60, 80)
                        Text(s.name, style = style(INK, 9, FontWeight.Medium, serif = true, center = true), maxLines = 2)
                    }
                }
                repeat(3 - row.size) { Spacer(GlanceModifier.defaultWeight()) }
            }
            Spacer(GlanceModifier.height(6.dp))
        }
    }
}

class SaintsWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = SaintsWidget()
}
