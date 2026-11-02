package org.synaxaire.calendrier.engine

/** Une commémoration du ménologe. */
data class Commemoration(val fr: String, val en: String, val festal: Boolean = false) {
    /** Nom dans la langue courante (français, sinon anglais). */
    val displayName: String get() = if (Loc.language == "fr") fr else en
    val shortName: String get() = short(displayName)
    val shortFrench: String get() = short(fr)

    /** Requête Wikipédia (nom français sans « Saint », ni qualificatifs). */
    val searchQuery: String
        get() {
            var s = shortFrench
            s.indexOf(" (").takeIf { it >= 0 }?.let { s = s.substring(0, it) }
            for (p in listOf("Saintes ", "Saints ", "Sainte ", "Saint ", "Les saints ", "Les saintes ", "Le ", "La ", "Les ")) {
                if (s.startsWith(p)) { s = s.substring(p.length); break }
            }
            return s
        }

    val initial: String get() = searchQuery.firstOrNull()?.uppercase() ?: "☦"

    companion object {
        fun short(s: String): String {
            s.indexOf(",").takeIf { it >= 0 }?.let { return s.substring(0, it) }
            s.indexOf(" — ").takeIf { it >= 0 }?.let { return s.substring(0, it) }
            return s
        }
    }
}

/** Synaxaire embarqué (synaxaire.json : 366 jours). */
class Synaxarion(jsonText: String) {
    private val days: Map<String, List<Commemoration>> =
        Json.parse(jsonText).asMap().mapValues { (_, list) ->
            list.asList().map { item ->
                val m = item.asMap()
                Commemoration(m["fr"] as String, m["en"] as String, m["t"] == "f")
            }
        }

    fun commemorations(church: CivilDate): List<Commemoration> {
        var list = days[church.monthDayKey] ?: emptyList()
        if (church.month == 2 && church.day == 28 && CivilDate.daysInMonth(church.year, 2) == 28) {
            list = list + (days["02-29"] ?: emptyList())
        }
        return list
    }
}

/** Tout ce que l'application et le widget affichent pour une journée. */
class LiturgicalDay(val civil: CivilDate, val calendar: ChurchCalendar, synaxarion: Synaxarion) {
    val church: CivilDate = calendar.churchDate(civil)
    val paschaDistance: Int = Paschalion.distance(civil)
    val tone: Int = Paschalion.tone(civil)
    val fasting: FastingInfo = FastingRules.fasting(civil, calendar)
    val commemorations: List<Commemoration>
    val title: String
    val subtitles: List<String>
    val rank: FeastRank
    val titleIsSaint: Boolean
    val feastWikipediaTitle: String?
    val primarySaintWikipediaTitle: String?

    val saints: List<Commemoration> get() = commemorations.filter { !it.festal }
    val primarySaint: Commemoration? get() = saints.firstOrNull()
    val isGreatFeast: Boolean get() = rank >= FeastRank.GREAT

    fun wikipediaTitle(c: Commemoration): String? = if (c == primarySaint) primarySaintWikipediaTitle else null

