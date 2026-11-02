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

    public var label: String {
        switch self {
        case .ordinary: return "Jour ordinaire"
        case .sunday: return "Dimanche"
        case .saint: return "Fête d'un saint"
        case .major: return "Fête importante"
        case .holyWeek: return "Semaine sainte"
        case .great: return "Grande fête"
        case .pascha: return "Fête des fêtes"
        }
    }
}

/// Fête du cycle fixe (date du ménologe).
public struct FixedFeast: Sendable {
    public let title: String
    public let rank: FeastRank
    public let wikipediaTitle: String?
}

public enum FixedFeasts {
    /// Clé « MM-JJ » du ménologe.
    public static func feast(for churchDate: CivilDate) -> FixedFeast? {
        table[churchDate.monthDayKey]
    }

    static let table: [String: FixedFeast] = [
        // Les douze grandes fêtes (fixes)
        "09-08": FixedFeast(title: "Nativité de la très sainte Mère de Dieu", rank: .great, wikipediaTitle: "Nativité de Marie"),
        "09-14": FixedFeast(title: "Exaltation universelle de la précieuse et vivifiante Croix", rank: .great, wikipediaTitle: "Exaltation de la Sainte-Croix"),
        "11-21": FixedFeast(title: "Entrée au Temple de la très sainte Mère de Dieu", rank: .great, wikipediaTitle: "Présentation de Marie au Temple"),
        "12-25": FixedFeast(title: "Nativité selon la chair de notre Seigneur Jésus-Christ", rank: .great, wikipediaTitle: "Nativité de Jésus"),
        "01-06": FixedFeast(title: "Sainte Théophanie — Baptême du Christ", rank: .great, wikipediaTitle: "Théophanie"),
        "02-02": FixedFeast(title: "Hypapante — Présentation du Seigneur au Temple", rank: .great, wikipediaTitle: "Présentation de Jésus au Temple"),
        "03-25": FixedFeast(title: "Annonciation de la très sainte Mère de Dieu", rank: .great, wikipediaTitle: "Annonciation"),
        "08-06": FixedFeast(title: "Transfiguration de notre Seigneur Jésus-Christ", rank: .great, wikipediaTitle: "Transfiguration"),
        "08-15": FixedFeast(title: "Dormition de la très sainte Mère de Dieu", rank: .great, wikipediaTitle: "Dormition"),
        // Autres fêtes majeures
        "09-01": FixedFeast(title: "Début de l'année ecclésiastique (Indiction) — saint Syméon le Stylite", rank: .major, wikipediaTitle: "Syméon le Stylite"),
        "01-01": FixedFeast(title: "Circoncision du Seigneur — saint Basile le Grand", rank: .major, wikipediaTitle: "Basile de Césarée"),
        "01-07": FixedFeast(title: "Synaxe de saint Jean le Prodrome et Baptiste", rank: .major, wikipediaTitle: "Jean le Baptiste"),
        "01-30": FixedFeast(title: "Les Trois Saints Hiérarques : Basile, Grégoire et Jean Chrysostome", rank: .major, wikipediaTitle: "Trois Saints Hiérarques"),
        "06-24": FixedFeast(title: "Nativité de saint Jean le Prodrome et Baptiste", rank: .major, wikipediaTitle: "Nativité de Jean le Baptiste"),
        "06-29": FixedFeast(title: "Saints Pierre et Paul, coryphées des Apôtres", rank: .major, wikipediaTitle: "Saints Pierre et Paul"),
        "08-29": FixedFeast(title: "Décollation de saint Jean le Prodrome et Baptiste", rank: .major, wikipediaTitle: "Décollation de saint Jean-Baptiste"),
        "10-26": FixedFeast(title: "Saint Démétrios le Myroblite, grand martyr", rank: .major, wikipediaTitle: "Démétrios de Thessalonique"),
        "11-08": FixedFeast(title: "Synaxe des saints Archanges Michel, Gabriel et de toutes les Puissances célestes", rank: .major, wikipediaTitle: "Archange Michel"),
        "11-13": FixedFeast(title: "Saint Jean Chrysostome, archevêque de Constantinople", rank: .major, wikipediaTitle: "Jean Chrysostome"),
        "11-30": FixedFeast(title: "Saint André, apôtre le Premier-Appelé", rank: .major, wikipediaTitle: "André (apôtre)"),
        "12-06": FixedFeast(title: "Saint Nicolas, archevêque de Myre en Lycie, le Thaumaturge", rank: .major, wikipediaTitle: "Nicolas de Myre"),
        "12-12": FixedFeast(title: "Saint Spyridon, évêque de Trimythonte, le Thaumaturge", rank: .major, wikipediaTitle: "Spyridon de Trimythonte"),
        "01-17": FixedFeast(title: "Saint Antoine le Grand", rank: .major, wikipediaTitle: "Antoine le Grand"),
        "01-18": FixedFeast(title: "Saints Athanase et Cyrille, patriarches d'Alexandrie", rank: .saint, wikipediaTitle: "Athanase d'Alexandrie"),
        "01-25": FixedFeast(title: "Saint Grégoire le Théologien", rank: .major, wikipediaTitle: "Grégoire de Nazianze"),
        "02-10": FixedFeast(title: "Saint Charalampos, hiéromartyr", rank: .saint, wikipediaTitle: "Charalampe"),
        "04-23": FixedFeast(title: "Saint Georges, grand martyr et trophophore", rank: .major, wikipediaTitle: "Georges de Lydda"),
        "05-08": FixedFeast(title: "Saint Jean le Théologien, apôtre et évangéliste", rank: .major, wikipediaTitle: "Jean (apôtre)"),
        "05-21": FixedFeast(title: "Saints Constantin et Hélène, égaux aux apôtres", rank: .major, wikipediaTitle: "Constantin Ier (empereur romain)"),
        "06-30": FixedFeast(title: "Synaxe des douze saints Apôtres", rank: .saint, wikipediaTitle: "Douze Apôtres"),
        "07-20": FixedFeast(title: "Saint Élie le Prophète", rank: .major, wikipediaTitle: "Élie"),
        "07-26": FixedFeast(title: "Sainte Paraskévi, vierge martyre", rank: .saint, wikipediaTitle: "Parascève de Rome"),
        "07-27": FixedFeast(title: "Saint Pantéléimon, grand martyr et anargyre", rank: .saint, wikipediaTitle: "Pantaléon de Nicomédie"),
        "08-31": FixedFeast(title: "Déposition de la précieuse Ceinture de la Mère de Dieu", rank: .saint, wikipediaTitle: nil),
        "09-26": FixedFeast(title: "Dormition de saint Jean le Théologien", rank: .saint, wikipediaTitle: "Jean (apôtre)"),
        "10-28": FixedFeast(title: "Protection de la Mère de Dieu (Agia Skepi)", rank: .major, wikipediaTitle: "Protection de la Mère de Dieu"),
        "12-15": FixedFeast(title: "Saint Éleuthère, hiéromartyr", rank: .saint, wikipediaTitle: "Éleuthère d'Illyrie"),
        "12-17": FixedFeast(title: "Saint Daniel le Prophète et les Trois Jeunes Gens — saint Dionysios de Zante", rank: .saint, wikipediaTitle: "Dionysios de Zante"),
        "12-20": FixedFeast(title: "Saint Ignace le Théophore, hiéromartyr", rank: .saint, wikipediaTitle: "Ignace d'Antioche"),
        "11-09": FixedFeast(title: "Saint Nectaire d'Égine, le Thaumaturge", rank: .major, wikipediaTitle: "Nectaire d'Égine"),
        "11-25": FixedFeast(title: "Sainte Catherine, grande martyre — apodose de l'Entrée au Temple", rank: .saint, wikipediaTitle: "Catherine d'Alexandrie"),
        "11-14": FixedFeast(title: "Saint Philippe, apôtre — saint Grégoire Palamas", rank: .saint, wikipediaTitle: "Philippe (apôtre)"),
        "11-16": FixedFeast(title: "Saint Matthieu, apôtre et évangéliste", rank: .saint, wikipediaTitle: "Matthieu (apôtre)"),
        "10-18": FixedFeast(title: "Saint Luc, apôtre et évangéliste", rank: .saint, wikipediaTitle: "Luc (évangéliste)"),
        "04-25": FixedFeast(title: "Saint Marc, apôtre et évangéliste", rank: .saint, wikipediaTitle: "Marc (évangéliste)"),
        "10-06": FixedFeast(title: "Saint Thomas, apôtre", rank: .saint, wikipediaTitle: "Thomas (apôtre)"),
        "02-24": FixedFeast(title: "Première et deuxième inventions du chef de saint Jean Baptiste", rank: .saint, wikipediaTitle: "Jean le Baptiste"),
        "03-09": FixedFeast(title: "Les saints Quarante Martyrs de Sébaste", rank: .saint, wikipediaTitle: "Quarante martyrs de Sébaste"),
        "03-26": FixedFeast(title: "Synaxe de l'Archange Gabriel", rank: .saint, wikipediaTitle: "Gabriel (archange)"),
        "05-25": FixedFeast(title: "Troisième invention du chef de saint Jean Baptiste", rank: .saint, wikipediaTitle: "Jean le Baptiste"),
        "07-22": FixedFeast(title: "Sainte Marie-Madeleine, myrrhophore et égale aux apôtres", rank: .saint, wikipediaTitle: "Marie de Magdala"),
        "09-09": FixedFeast(title: "Saints Joachim et Anne, ancêtres de Dieu", rank: .saint, wikipediaTitle: "Joachim et Anne"),
        "09-23": FixedFeast(title: "Conception de saint Jean le Prodrome", rank: .saint, wikipediaTitle: nil),
        "12-09": FixedFeast(title: "Conception de sainte Anne, mère de la Mère de Dieu", rank: .saint, wikipediaTitle: nil),
        "12-04": FixedFeast(title: "Sainte Barbara, grande martyre — saint Jean Damascène", rank: .saint, wikipediaTitle: "Barbe d'Héliopolis"),
        "08-01": FixedFeast(title: "Procession de la précieuse Croix — début du Carême de la Dormition", rank: .saint, wikipediaTitle: nil),
    ]
}
