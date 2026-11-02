import Foundation

/// Rang liturgique d'un jour, utilisé pour la couleur et l'importance visuelle.
public enum FeastRank: Int, Comparable, Codable, Sendable {
    case ordinary = 0
    case sunday = 1
    case saint = 2
    case major = 3
    case holyWeek = 4
    case great = 5
    case pascha = 6

    public static func < (l: FeastRank, r: FeastRank) -> Bool { l.rawValue < r.rawValue }

}

/// Fête du cycle fixe (date du ménologe).
public struct FixedFeast: Sendable {
    public let key: String
    public let rank: FeastRank
    public let wikipediaTitle: String?

    public var title: String { Loc.t(key) }
}

public enum FixedFeasts {
    /// Clé « MM-JJ » du ménologe.
    public static func feast(for churchDate: CivilDate) -> FixedFeast? {
        let md = churchDate.monthDayKey
        guard let e = table[md] else { return nil }
        return FixedFeast(key: "feast." + md, rank: e.rank, wikipediaTitle: e.wikipediaTitle)
    }

    struct Entry { let rank: FeastRank; let wikipediaTitle: String? }

    static let table: [String: Entry] = [
        // Les douze grandes fêtes (fixes)
        "09-08": Entry(rank: .great, wikipediaTitle: "Nativité de Marie"),
        "09-14": Entry(rank: .great, wikipediaTitle: "Exaltation de la Sainte-Croix"),
        "11-21": Entry(rank: .great, wikipediaTitle: "Présentation de Marie au Temple"),
        "12-25": Entry(rank: .great, wikipediaTitle: "Nativité de Jésus"),
        "01-06": Entry(rank: .great, wikipediaTitle: "Théophanie"),
        "02-02": Entry(rank: .great, wikipediaTitle: "Présentation de Jésus au Temple"),
        "03-25": Entry(rank: .great, wikipediaTitle: "Annonciation"),
        "08-06": Entry(rank: .great, wikipediaTitle: "Transfiguration"),
        "08-15": Entry(rank: .great, wikipediaTitle: "Dormition"),
        // Autres fêtes majeures
        "09-01": Entry(rank: .major, wikipediaTitle: "Syméon le Stylite"),
        "01-01": Entry(rank: .major, wikipediaTitle: "Basile de Césarée"),
        "01-07": Entry(rank: .major, wikipediaTitle: "Jean le Baptiste"),
        "01-30": Entry(rank: .major, wikipediaTitle: "Trois Saints Hiérarques"),
        "06-24": Entry(rank: .major, wikipediaTitle: "Nativité de Jean le Baptiste"),
        "06-29": Entry(rank: .major, wikipediaTitle: "Saints Pierre et Paul"),
        "08-29": Entry(rank: .major, wikipediaTitle: "Décollation de saint Jean-Baptiste"),
        "10-26": Entry(rank: .major, wikipediaTitle: "Démétrios de Thessalonique"),
        "11-08": Entry(rank: .major, wikipediaTitle: "Archange Michel"),
        "11-13": Entry(rank: .major, wikipediaTitle: "Jean Chrysostome"),
        "11-30": Entry(rank: .major, wikipediaTitle: "André (apôtre)"),
        "12-06": Entry(rank: .major, wikipediaTitle: "Nicolas de Myre"),
        "12-12": Entry(rank: .major, wikipediaTitle: "Spyridon de Trimythonte"),
        "01-17": Entry(rank: .major, wikipediaTitle: "Antoine le Grand"),
        "01-18": Entry(rank: .saint, wikipediaTitle: "Athanase d'Alexandrie"),
        "01-25": Entry(rank: .major, wikipediaTitle: "Grégoire de Nazianze"),
        "02-10": Entry(rank: .saint, wikipediaTitle: "Charalampe"),
        "04-23": Entry(rank: .major, wikipediaTitle: "Georges de Lydda"),
        "05-08": Entry(rank: .major, wikipediaTitle: "Jean (apôtre)"),
        "05-21": Entry(rank: .major, wikipediaTitle: "Constantin Ier (empereur romain)"),
        "06-30": Entry(rank: .saint, wikipediaTitle: "Douze Apôtres"),
        "07-20": Entry(rank: .major, wikipediaTitle: "Élie"),
        "07-26": Entry(rank: .saint, wikipediaTitle: "Parascève de Rome"),
        "07-27": Entry(rank: .saint, wikipediaTitle: "Pantaléon de Nicomédie"),
        "08-31": Entry(rank: .saint, wikipediaTitle: nil),
        "09-26": Entry(rank: .saint, wikipediaTitle: "Jean (apôtre)"),
        "10-28": Entry(rank: .major, wikipediaTitle: "Protection de la Mère de Dieu"),
        "12-15": Entry(rank: .saint, wikipediaTitle: "Éleuthère d'Illyrie"),
        "12-17": Entry(rank: .saint, wikipediaTitle: "Dionysios de Zante"),
        "12-20": Entry(rank: .saint, wikipediaTitle: "Ignace d'Antioche"),
        "11-09": Entry(rank: .major, wikipediaTitle: "Nectaire d'Égine"),
        "11-25": Entry(rank: .saint, wikipediaTitle: "Catherine d'Alexandrie"),
        "11-14": Entry(rank: .saint, wikipediaTitle: "Philippe (apôtre)"),
        "11-16": Entry(rank: .saint, wikipediaTitle: "Matthieu (apôtre)"),
        "10-18": Entry(rank: .saint, wikipediaTitle: "Luc (évangéliste)"),
        "04-25": Entry(rank: .saint, wikipediaTitle: "Marc (évangéliste)"),
        "10-06": Entry(rank: .saint, wikipediaTitle: "Thomas (apôtre)"),
        "02-24": Entry(rank: .saint, wikipediaTitle: "Jean le Baptiste"),
        "03-09": Entry(rank: .saint, wikipediaTitle: "Quarante martyrs de Sébaste"),
        "03-26": Entry(rank: .saint, wikipediaTitle: "Gabriel (archange)"),
        "05-25": Entry(rank: .saint, wikipediaTitle: "Jean le Baptiste"),
        "07-22": Entry(rank: .saint, wikipediaTitle: "Marie de Magdala"),
        "09-09": Entry(rank: .saint, wikipediaTitle: "Joachim et Anne"),
        "09-23": Entry(rank: .saint, wikipediaTitle: nil),
        "12-09": Entry(rank: .saint, wikipediaTitle: nil),
        "12-04": Entry(rank: .saint, wikipediaTitle: "Barbe d'Héliopolis"),
        "08-01": Entry(rank: .saint, wikipediaTitle: nil),
    ]
}
