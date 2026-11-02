import AppIntents
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Configuration (réglages propres au widget)

enum CalendarChoice: String, AppEnum {
    case newCalendar
    case oldCalendar

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Calendrier / Calendar"
    static var caseDisplayRepresentations: [CalendarChoice: DisplayRepresentation] = [
        .newCalendar: "Nouveau calendrier / New Calendar",
        .oldCalendar: "Ancien calendrier / Old Calendar",
    ]

    var church: ChurchCalendar { self == .oldCalendar ? .oldCalendar : .newCalendar }
}

enum WidgetLanguage: String, AppEnum {
    case automatic, fr, en, el, ru, ro, ar

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Langue / Language"
    static var caseDisplayRepresentations: [WidgetLanguage: DisplayRepresentation] = [
        .automatic: "Automatique / Automatic",
        .fr: "Français",
        .en: "English",
        .el: "Ελληνικά",
        .ru: "Русский",
        .ro: "Română",
        .ar: "العربية",
    ]

    var code: String { self == .automatic ? Loc.deviceLanguage : rawValue }
}

struct SynaxaireConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Synaxaire"
    static var description = IntentDescription("Calendrier orthodoxe / Orthodox calendar")

    @Parameter(title: "Calendrier / Calendar", default: .newCalendar)
    var calendar: CalendarChoice

    @Parameter(title: "Langue / Language", default: .automatic)
    var language: WidgetLanguage

    @Parameter(title: "Icône / Icon", default: true)
    var showIcon: Bool

    init() {}
}

// MARK: - Entrée de la timeline

struct WidgetSaint: Identifiable, Sendable {
    let id: Int
    let name: String
    let initial: String
    let image: UIImage?
}

struct DayEntry: TimelineEntry {
    let date: Date
    let language: String
    let civil: CivilDate
    let calendar: ChurchCalendar
    let title: String
    let subtitle: String?
    let rank: FeastRank
    let saints: [String]
    let fasting: FastLevel
    let fastNote: String?
    let season: FastSeason
    let initial: String
    let image: UIImage?
    let showIcon: Bool
    /// Saints avec leur icône (widget « Saints du jour »).
    let gallery: [WidgetSaint]

    static func make(for civil: CivilDate, date: Date, calendar: ChurchCalendar, language: String,
                     image: UIImage?, showIcon: Bool, gallery: [WidgetSaint] = [],
                     localizedTitle: String? = nil) -> DayEntry {
        Loc.language = language
        let day = LiturgicalDay(civil: civil, calendar: calendar)
        let title = (day.titleIsSaint ? localizedTitle : nil) ?? day.title
        let saintNames = day.saints.map { $0.shortName }.filter { $0 != day.title }
        return DayEntry(date: date,
                        language: language,
                        civil: civil,
                        calendar: calendar,
                        title: title,
                        subtitle: day.subtitles.first,
                        rank: day.rank,
                        saints: Array(saintNames.prefix(5)),
                        fasting: day.fasting.level,
                        fastNote: day.fasting.note,
                        season: day.fasting.season,
                        initial: day.primarySaint?.initial ?? "☦",
                        image: image,
                        showIcon: showIcon,
                        gallery: gallery)
    }

    static var sample: DayEntry {
        make(for: CivilDate(year: 2026, month: 11, day: 13), date: Date(), calendar: .newCalendar,
             language: Loc.deviceLanguage, image: nil, showIcon: true,
             gallery: [WidgetSaint(id: 0, name: "Jean Chrysostome", initial: "J", image: nil),
                       WidgetSaint(id: 1, name: "Anthousa", initial: "A", image: nil),
                       WidgetSaint(id: 2, name: "Damascène", initial: "D", image: nil)])
    }
}

// MARK: - Chargement des données (partagé par les deux widgets)

