package org.synaxaire.calendrier.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import org.synaxaire.calendrier.data.AppData
import org.synaxaire.calendrier.engine.ChurchCalendar
import org.synaxaire.calendrier.engine.Loc
import org.synaxaire.calendrier.widget.WidgetUpdater

@Composable
fun SettingsScreen(state: AppState) {
    val p = pal
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val uri = LocalUriHandler.current
    var cacheCleared by remember { mutableStateOf(false) }

    fun refreshWidgets() {
        scope.launch { WidgetUpdater.updateAll(context) }
    }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(Loc.t("tab.settings"), fontFamily = Serif, fontWeight = FontWeight.Bold, fontSize = 28.sp, color = p.ink)

        SectionCard(Loc.t("settings.language")) {
            Loc.languages.forEach { lang ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable {
                            // La langue est appliquée puis toute l'interface est reconstruite.
                            state.settings.language = lang.code
                            Loc.language = lang.code
                            state.language = lang.code
                            refreshWidgets()
                        },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RadioButton(selected = state.language == lang.code, onClick = null, colors = RadioButtonDefaults.colors(selectedColor = p.burgundy))
                    Text(lang.name, color = p.ink, fontSize = 16.sp, modifier = Modifier.padding(start = 8.dp))
                }
            }
            SoftText(Loc.t("settings.languageFooter"), 12)
        }

        SectionCard(Loc.t("settings.calendar")) {
            ChurchCalendar.values().forEach { cal ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable {
                            state.settings.calendar = cal
                            state.calendar = cal
                            refreshWidgets()
                        },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RadioButton(selected = state.calendar == cal, onClick = null, colors = RadioButtonDefaults.colors(selectedColor = p.burgundy))
                    Column(Modifier.padding(start = 8.dp)) {
                        Text(cal.label, color = p.ink, fontSize = 16.sp)
                        SoftText(cal.explanation, 12)
                    }
                }
            }
            SoftText(Loc.t("settings.calendarFooter"), 12)
        }

        SectionCard(Loc.t("section.lives")) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(Loc.t("settings.translate"), color = p.ink, fontSize = 16.sp, modifier = Modifier.weight(1f))
                Switch(
                    checked = state.autoTranslate,
                    onCheckedChange = { state.autoTranslate = it; state.settings.autoTranslate = it },
                    colors = SwitchDefaults.colors(checkedTrackColor = p.burgundy),
                )
            }
            SoftText(Loc.t("settings.translateFooter"), 12)
        }

        SectionCard(Loc.t("settings.widget")) {
            Text("1. " + Loc.t("settings.widget.android1"), color = p.ink, fontSize = 14.sp)
            Text("2. " + Loc.t("settings.widget.android2"), color = p.ink, fontSize = 14.sp)
        }

        SectionCard(Loc.t("settings.sources")) {
            val sources = listOf(
                "menologion" to "https://github.com/brianglass/orthocal-python",
                "fasting" to "https://www.goarch.org/chapel/calendar",
                "lives" to "https://orthocal.info",
                "icons" to "https://www.wikipedia.org",
            )
            sources.forEach { (id, url) ->
                // Ouvre le lien dans le navigateur par défaut du téléphone.
                Column(
                    Modifier
                        .fillMaxWidth()
                        .clickable { uri.openUri(url) }
                        .padding(vertical = 6.dp),
                ) {
                    Text(Loc.t("source.$id.title"), color = p.ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    SoftText(Loc.t("source.$id.detail"), 12)
                    Text(url.removePrefix("https://") + "  ↗", color = p.burgundy, fontSize = 12.sp)
                }
            }
        }

        Button(
            onClick = {
                AppData.cacheDir.listFiles()?.forEach { it.delete() }
                cacheCleared = true
                refreshWidgets()
            },
            enabled = !cacheCleared,
            colors = ButtonDefaults.buttonColors(containerColor = p.burgundy),
        ) {
            Text(Loc.t(if (cacheCleared) "settings.cacheCleared" else "settings.clearCache"))
        }
        SoftText(Loc.t("settings.footer"), 12)
        VSpace(12)
    }
}
