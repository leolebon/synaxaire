import Foundation

/// Une date civile (grégorienne) indépendante des fuseaux horaires.
/// Les calculs se font via le numéro de jour julien (JDN), ce qui évite
/// les erreurs de changement d'heure.
public struct CivilDate: Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Construit la date à partir du numéro de jour julien (calendrier grégorien).
    public init(jdn: Int) {
        let a = jdn + 32044
        let b = (4 * a + 3) / 146097
        let c = a - 146097 * b / 4
        let d = (4 * c + 3) / 1461
        let e = c - 1461 * d / 4
        let m = (5 * e + 2) / 153
        self.day = e - (153 * m + 2) / 5 + 1
        self.month = m + 3 - 12 * (m / 10)
        self.year = 100 * b + d - 4800 + m / 10
    }

    /// Numéro de jour julien de la date (grégorienne).
    public var jdn: Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    /// 1 = dimanche, 2 = lundi … 7 = samedi (même convention que `Calendar`).
    public var weekday: Int {
        ((jdn + 1) % 7) + 1
    }

    public var isSunday: Bool { weekday == 1 }
    public var isSaturday: Bool { weekday == 7 }
    public var isWeekend: Bool { isSunday || isSaturday }
    public var isWednesdayOrFriday: Bool { weekday == 4 || weekday == 6 }

    public func adding(days: Int) -> CivilDate { CivilDate(jdn: jdn + days) }

    public func days(since other: CivilDate) -> Int { jdn - other.jdn }

    /// Clé « MM-JJ » utilisée par le synaxaire.
    public var monthDayKey: String { String(format: "%02d-%02d", month, day) }

    public static func < (lhs: CivilDate, rhs: CivilDate) -> Bool { lhs.jdn < rhs.jdn }

    public static func today(in calendar: Calendar = .current) -> CivilDate {
        CivilDate(date: Date(), calendar: calendar)
    }

    public init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
    }

    /// Minuit local de cette date.
    public func date(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        let next = month == 12 ? CivilDate(year: year + 1, month: 1, day: 1) : CivilDate(year: year, month: month + 1, day: 1)
        return next.jdn - CivilDate(year: year, month: month, day: 1).jdn
    }
}

/// Le calendrier utilisé pour les fêtes fixes.
public enum ChurchCalendar: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Calendrier julien révisé (Église de Grèce, Patriarcat œcuménique).
    case newCalendar = "new"
    /// Calendrier julien (Mont Athos, vieux-calendaristes).
    case oldCalendar = "old"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .newCalendar: return "Nouveau calendrier"
        case .oldCalendar: return "Ancien calendrier"
        }
    }

    public var shortLabel: String {
        switch self {
        case .newCalendar: return "N.C."
        case .oldCalendar: return "A.C."
        }
    }

    public var explanation: String {
        switch self {
        case .newCalendar:
            return "Julien révisé : Église de Grèce, Patriarcat œcuménique, Chypre, Roumanie… Noël le 25 décembre."
        case .oldCalendar:
            return "Julien : Mont Athos, Jérusalem, Russie, Serbie, vieux-calendaristes grecs… Noël le 7 janvier."
        }
    }

    /// Décalage entre la date civile et la date ecclésiastique (julienne).
    /// 13 jours de 1900 à 2099.
    public static func julianOffset(year: Int) -> Int {
        year / 100 - year / 400 - 2
    }

    /// Convertit une date civile en date du ménologe (jour/mois liturgique).
    public func churchDate(for civil: CivilDate) -> CivilDate {
        switch self {
        case .newCalendar: return civil
        case .oldCalendar: return civil.adding(days: -ChurchCalendar.julianOffset(year: civil.year))
        }
    }

    /// Date civile d'une date du ménologe pour une année civile donnée (approx. pour l'ancien calendrier).
    public func civilDate(forChurch month: Int, day: Int, civilYear: Int) -> CivilDate {
        let base = CivilDate(year: civilYear, month: month, day: day)
        switch self {
        case .newCalendar: return base
        case .oldCalendar: return base.adding(days: ChurchCalendar.julianOffset(year: civilYear))
        }
    }
}