enum WidgetData {
    /// Délai maximal par chargement réseau, pour respecter le budget du widget.
    static func withTimeout<T: Sendable>(_ seconds: Double, _ work: @escaping @Sendable () async -> T?) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// Entrée complète d'un jour : icône principale, nom localisé et (option) galerie.
    static func entry(for civil: CivilDate, date: Date, calendar: ChurchCalendar, language: String,
                      showIcon: Bool, galleryCount: Int) async -> DayEntry {
        Loc.language = language
        let day = LiturgicalDay(civil: civil, calendar: calendar)
        var image: UIImage?
        var localizedTitle: String?
        if showIcon, let source = IconSource.hero(for: day) {
            let profile = await withTimeout(12) { await IconLoader.profile(for: source, language: language) }
            image = await withTimeout(8) { await IconLoader.image(for: profile, maxPixel: 360) }
            if day.titleIsSaint, language != "fr", language != "en", let profile, profile.language == language {
                localizedTitle = profile.name
            }
        }
        var gallery: [WidgetSaint] = []
        if galleryCount > 0 {
            let saints = Array(day.saints.prefix(galleryCount))
            gallery = await withTaskGroup(of: WidgetSaint.self) { group in
                for (i, c) in saints.enumerated() {
                    let known = day.wikipediaTitle(for: c)
                    group.addTask {
                        let profile = await withTimeout(12) {
                            await IconLoader.profile(for: .saint(c, knownTitle: known), language: language)
                        }
                        let img = await withTimeout(8) { await IconLoader.image(for: profile, maxPixel: 240) }
                        var name = c.shortName
                        if language != "fr", language != "en", let profile, profile.language == language { name = profile.name }
                        return WidgetSaint(id: i, name: name, initial: c.initial, image: img)
                    }
                }
                var out: [WidgetSaint] = []
                for await s in group { out.append(s) }
                return out.sorted { $0.id < $1.id }
            }
        }
        return DayEntry.make(for: civil, date: date, calendar: calendar, language: language,
                             image: image, showIcon: showIcon, gallery: gallery, localizedTitle: localizedTitle)
    }

    static func timeline(calendar: ChurchCalendar, language: String, showIcon: Bool, galleryCount: Int) async -> Timeline<DayEntry> {
        let now = Date()
        let cal = Calendar.current
        let today = CivilDate(date: now, calendar: cal)
        let tomorrow = today.adding(days: 1)
        let tomorrowStart = tomorrow.date(in: cal)
        let first = await entry(for: today, date: now, calendar: calendar, language: language,
                                showIcon: showIcon, galleryCount: galleryCount)
        let second = await entry(for: tomorrow, date: tomorrowStart, calendar: calendar, language: language,
                                 showIcon: showIcon, galleryCount: galleryCount)
        // Sans réseau, on réessaie dans une heure ; sinon on se recharge après minuit.
        let missing = (showIcon && first.image == nil) || (galleryCount > 0 && first.gallery.contains { $0.image == nil })
        let refresh = missing ? min(now.addingTimeInterval(3600), tomorrowStart) : tomorrowStart.addingTimeInterval(1800)
        return Timeline(entries: [first, second], policy: .after(refresh))
    }
}

// MARK: - Widget « Synaxaire » (petit, moyen, grand, écran verrouillé)

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DayEntry { .sample }

    func snapshot(for configuration: SynaxaireConfigIntent, in context: Context) async -> DayEntry {
        if context.isPreview { return .sample }
        return await WidgetData.entry(for: CivilDate.today(), date: Date(), calendar: configuration.calendar.church,
                                      language: configuration.language.code, showIcon: configuration.showIcon, galleryCount: 0)
    }

    func timeline(for configuration: SynaxaireConfigIntent, in context: Context) async -> Timeline<DayEntry> {
        await WidgetData.timeline(calendar: configuration.calendar.church, language: configuration.language.code,
                                  showIcon: configuration.showIcon, galleryCount: 0)
    }
}