    init {
        val pd = paschaDistance
        var list = synaxarion.commemorations(church)

        // Usage grec : saint Georges tombant avant Pâques est fêté le lundi radieux.
        val georgeDate = calendar.civilDateForChurch(4, 23, civil.year)
        val georgeBeforePascha = Paschalion.distance(georgeDate) < 1
        val georgeToday = church.month == 4 && church.day == 23 && georgeBeforePascha
        if (georgeToday) {
            list = list.map { c ->
                if (c.en.startsWith("George the Great Martyr"))
                    Commemoration(c.fr + Loc.t("george.suffix"), c.en + Loc.t("george.suffix"))
                else c
            }
        }
        if (pd == 1 && georgeBeforePascha) {
            list = synaxarion.commemorations(CivilDate(church.year, 4, 23)) + list
        }
        commemorations = list

        val movable = MovableCycle.day(pd, civil.weekday) ?: MovableCycle.fixedCycleSunday(church, civil.weekday)
        val fixed = if (georgeToday) null else FixedFeasts.feast(church)
        primarySaintWikipediaTitle = fixed?.wikipediaTitle

        val titles = mutableListOf<Triple<String, FeastRank, String?>>()
        movable?.let { titles.add(Triple(it.title, it.rank, it.wikipediaTitle)) }
        fixed?.let { titles.add(Triple(it.title, it.rank, it.wikipediaTitle)) }
        if (pd == 1 && georgeBeforePascha) titles.add(Triple(Loc.t("george.title"), FeastRank.MAJOR, "Georges de Lydda"))
        titles.sortByDescending { it.second }

        val sundayRank = if (civil.isSunday) FeastRank.SUNDAY else FeastRank.ORDINARY
        val first = titles.firstOrNull()
        if (first != null && (first.second >= FeastRank.SUNDAY || movable == null)) {
            title = first.first
            titleIsSaint = false
            rank = maxOf(first.second, sundayRank)
            feastWikipediaTitle = first.third
            subtitles = titles.drop(1).map { it.first }
        } else if (movable != null) {
            title = list.firstOrNull { !it.festal }?.displayName ?: movable.title
            titleIsSaint = true
            rank = sundayRank
            feastWikipediaTitle = null
            subtitles = listOf(movable.title) + titles.drop(1).map { it.first }
        } else {
            title = list.firstOrNull { !it.festal }?.displayName ?: list.firstOrNull()?.displayName ?: Loc.t("ferial")
            titleIsSaint = list.isNotEmpty()
            rank = if (civil.isSunday) FeastRank.SUNDAY else if (list.isEmpty()) FeastRank.ORDINARY else FeastRank.SAINT
            feastWikipediaTitle = null
            subtitles = emptyList()
        }
    }
}

// MARK: Périodes de jeûne

data class FastPeriod(val season: FastSeason, val start: CivilDate, val end: CivilDate) {
    val id: String get() = "${season.key}-${start.jdn}"
    operator fun contains(d: CivilDate): Boolean = d >= start && d <= end
}

object FastCalendar {
    fun periods(year: Int, calendar: ChurchCalendar): List<FastPeriod> {
        val p = Paschalion.pascha(year)
        val out = mutableListOf(
            FastPeriod(FastSeason.PUBLICAN_WEEK, p.plusDays(-69), p.plusDays(-64)),
            FastPeriod(FastSeason.CHEESEFARE, p.plusDays(-55), p.plusDays(-49)),
            FastPeriod(FastSeason.GREAT_LENT, p.plusDays(-48), p.plusDays(-9)),
            FastPeriod(FastSeason.HOLY_WEEK, p.plusDays(-6), p.plusDays(-1)),
            FastPeriod(FastSeason.BRIGHT_WEEK, p, p.plusDays(6)),
            FastPeriod(FastSeason.TRINITY_WEEK, p.plusDays(50), p.plusDays(55)),
        )
        val apStart = p.plusDays(57)
        val apEnd = calendar.civilDateForChurch(6, 28, year)
        if (apStart <= apEnd) out.add(FastPeriod(FastSeason.APOSTLES, apStart, apEnd))
        out.add(FastPeriod(FastSeason.DORMITION, calendar.civilDateForChurch(8, 1, year), calendar.civilDateForChurch(8, 14, year)))
        out.add(FastPeriod(FastSeason.NATIVITY, calendar.civilDateForChurch(11, 15, year), calendar.civilDateForChurch(12, 24, year)))
        out.add(FastPeriod(FastSeason.CHRISTMASTIDE, calendar.civilDateForChurch(12, 25, year), calendar.civilDateForChurch(1, 4, year + 1)))
        out.add(FastPeriod(FastSeason.CHRISTMASTIDE, calendar.civilDateForChurch(12, 25, year - 1), calendar.civilDateForChurch(1, 4, year)))
        if (calendar == ChurchCalendar.OLD) {
            out.add(FastPeriod(FastSeason.NATIVITY, calendar.civilDateForChurch(11, 15, year - 1), calendar.civilDateForChurch(12, 24, year - 1)))
        }
        return out.filter { it.end.year >= year && it.start.year <= year }.sortedBy { it.start }
    }

    fun currentOrNextLent(from: CivilDate, calendar: ChurchCalendar): FastPeriod? =
        (periods(from.year, calendar) + periods(from.year + 1, calendar))
            .filter { it.season.isLent && it.season != FastSeason.CHEESEFARE }
            .firstOrNull { it.end >= from }
}
