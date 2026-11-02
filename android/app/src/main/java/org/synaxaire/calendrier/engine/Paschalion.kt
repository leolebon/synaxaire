package org.synaxaire.calendrier.engine

/** Rang liturgique d'un jour. */
enum class FeastRank { ORDINARY, SUNDAY, SAINT, MAJOR, HOLY_WEEK, GREAT, PASCHA }

object Paschalion {
    /** Date civile de la Pâque orthodoxe (comput julien). */
    fun pascha(year: Int): CivilDate {
        val a = year % 4
        val b = year % 7
        val c = year % 19
        val d = (19 * c + 15) % 30
        val e = (2 * a + 4 * b - d + 34) % 7
        val month = (d + e + 114) / 31
        val day = ((d + e + 114) % 31) + 1
        return CivilDate.fromJdn(julianToJdn(year, month, day))
    }

    private fun julianToJdn(year: Int, month: Int, day: Int): Int {
        val a = (14 - month) / 12
        val y = year + 4800 - a
        val m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - 32083
    }

    fun distance(date: CivilDate): Int = date.daysSince(pascha(date.year))

    fun tone(date: CivilDate): Int {
        var pd = distance(date)
        if (pd < -9) pd = date.daysSince(pascha(date.year - 1))
        if (pd < 7) return 0
        return ((pd - 7) / 7) % 8 + 1
    }
}

data class MovableDay(val key: String, val args: Map<String, String> = emptyMap(), val rank: FeastRank, val wikipediaTitle: String?) {
    val title: String get() = Loc.t(key, args)
}

object MovableCycle {
    fun day(pd: Int, weekday: Int): MovableDay? {
        table[pd]?.let { return MovableDay("mov.$pd", rank = it.first, wikipediaTitle = it.second) }
        if (pd in 1..6) {
            return MovableDay("mov.$pd", rank = FeastRank.MAJOR, wikipediaTitle = if (pd == 5) "Zoodochos Pege" else "Semaine radieuse")
        }
        if (pd in -48..-9 && weekday != 1 && weekday != 7) {
            val week = (pd + 48) / 7 + 1
            return MovableDay("mov.lentWeek", mapOf("n" to week.toString()), FeastRank.ORDINARY, null)
        }
        if (pd in 8..38) return MovableDay("mov.paschal", rank = FeastRank.ORDINARY, wikipediaTitle = null)
        return null
    }

