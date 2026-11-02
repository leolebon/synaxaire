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
    public let title: String
    public let rank: FeastRank
    public let wikipediaTitle: String?
}

public enum MovableCycle {

    /// Titre liturgique français du jour mobile, s'il en a un.
    public static func day(forPaschaDistance pd: Int, weekday: Int) -> MovableDay? {
        if let fixed = table[pd] { return fixed }
        // Semaine radieuse.
        if (1...6).contains(pd) {
            let names = ["", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]
            if pd == 5 {
                return MovableDay(title: "Vendredi radieux — Notre-Dame de la Source vivifiante (Zoodochos Pigi)", rank: .major, wikipediaTitle: "Zoodochos Pege")
            }
            return MovableDay(title: "\(names[pd]) radieux — Semaine du Renouveau", rank: .major, wikipediaTitle: "Semaine radieuse")
        }
        // Semaine sainte (titres déjà dans la table) et carême : dimanches couverts par la table.
        if (-48 ... -9).contains(pd) {
            let week = (pd + 48) / 7 + 1
            if weekday != 1 && weekday != 7 {
                return MovableDay(title: "\(ordinal(week)) semaine du Grand Carême", rank: .ordinary, wikipediaTitle: nil)
            }
        }
        // Temps pascal : jours ordinaires.
        if (8...38).contains(pd) {
            return MovableDay(title: "Temps pascal — « Le Christ est ressuscité ! »", rank: .ordinary, wikipediaTitle: nil)
        }
        return nil
    }

    private static func ordinal(_ n: Int) -> String {
        n == 1 ? "1re" : "\(n)e"
    }

    static let table: [Int: MovableDay] = [
        -70: MovableDay(title: "Dimanche du Publicain et du Pharisien — début du Triode", rank: .sunday, wikipediaTitle: nil),
        -63: MovableDay(title: "Dimanche du Fils prodigue", rank: .sunday, wikipediaTitle: "Parabole du fils prodigue"),
        -57: MovableDay(title: "Samedi des âmes — commémoration de tous les défunts", rank: .sunday, wikipediaTitle: nil),
        -56: MovableDay(title: "Dimanche du Jugement dernier — dimanche de l'Apocréo (adieu à la viande)", rank: .sunday, wikipediaTitle: "Jugement dernier"),
        -50: MovableDay(title: "Samedi de la Tyrophagie — saints moines et moniales", rank: .ordinary, wikipediaTitle: nil),
        -49: MovableDay(title: "Dimanche de la Tyrophagie — dimanche du Pardon, expulsion d'Adam du Paradis", rank: .sunday, wikipediaTitle: "Dimanche du Pardon"),
        -48: MovableDay(title: "Lundi pur — début du Grand Carême", rank: .major, wikipediaTitle: "Lundi pur"),
        -43: MovableDay(title: "Samedi de saint Théodore le Tiron — miracle des colyves", rank: .ordinary, wikipediaTitle: "Théodore le Conscrit"),
        -42: MovableDay(title: "Dimanche de l'Orthodoxie — triomphe des saintes icônes", rank: .sunday, wikipediaTitle: "Triomphe de l'Orthodoxie"),
        -36: MovableDay(title: "Samedi des âmes (2e samedi du Carême)", rank: .ordinary, wikipediaTitle: nil),
        -35: MovableDay(title: "Dimanche de saint Grégoire Palamas", rank: .sunday, wikipediaTitle: "Grégoire Palamas"),
        -29: MovableDay(title: "Samedi des âmes (3e samedi du Carême)", rank: .ordinary, wikipediaTitle: nil),
        -28: MovableDay(title: "Dimanche de la Vénération de la sainte Croix", rank: .sunday, wikipediaTitle: "Vraie Croix"),
        -22: MovableDay(title: "Samedi des âmes (4e samedi du Carême)", rank: .ordinary, wikipediaTitle: nil),
        -21: MovableDay(title: "Dimanche de saint Jean Climaque", rank: .sunday, wikipediaTitle: "Jean Climaque"),
        -18: MovableDay(title: "Mercredi du Grand Canon de saint André de Crète (office du soir)", rank: .ordinary, wikipediaTitle: "André de Crète"),
        -17: MovableDay(title: "Jeudi du Grand Canon de saint André de Crète", rank: .ordinary, wikipediaTitle: "André de Crète"),
        -16: MovableDay(title: "Vendredi de l'Hymne acathiste (office du soir)", rank: .ordinary, wikipediaTitle: "Hymne acathiste"),
        -15: MovableDay(title: "Samedi de l'Acathiste", rank: .ordinary, wikipediaTitle: "Hymne acathiste"),
        -14: MovableDay(title: "Dimanche de sainte Marie l'Égyptienne", rank: .sunday, wikipediaTitle: "Marie l'Égyptienne"),
        -8: MovableDay(title: "Samedi de Lazare — résurrection de Lazare", rank: .major, wikipediaTitle: "Résurrection de Lazare"),
        -7: MovableDay(title: "Dimanche des Rameaux — entrée du Seigneur à Jérusalem", rank: .great, wikipediaTitle: "Entrée de Jésus à Jérusalem"),
        -6: MovableDay(title: "Grand et Saint Lundi — Joseph le Très-Beau, le figuier desséché", rank: .holyWeek, wikipediaTitle: "Semaine sainte"),
        -5: MovableDay(title: "Grand et Saint Mardi — parabole des dix vierges", rank: .holyWeek, wikipediaTitle: "Semaine sainte"),
        -4: MovableDay(title: "Grand et Saint Mercredi — la femme pécheresse, saint Office des Huiles", rank: .holyWeek, wikipediaTitle: "Semaine sainte"),
        -3: MovableDay(title: "Grand et Saint Jeudi — la Cène mystique, le lavement des pieds", rank: .holyWeek, wikipediaTitle: "Jeudi saint"),
        -2: MovableDay(title: "Grand et Saint Vendredi — la Passion du Seigneur, l'Épitaphios", rank: .holyWeek, wikipediaTitle: "Vendredi saint"),
        -1: MovableDay(title: "Grand et Saint Samedi — la mise au tombeau et la descente aux enfers", rank: .holyWeek, wikipediaTitle: "Samedi saint"),
        0: MovableDay(title: "Sainte et Grande Pâque — la Résurrection du Christ", rank: .pascha, wikipediaTitle: "Pâques"),
        7: MovableDay(title: "Dimanche de Thomas (Antipascha)", rank: .sunday, wikipediaTitle: "Thomas (apôtre)"),
        14: MovableDay(title: "Dimanche des saintes Femmes myrrhophores", rank: .sunday, wikipediaTitle: "Myrrhophores"),
        21: MovableDay(title: "Dimanche du Paralytique", rank: .sunday, wikipediaTitle: nil),
        24: MovableDay(title: "Mi-Pentecôte", rank: .major, wikipediaTitle: "Mi-Pentecôte"),
        28: MovableDay(title: "Dimanche de la Samaritaine", rank: .sunday, wikipediaTitle: "Femme samaritaine"),
        35: MovableDay(title: "Dimanche de l'Aveugle-né", rank: .sunday, wikipediaTitle: nil),
        38: MovableDay(title: "Apodose (clôture) de Pâques", rank: .major, wikipediaTitle: nil),
        39: MovableDay(title: "Ascension de notre Seigneur Jésus-Christ", rank: .great, wikipediaTitle: "Ascension (fête)"),
        42: MovableDay(title: "Dimanche des saints Pères du Ier concile œcuménique (Nicée, 325)", rank: .sunday, wikipediaTitle: "Premier concile de Nicée"),
        48: MovableDay(title: "Samedi des âmes avant la Pentecôte", rank: .ordinary, wikipediaTitle: nil),
        49: MovableDay(title: "Sainte Pentecôte — descente du Saint-Esprit", rank: .great, wikipediaTitle: "Pentecôte"),
        50: MovableDay(title: "Lundi du Saint-Esprit", rank: .major, wikipediaTitle: "Lundi de Pentecôte"),
        56: MovableDay(title: "Dimanche de Tous les Saints", rank: .sunday, wikipediaTitle: "Toussaint"),
        63: MovableDay(title: "Dimanche de tous les saints de Grèce (Église de Grèce)", rank: .sunday, wikipediaTitle: nil),
    ]

