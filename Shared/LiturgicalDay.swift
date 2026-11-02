import Foundation

/// Tout ce que l'application et le widget affichent pour une journée.
public struct LiturgicalDay: Identifiable, Sendable {
    public let civil: CivilDate
    public let church: CivilDate
    public let calendar: ChurchCalendar
    public let paschaDistance: Int
    public let tone: Int

    /// Titre principal du jour (grande fête, dimanche du Triode, ou premier saint).
    public let title: String
    /// Titres secondaires (fête fixe + jour mobile, quand les deux coïncident).
    public let subtitles: [String]
    public let rank: FeastRank
    /// Vrai quand le titre est le nom du premier saint (pas une fête).
    public let titleIsSaint: Bool
    /// Article Wikipédia (fr) de la fête, quand il est connu.
    public let feastWikipediaTitle: String?

    public let commemorations: [Commemoration]
    public let fasting: FastingInfo

    public var id: Int { civil.jdn }

    /// Saints (hors mentions festales), dans l'ordre du ménologe.
    public var saints: [Commemoration] { commemorations.filter { !$0.isFestal } }

    /// Le saint mis en avant (icône du widget).
    public var primarySaint: Commemoration? { saints.first }

    public var isGreatFeast: Bool { rank >= .great }

    /// Article Wikipédia connu du saint principal (grands saints du ménologe).
    public let primarySaintWikipediaTitle: String?

    /// Article Wikipédia à utiliser pour une commémoration donnée, s'il est connu.
    public func wikipediaTitle(for c: Commemoration) -> String? {
        c == primarySaint ? primarySaintWikipediaTitle : nil
    }

    /// Source de l'icône principale du jour : la fête si elle est connue, sinon le premier saint.
    public var heroWikipediaTitle: String? { feastWikipediaTitle ?? primarySaintWikipediaTitle }

    public init(civil: CivilDate, calendar: ChurchCalendar, synaxarion: Synaxarion = .shared) {
        self.civil = civil
        self.calendar = calendar
        let church = calendar.churchDate(for: civil)
        self.church = church
        let pd = Paschalion.distance(from: civil)
        self.paschaDistance = pd
        self.tone = Paschalion.tone(for: civil)
        self.fasting = FastingRules.fasting(civil: civil, calendar: calendar)

        var list = synaxarion.commemorations(forChurchDate: church)

        // Usage grec : si saint Georges (23 avril) tombe avant Pâques, il est fêté le lundi radieux.
        let georgeDate = calendar.civilDate(forChurch: 4, day: 23, civilYear: civil.year)
        let georgeBeforePascha = Paschalion.distance(from: georgeDate) < 1
        if church.month == 4 && church.day == 23 && georgeBeforePascha {
            list = list.map { c in
                c.en.hasPrefix("George the Great Martyr")
                    ? Commemoration(fr: c.fr + Loc.t("george.suffix"), en: c.en + Loc.t("george.suffix"), t: nil)
                    : c
            }
        }
        if pd == 1 && georgeBeforePascha {
            let george = synaxarion.commemorations(forChurchDate: CivilDate(year: church.year, month: 4, day: 23))
            list = george + list
        }
        self.commemorations = list

        let movable = MovableCycle.day(forPaschaDistance: pd, weekday: civil.weekday)
            ?? MovableCycle.fixedCycleSunday(churchDate: church, weekday: civil.weekday)
        let georgeTransferredToday = church.month == 4 && church.day == 23 && georgeBeforePascha
        let fixed = georgeTransferredToday ? nil : FixedFeasts.feast(for: church)
        self.primarySaintWikipediaTitle = fixed?.wikipediaTitle

        var titles: [(String, FeastRank, String?)] = []
        if let m = movable { titles.append((m.title, m.rank, m.wikipediaTitle)) }
        if let f = fixed { titles.append((f.title, f.rank, f.wikipediaTitle)) }
        if pd == 1 && georgeBeforePascha {
            titles.append((Loc.t("george.title"), .major, "Georges de Lydda"))
        }
        // La fête du rang le plus élevé passe en premier.
        titles.sort { $0.1 > $1.1 }

        if let first = titles.first, first.1 >= .sunday || movable == nil {
            self.title = first.0
            self.titleIsSaint = false
            self.rank = max(first.1, civil.isSunday ? .sunday : .ordinary)
            self.feastWikipediaTitle = first.2
            self.subtitles = titles.dropFirst().map { $0.0 }
        } else if let m = movable {
            // Jour de semaine ordinaire du Carême ou du temps pascal : le saint du jour devient le titre.
            let saintTitle = list.first(where: { !$0.isFestal })?.displayName ?? m.title
            self.title = saintTitle
            self.titleIsSaint = true
            self.rank = civil.isSunday ? .sunday : .ordinary
            self.feastWikipediaTitle = nil
            self.subtitles = [m.title] + titles.dropFirst().map { $0.0 }
        } else {
            self.title = list.first(where: { !$0.isFestal })?.displayName ?? list.first?.displayName ?? Loc.t("ferial")
            self.titleIsSaint = !list.isEmpty
            self.rank = civil.isSunday ? .sunday : (list.isEmpty ? .ordinary : .saint)
            self.feastWikipediaTitle = nil
            self.subtitles = []
        }
    }
}

