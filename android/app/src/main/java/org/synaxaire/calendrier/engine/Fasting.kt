package org.synaxaire.calendrier.engine

/** Niveau de jeûne, du plus permissif au plus strict. */
enum class FastLevel(val key: String) {
    NO_FAST("noFast"),
    FAST_FREE("fastFree"),
    DAIRY("dairy"),
    FISH("fish"),
    WINE_OIL("wineOil"),
    STRICT("strict");

    val isFasting: Boolean get() = this >= DAIRY
    val title: String get() = Loc.t("fast.$key.title")
    val shortTitle: String get() = Loc.t("fast.$key.short")
    val explanation: String get() = Loc.t("fast.$key.explain")

    val allowed: Set<FoodCategory>
        get() = when (this) {
            NO_FAST, FAST_FREE -> FoodCategory.values().toSet()
            DAIRY -> setOf(FoodCategory.DAIRY, FoodCategory.EGGS, FoodCategory.FISH, FoodCategory.OIL, FoodCategory.WINE, FoodCategory.SHELLFISH)
            FISH -> setOf(FoodCategory.FISH, FoodCategory.OIL, FoodCategory.WINE, FoodCategory.SHELLFISH)
            WINE_OIL -> setOf(FoodCategory.OIL, FoodCategory.WINE, FoodCategory.SHELLFISH)
            STRICT -> setOf(FoodCategory.SHELLFISH)
        }
}

enum class FoodCategory(val key: String, val emoji: String) {
    MEAT("meat", "🥩"),
    DAIRY("dairy", "🧀"),
    EGGS("eggs", "🥚"),
    FISH("fish", "🐟"),
    OIL("oil", "🫒"),
    WINE("wine", "🍷"),
    SHELLFISH("shellfish", "🦐");

    val label: String get() = Loc.t("food.$key")
}

enum class FastSeason(val key: String) {
    ORDINARY("ordinary"),
    WEDNESDAY_FRIDAY("wednesdayFriday"),
    PASCHAL_SEASON("paschalSeason"),
    CHRISTMASTIDE("christmastide"),
    PUBLICAN_WEEK("publicanWeek"),
    BRIGHT_WEEK("brightWeek"),
    TRINITY_WEEK("trinityWeek"),
    CHEESEFARE("cheesefare"),
    GREAT_LENT("greatLent"),
    HOLY_WEEK("holyWeek"),
    APOSTLES("apostles"),
    DORMITION("dormition"),
    NATIVITY("nativity"),
    STRICT_DAY("strictDay");

    val title: String get() = Loc.t("season.$key")

    val isLent: Boolean
        get() = this == GREAT_LENT || this == HOLY_WEEK || this == APOSTLES || this == DORMITION || this == NATIVITY || this == CHEESEFARE

    val isFastFree: Boolean
        get() = this == PUBLICAN_WEEK || this == BRIGHT_WEEK || this == TRINITY_WEEK || this == CHRISTMASTIDE

    val recommendations: List<String>
        get() {
            if (this == ORDINARY || !Loc.has("rec.$key")) return emptyList()
            return Loc.t("rec.$key").split("\n").filter { it.isNotBlank() }
        }
}

class FastingInfo(val level: FastLevel, val season: FastSeason, val noteKey: String? = null) {
    val note: String? get() = noteKey?.let { Loc.t(it) }
}

/** Règles du jeûne selon l'usage grec (GOARCH), validées contre goarch.org 2025-2035. */
object FastingRules {

