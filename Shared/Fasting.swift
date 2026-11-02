import Foundation

/// Niveau de jeûne d'une journée, du plus permissif au plus strict.
public enum FastLevel: Int, Codable, Sendable, Comparable {
    case noFast = 0       // jour ordinaire, pas de jeûne
    case fastFree = 1     // période sans jeûne (même mercredi et vendredi)
    case dairy = 2        // pas de viande ; laitages, œufs, poisson permis
    case fish = 3         // poisson, vin et huile permis
    case wineOil = 4      // vin et huile permis
    case strict = 5       // xérophagie : ni huile, ni vin

    public static func < (l: FastLevel, r: FastLevel) -> Bool { l.rawValue < r.rawValue }

    public var isFasting: Bool { self >= .dairy }

    /// Nom de clé de traduction.
    public var key: String {
        switch self {
        case .noFast: return "noFast"
        case .fastFree: return "fastFree"
        case .dairy: return "dairy"
        case .fish: return "fish"
        case .wineOil: return "wineOil"
        case .strict: return "strict"
        }
    }

    public var title: String { Loc.t("fast.\(key).title") }
    public var shortTitle: String { Loc.t("fast.\(key).short") }
    public var explanation: String { Loc.t("fast.\(key).explain") }

    /// Symbole SF Symbols utilisé dans l'interface.
    public var symbol: String {
        switch self {
        case .noFast: return "fork.knife"
        case .fastFree: return "party.popper"
        case .dairy: return "cup.and.saucer"
        case .fish: return "fish"
        case .wineOil: return "wineglass"
        case .strict: return "leaf"
        }
    }

    /// Catégories d'aliments permises.
    public var allowed: Set<FoodCategory> {
        switch self {
        case .noFast, .fastFree: return Set(FoodCategory.allCases)
        case .dairy: return [.dairy, .eggs, .fish, .oil, .wine, .shellfish]
        case .fish: return [.fish, .oil, .wine, .shellfish]
        case .wineOil: return [.oil, .wine, .shellfish]
        case .strict: return [.shellfish]
        }
    }
}

public enum FoodCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case meat, dairy, eggs, fish, oil, wine, shellfish
    public var id: String { rawValue }

    public var label: String { Loc.t("food.\(rawValue)") }

    public var emoji: String {
        switch self {
        case .meat: return "🥩"
        case .dairy: return "🧀"
        case .eggs: return "🥚"
        case .fish: return "🐟"
        case .oil: return "🫒"
        case .wine: return "🍷"
        case .shellfish: return "🦐"
        }
    }
}

/// Période de jeûne ou de fête dans laquelle tombe la journée.
public enum FastSeason: String, Codable, Sendable {
    case ordinary
    case wednesdayFriday
    case paschalSeason
    case christmastide
    case publicanWeek
    case brightWeek
    case trinityWeek
    case cheesefare
    case greatLent
    case holyWeek
    case apostles
    case dormition
    case nativity
    case strictDay

    public var title: String { Loc.t("season.\(rawValue)") }

    /// Les grands carêmes, affichés comme « périodes ».
    public var isLent: Bool {
        switch self {
        case .greatLent, .holyWeek, .apostles, .dormition, .nativity, .cheesefare: return true
        default: return false
        }
    }

    /// Recommandations spirituelles et pratiques pour la période.
    public var recommendations: [String] {
        guard self != .ordinary, Loc.has("rec.\(rawValue)") else { return [] }
        return Loc.t("rec.\(rawValue)").components(separatedBy: "\n").filter { !$0.isEmpty }
    }
}

/// Résultat complet du calcul du jeûne pour une journée.
public struct FastingInfo: Sendable {
    public let level: FastLevel
    public let season: FastSeason
    /// Clé de traduction de la précision propre au jour.
    public let noteKey: String?

    public init(level: FastLevel, season: FastSeason, note: String?) {
        self.level = level
        self.season = season
        self.noteKey = note
    }

    /// Précision propre au jour, traduite.
    public var note: String? { noteKey.map { Loc.t($0) } }

    public var summary: String {
        if let note { return "\(level.title) — \(note)" }
        return level.title
    }
}

/// Règles du jeûne selon l'usage grec (Archevêché grec-orthodoxe, Typikon de la Grande Église).
/// Validées jour par jour contre le calendrier publié par goarch.org (2025-2035).
public enum FastingRules {