// MARK: - Périodes de jeûne de l'année

public struct FastPeriod: Identifiable, Sendable {
    public let season: FastSeason
    public let start: CivilDate
    public let end: CivilDate
    public var id: String { "\(season.rawValue)-\(start.jdn)" }

    public func contains(_ d: CivilDate) -> Bool { d >= start && d <= end }
}

public enum FastCalendar {
    /// Grands carêmes et semaines sans jeûne de l'année civile, triés par date.
    public static func periods(year: Int, calendar: ChurchCalendar) -> [FastPeriod] {
        let p = Paschalion.pascha(year: year)
        var out: [FastPeriod] = []
        out.append(FastPeriod(season: .publicanWeek, start: p.adding(days: -69), end: p.adding(days: -64)))
        out.append(FastPeriod(season: .cheesefare, start: p.adding(days: -55), end: p.adding(days: -49)))
        out.append(FastPeriod(season: .greatLent, start: p.adding(days: -48), end: p.adding(days: -9)))
        out.append(FastPeriod(season: .holyWeek, start: p.adding(days: -6), end: p.adding(days: -1)))
        out.append(FastPeriod(season: .brightWeek, start: p, end: p.adding(days: 6)))
        out.append(FastPeriod(season: .trinityWeek, start: p.adding(days: 50), end: p.adding(days: 55)))

        let apostlesStart = p.adding(days: 57)
        let apostlesEnd = calendar.civilDate(forChurch: 6, day: 28, civilYear: year)
        if apostlesStart <= apostlesEnd {
            out.append(FastPeriod(season: .apostles, start: apostlesStart, end: apostlesEnd))
        }
        out.append(FastPeriod(season: .dormition,
                              start: calendar.civilDate(forChurch: 8, day: 1, civilYear: year),
                              end: calendar.civilDate(forChurch: 8, day: 14, civilYear: year)))
        out.append(FastPeriod(season: .nativity,
                              start: calendar.civilDate(forChurch: 11, day: 15, civilYear: year),
                              end: calendar.civilDate(forChurch: 12, day: 24, civilYear: year)))
        out.append(FastPeriod(season: .christmastide,
                              start: calendar.civilDate(forChurch: 12, day: 25, civilYear: year),
                              end: calendar.civilDate(forChurch: 1, day: 4, civilYear: year + 1)))
        // Fin du Dodécaémeron de l'année précédente (janvier).
        out.append(FastPeriod(season: .christmastide,
                              start: calendar.civilDate(forChurch: 12, day: 25, civilYear: year - 1),
                              end: calendar.civilDate(forChurch: 1, day: 4, civilYear: year)))
        // Ancien calendrier : le Carême de Noël de l'année précédente déborde sur janvier.
        if calendar == .oldCalendar {
            out.append(FastPeriod(season: .nativity,
                                  start: calendar.civilDate(forChurch: 11, day: 15, civilYear: year - 1),
                                  end: calendar.civilDate(forChurch: 12, day: 24, civilYear: year - 1)))
        }
        return out.filter { $0.end.year >= year && $0.start.year <= year }
            .sorted { $0.start < $1.start }
    }

    /// Prochaine grande période de jeûne (ou celle en cours) à partir d'une date.
    public static func currentOrNextLent(from d: CivilDate, calendar: ChurchCalendar) -> FastPeriod? {
        let all = (periods(year: d.year, calendar: calendar) + periods(year: d.year + 1, calendar: calendar))
            .filter { $0.season.isLent && $0.season != .cheesefare }
        return all.first(where: { $0.end >= d })
    }
}
