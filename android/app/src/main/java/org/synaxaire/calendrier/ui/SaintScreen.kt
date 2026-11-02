package org.synaxaire.calendrier.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.synaxaire.calendrier.data.HtmlText
import org.synaxaire.calendrier.data.SaintProfile
import org.synaxaire.calendrier.data.SaintStory
import org.synaxaire.calendrier.data.Translator
import org.synaxaire.calendrier.data.Wikipedia
import org.synaxaire.calendrier.engine.Commemoration
import org.synaxaire.calendrier.engine.Loc

/** Fiche d'un saint : icône, nom et biographie Wikipédia. */
@Composable
fun SaintScreen(c: Commemoration, knownTitle: String?, state: AppState) {
    val p = pal
    val uri = LocalUriHandler.current
    val lang = Loc.language
    // (chargé, fiche) : distingue « en cours » de « introuvable ».
    val result by produceState<Pair<Boolean, SaintProfile?>>(false to null, c, knownTitle, lang) {
        value = true to Wikipedia.profile(c, knownTitle, lang)
    }
    val loaded = result.first
    val profile = result.second
    val bmp = rememberBitmap(profile?.imageUrl, 900)
    val name = localizedName(c, profile, short = false)

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        IconFrame(bmp, c.initial, IconSizes.detailW, IconSizes.detailH, 18.dp)
        Text(name, fontFamily = Serif, fontWeight = FontWeight.SemiBold, fontSize = 23.sp, color = p.burgundy, textAlign = TextAlign.Center)
        if (name != c.en) {
            Text(c.en, fontStyle = FontStyle.Italic, fontSize = 13.sp, color = p.inkSoft, textAlign = TextAlign.Center)
        }
        SectionCard(Loc.t("saint.bio")) {
            when {
                !loaded -> Row(verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = p.burgundy)
                    SoftText(Loc.t("saint.searching"), 14, modifier = Modifier.padding(start = 8.dp))
                }
                profile == null -> SoftText(Loc.t("saint.notFound"), 14)
                else -> {
                    Text(Loc.t("saint.article", mapOf("t" to profile.title)), color = p.gold, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    TranslatableText(profile.extract, profile.language, state)
                    profile.pageUrl?.let { url ->
                        Text(
                            "↗ " + Loc.t("saint.readMore"), color = p.burgundy, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.clickable { uri.openUri(url) }.padding(vertical = 4.dp),
                        )
                    }
                    SoftText(Loc.t("saint.license", mapOf("l" to profile.language)), 11)
                }
            }
        }
    }
}

@Composable
fun StoryScreen(story: SaintStory, state: AppState) {
    val p = pal
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(story.title, fontFamily = Serif, fontWeight = FontWeight.SemiBold, fontSize = 24.sp, color = p.burgundy)
        TranslatableText(story.text, "en", state)
        SoftText(Loc.t("story.source"), 12)
    }
}

/** Texte d'origine et sa traduction automatique (ML Kit, sur l'appareil) dans la langue de l'app. */
@Composable
fun TranslatableText(original: String, sourceLanguage: String, state: AppState) {
    val p = pal
    val target = Loc.language
    val paragraphs = remember(original) { HtmlText.paragraphs(original) }
    val needs = sourceLanguage != target
    var translated by remember(original, target) { mutableStateOf<List<String>?>(null) }
    var failed by remember(original, target) { mutableStateOf(false) }
    var showOriginal by remember { mutableStateOf(false) }

    LaunchedEffect(original, target, state.autoTranslate) {
        if (needs && state.autoTranslate && translated == null) {
            val r = Translator.translate(paragraphs, sourceLanguage, target)
            if (r == null) failed = true else translated = r
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (needs) {
            if (state.autoTranslate) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    val status = when {
                        failed -> "⚠ " + Loc.t("tr.unavailable")
                        translated == null -> Loc.t("tr.translating")
                        showOriginal -> Loc.t("tr.original")
                        else -> Loc.t("tr.auto")
                    }
                    SoftText(status, 12, modifier = Modifier.weight(1f))
                    if (translated != null) {
                        Text(
                            Loc.t(if (showOriginal) "tr.showTranslation" else "tr.showOriginal"),
                            color = p.burgundy, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.clickable { showOriginal = !showOriginal }.padding(4.dp),
                        )
                    }
                }
            } else {
                SoftText(Loc.t("tr.disabled"), 12)
            }
        }
        val shown = if (translated != null && !showOriginal) translated!! else paragraphs
        shown.forEach { para ->
            Text(para, fontFamily = Serif, fontSize = 17.sp, lineHeight = 25.sp, color = p.ink, modifier = Modifier.fillMaxWidth())
        }
    }
}