    public static func fasting(civil: CivilDate, calendar: ChurchCalendar) -> FastingInfo {
        let c = calendar.churchDate(for: civil)
        let pd = Paschalion.distance(from: civil)
        let weekend = civil.isWeekend
        let wedFri = civil.isWednesdayOrFriday
        let md = c.monthDayKey

        // 1. Dodécaémeron : 25 décembre – 4 janvier.
        if (c.month == 12 && c.day >= 25) || (c.month == 1 && c.day <= 4) {
            return FastingInfo(level: .fastFree, season: .christmastide, note: nil)
        }

        // 2. Semaines sans jeûne du cycle mobile.
        if (0...6).contains(pd) { return FastingInfo(level: .fastFree, season: .brightWeek, note: nil) }
        if (-69 ... -64).contains(pd) { return FastingInfo(level: .fastFree, season: .publicanWeek, note: nil) }
        if (50...55).contains(pd) { return FastingInfo(level: .fastFree, season: .trinityWeek, note: nil) }

        // 3. Semaine de la Tyrophagie.
        if (-55 ... -49).contains(pd) {
            return FastingInfo(level: .dairy, season: .cheesefare, note: pd == -49 ? "note.cheesefareLast" : nil)
        }

        // 4. Grand Carême et Semaine sainte.
        if (-48 ... -1).contains(pd) {
            return greatLent(pd: pd, church: c, weekend: weekend)
        }

        // 5. Jours de jeûne strict fixes.
        if md == "01-05" || md == "08-29" || md == "09-14" {
            return FastingInfo(level: weekend ? .wineOil : .strict, season: .strictDay, note: nil)
        }

        // 6. Carême de la Dormition : 1er – 14 août.
        if c.month == 8 && c.day <= 14 {
            if c.day == 6 { return FastingInfo(level: .fish, season: .dormition, note: "note.transfiguration") }
            return FastingInfo(level: weekend ? .wineOil : .strict, season: .dormition, note: nil)
        }

        // 7. Carême de la Nativité : 15 novembre – 24 décembre.
        if (c.month == 11 && c.day >= 15) || (c.month == 12 && c.day <= 24) {
            return nativityFast(church: c, wedFri: wedFri, weekend: weekend)
        }

        // 8. Carême des Apôtres : lundi après Tous les Saints → 28 juin.
        if pd >= 57 && (c.month < 6 || (c.month == 6 && c.day <= 28)) {
            if md == "06-24" { return FastingInfo(level: .fish, season: .apostles, note: "note.forerunner") }
            if wedFri {
                if let lvl = wedFriExceptions[md] { return FastingInfo(level: lvl, season: .apostles, note: nil) }
                return FastingInfo(level: .strict, season: .apostles, note: nil)
            }
            return FastingInfo(level: .fish, season: .apostles, note: nil)
        }

        guard wedFri else {
            return FastingInfo(level: .noFast, season: (7...48).contains(pd) ? .paschalSeason : .ordinary, note: nil)
        }

        // 9. Mercredi et vendredi du temps pascal.
        if (7...48).contains(pd) {
            if pd == 24 || pd == 38 { return FastingInfo(level: .fish, season: .paschalSeason, note: nil) }
            if let lvl = wedFriExceptions[md], lvl == .fish { return FastingInfo(level: .fish, season: .paschalSeason, note: nil) }
            return FastingInfo(level: .wineOil, season: .paschalSeason, note: nil)
        }

        // 10. Mercredi et vendredi ordinaires.
        if let lvl = wedFriExceptions[md] {
            if lvl == .noFast { return FastingInfo(level: .noFast, season: .ordinary, note: nil) }
            return FastingInfo(level: lvl, season: .wednesdayFriday, note: lvl == .fish ? "note.feastFish" : (lvl == .wineOil ? "note.feastWineOil" : nil))
        }
        return FastingInfo(level: .strict, season: .wednesdayFriday, note: nil)
    }

