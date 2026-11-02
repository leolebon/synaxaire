import Foundation

/// Langue de l'application et traductions (fichier `i18n.json`, partagé avec Android).
public enum Loc {
    public struct Language: Hashable, Identifiable, Sendable {
        public let code: String
        public let name: String
        public let rtl: Bool
        public var id: String { code }
    }

    /// Langue courante (code ISO : fr, en, el, ru, ro, ar).
    public static var language: String = "fr"

    public static let defaultLanguage = "fr"

    private static var table: [String: [String: String]] = loadFromBundle()
    private static var languageList: [Language] = []

    public static var languages: [Language] {
        if languageList.isEmpty { _ = table }
        return languageList.isEmpty
            ? [Language(code: "fr", name: "Français", rtl: false)]
            : languageList
    }

    public static var isRTL: Bool { languages.first(where: { $0.code == language })?.rtl ?? false }

    /// Langue de l'appareil si elle est prise en charge, sinon le français.
    public static var deviceLanguage: String {
        let supported = Set(languages.map(\.code))
        for id in Locale.preferredLanguages {
            let code = String(id.prefix(2)).lowercased()
            if supported.contains(code) { return code }
        }
        return defaultLanguage
    }

    /// Traduction d'une clé, avec remplacement des {paramètres}.
    public static func t(_ key: String, _ args: [String: String] = [:]) -> String {
        let entry = table[key]
        var s = entry?[language] ?? entry?["en"] ?? entry?["fr"] ?? key
        for (k, v) in args { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
        return s
    }

    public static func has(_ key: String) -> Bool { table[key] != nil }

    /// Chargement explicite (tests en ligne de commande).
    public static func load(data: Data) {
        table = parse(data)
    }

    private static func loadFromBundle() -> [String: [String: String]] {
        for bundle in [Bundle.main, Bundle(for: BundleToken.self)] {
            if let url = bundle.url(forResource: "i18n", withExtension: "json"),
               let data = try? Data(contentsOf: url) {
                return parse(data)
            }
        }
        return [:]
    }

    private static func parse(_ data: Data) -> [String: [String: String]] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        if let langs = root["languages"] as? [[String: Any]] {
            languageList = langs.compactMap { l in
                guard let code = l["code"] as? String, let name = l["name"] as? String else { return nil }
                return Language(code: code, name: name, rtl: (l["rtl"] as? Bool) ?? false)
            }
        }
        return (root["strings"] as? [String: [String: String]]) ?? [:]
    }
}

private final class BundleToken {}

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
