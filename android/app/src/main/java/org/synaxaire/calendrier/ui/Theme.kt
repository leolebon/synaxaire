package org.synaxaire.calendrier.ui

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.synaxaire.calendrier.engine.FastLevel
import org.synaxaire.calendrier.engine.FeastRank
import org.synaxaire.calendrier.engine.FoodCategory
import org.synaxaire.calendrier.engine.Loc

// ---------------------------------------------------------------------------
// Couleurs (bordeaux, or, parchemin), claires et sombres
// ---------------------------------------------------------------------------

data class Palette(
    val burgundy: Color,
    val gold: Color,
    val parchment: Color,
    val card: Color,
    val ink: Color,
    val inkSoft: Color,
    val hairline: Color,
    val dark: Boolean,
)

val LightPalette = Palette(
    burgundy = Color(0xFF7A1F2B), gold = Color(0xFFA8801E), parchment = Color(0xFFF7F1E3), card = Color(0xFFFFFBF2),
    ink = Color(0xFF2B1D16), inkSoft = Color(0xFF6E5B4E), hairline = Color(0xFFE4D6B8), dark = false,
)
val DarkPalette = Palette(
    burgundy = Color(0xFFD9707C), gold = Color(0xFFE2C064), parchment = Color(0xFF16110F), card = Color(0xFF241C19),
    ink = Color(0xFFF2E8D8), inkSoft = Color(0xFFBFAE9B), hairline = Color(0xFF3D312A), dark = true,
)
val GoldBright = Color(0xFFD4AF37)

val LocalPalette = staticCompositionLocalOf { LightPalette }

val pal: Palette
    @Composable get() = LocalPalette.current

@Composable
fun SynaxaireTheme(content: @Composable () -> Unit) {
    val p = if (isSystemInDarkTheme()) DarkPalette else LightPalette
    val scheme = if (p.dark) {
        darkColorScheme(primary = p.burgundy, secondary = p.gold, background = p.parchment, surface = p.card, onBackground = p.ink, onSurface = p.ink)
    } else {
        lightColorScheme(primary = p.burgundy, secondary = p.gold, background = p.parchment, surface = p.card, onBackground = p.ink, onSurface = p.ink)
    }
    CompositionLocalProvider(LocalPalette provides p) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}

fun FastLevel.color(p: Palette): Color = when (this) {
    FastLevel.NO_FAST -> if (p.dark) Color(0xFF8CC084) else Color(0xFF4F7A4A)
    FastLevel.FAST_FREE -> if (p.dark) Color(0xFFE8C063) else Color(0xFFB8862B)
    FastLevel.DAIRY -> if (p.dark) Color(0xFFF0CF6A) else Color(0xFFC49A2C)
    FastLevel.FISH -> if (p.dark) Color(0xFF7FB5E0) else Color(0xFF2F6690)
    FastLevel.WINE_OIL -> if (p.dark) Color(0xFFE07A98) else Color(0xFF8E2C48)
    FastLevel.STRICT -> if (p.dark) Color(0xFFA996D6) else Color(0xFF4B3B6B)
}

val FastLevel.symbol: String
    get() = when (this) {
        FastLevel.NO_FAST -> "🍽"
        FastLevel.FAST_FREE -> "🎉"
        FastLevel.DAIRY -> "🧀"
        FastLevel.FISH -> "🐟"
        FastLevel.WINE_OIL -> "🍷"
        FastLevel.STRICT -> "🌿"
    }

fun FeastRank.color(p: Palette): Color = when (this) {
    FeastRank.PASCHA, FeastRank.GREAT -> p.burgundy
    FeastRank.HOLY_WEEK -> if (p.dark) Color(0xFFB7A3D8) else Color(0xFF3B2A4D)
    FeastRank.MAJOR -> p.gold
    FeastRank.SUNDAY -> p.burgundy.copy(alpha = 0.85f)
    FeastRank.SAINT, FeastRank.ORDINARY -> p.inkSoft
}

