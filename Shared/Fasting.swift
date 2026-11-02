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

    public var title: String {
        switch self {
        case .noFast: return "Pas de jeûne"
        case .fastFree: return "Sans jeûne"
        case .dairy: return "Jeûne de la viande"
        case .fish: return "Poisson permis"
        case .wineOil: return "Vin et huile permis"
        case .strict: return "Jeûne strict"
        }
    }

    public var shortTitle: String {
        switch self {
        case .noFast: return "Pas de jeûne"
        case .fastFree: return "Sans jeûne"
        case .dairy: return "Sans viande"
        case .fish: return "Poisson"
        case .wineOil: return "Vin & huile"
        case .strict: return "Strict"
        }
    }

    public var explanation: String {
        switch self {
        case .noFast:
            return "Aucune restriction alimentaire aujourd'hui."
        case .fastFree:
            return "Période sans jeûne : tout est permis, y compris le mercredi et le vendredi."
        case .dairy:
            return "On s'abstient de viande. Laitages, œufs, poisson, vin et huile sont permis."
        case .fish:
            return "On s'abstient de viande, de laitages et d'œufs. Le poisson, le vin et l'huile sont permis."
        case .wineOil:
            return "On s'abstient de viande, de laitages, d'œufs et de poisson. Le vin et l'huile d'olive sont permis."
        case .strict:
            return "Xérophagie : on s'abstient de viande, laitages, œufs, poisson, mais aussi d'huile et de vin. Légumes, légumineuses, fruits, pain."
        }
    }

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

    public var label: String {
        switch self {
        case .meat: return "Viande"
        case .dairy: return "Laitages"
        case .eggs: return "Œufs"
        case .fish: return "Poisson"
        case .oil: return "Huile"
        case .wine: return "Vin"
        case .shellfish: return "Fruits de mer"
        }
    }

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

    public var title: String {
        switch self {
        case .ordinary: return "Temps ordinaire"
        case .wednesdayFriday: return "Jeûne du mercredi et du vendredi"
        case .paschalSeason: return "Temps pascal"
        case .christmastide: return "Dodécaémeron (de Noël à la Théophanie)"
        case .publicanWeek: return "Semaine du Publicain et du Pharisien"
        case .brightWeek: return "Semaine radieuse"
        case .trinityWeek: return "Semaine de la Pentecôte"
        case .cheesefare: return "Semaine de la Tyrophagie"
        case .greatLent: return "Grand Carême"
        case .holyWeek: return "Semaine sainte"
        case .apostles: return "Carême des Apôtres"
        case .dormition: return "Carême de la Dormition"
        case .nativity: return "Carême de la Nativité"
        case .strictDay: return "Jour de jeûne strict"
        }
    }

    /// Les grands carêmes, affichés comme « périodes ».
    public var isLent: Bool {
        switch self {
        case .greatLent, .holyWeek, .apostles, .dormition, .nativity, .cheesefare: return true
        default: return false
        }
    }

    /// Recommandations spirituelles et pratiques pour la période.
    public var recommendations: [String] {
        switch self {
        case .greatLent:
            return [
                "Du lundi au vendredi : xérophagie (ni huile ni vin) ; samedi et dimanche : vin et huile.",
                "Poisson permis à l'Annonciation (25 mars) et au dimanche des Rameaux ; œufs de poisson (tarama) le samedi de Lazare.",
                "Les trois premiers jours (Lundi pur → mercredi), la tradition recommande une abstinence complète ou très légère jusqu'à la Liturgie des Présanctifiés.",
                "Offices propres : Grand Canon de saint André (1re semaine), Présanctifiés le mercredi et le vendredi, Salutations à la Mère de Dieu le vendredi soir.",
                "Le jeûne va avec la prière, l'aumône, la confession et le pardon mutuel ; il s'adapte selon la santé, avec la bénédiction du père spirituel.",
            ]
        case .holyWeek:
            return [
                "Semaine la plus stricte de l'année : xérophagie chaque jour, vin et huile le Grand Jeudi.",
                "Le Grand Vendredi, beaucoup ne mangent rien jusqu'à la mise au tombeau (Épitaphios) ; jour d'abstinence totale si possible.",
                "Le Grand Samedi, jeûne strict ; la tradition admet un peu de vin après la Liturgie de saint Basile.",
                "Se préparer à la communion pascale par la confession au début de la semaine.",
            ]
        case .cheesefare:
            return [
                "Dernière semaine avant le Carême : plus de viande, mais laitages, œufs et poisson sont permis tous les jours, même le mercredi et le vendredi.",
                "Le dimanche du Pardon, on se demande mutuellement pardon aux Vêpres du soir.",
            ]
        case .apostles:
            return [
                "Selon l'usage grec (GOARCH) : poisson, vin et huile permis tous les jours sauf le mercredi et le vendredi.",
                "Mercredi et vendredi : jeûne strict, sauf fête (Nativité du Prodrome le 24 juin : poisson).",
                "Le carême s'achève avec la fête des saints Pierre et Paul (29 juin).",
            ]
        case .dormition:
            return [
                "Du 1er au 14 août : jeûne strict en semaine, vin et huile le samedi et le dimanche.",
                "Poisson permis à la Transfiguration (6 août).",
                "On chante chaque soir la Paraclisis (petite ou grande supplication) à la Mère de Dieu.",
            ]
        case .nativity:
            return [
                "Du 15 novembre au 11 décembre : poisson, vin et huile permis, sauf le mercredi et le vendredi (jeûne strict, ou vin et huile en cas de fête).",
                "Du 12 au 24 décembre : plus de poisson ; vin et huile le samedi et le dimanche, jeûne strict en semaine.",
                "Poisson à l'Entrée au Temple de la Mère de Dieu (21 novembre).",
                "La veille de Noël (24 décembre) : jeûne strict, traditionnellement jusqu'à la première étoile ou après la Liturgie.",
            ]
        case .wednesdayFriday:
            return [
                "Le mercredi (trahison du Christ) et le vendredi (Crucifixion) sont jours de jeûne toute l'année, hors périodes sans jeûne.",
                "Jeûne strict par défaut ; vin et huile, ou poisson, lorsqu'une fête tombe ce jour-là.",
            ]
        case .paschalSeason:
            return [
                "De Thomas à la Pentecôte, le jeûne du mercredi et du vendredi est adouci : vin et huile permis.",
                "Poisson à la Mi-Pentecôte et à l'Apodose de Pâques.",
                "On se salue par « Le Christ est ressuscité ! — En vérité Il est ressuscité ! » jusqu'à l'Ascension.",
            ]
        case .christmastide:
            return ["Du 25 décembre au 4 janvier : aucun jeûne.", "La veille de la Théophanie (5 janvier) est un jour de jeûne strict."]
        case .publicanWeek:
            return ["Semaine sans jeûne, pour ne pas imiter l'orgueil du pharisien qui « jeûnait deux fois la semaine »."]
        case .brightWeek:
            return ["Toute la semaine est un seul jour de Pâques : aucun jeûne."]
        case .trinityWeek:
            return ["Semaine sans jeûne après la Pentecôte. Le Carême des Apôtres commence le lundi suivant le dimanche de Tous les Saints."]
        case .strictDay:
            return [
                "Jour de jeûne strict quel que soit le jour de la semaine (veille de la Théophanie, Décollation du Prodrome, Exaltation de la Croix).",
                "S'il tombe un samedi ou un dimanche, vin et huile sont permis.",
            ]
        case .ordinary:
            return []
        }
    }
}

