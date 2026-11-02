package org.synaxaire.calendrier.engine

import java.time.LocalDate

/** Date civile (grégorienne) ; calculs via le numéro de jour julien, sans fuseau horaire. */
data class CivilDate(val year: Int, val month: Int, val day: Int) : Comparable<CivilDate> {

    val jdn: Int
        get() {
            val a = (14 - month) / 12
            val y = year + 4800 - a
            val m = month + 12 * a - 3
            return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
        }

    /** 1 = dimanche, 2 = lundi … 7 = samedi. */
    val weekday: Int get() = ((jdn + 1) % 7) + 1

    val isSunday: Boolean get() = weekday == 1
    val isSaturday: Boolean get() = weekday == 7
    val isWeekend: Boolean get() = isSunday || isSaturday
    val isWednesdayOrFriday: Boolean get() = weekday == 4 || weekday == 6

    fun plusDays(n: Int): CivilDate = fromJdn(jdn + n)
    fun daysSince(other: CivilDate): Int = jdn - other.jdn

    /** Clé « MM-JJ » du synaxaire. */
    val monthDayKey: String get() = month.toString().padStart(2, '0') + "-" + day.toString().padStart(2, '0')

    override fun compareTo(other: CivilDate): Int = jdn.compareTo(other.jdn)

    companion object {
        fun fromJdn(jdn: Int): CivilDate {
            val a = jdn + 32044
            val b = (4 * a + 3) / 146097
            val c = a - 146097 * b / 4
            val d = (4 * c + 3) / 1461
            val e = c - 1461 * d / 4
            val m = (5 * e + 2) / 153
            val day = e - (153 * m + 2) / 5 + 1
            val month = m + 3 - 12 * (m / 10)
            val year = 100 * b + d - 4800 + m / 10
            return CivilDate(year, month, day)
        }

        fun today(): CivilDate {
            val t = LocalDate.now()
            return CivilDate(t.year, t.monthValue, t.dayOfMonth)
        }

        fun daysInMonth(year: Int, month: Int): Int {
            val next = if (month == 12) CivilDate(year + 1, 1, 1) else CivilDate(year, month + 1, 1)
            return next.jdn - CivilDate(year, month, 1).jdn
        }
    }
}

/** Calendrier des fêtes fixes. */
enum class ChurchCalendar(val code: String) {
    NEW("new"),
    OLD("old");

    val label: String get() = Loc.t(if (this == NEW) "cal.new" else "cal.old")
    val explanation: String get() = Loc.t(if (this == NEW) "cal.new.explain" else "cal.old.explain")

    /** Date du ménologe correspondant à une date civile. */
    fun churchDate(civil: CivilDate): CivilDate =
        if (this == NEW) civil else civil.plusDays(-julianOffset(civil.year))

    /** Date civile d'une date du ménologe pour une année civile donnée. */
    fun civilDateForChurch(month: Int, day: Int, civilYear: Int): CivilDate {
        val base = CivilDate(civilYear, month, day)
        return if (this == NEW) base else base.plusDays(julianOffset(civilYear))
    }

    companion object {
        /** 13 jours de 1900 à 2099. */
        fun julianOffset(year: Int): Int = year / 100 - year / 400 - 2
        fun fromCode(code: String?): ChurchCalendar = if (code == "old") OLD else NEW
    }
}