struct SynaxaireWidgetView: View {
    let entry: DayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let _ = { Loc.language = entry.language }()
        Group {
            switch family {
            case .systemSmall: SmallView(entry: entry)
            case .systemMedium: MediumView(entry: entry)
            case .systemLarge, .systemExtraLarge: LargeView(entry: entry)
            case .accessoryRectangular: RectangularView(entry: entry)
            case .accessoryInline: InlineView(entry: entry)
            case .accessoryCircular: CircularView(entry: entry)
            @unknown default: SmallView(entry: entry)
            }
        }
        .environment(\.layoutDirection, Loc.isRTL ? .rightToLeft : .leftToRight)
    }
}

private struct WidgetIcon: View {
    let entry: DayEntry
    let size: CGSize
    var radius: CGFloat = 8

    var body: some View {
        IconFrame(image: entry.image, initial: entry.initial, cornerRadius: radius)
            .iconSize(size)
    }
}

private struct DateHeader: View {
    let entry: DayEntry
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(DateText.weekday(entry.civil.weekday).uppercased())
                .font(.system(size: compact ? 9 : 10, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(Theme.burgundy)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(entry.civil.day))
                    .font(.system(size: compact ? 26 : 30, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text(DateText.monthGenitive(entry.civil.month))
                    .font(.system(size: compact ? 11 : 12, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .layoutPriority(1)
    }
}

private struct SmallView: View {
    let entry: DayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                DateHeader(entry: entry, compact: true)
                Spacer(minLength: 0)
                if entry.showIcon {
                    WidgetIcon(entry: entry, size: IconSize.widgetSmall, radius: 6)
                }
            }
            Spacer(minLength: 0)
            Text(entry.title)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(entry.rank >= .sunday ? entry.rank.color : Theme.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            FastBadge(level: entry.fasting, compact: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Theme.parchment }
        .widgetURL(URL(string: "synaxaire://jour"))
    }
}

private struct MediumView: View {
    let entry: DayEntry

    var body: some View {
        HStack(spacing: 12) {
            if entry.showIcon {
                WidgetIcon(entry: entry, size: IconSize.widgetMedium, radius: 10)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(DateText.weekday(entry.civil.weekday).capitalized + " " + DateText.dayMonth(entry.civil))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.burgundy)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if !entry.rank.marks.isEmpty {
                        Text(entry.rank.marks).font(.system(size: 11)).foregroundStyle(entry.rank.color)
                    }
                }
                Text(entry.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(entry.rank >= .sunday ? entry.rank.color : Theme.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                if let other = entry.subtitle ?? entry.saints.first {
                    Text(other)
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    FastBadge(level: entry.fasting, compact: true)
                    if entry.season != .ordinary && entry.season != .wednesdayFriday {
                        Text(entry.season.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Theme.parchment }
        .widgetURL(URL(string: "synaxaire://jour"))
    }
}

private struct LargeView: View {
    let entry: DayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if entry.showIcon {
                    WidgetIcon(entry: entry, size: IconSize.widgetLarge, radius: 12)
                }
                VStack(alignment: .leading, spacing: 4) {
                    DateHeader(entry: entry)
                    if entry.calendar == .oldCalendar {
                        Text(Loc.t("day.menologion", ["d": DateText.dayMonth(entry.calendar.churchDate(for: entry.civil))]))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Text(entry.title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(entry.rank >= .sunday ? entry.rank.color : Theme.ink)
                        .lineLimit(4)
                        .minimumScaleFactor(0.75)
                    if let sub = entry.subtitle {
                        Text(sub)
                            .font(.system(size: 11, design: .serif))
                            .italic()
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(2)
                    }
                }
            }

            if !entry.saints.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Loc.t("widget.alsoCelebrated"))
                        .font(.system(size: 9, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(Theme.gold)
                    ForEach(Array(entry.saints.prefix(4).enumerated()), id: \.offset) { _, name in
                        Text("☩ " + name)
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    FastBadge(level: entry.fasting)
                    Spacer(minLength: 0)
                    Text(entry.season.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if let note = entry.fastNote {
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.burgundy)
                        .lineLimit(2)
                }
                FoodChips(level: entry.fasting)
            }
            .padding(10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Theme.parchment }
        .widgetURL(URL(string: "synaxaire://jour"))
    }
}

private struct RectangularView: View {
    let entry: DayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text("☦ " + DateText.dayMonth(entry.civil))
                    .font(.system(size: 12, weight: .bold))
                Spacer(minLength: 0)
                Image(systemName: entry.fasting.symbol)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(entry.title)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(entry.fasting.title)
                .font(.system(size: 11))
                .lineLimit(1)
                .opacity(0.8)
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
    }
}

private struct InlineView: View {
    let entry: DayEntry

    var body: some View {
        Text("☦ " + (entry.saints.first ?? entry.title) + " · " + entry.fasting.shortTitle)
            .containerBackground(for: .widget) { Color.clear }
    }
}

private struct CircularView: View {
    let entry: DayEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(String(entry.civil.day))
                    .font(.system(size: 20, weight: .bold, design: .serif))
                Image(systemName: entry.fasting.symbol)
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct SynaxaireWidget: Widget {
    let kind = "SynaxaireWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SynaxaireConfigIntent.self, provider: Provider()) { entry in
            SynaxaireWidgetView(entry: entry)
        }
        .configurationDisplayName("Synaxaire")
        .description(Loc.t("widget.desc"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

// MARK: - Widget « Saints du jour » (mosaïque d'icônes, moyen et grand)

struct SaintsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DayEntry { .sample }

    func snapshot(for configuration: SynaxaireConfigIntent, in context: Context) async -> DayEntry {
        if context.isPreview { return .sample }
        return await WidgetData.entry(for: CivilDate.today(), date: Date(), calendar: configuration.calendar.church,
                                      language: configuration.language.code, showIcon: false, galleryCount: 6)
    }

    func timeline(for configuration: SynaxaireConfigIntent, in context: Context) async -> Timeline<DayEntry> {
        await WidgetData.timeline(calendar: configuration.calendar.church, language: configuration.language.code,
                                  showIcon: false, galleryCount: 6)
    }
}

struct SaintsWidgetView: View {
    let entry: DayEntry
    @Environment(\.widgetFamily) private var family

    private var maxTiles: Int { family == .systemLarge ? 6 : 3 }

    var body: some View {
        let _ = { Loc.language = entry.language }()
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(DateText.weekday(entry.civil.weekday).capitalized + " " + DateText.dayMonth(entry.civil))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.burgundy)
                    .lineLimit(1)
                Spacer(minLength: 4)
                FastBadge(level: entry.fasting, compact: true)
            }
            if family == .systemLarge {
                Text(entry.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(entry.rank >= .sunday ? entry.rank.color : Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            let tiles = Array(entry.gallery.prefix(maxTiles))
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 3)
            LazyVGrid(columns: columns, alignment: .center, spacing: 8) {
                ForEach(tiles) { saint in
                    VStack(spacing: 3) {
                        IconFrame(image: saint.image, initial: saint.initial, cornerRadius: 8)
                            .iconSize(IconSize.widgetTile)
                        Text(saint.name)
                            .font(.system(size: 9, weight: .medium, design: .serif))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(height: 24, alignment: .top)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.layoutDirection, Loc.isRTL ? .rightToLeft : .leftToRight)
        .containerBackground(for: .widget) { Theme.parchment }
        .widgetURL(URL(string: "synaxaire://jour"))
    }
}

struct SaintsWidget: Widget {
    let kind = "SaintsOfTheDayWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SynaxaireConfigIntent.self, provider: SaintsProvider()) { entry in
            SaintsWidgetView(entry: entry)
        }
        .configurationDisplayName(Loc.t("widget.saints.name"))
        .description(Loc.t("widget.saints.desc"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct SynaxaireWidgetBundle: WidgetBundle {
    init() {
        Loc.language = Loc.deviceLanguage
    }

    var body: some Widget {
        SynaxaireWidget()
        SaintsWidget()
    }
}
