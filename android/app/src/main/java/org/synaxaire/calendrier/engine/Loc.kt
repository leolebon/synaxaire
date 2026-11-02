package org.synaxaire.calendrier.engine

import java.util.Locale

/** Langue de l'application et traductions (fichier i18n.json, partagé avec l'iPhone). */
object Loc {
    data class Language(val code: String, val name: String, val rtl: Boolean)

    @Volatile var language: String = "fr"
    const val DEFAULT = "fr"

    private var table: Map<String, Map<String, String>> = emptyMap()
    var languages: List<Language> = listOf(Language("fr", "Français", false))
        private set

    val isLoaded: Boolean get() = table.isNotEmpty()

    fun load(jsonText: String) {
        val root = Json.parse(jsonText).asMap()
        languages = root["languages"].asList().map { l ->
            val m = l.asMap()
            Language(m["code"] as String, m["name"] as String, (m["rtl"] as? Boolean) ?: false)
        }
        table = root["strings"].asMap().mapValues { (_, v) ->
            v.asMap().mapValues { (_, s) -> s as String }
        }
    }

    val isRtl: Boolean get() = languages.firstOrNull { it.code == language }?.rtl ?: false

    /** Langue du téléphone si elle est prise en charge, sinon le français. */
    val deviceLanguage: String
        get() {
            val code = Locale.getDefault().language.lowercase()
            return if (languages.any { it.code == code }) code else DEFAULT
        }

    fun t(key: String, args: Map<String, String> = emptyMap()): String {
        val entry = table[key]
        var s = entry?.get(language) ?: entry?.get("en") ?: entry?.get("fr") ?: key
        for ((k, v) in args) s = s.replace("{$k}", v)
        return s
    }

    fun has(key: String): Boolean = table.containsKey(key)
}

/** Dates localisées. */
object DateText {
    fun monthGenitive(m: Int) = Loc.t("month.$m")
    fun monthName(m: Int) = Loc.t("monthN.$m")
    fun weekday(wd: Int) = Loc.t("weekday.$wd")
    fun weekdayShort(wd: Int) = Loc.t("wd.short.$wd")

    private fun dayNumber(d: Int) = if (d == 1) Loc.t("date.first") else d.toString()

    fun long(d: CivilDate): String {
        val w = weekday(d.weekday).replaceFirstChar { it.uppercase() }
        return Loc.t("date.long", mapOf("w" to w, "d" to dayNumber(d.day), "m" to monthGenitive(d.month), "y" to d.year.toString()))
    }

    fun dayMonth(d: CivilDate) = Loc.t("date.dayMonth", mapOf("d" to dayNumber(d.day), "m" to monthGenitive(d.month)))
    fun dayMonthYear(d: CivilDate) = dayMonth(d) + " " + d.year
    fun monthYear(year: Int, month: Int) = monthName(month) + " " + year

    fun churchLabel(day: LiturgicalDay): String? {
        if (day.calendar != ChurchCalendar.OLD) return null
        return Loc.t("day.menologion", mapOf("d" to dayMonth(day.church) + " " + Loc.t("cal.julianSuffix")))
    }
}
