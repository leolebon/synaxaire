import AppIntents
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Configuration (choix du calendrier dans le widget)

enum CalendarChoice: String, AppEnum {
    case newCalendar
    case oldCalendar

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Calendrier"
    static var caseDisplayRepresentations: [CalendarChoice: DisplayRepresentation] = [
        .newCalendar: "Nouveau calendrier",
        .oldCalendar: "Ancien calendrier",
    ]

    var church: ChurchCalendar { self == .oldCalendar ? .oldCalendar : .newCalendar }
}

struct SynaxaireConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Calendrier orthodoxe"
    static var description = IntentDescription("Saint du jour, fête et jeûne selon la tradition grecque.")

    @Parameter(title: "Calendrier", default: .newCalendar)
    var calendar: CalendarChoice

    @Parameter(title: "Afficher l'icône", default: true)
    var showIcon: Bool

    init() {}
}

// MARK: - Entrée de la timeline

struct DayEntry: TimelineEntry {
    let date: Date
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

    static func make(for civil: CivilDate, date: Date, calendar: ChurchCalendar, image: UIImage?, showIcon: Bool) -> DayEntry {
        let day = LiturgicalDay(civil: civil, calendar: calendar)
        let saintNames = day.saints.map { $0.shortName }.filter { $0 != day.title }
        return DayEntry(date: date,
                        civil: civil,
                        calendar: calendar,
                        title: day.title,
                        subtitle: day.subtitles.first,
                        rank: day.rank,
                        saints: Array(saintNames.prefix(5)),
                        fasting: day.fasting.level,
                        fastNote: day.fasting.note,
                        season: day.fasting.season,
                        initial: day.primarySaint?.initial ?? "☦",
                        image: image,
                        showIcon: showIcon)
    }

    static var sample: DayEntry {
        make(for: CivilDate(year: 2026, month: 11, day: 13), date: Date(), calendar: .newCalendar, image: nil, showIcon: true)
    }
}

// MARK: - Fournisseur

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DayEntry { .sample }

    func snapshot(for configuration: SynaxaireConfigIntent, in context: Context) async -> DayEntry {
        let today = CivilDate.today()
        var image: UIImage?
        if !context.isPreview && configuration.showIcon {
            image = await loadImage(for: today, calendar: configuration.calendar.church)
        }
        return DayEntry.make(for: today, date: Date(), calendar: configuration.calendar.church, image: image, showIcon: configuration.showIcon)
    }

    func timeline(for configuration: SynaxaireConfigIntent, in context: Context) async -> Timeline<DayEntry> {
        let calendar = configuration.calendar.church
        let now = Date()
        let cal = Calendar.current
        let today = CivilDate(date: now, calendar: cal)
        let tomorrow = today.adding(days: 1)
        let tomorrowStart = tomorrow.date(in: cal)

        var todayImage: UIImage?
        var tomorrowImage: UIImage?
        if configuration.showIcon {
            async let a = loadImage(for: today, calendar: calendar)
            async let b = loadImage(for: tomorrow, calendar: calendar)
            todayImage = await a
            tomorrowImage = await b
        }

        let entries = [
            DayEntry.make(for: today, date: now, calendar: calendar, image: todayImage, showIcon: configuration.showIcon),
            DayEntry.make(for: tomorrow, date: tomorrowStart, calendar: calendar, image: tomorrowImage, showIcon: configuration.showIcon),
        ]
        // Si l'icône n'a pas pu être chargée (pas de réseau), on réessaie dans une heure.
        let retry = configuration.showIcon && todayImage == nil
        let refresh = retry ? min(now.addingTimeInterval(3600), tomorrowStart) : tomorrowStart.addingTimeInterval(3600)
        return Timeline(entries: entries, policy: .after(refresh))
    }

    /// Icône du jour, avec un délai maximal pour respecter le budget du widget.
    private func loadImage(for civil: CivilDate, calendar: ChurchCalendar) async -> UIImage? {
        let day = LiturgicalDay(civil: civil, calendar: calendar)
        guard let source = IconSource.hero(for: day) else { return nil }
        return await withTaskGroup(of: UIImage?.self) { group in
            group.addTask { await IconLoader.image(for: source, maxPixel: 360) }
            group.addTask {
                try? await Task.sleep(nanoseconds: 18_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

// MARK: - Vues

struct SynaxaireWidgetView: View {
    let entry: DayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
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
}

private struct WidgetIcon: View {
    let entry: DayEntry
    var radius: CGFloat = 8
    var body: some View {
        IconFrame(image: entry.image, initial: entry.initial, cornerRadius: radius)
    }
}

private struct DateHeader: View {
    let entry: DayEntry
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(DateText.weekdayNames[entry.civil.weekday].uppercased())
                .font(.system(size: compact ? 9 : 10, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(Theme.burgundy)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(entry.civil.day)")
                    .font(.system(size: compact ? 26 : 30, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text(DateText.monthNames[entry.civil.month - 1])
                    .font(.system(size: compact ? 11 : 12, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

private struct SmallView: View {
    let entry: DayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                DateHeader(entry: entry, compact: true)
                Spacer(minLength: 0)
                if entry.showIcon {
                    WidgetIcon(entry: entry, radius: 6)
                        .frame(width: 44, height: 58)
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
        .containerBackground(for: .widget) { Theme.parchment }
        .widgetURL(URL(string: "synaxaire://jour"))
    }
}

private struct MediumView: View {
    let entry: DayEntry

    var body: some View {
        HStack(spacing: 12) {
            if entry.showIcon {
                WidgetIcon(entry: entry, radius: 10)
                    .frame(width: 92, height: 122)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(DateText.weekdayNames[entry.civil.weekday].capitalized) \(DateText.dayMonth(entry.civil))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.burgundy)
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
                    WidgetIcon(entry: entry, radius: 12)
                        .frame(width: 108, height: 142)
                }
                VStack(alignment: .leading, spacing: 4) {
                    DateHeader(entry: entry)
                    if entry.calendar == .oldCalendar {
                        Text("Ménologe : \(DateText.dayMonth(entry.calendar.churchDate(for: entry.civil)))")
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
                    Text("AUSSI FÊTÉS")
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
        .containerBackground(for: .widget) { Theme.parchment }
        .widgetURL(URL(string: "synaxaire://jour"))
    }
}

private struct RectangularView: View {
    let entry: DayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text("☦ \(DateText.dayMonth(entry.civil))")
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
        Text("☦ \(entry.saints.first ?? entry.title) · \(entry.fasting.shortTitle)")
            .containerBackground(for: .widget) { Color.clear }
    }
}

private struct CircularView: View {
    let entry: DayEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(entry.civil.day)")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                Image(systemName: entry.fasting.symbol)
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Déclaration

struct SynaxaireWidget: Widget {
    let kind = "SynaxaireWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SynaxaireConfigIntent.self, provider: Provider()) { entry in
            SynaxaireWidgetView(entry: entry)
        }
        .configurationDisplayName("Synaxaire")
        .description("Le saint du jour avec son icône, la fête et le jeûne.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

@main
struct SynaxaireWidgetBundle: WidgetBundle {
    var body: some Widget {
        SynaxaireWidget()
    }
}