/// Résultat complet du calcul du jeûne pour une journée.
public struct FastingInfo: Sendable {
    public let level: FastLevel
    public let season: FastSeason
    /// Précision propre au jour (ex. « Œufs de poisson permis »).
    public let note: String?

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
            return FastingInfo(level: .dairy, season: .cheesefare, note: pd == -49 ? "Dernier jour des laitages avant le Carême" : nil)
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
            if c.day == 6 { return FastingInfo(level: .fish, season: .dormition, note: "Transfiguration : poisson permis") }
            return FastingInfo(level: weekend ? .wineOil : .strict, season: .dormition, note: nil)
        }

        // 7. Carême de la Nativité : 15 novembre – 24 décembre.
        if (c.month == 11 && c.day >= 15) || (c.month == 12 && c.day <= 24) {
            return nativityFast(church: c, wedFri: wedFri, weekend: weekend)
        }

        // 8. Carême des Apôtres : lundi après Tous les Saints → 28 juin.
        if pd >= 57 && (c.month < 6 || (c.month == 6 && c.day <= 28)) {
            if md == "06-24" { return FastingInfo(level: .fish, season: .apostles, note: "Nativité du Prodrome : poisson permis") }
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
            return FastingInfo(level: lvl, season: .wednesdayFriday, note: lvl == .fish ? "Fête : poisson permis" : (lvl == .wineOil ? "Fête : vin et huile permis" : nil))
        }
        return FastingInfo(level: .strict, season: .wednesdayFriday, note: nil)
    }

    private static func greatLent(pd: Int, church c: CivilDate, weekend: Bool) -> FastingInfo {
        let md = c.monthDayKey
        let holy = pd >= -6
        let season: FastSeason = holy ? .holyWeek : .greatLent
        if md == "03-25" {
            if pd >= -2 { return FastingInfo(level: .wineOil, season: season, note: "Annonciation") }
            return FastingInfo(level: .fish, season: season, note: "Annonciation : poisson permis")
        }
        switch pd {
        case -1: return FastingInfo(level: .strict, season: .holyWeek, note: "Un peu de vin est d'usage après la Liturgie de saint Basile")
        case -2: return FastingInfo(level: .strict, season: .holyWeek, note: "Abstinence totale recommandée jusqu'à la mise au tombeau")
        case -3: return FastingInfo(level: .wineOil, season: .holyWeek, note: "Jeudi de la Cène : vin et huile")
        case -6 ... -4: return FastingInfo(level: .strict, season: .holyWeek, note: nil)
        case -7: return FastingInfo(level: .fish, season: .greatLent, note: "Rameaux : poisson permis")
        case -8: return FastingInfo(level: .wineOil, season: .greatLent, note: "Samedi de Lazare : œufs de poisson (tarama) permis")
        case -48: return FastingInfo(level: .strict, season: .greatLent, note: "Lundi pur : abstinence complète recommandée jusqu'au soir")
        default: break
        }
        if weekend { return FastingInfo(level: .wineOil, season: .greatLent, note: nil) }
        if pd == -17 { return FastingInfo(level: .wineOil, season: .greatLent, note: "Grand Canon : vin et huile") }
        if lentWeekdayWineOil.contains(md) { return FastingInfo(level: .wineOil, season: .greatLent, note: "Fête : vin et huile") }
        return FastingInfo(level: .strict, season: .greatLent, note: nil)
    }

    private static func nativityFast(church c: CivilDate, wedFri: Bool, weekend: Bool) -> FastingInfo {
        let md = c.monthDayKey
        if md == "12-24" {
            return FastingInfo(level: weekend ? .wineOil : .strict, season: .nativity, note: "Veille de Noël (Paramoni)")
        }
        if md == "11-21" { return FastingInfo(level: .fish, season: .nativity, note: "Entrée au Temple : poisson permis") }
        let secondPhase = c.month == 12 && c.day >= 12
        if secondPhase {
            if weekend { return FastingInfo(level: .wineOil, season: .nativity, note: nil) }
            if let lvl = nativityLateWineOil[md], !(wedFri && lvl == .strict) {
                return FastingInfo(level: lvl, season: .nativity, note: lvl == .wineOil ? "Fête : vin et huile" : nil)
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
