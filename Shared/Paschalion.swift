import Foundation

/// Calcul de la Pâque orthodoxe (comput julien, exprimé en date civile grégorienne)
/// et des jours mobiles du Triode et du Pentecostaire.
public enum Paschalion {

    /// Date civile (grégorienne) de la Pâque orthodoxe pour l'année donnée.
    public static func pascha(year: Int) -> CivilDate {
        // Algorithme de Meeus pour le comput julien.
        let a = year % 4
        let b = year % 7
        let c = year % 19
        let d = (19 * c + 15) % 30
        let e = (2 * a + 4 * b - d + 34) % 7
        let month = (d + e + 114) / 31
        let day = ((d + e + 114) % 31) + 1
        // Date julienne → grégorienne.
        let julianJDN = julianToJDN(year: year, month: month, day: day)
        return CivilDate(jdn: julianJDN)
    }

    private static func julianToJDN(year: Int, month: Int, day: Int) -> Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - 32083
    }

    /// Nombre de jours depuis la Pâque de l'année civile (négatif avant Pâques).
    public static func distance(from date: CivilDate) -> Int {
        date.days(since: pascha(year: date.year))
    }

    /// Ton de l'Octoèque de la semaine (1–8), 0 pendant la semaine radieuse ou hors cycle.
    public static func tone(for date: CivilDate) -> Int {
        var pd = distance(from: date)
        if pd < -9 {
            // Rattacher à la Pâque de l'année précédente.
            pd = date.days(since: pascha(year: date.year - 1))
        }
        guard pd >= 7 else { return 0 }
        // Le dimanche de Thomas ouvre le ton 1.
        let week = (pd - 7) / 7
        return (week % 8) + 1
    }
}

/// Un jour du cycle mobile (Triode / Pentecostaire).
public struct MovableDay: Sendable {
    public let key: String
    public let args: [String: String]
    public let rank: FeastRank
    public let wikipediaTitle: String?

    public init(key: String, args: [String: String] = [:], rank: FeastRank, wikipediaTitle: String?) {
        self.key = key
        self.args = args
        self.rank = rank
        self.wikipediaTitle = wikipediaTitle
    }

    public var title: String { Loc.t(key, args) }
}

public enum MovableCycle {

    /// Jour liturgique mobile, s'il a un titre propre.
    public static func day(forPaschaDistance pd: Int, weekday: Int) -> MovableDay? {
        if let fixed = table[pd] {
            return MovableDay(key: "mov.\(pd)", rank: fixed.0, wikipediaTitle: fixed.1)
        }
        // Semaine radieuse.
        if (1...6).contains(pd) {
            return MovableDay(key: "mov.\(pd)", rank: .major,
                              wikipediaTitle: pd == 5 ? "Zoodochos Pege" : "Semaine radieuse")
        }
        // Jours de semaine du Grand Carême.
        if (-48 ... -9).contains(pd), weekday != 1 && weekday != 7 {
            let week = (pd + 48) / 7 + 1
            return MovableDay(key: "mov.lentWeek", args: ["n": String(week)], rank: .ordinary, wikipediaTitle: nil)
        }
        // Temps pascal : jours ordinaires.
        if (8...38).contains(pd) {
            return MovableDay(key: "mov.paschal", rank: .ordinary, wikipediaTitle: nil)
        }
        return nil
    }

    static let table: [Int: (FeastRank, String?)] = [
        -70: (.sunday, nil),
        -63: (.sunday, "Parabole du fils prodigue"),
        -57: (.sunday, nil),
        -56: (.sunday, "Jugement dernier"),
        -50: (.ordinary, nil),
        -49: (.sunday, "Dimanche du Pardon"),
        -48: (.major, "Lundi pur"),
        -43: (.ordinary, "Théodore le Conscrit"),
        -42: (.sunday, "Triomphe de l'Orthodoxie"),
        -36: (.ordinary, nil),
        -35: (.sunday, "Grégoire Palamas"),
        -29: (.ordinary, nil),
        -28: (.sunday, "Vraie Croix"),
        -22: (.ordinary, nil),
        -21: (.sunday, "Jean Climaque"),
        -18: (.ordinary, "André de Crète"),
        -17: (.ordinary, "André de Crète"),
        -16: (.ordinary, "Hymne acathiste"),
        -15: (.ordinary, "Hymne acathiste"),
        -14: (.sunday, "Marie l'Égyptienne"),
        -8: (.major, "Résurrection de Lazare"),
        -7: (.great, "Entrée de Jésus à Jérusalem"),
        -6: (.holyWeek, "Semaine sainte"),
        -5: (.holyWeek, "Semaine sainte"),
        -4: (.holyWeek, "Semaine sainte"),
        -3: (.holyWeek, "Jeudi saint"),
        -2: (.holyWeek, "Vendredi saint"),
        -1: (.holyWeek, "Samedi saint"),
        0: (.pascha, "Pâques"),
        7: (.sunday, "Thomas (apôtre)"),
        14: (.sunday, "Myrrhophores"),
        21: (.sunday, nil),
        24: (.major, "Mi-Pentecôte"),
        28: (.sunday, "Femme samaritaine"),
        35: (.sunday, nil),
        38: (.major, nil),
        39: (.great, "Ascension (fête)"),
        42: (.sunday, "Premier concile de Nicée"),
        48: (.ordinary, nil),
        49: (.great, "Pentecôte"),
        50: (.major, "Lundi de Pentecôte"),
        56: (.sunday, "Toussaint"),
        63: (.sunday, nil),
    ]

    /// Dimanches du cycle fixe dépendant de la date (Pères des conciles, Ancêtres…).
    public static func fixedCycleSunday(churchDate c: CivilDate, weekday: Int) -> MovableDay? {
        guard weekday == 1 else { return nil }
        let entry: (String, String?)?
        switch (c.month, c.day) {
        case (7, 13...19): entry = ("sun.fathers4", "Concile de Chalcédoine")
        case (10, 11...17): entry = ("sun.fathers7", "Deuxième concile de Nicée")
        case (12, 11...17): entry = ("sun.forefathers", nil)
        case (12, 18...24): entry = ("sun.genealogy", nil)
        case (12, 26...31): entry = ("sun.afterNativity", nil)
        case (1, 1...5): entry = ("sun.beforeTheophany", nil)
        case (1, 7...13): entry = ("sun.afterTheophany", nil)
        case (9, 7...13): entry = ("sun.beforeCross", nil)
        case (9, 15...21): entry = ("sun.afterCross", nil)
        default: entry = nil
        }
        guard let entry else { return nil }
        return MovableDay(key: entry.0, rank: .sunday, wikipediaTitle: entry.1)
    }
}