    fun fasting(civil: CivilDate, calendar: ChurchCalendar): FastingInfo {
        val c = calendar.churchDate(civil)
        val pd = Paschalion.distance(civil)
        val weekend = civil.isWeekend
        val wedFri = civil.isWednesdayOrFriday
        val md = c.monthDayKey

        // 1. Dodécaémeron.
        if ((c.month == 12 && c.day >= 25) || (c.month == 1 && c.day <= 4)) {
            return FastingInfo(FastLevel.FAST_FREE, FastSeason.CHRISTMASTIDE)
        }
        // 2. Semaines sans jeûne du cycle mobile.
        if (pd in 0..6) return FastingInfo(FastLevel.FAST_FREE, FastSeason.BRIGHT_WEEK)
        if (pd in -69..-64) return FastingInfo(FastLevel.FAST_FREE, FastSeason.PUBLICAN_WEEK)
        if (pd in 50..55) return FastingInfo(FastLevel.FAST_FREE, FastSeason.TRINITY_WEEK)
        // 3. Tyrophagie.
        if (pd in -55..-49) {
            return FastingInfo(FastLevel.DAIRY, FastSeason.CHEESEFARE, if (pd == -49) "note.cheesefareLast" else null)
        }
        // 4. Grand Carême et Semaine sainte.
        if (pd in -48..-1) return greatLent(pd, c, weekend)
        // 5. Jours de jeûne strict fixes.
        if (md == "01-05" || md == "08-29" || md == "09-14") {
            return FastingInfo(if (weekend) FastLevel.WINE_OIL else FastLevel.STRICT, FastSeason.STRICT_DAY)
        }
        // 6. Dormition.
        if (c.month == 8 && c.day <= 14) {
            if (c.day == 6) return FastingInfo(FastLevel.FISH, FastSeason.DORMITION, "note.transfiguration")
            return FastingInfo(if (weekend) FastLevel.WINE_OIL else FastLevel.STRICT, FastSeason.DORMITION)
        }
        // 7. Nativité.
        if ((c.month == 11 && c.day >= 15) || (c.month == 12 && c.day <= 24)) {
            return nativityFast(c, wedFri, weekend)
        }
        // 8. Apôtres.
        if (pd >= 57 && (c.month < 6 || (c.month == 6 && c.day <= 28))) {
            if (md == "06-24") return FastingInfo(FastLevel.FISH, FastSeason.APOSTLES, "note.forerunner")
            if (wedFri) {
                wedFriExceptions[md]?.let { return FastingInfo(it, FastSeason.APOSTLES) }
                return FastingInfo(FastLevel.STRICT, FastSeason.APOSTLES)
            }
            return FastingInfo(FastLevel.FISH, FastSeason.APOSTLES)
        }
        if (!wedFri) {
            return FastingInfo(FastLevel.NO_FAST, if (pd in 7..48) FastSeason.PASCHAL_SEASON else FastSeason.ORDINARY)
        }
        // 9. Mercredi et vendredi du temps pascal.
        if (pd in 7..48) {
            if (pd == 24 || pd == 38) return FastingInfo(FastLevel.FISH, FastSeason.PASCHAL_SEASON)
            if (wedFriExceptions[md] == FastLevel.FISH) return FastingInfo(FastLevel.FISH, FastSeason.PASCHAL_SEASON)
            return FastingInfo(FastLevel.WINE_OIL, FastSeason.PASCHAL_SEASON)
        }
        // 10. Mercredi et vendredi ordinaires.
        wedFriExceptions[md]?.let { lvl ->
            if (lvl == FastLevel.NO_FAST) return FastingInfo(FastLevel.NO_FAST, FastSeason.ORDINARY)
            val note = when (lvl) {
                FastLevel.FISH -> "note.feastFish"
                FastLevel.WINE_OIL -> "note.feastWineOil"
                else -> null
            }
            return FastingInfo(lvl, FastSeason.WEDNESDAY_FRIDAY, note)
        }
        return FastingInfo(FastLevel.STRICT, FastSeason.WEDNESDAY_FRIDAY)
    }

