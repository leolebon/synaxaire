package org.synaxaire.calendrier.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import org.synaxaire.calendrier.data.AppData
import org.synaxaire.calendrier.data.SaintStory
import org.synaxaire.calendrier.data.Settings
import org.synaxaire.calendrier.engine.ChurchCalendar
import org.synaxaire.calendrier.engine.CivilDate
import org.synaxaire.calendrier.engine.Commemoration
import org.synaxaire.calendrier.engine.DateText
import org.synaxaire.calendrier.engine.Loc

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppData.init(this)
        setContent { SynaxaireApp() }
    }
}

/** Écrans empilés au-dessus des onglets. */
sealed interface Route {
    data class Day(val date: CivilDate) : Route
    data class Saint(val commemoration: Commemoration, val knownTitle: String?) : Route
    data class Story(val story: SaintStory) : Route
}

typealias Navigate = (Route) -> Unit

/** État partagé de l'application (langue, calendrier). */
class AppState(val settings: Settings) {
    var language by mutableStateOf(settings.language)
    var calendar by mutableStateOf(settings.calendar)
    var autoTranslate by mutableStateOf(settings.autoTranslate)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SynaxaireApp() {
    val context = LocalContext.current
    val state = remember { AppState(Settings(context)) }
    var tab by rememberSaveable { mutableIntStateOf(0) }
    val stack = remember { mutableStateListOf<Route>() }
    val navigate: Navigate = { stack.add(it) }

    // La langue est appliquée avant de (re)construire toute l'interface.
    Loc.language = state.language

    key(state.language) {
        CompositionLocalProvider(LocalLayoutDirection provides if (Loc.isRtl) LayoutDirection.Rtl else LayoutDirection.Ltr) {
            SynaxaireTheme {
                val p = pal
                BackHandler(enabled = stack.isNotEmpty()) { stack.removeAt(stack.lastIndex) }
                val top = stack.lastOrNull()
                Scaffold(
                    containerColor = p.parchment,
                    topBar = {
                        if (top != null) {
                            TopAppBar(
                                title = {
                                    Text(
                                        routeTitle(top),
                                        maxLines = 1, overflow = TextOverflow.Ellipsis, fontWeight = FontWeight.SemiBold,
                                    )
                                },
                                navigationIcon = {
                                    IconButton(onClick = { stack.removeAt(stack.lastIndex) }) {
                                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                                    }
                                },
                                colors = TopAppBarDefaults.topAppBarColors(containerColor = p.parchment, titleContentColor = p.ink),
                            )
                        }
                    },
                    bottomBar = {
                        if (top == null) {
                            NavigationBar(containerColor = p.card) {
                                TabItem(Loc.t("tab.today"), Icons.Filled.Home, tab == 0) { tab = 0 }
                                TabItem(Loc.t("tab.calendar"), Icons.Filled.DateRange, tab == 1) { tab = 1 }
                                TabItem(Loc.t("tab.lent"), Icons.AutoMirrored.Filled.List, tab == 2) { tab = 2 }
                                TabItem(Loc.t("tab.settings"), Icons.Filled.Settings, tab == 3) { tab = 3 }
                            }
                        }
                    },
                ) { padding ->
                    Box(
                        Modifier
                            .padding(padding)
                            .fillMaxSize()
                            .background(p.parchment),
                    ) {
                        when (top) {
                            null -> when (tab) {
                                0 -> DayScreen(CivilDate.today(), state, navigate, isToday = true)
                                1 -> CalendarScreen(state, navigate)
                                2 -> LentScreen(state)
                                else -> SettingsScreen(state)
                            }
                            is Route.Day -> DayScreen(top.date, state, navigate)
                            is Route.Saint -> SaintScreen(top.commemoration, top.knownTitle, state)
                            is Route.Story -> StoryScreen(top.story, state)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.TabItem(label: String, icon: ImageVector, selected: Boolean, onClick: () -> Unit) {
    val p = pal
    NavigationBarItem(
        selected = selected,
        onClick = onClick,
        icon = { Icon(icon, contentDescription = null) },
        label = { Text(label, maxLines = 1, overflow = TextOverflow.Ellipsis) },
        colors = NavigationBarItemDefaults.colors(
            selectedIconColor = p.burgundy, selectedTextColor = p.burgundy,
            indicatorColor = p.burgundy.copy(alpha = 0.12f),
            unselectedIconColor = p.inkSoft, unselectedTextColor = p.inkSoft,
        ),
    )
}

private fun routeTitle(route: Route): String = when (route) {
    is Route.Day -> DateText.dayMonth(route.date)
    is Route.Saint -> route.commemoration.shortName
    is Route.Story -> route.story.title
}

/** Utilitaire : calendrier courant. */
val AppState.church: ChurchCalendar get() = calendar