    private val table: Map<Int, Pair<FeastRank, String?>> = mapOf(
        -70 to (FeastRank.SUNDAY to null),
        -63 to (FeastRank.SUNDAY to "Parabole du fils prodigue"),
        -57 to (FeastRank.SUNDAY to null),
        -56 to (FeastRank.SUNDAY to "Jugement dernier"),
        -50 to (FeastRank.ORDINARY to null),
        -49 to (FeastRank.SUNDAY to "Dimanche du Pardon"),
        -48 to (FeastRank.MAJOR to "Lundi pur"),
        -43 to (FeastRank.ORDINARY to "Théodore le Conscrit"),
        -42 to (FeastRank.SUNDAY to "Triomphe de l'Orthodoxie"),
        -36 to (FeastRank.ORDINARY to null),
        -35 to (FeastRank.SUNDAY to "Grégoire Palamas"),
        -29 to (FeastRank.ORDINARY to null),
        -28 to (FeastRank.SUNDAY to "Vraie Croix"),
        -22 to (FeastRank.ORDINARY to null),
        -21 to (FeastRank.SUNDAY to "Jean Climaque"),
        -18 to (FeastRank.ORDINARY to "André de Crète"),
        -17 to (FeastRank.ORDINARY to "André de Crète"),
        -16 to (FeastRank.ORDINARY to "Hymne acathiste"),
        -15 to (FeastRank.ORDINARY to "Hymne acathiste"),
        -14 to (FeastRank.SUNDAY to "Marie l'Égyptienne"),
        -8 to (FeastRank.MAJOR to "Résurrection de Lazare"),
        -7 to (FeastRank.GREAT to "Entrée de Jésus à Jérusalem"),
        -6 to (FeastRank.HOLY_WEEK to "Semaine sainte"),
        -5 to (FeastRank.HOLY_WEEK to "Semaine sainte"),
        -4 to (FeastRank.HOLY_WEEK to "Semaine sainte"),
        -3 to (FeastRank.HOLY_WEEK to "Jeudi saint"),
        -2 to (FeastRank.HOLY_WEEK to "Vendredi saint"),
        -1 to (FeastRank.HOLY_WEEK to "Samedi saint"),
        0 to (FeastRank.PASCHA to "Pâques"),
        7 to (FeastRank.SUNDAY to "Thomas (apôtre)"),
        14 to (FeastRank.SUNDAY to "Myrrhophores"),
        21 to (FeastRank.SUNDAY to null),
        24 to (FeastRank.MAJOR to "Mi-Pentecôte"),
        28 to (FeastRank.SUNDAY to "Femme samaritaine"),
        35 to (FeastRank.SUNDAY to null),
        38 to (FeastRank.MAJOR to null),
        39 to (FeastRank.GREAT to "Ascension (fête)"),
        42 to (FeastRank.SUNDAY to "Premier concile de Nicée"),
        48 to (FeastRank.ORDINARY to null),
        49 to (FeastRank.GREAT to "Pentecôte"),
        50 to (FeastRank.MAJOR to "Lundi de Pentecôte"),
        56 to (FeastRank.SUNDAY to "Toussaint"),
        63 to (FeastRank.SUNDAY to null),
    )

    fun fixedCycleSunday(c: CivilDate, weekday: Int): MovableDay? {
        if (weekday != 1) return null
        val e: Pair<String, String?> = when {
            c.month == 7 && c.day in 13..19 -> "sun.fathers4" to "Concile de Chalcédoine"
            c.month == 10 && c.day in 11..17 -> "sun.fathers7" to "Deuxième concile de Nicée"
            c.month == 12 && c.day in 11..17 -> "sun.forefathers" to null
            c.month == 12 && c.day in 18..24 -> "sun.genealogy" to null
            c.month == 12 && c.day in 26..31 -> "sun.afterNativity" to null
            c.month == 1 && c.day in 1..5 -> "sun.beforeTheophany" to null
            c.month == 1 && c.day in 7..13 -> "sun.afterTheophany" to null
            c.month == 9 && c.day in 7..13 -> "sun.beforeCross" to null
            c.month == 9 && c.day in 15..21 -> "sun.afterCross" to null
            else -> return null
        }
        return MovableDay(e.first, rank = FeastRank.SUNDAY, wikipediaTitle = e.second)
    }
}

data class FixedFeast(val key: String, val rank: FeastRank, val wikipediaTitle: String?) {
    val title: String get() = Loc.t(key)
}

object FixedFeasts {
    fun feast(church: CivilDate): FixedFeast? {
        val md = church.monthDayKey
        val e = table[md] ?: return null
        return FixedFeast("feast.$md", e.first, e.second)
    }

