package org.synaxaire.calendrier.data

import android.content.Context
import android.content.SharedPreferences
import org.synaxaire.calendrier.engine.ChurchCalendar
import org.synaxaire.calendrier.engine.CivilDate
import org.synaxaire.calendrier.engine.LiturgicalDay
import org.synaxaire.calendrier.engine.Loc
import org.synaxaire.calendrier.engine.Synaxarion
import java.io.File

/** Données partagées par l'application et les widgets. */
object AppData {
    @Volatile private var synaxarionInstance: Synaxarion? = null
    lateinit var cacheDir: File
        private set

    val synaxarion: Synaxarion get() = synaxarionInstance!!

    @Synchronized
    fun init(context: Context) {
        val app = context.applicationContext
        if (!::cacheDir.isInitialized) {
            cacheDir = File(app.cacheDir, "synaxaire").apply { mkdirs() }
        }
        if (!Loc.isLoaded) {
            Loc.load(app.assets.open("i18n.json").bufferedReader().use { it.readText() })
        }
        if (synaxarionInstance == null) {
            synaxarionInstance = Synaxarion(app.assets.open("synaxaire.json").bufferedReader().use { it.readText() })
        }
        Loc.language = Settings(app).language
    }

    fun day(date: CivilDate, calendar: ChurchCalendar) = LiturgicalDay(date, calendar, synaxarion)
}

/** Réglages enregistrés (partagés avec les widgets). */
class Settings(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences("synaxaire", Context.MODE_PRIVATE)

    var language: String
        get() = prefs.getString("language", null) ?: Loc.deviceLanguage
        set(v) = prefs.edit().putString("language", v).apply()

    var calendar: ChurchCalendar
        get() = ChurchCalendar.fromCode(prefs.getString("calendar", "new"))
        set(v) = prefs.edit().putString("calendar", v.code).apply()

    var autoTranslate: Boolean
        get() = prefs.getBoolean("autoTranslate", true)
        set(v) = prefs.edit().putBoolean("autoTranslate", v).apply()
}