    private static func greatLent(pd: Int, church c: CivilDate, weekend: Bool) -> FastingInfo {
        let md = c.monthDayKey
        let holy = pd >= -6
        let season: FastSeason = holy ? .holyWeek : .greatLent
        if md == "03-25" {
            if pd >= -2 { return FastingInfo(level: .wineOil, season: season, note: "note.annunciation") }
            return FastingInfo(level: .fish, season: season, note: "note.annunciationFish")
        }
        switch pd {
        case -1: return FastingInfo(level: .strict, season: .holyWeek, note: "note.holySat")
        case -2: return FastingInfo(level: .strict, season: .holyWeek, note: "note.holyFri")
        case -3: return FastingInfo(level: .wineOil, season: .holyWeek, note: "note.holyThu")
        case -6 ... -4: return FastingInfo(level: .strict, season: .holyWeek, note: nil)
        case -7: return FastingInfo(level: .fish, season: .greatLent, note: "note.palm")
        case -8: return FastingInfo(level: .wineOil, season: .greatLent, note: "note.lazarus")
        case -48: return FastingInfo(level: .strict, season: .greatLent, note: "note.cleanMonday")
        default: break
        }
        if weekend { return FastingInfo(level: .wineOil, season: .greatLent, note: nil) }
        if pd == -17 { return FastingInfo(level: .wineOil, season: .greatLent, note: "note.greatCanon") }
        if lentWeekdayWineOil.contains(md) { return FastingInfo(level: .wineOil, season: .greatLent, note: "note.feastWineOil") }
        return FastingInfo(level: .strict, season: .greatLent, note: nil)
    }

    private static func nativityFast(church c: CivilDate, wedFri: Bool, weekend: Bool) -> FastingInfo {
        let md = c.monthDayKey
        if md == "12-24" {
            return FastingInfo(level: weekend ? .wineOil : .strict, season: .nativity, note: "note.paramoni")
        }
        if md == "11-21" { return FastingInfo(level: .fish, season: .nativity, note: "note.entryFish") }
        let secondPhase = c.month == 12 && c.day >= 12
        if secondPhase {
            if weekend { return FastingInfo(level: .wineOil, season: .nativity, note: nil) }
            if let lvl = nativityLateWineOil[md], !(wedFri && lvl == .strict) {
                return FastingInfo(level: lvl, season: .nativity, note: lvl == .wineOil ? "note.feastWineOil" : nil)
            }
            return FastingInfo(level: .strict, season: .nativity, note: nil)
        }
        if wedFri {
            if let lvl = wedFriExceptions[md] { return FastingInfo(level: max(lvl, .fish), season: .nativity, note: nil) }
            return FastingInfo(level: .strict, season: .nativity, note: nil)
        }
        return FastingInfo(level: .fish, season: .nativity, note: nil)
    }

    /// Jours de semaine du Grand Carême où vin et huile sont permis (usage GOARCH).
    static let lentWeekdayWineOil: Set<String> = ["02-24", "03-09", "03-26"]

    /// Seconde partie du Carême de Noël : saints dont la fête adoucit le jeûne en semaine.
    static let nativityLateWineOil: [String: FastLevel] = [
        "12-12": .wineOil, "12-15": .wineOil, "12-17": .wineOil, "12-20": .wineOil,
    ]

    /// Fêtes qui adoucissent le jeûne du mercredi et du vendredi (hors Grand Carême).
    static let wedFriExceptions: [String: FastLevel] = [
        "01-06": .noFast,
        "01-07": .fish,
        "02-02": .fish,
        "06-24": .fish,
        "06-29": .fish,
        "08-15": .fish,
        "09-08": .fish,
        "11-14": .fish,
        "11-21": .fish,
        "01-11": .wineOil, "01-14": .wineOil, "01-16": .wineOil, "01-17": .wineOil, "01-18": .wineOil,
        "01-20": .wineOil, "01-22": .wineOil, "01-25": .wineOil, "01-27": .wineOil, "01-30": .wineOil,
        "02-08": .wineOil, "02-10": .wineOil, "02-11": .wineOil, "02-17": .wineOil, "06-08": .wineOil,
        "06-11": .wineOil, "06-30": .wineOil, "07-01": .wineOil, "07-02": .wineOil, "07-08": .wineOil,
        "07-17": .wineOil, "07-20": .wineOil, "07-22": .wineOil, "07-25": .wineOil, "07-26": .wineOil,
        "07-27": .wineOil, "08-31": .wineOil, "09-01": .wineOil, "09-06": .wineOil, "09-09": .wineOil,
        "09-13": .wineOil, "09-20": .wineOil, "09-23": .wineOil, "09-26": .wineOil, "10-01": .wineOil,
        "10-06": .wineOil, "10-23": .wineOil, "10-26": .wineOil, "11-01": .wineOil, "11-08": .wineOil,
        "11-12": .wineOil, "11-13": .wineOil, "11-16": .wineOil, "11-25": .wineOil, "11-30": .wineOil,
        "12-04": .wineOil, "12-05": .wineOil, "12-06": .wineOil, "12-09": .wineOil,
    ]
}