val FeastRank.marks: String
    get() = when (this) {
        FeastRank.PASCHA -> "☩☩☩"
        FeastRank.GREAT -> "☩☩"
        FeastRank.MAJOR, FeastRank.HOLY_WEEK -> "☩"
        else -> ""
    }

val Serif = FontFamily.Serif

/** Tailles standard des icônes (portrait 3:4). */
object IconSizes {
    val galleryW = 96.dp
    val galleryH = 128.dp
    val detailW = 210.dp
    val detailH = 280.dp
}

// ---------------------------------------------------------------------------
// Composants
// ---------------------------------------------------------------------------

@Composable
fun SectionCard(title: String, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val p = pal
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(p.card)
            .border(1.dp, p.hairline, RoundedCornerShape(18.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(title.uppercase(), color = p.gold, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp)
        content()
    }
}

@Composable
fun FastBadge(level: FastLevel, compact: Boolean = false) {
    val c = level.color(pal)
    Row(
        Modifier
            .clip(RoundedCornerShape(50))
            .background(c.copy(alpha = 0.14f))
            .padding(horizontal = if (compact) 6.dp else 10.dp, vertical = if (compact) 3.dp else 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(level.symbol + " ", fontSize = if (compact) 11.sp else 13.sp)
        Text(
            if (compact) level.shortTitle else level.title,
            color = c, fontSize = if (compact) 11.sp else 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
        )
    }
}

@Composable
fun FoodChips(level: FastLevel) {
    val p = pal
    val cats = listOf(FoodCategory.MEAT, FoodCategory.DAIRY, FoodCategory.EGGS, FoodCategory.FISH, FoodCategory.OIL, FoodCategory.WINE)
    Row(Modifier.fillMaxWidth()) {
        cats.forEach { cat ->
            val ok = cat in level.allowed
            Column(
                Modifier
                    .weight(1f)
                    .semantics { contentDescription = cat.label + " : " + Loc.t(if (ok) "food.allowed" else "food.forbidden") },
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(cat.emoji, fontSize = 18.sp, modifier = Modifier.alpha(if (ok) 1f else 0.3f))
                Text(
                    cat.label,
                    fontSize = 9.sp,
                    color = if (ok) p.ink else p.inkSoft.copy(alpha = 0.6f),
                    textDecoration = if (ok) null else TextDecoration.LineThrough,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/** Cadre d'icône à taille fixe : l'image est recadrée et ne déborde jamais. */
@Composable
fun IconFrame(bitmap: Bitmap?, initial: String, width: Dp, height: Dp, corner: Dp = 12.dp) {
    val shape = RoundedCornerShape(corner)
    Box(
        Modifier
            .size(width, height)
            .clip(shape)
            .border(2.dp, Brush.linearGradient(listOf(GoldBright, pal.gold.copy(alpha = 0.6f), GoldBright)), shape),
    ) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                alignment = Alignment.TopCenter,
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            IconPlaceholder(initial, width)
        }
    }
}

@Composable
fun IconPlaceholder(initial: String, width: Dp) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF5C1621), Color(0xFF2E0B10)))),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .offset(y = -(width * 0.08f))
                .size(width * 0.62f)
                .clip(CircleShape)
                .background(Brush.radialGradient(listOf(GoldBright.copy(alpha = 0.9f), GoldBright.copy(alpha = 0.25f)))),
            contentAlignment = Alignment.Center,
        ) {
            Text(initial, fontFamily = Serif, fontWeight = FontWeight.Bold, color = Color(0xFF3A0E15), fontSize = (width.value * 0.3f).sp)
        }
    }
}

@Composable
fun TipsList(tips: List<String>) {
    val p = pal
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        tips.forEach { tip ->
            Row {
                Text("☩", color = p.gold, modifier = Modifier.width(18.dp))
                Text(tip, color = p.ink, fontSize = 14.sp)
            }
        }
    }
}

@Composable
fun SoftText(text: String, size: Int = 13, align: TextAlign? = null, modifier: Modifier = Modifier) {
    Text(text, color = pal.inkSoft, fontSize = size.sp, textAlign = align, modifier = modifier)
}

@Composable
fun VSpace(h: Int) = Spacer(Modifier.height(h.dp))