    private fun greatLent(pd: Int, c: CivilDate, weekend: Boolean): FastingInfo {
        val md = c.monthDayKey
        val season = if (pd >= -6) FastSeason.HOLY_WEEK else FastSeason.GREAT_LENT
        if (md == "03-25") {
            if (pd >= -2) return FastingInfo(FastLevel.WINE_OIL, season, "note.annunciation")
            return FastingInfo(FastLevel.FISH, season, "note.annunciationFish")
        }
        when (pd) {
            -1 -> return FastingInfo(FastLevel.STRICT, FastSeason.HOLY_WEEK, "note.holySat")
            -2 -> return FastingInfo(FastLevel.STRICT, FastSeason.HOLY_WEEK, "note.holyFri")
            -3 -> return FastingInfo(FastLevel.WINE_OIL, FastSeason.HOLY_WEEK, "note.holyThu")
            in -6..-4 -> return FastingInfo(FastLevel.STRICT, FastSeason.HOLY_WEEK)
            -7 -> return FastingInfo(FastLevel.FISH, FastSeason.GREAT_LENT, "note.palm")
            -8 -> return FastingInfo(FastLevel.WINE_OIL, FastSeason.GREAT_LENT, "note.lazarus")
            -48 -> return FastingInfo(FastLevel.STRICT, FastSeason.GREAT_LENT, "note.cleanMonday")
        }
        if (weekend) return FastingInfo(FastLevel.WINE_OIL, FastSeason.GREAT_LENT)
        if (pd == -17) return FastingInfo(FastLevel.WINE_OIL, FastSeason.GREAT_LENT, "note.greatCanon")
        if (md in lentWeekdayWineOil) return FastingInfo(FastLevel.WINE_OIL, FastSeason.GREAT_LENT, "note.feastWineOil")
        return FastingInfo(FastLevel.STRICT, FastSeason.GREAT_LENT)
    }

    private fun nativityFast(c: CivilDate, wedFri: Boolean, weekend: Boolean): FastingInfo {
        val md = c.monthDayKey
        if (md == "12-24") {
            return FastingInfo(if (weekend) FastLevel.WINE_OIL else FastLevel.STRICT, FastSeason.NATIVITY, "note.paramoni")
        }
        if (md == "11-21") return FastingInfo(FastLevel.FISH, FastSeason.NATIVITY, "note.entryFish")
        if (c.month == 12 && c.day >= 12) {
            if (weekend) return FastingInfo(FastLevel.WINE_OIL, FastSeason.NATIVITY)
            val lvl = nativityLateWineOil[md]
            if (lvl != null && !(wedFri && lvl == FastLevel.STRICT)) {
                return FastingInfo(lvl, FastSeason.NATIVITY, if (lvl == FastLevel.WINE_OIL) "note.feastWineOil" else null)
            }
            return FastingInfo(FastLevel.STRICT, FastSeason.NATIVITY)
        }
        if (wedFri) {
            wedFriExceptions[md]?.let { return FastingInfo(maxOf(it, FastLevel.FISH), FastSeason.NATIVITY) }
            return FastingInfo(FastLevel.STRICT, FastSeason.NATIVITY)
        }
        return FastingInfo(FastLevel.FISH, FastSeason.NATIVITY)
    }

    private val lentWeekdayWineOil = setOf("02-24", "03-09", "03-26")

    private val nativityLateWineOil = mapOf(
        "12-12" to FastLevel.WINE_OIL, "12-15" to FastLevel.WINE_OIL,
        "12-17" to FastLevel.WINE_OIL, "12-20" to FastLevel.WINE_OIL,
    )

    private val wedFriExceptions: Map<String, FastLevel> = buildMap {
        put("01-06", FastLevel.NO_FAST)
        listOf("01-07", "02-02", "06-24", "06-29", "08-15", "09-08", "11-14", "11-21").forEach { put(it, FastLevel.FISH) }
        listOf(
            "01-11", "01-14", "01-16", "01-17", "01-18", "01-20", "01-22", "01-25", "01-27", "01-30",
            "02-08", "02-10", "02-11", "02-17", "06-08", "06-11", "06-30", "07-01", "07-02", "07-08",
            "07-17", "07-20", "07-22", "07-25", "07-26", "07-27", "08-31", "09-01", "09-06", "09-09",
            "09-13", "09-20", "09-23", "09-26", "10-01", "10-06", "10-23", "10-26", "11-01", "11-08",
            "11-12", "11-13", "11-16", "11-25", "11-30", "12-04", "12-05", "12-06", "12-09",
        ).forEach { put(it, FastLevel.WINE_OIL) }
    }
}
