import Foundation


// MARK: - Dates localisées

public enum DateText {
    public static func monthGenitive(_ m: Int) -> String { Loc.t("month.\(m)") }
    public static func monthName(_ m: Int) -> String { Loc.t("monthN.\(m)") }
    public static func weekday(_ wd: Int) -> String { Loc.t("weekday.\(wd)") }
    public static func weekdayShort(_ wd: Int) -> String { Loc.t("wd.short.\(wd)") }

    private static func dayNumber(_ d: Int) -> String { d == 1 ? Loc.t("date.first") : String(d) }

    /// « Lundi 2 novembre 2026 ».
    public static func long(_ d: CivilDate) -> String {
        let w = weekday(d.weekday)
        let cap = w.prefix(1).uppercased() + w.dropFirst()
        return Loc.t("date.long", ["w": cap, "d": dayNumber(d.day), "m": monthGenitive(d.month), "y": String(d.year)])
    }

    /// « 2 novembre ».
    public static func dayMonth(_ d: CivilDate) -> String {
        Loc.t("date.dayMonth", ["d": dayNumber(d.day), "m": monthGenitive(d.month)])
    }

    /// « 2 novembre 2026 ».
    public static func dayMonthYear(_ d: CivilDate) -> String { dayMonth(d) + " " + String(d.year) }

    /// « Novembre 2026 ».
    public static func monthYear(year: Int, month: Int) -> String { monthName(month) + " " + String(year) }

    /// Date du ménologe (ancien calendrier).
    public static func churchLabel(_ day: LiturgicalDay) -> String? {
        guard day.calendar == .oldCalendar else { return nil }
        return Loc.t("day.menologion", ["d": dayMonth(day.church) + " " + Loc.t("cal.julianSuffix")])
    }
}