    /// Dimanches du cycle fixe dépendant de la date (Pères des conciles, Ancêtres…).
    public static func fixedCycleSunday(churchDate c: CivilDate, weekday: Int) -> MovableDay? {
        guard weekday == 1 else { return nil }
        switch (c.month, c.day) {
        case (7, 13...19):
            return MovableDay(title: "Dimanche des saints Pères du IVe concile œcuménique (Chalcédoine)", rank: .sunday, wikipediaTitle: "Concile de Chalcédoine")
        case (10, 11...17):
            return MovableDay(title: "Dimanche des saints Pères du VIIe concile œcuménique (Nicée II, 787)", rank: .sunday, wikipediaTitle: "Deuxième concile de Nicée")
        case (12, 11...17):
            return MovableDay(title: "Dimanche des saints Ancêtres du Christ", rank: .sunday, wikipediaTitle: nil)
        case (12, 18...24):
            return MovableDay(title: "Dimanche avant la Nativité — de la Généalogie", rank: .sunday, wikipediaTitle: nil)
        case (12, 26...31):
            return MovableDay(title: "Dimanche après la Nativité — saints Joseph, David et Jacques", rank: .sunday, wikipediaTitle: nil)
        case (1, 1...5):
            return MovableDay(title: "Dimanche avant la Théophanie", rank: .sunday, wikipediaTitle: nil)
        case (1, 7...13):
            return MovableDay(title: "Dimanche après la Théophanie", rank: .sunday, wikipediaTitle: nil)
        case (9, 7...13):
            return MovableDay(title: "Dimanche avant l'Exaltation de la Croix", rank: .sunday, wikipediaTitle: nil)
        case (9, 15...21):
            return MovableDay(title: "Dimanche après l'Exaltation de la Croix", rank: .sunday, wikipediaTitle: nil)
        default:
            return nil
        }
    }
}
