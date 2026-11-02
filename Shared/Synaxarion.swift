import Foundation

/// Une commémoration du ménologe (synaxaire) pour un jour fixe.
public struct Commemoration: Codable, Hashable, Identifiable, Sendable {
    public let fr: String
    public let en: String
    /// "f" pour une mention festale (avant-fête, après-fête, apodose…).
    public let t: String?

    public var id: String { en }
    public var isFestal: Bool { t == "f" }

    /// Nom court pour l'affichage compact (avant la première virgule).
    public var shortName: String {
        if let r = fr.range(of: ",") { return String(fr[..<r.lowerBound]) }
        if let r = fr.range(of: " — ") { return String(fr[..<r.lowerBound]) }
        return fr
    }

    /// Requête de recherche pour Wikipédia (sans « Saint », ni qualificatifs).
    public var searchQuery: String {
        var s = shortName
        for prefix in ["Saintes ", "Saints ", "Sainte ", "Saint ", "Les saints ", "Les saintes ", "Le ", "La ", "Les "] {
            if s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)); break }
        }
        return s
    }
}

/// Accès au synaxaire embarqué (`synaxaire.json`, 366 jours, ~1560 commémorations).
public final class Synaxarion: @unchecked Sendable {
    public static let shared = Synaxarion()

    private let days: [String: [Commemoration]]

    private init() {
        var loaded: [String: [Commemoration]] = [:]
        let bundles = [Bundle.main, Bundle(for: Synaxarion.self)]
        for bundle in bundles {
            if let url = bundle.url(forResource: "synaxaire", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([String: [Commemoration]].self, from: data) {
                loaded = decoded
                break
            }
        }
        self.days = loaded
    }

    /// Initialiseur de test.
    public init(data: Data) {
        self.days = (try? JSONDecoder().decode([String: [Commemoration]].self, from: data)) ?? [:]
    }

    /// Commémorations d'une date du ménologe (jour/mois ecclésiastique).
    public func commemorations(forChurchDate c: CivilDate) -> [Commemoration] {
        var list = days[c.monthDayKey] ?? []
        // Le 29 février n'existe que les années bissextiles : les années ordinaires,
        // ses saints (saint Jean Cassien) sont fêtés le 28.
        if c.month == 2 && c.day == 28 && CivilDate.daysInMonth(year: c.year, month: 2) == 28 {
            list += days["02-29"] ?? []
        }
        return list
    }
}