    private val table: Map<String, Pair<FeastRank, String?>> = mapOf(
        "09-08" to (FeastRank.GREAT to "Nativité de Marie"),
        "09-14" to (FeastRank.GREAT to "Exaltation de la Sainte-Croix"),
        "11-21" to (FeastRank.GREAT to "Présentation de Marie au Temple"),
        "12-25" to (FeastRank.GREAT to "Nativité de Jésus"),
        "01-06" to (FeastRank.GREAT to "Théophanie"),
        "02-02" to (FeastRank.GREAT to "Présentation de Jésus au Temple"),
        "03-25" to (FeastRank.GREAT to "Annonciation"),
        "08-06" to (FeastRank.GREAT to "Transfiguration"),
        "08-15" to (FeastRank.GREAT to "Dormition"),
        "09-01" to (FeastRank.MAJOR to "Syméon le Stylite"),
        "01-01" to (FeastRank.MAJOR to "Basile de Césarée"),
        "01-07" to (FeastRank.MAJOR to "Jean le Baptiste"),
        "01-30" to (FeastRank.MAJOR to "Trois Saints Hiérarques"),
        "06-24" to (FeastRank.MAJOR to "Nativité de Jean le Baptiste"),
        "06-29" to (FeastRank.MAJOR to "Saints Pierre et Paul"),
        "08-29" to (FeastRank.MAJOR to "Décollation de saint Jean-Baptiste"),
        "10-26" to (FeastRank.MAJOR to "Démétrios de Thessalonique"),
        "11-08" to (FeastRank.MAJOR to "Archange Michel"),
        "11-13" to (FeastRank.MAJOR to "Jean Chrysostome"),
        "11-30" to (FeastRank.MAJOR to "André (apôtre)"),
        "12-06" to (FeastRank.MAJOR to "Nicolas de Myre"),
        "12-12" to (FeastRank.MAJOR to "Spyridon de Trimythonte"),
        "01-17" to (FeastRank.MAJOR to "Antoine le Grand"),
        "01-18" to (FeastRank.SAINT to "Athanase d'Alexandrie"),
        "01-25" to (FeastRank.MAJOR to "Grégoire de Nazianze"),
        "02-10" to (FeastRank.SAINT to "Charalampe"),
        "04-23" to (FeastRank.MAJOR to "Georges de Lydda"),
        "05-08" to (FeastRank.MAJOR to "Jean (apôtre)"),
        "05-21" to (FeastRank.MAJOR to "Constantin Ier (empereur romain)"),
        "06-30" to (FeastRank.SAINT to "Douze Apôtres"),
        "07-20" to (FeastRank.MAJOR to "Élie"),
        "07-26" to (FeastRank.SAINT to "Parascève de Rome"),
        "07-27" to (FeastRank.SAINT to "Pantaléon de Nicomédie"),
        "08-31" to (FeastRank.SAINT to null),
        "09-26" to (FeastRank.SAINT to "Jean (apôtre)"),
        "10-28" to (FeastRank.MAJOR to "Protection de la Mère de Dieu"),
        "12-15" to (FeastRank.SAINT to "Éleuthère d'Illyrie"),
        "12-17" to (FeastRank.SAINT to "Dionysios de Zante"),
        "12-20" to (FeastRank.SAINT to "Ignace d'Antioche"),
        "11-09" to (FeastRank.MAJOR to "Nectaire d'Égine"),
        "11-25" to (FeastRank.SAINT to "Catherine d'Alexandrie"),
        "11-14" to (FeastRank.SAINT to "Philippe (apôtre)"),
        "11-16" to (FeastRank.SAINT to "Matthieu (apôtre)"),
        "10-18" to (FeastRank.SAINT to "Luc (évangéliste)"),
        "04-25" to (FeastRank.SAINT to "Marc (évangéliste)"),
        "10-06" to (FeastRank.SAINT to "Thomas (apôtre)"),
        "02-24" to (FeastRank.SAINT to "Jean le Baptiste"),
        "03-09" to (FeastRank.SAINT to "Quarante martyrs de Sébaste"),
        "03-26" to (FeastRank.SAINT to "Gabriel (archange)"),
        "05-25" to (FeastRank.SAINT to "Jean le Baptiste"),
        "07-22" to (FeastRank.SAINT to "Marie de Magdala"),
        "09-09" to (FeastRank.SAINT to "Joachim et Anne"),
        "09-23" to (FeastRank.SAINT to null),
        "12-09" to (FeastRank.SAINT to null),
        "12-04" to (FeastRank.SAINT to "Barbe d'Héliopolis"),
        "08-01" to (FeastRank.SAINT to null),
    )
}
