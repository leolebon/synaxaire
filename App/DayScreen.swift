import SwiftUI
import UIKit

/// Écran complet d'une journée : fête, icônes des saints, jeûne, saints et vies des saints.
struct DayScreen: View {
    let date: CivilDate
    let calendar: ChurchCalendar
    var isToday = false

    @State private var stories: [SaintStory] = []
    @State private var storiesState: LoadState = .idle

    enum LoadState { case idle, loading, loaded, failed }

    var body: some View {
        let day = LiturgicalDay(civil: date, calendar: calendar)
        ScrollView {
            VStack(spacing: 16) {
                HeroHeader(day: day)
                SaintGallery(day: day)
                FastingCard(day: day)
                SaintsCard(day: day)
                StoriesCard(stories: stories, state: storiesState, retry: { Task { await loadStories() } })
                FooterInfo(day: day)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.parchment.ignoresSafeArea())
        .navigationTitle(isToday ? Loc.t("tab.today") : DateText.dayMonth(date))
        .navigationBarTitleDisplayMode(isToday ? .large : .inline)
        .task(id: "\(date.jdn)-\(calendar.rawValue)") { await loadStories() }
    }

    private func loadStories() async {
        storiesState = .loading
        do {
            stories = try await OrthocalService.shared.stories(for: date, calendar: calendar)
            storiesState = .loaded
        } catch {
            storiesState = .failed
        }
    }
}

// MARK: - En-tête

struct HeroHeader: View {
    let day: LiturgicalDay
    @State private var localizedTitle: String?

    /// Dans les langues sans noms embarqués, le nom du saint vient de Wikipédia.
    private var needsLocalizedName: Bool {
        day.titleIsSaint && Loc.language != "fr" && Loc.language != "en"
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(DateText.long(day.civil))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                if let church = DateText.churchLabel(day) {
                    Text(church)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSoft.opacity(0.8))
                }
            }
            .padding(.top, 8)

            if !day.rank.marks.isEmpty {
                Text(day.rank.marks)
                    .font(.system(size: 14))
                    .foregroundStyle(day.rank.color)
            }

            Text(localizedTitle ?? day.title)
                .font(Theme.titleFont(day.isGreatFeast ? 24 : 21))
                .multilineTextAlignment(.center)
                .foregroundStyle(day.rank >= .sunday ? day.rank.color : Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(day.subtitles, id: \.self) { sub in
                Text(sub)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.inkSoft)
            }

            HStack(spacing: 8) {
                FastBadge(level: day.fasting.level)
                if day.fasting.season != .ordinary && day.fasting.season != .wednesdayFriday {
                    Text(day.fasting.season.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: "\(day.id)-\(Loc.language)") {
            localizedTitle = nil
            guard needsLocalizedName, let c = day.primarySaint else { return }
            let p = await IconLoader.profile(for: .saint(c, knownTitle: day.primarySaintWikipediaTitle))
            if let p, p.language == Loc.language { localizedTitle = p.name }
        }
    }
}

// MARK: - Galerie des icônes

/// Un élément de la galerie : un saint, ou la fête mobile du jour.
struct GalleryItem: Identifiable {
    let id: String
    let commemoration: Commemoration
    let knownTitle: String?
}

struct SaintGallery: View {
    let day: LiturgicalDay

    private var items: [GalleryItem] {
        var out: [GalleryItem] = []
        // Fête mobile (Pâques, Pentecôte…) : son icône vient en premier.
        if let feast = day.feastWikipediaTitle, feast != day.primarySaintWikipediaTitle {
            out.append(GalleryItem(id: "feast", commemoration: Commemoration(fr: day.title, en: day.title, t: nil), knownTitle: feast))
        }
        for (i, c) in day.saints.enumerated() {
            out.append(GalleryItem(id: "s\(i)", commemoration: c, knownTitle: day.wikipediaTitle(for: c)))
        }
        return out
    }

    var body: some View {
        let items = self.items
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if items.count <= 3 {
                    HStack(alignment: .top, spacing: GalleryCard.spacing) {
                        ForEach(items) { item in
                            GalleryCard(item: item)
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    AutoScrollingRow(items: items)
                }
            }
        }
    }
}

/// Bandeau qui défile lentement de droite à gauche, en boucle.
struct AutoScrollingRow: View {
    let items: [GalleryItem]

    @State private var start = Date()
    private let speed: CGFloat = 24 // points par seconde

    var body: some View {
        let loopWidth = CGFloat(items.count) * (GalleryCard.width + GalleryCard.spacing)
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = CGFloat(context.date.timeIntervalSince(start))
                let x = (elapsed * speed).truncatingRemainder(dividingBy: max(loopWidth, 1))
                HStack(alignment: .top, spacing: GalleryCard.spacing) {
                    ForEach(0..<2, id: \.self) { copy in
                        ForEach(items) { item in
                            GalleryCard(item: item)
                                .id("\(copy)-\(item.id)")
                        }
                    }
                }
                .fixedSize()
                .offset(x: -x)
            }
        }
        .frame(height: GalleryCard.height)
        .clipped()
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct GalleryCard: View {
    static let width: CGFloat = IconSize.gallery.width + 6
    static let height: CGFloat = IconSize.gallery.height + 44
    static let spacing: CGFloat = 10

    let item: GalleryItem
    @State private var localizedName: String?

    var body: some View {
        NavigationLink {
            SaintScreen(commemoration: item.commemoration, wikipediaTitle: item.knownTitle)
        } label: {
            VStack(spacing: 6) {
                SaintIcon(source: .saint(item.commemoration, knownTitle: item.knownTitle),
                          initial: item.commemoration.initial,
                          cornerRadius: 10,
                          onProfile: { p in
                              if let p, p.language == Loc.language, Loc.language != "fr", Loc.language != "en" {
                                  localizedName = p.name
                              }
                          })
                    .iconSize(IconSize.gallery)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                Text(localizedName ?? item.commemoration.shortName)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: GalleryCard.width, height: 30, alignment: .top)
            }
            .frame(width: GalleryCard.width, height: GalleryCard.height, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Jeûne

struct FastingCard: View {
    let day: LiturgicalDay
    @State private var showTips = false

    var body: some View {
        SectionCard(title: Loc.t("section.fasting"), symbol: day.fasting.level.symbol) {
            HStack(alignment: .firstTextBaseline) {
                Text(day.fasting.level.title)
                    .font(Theme.titleFont(19))
                    .foregroundStyle(day.fasting.level.color)
                Spacer()
                Text(day.fasting.season.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.trailing)
            }
            if let note = day.fasting.note {
                Label(note, systemImage: "info.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.burgundy)
            }
            Text(day.fasting.level.explanation)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            FoodChips(level: day.fasting.level)
                .padding(.top, 4)
            if day.fasting.level.isFasting {
                Text(Loc.t("shellfish.note"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let tips = day.fasting.season.recommendations
            if !tips.isEmpty {
                DisclosureGroup(isExpanded: $showTips) {
                    TipsList(tips: tips)
                        .padding(.top, 6)
                } label: {
                    Text(Loc.t("rec.title", ["s": day.fasting.season.title]))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.burgundy)
                }
                .tint(Theme.burgundy)
            }
        }
    }
}

struct TipsList: View {
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Text("☩").foregroundStyle(Theme.gold)
                    Text(tip)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Saints

struct SaintsCard: View {
    let day: LiturgicalDay

    var body: some View {
        SectionCard(title: Loc.t("section.saints"), symbol: "person.3") {
            if day.commemorations.isEmpty {
                Text(Loc.t("saints.none"))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
            }
            VStack(spacing: 0) {
                ForEach(Array(day.commemorations.enumerated()), id: \.offset) { index, c in
                    if c.isFestal {
                        Text(c.displayName)
                            .font(.system(size: 14, design: .serif))
                            .italic()
                            .foregroundStyle(Theme.gold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        NavigationLink {
                            SaintScreen(commemoration: c, wikipediaTitle: day.wikipediaTitle(for: c))
                        } label: {
                            SaintRow(commemoration: c, prominent: c == day.primarySaint)
                        }
                        .buttonStyle(.plain)
                    }
                    if index < day.commemorations.count - 1 {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
        }
    }
}

struct SaintRow: View {
    let commemoration: Commemoration
    var prominent = false

    var body: some View {
        HStack(spacing: 12) {
            Text("☩")
                .font(.system(size: 14))
                .foregroundStyle(prominent ? Theme.burgundy : Theme.gold)
            Text(commemoration.displayName)
                .font(.system(size: 15, weight: prominent ? .semibold : .regular, design: .serif))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Image(systemName: "chevron.forward")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft.opacity(0.6))
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Vies des saints (orthocal.info)

struct StoriesCard: View {
    let stories: [SaintStory]
    let state: DayScreen.LoadState
    let retry: () -> Void

    var body: some View {
        SectionCard(title: Loc.t("section.lives"), symbol: "book.closed") {
            switch state {
            case .idle, .loading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text(Loc.t("lives.loading"))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSoft)
                }
            case .failed:
                VStack(alignment: .leading, spacing: 8) {
                    Text(Loc.t("lives.failed"))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSoft)
                    Button(Loc.t("lives.retry"), action: retry)
                        .font(.system(size: 14, weight: .semibold))
                }
            case .loaded:
                if stories.isEmpty {
                    Text(Loc.t("lives.empty"))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    VStack(spacing: 0) {
                        ForEach(stories) { story in
                            NavigationLink {
                                StoryScreen(story: story)
                            } label: {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(story.title)
                                            .font(.system(size: 15, weight: .semibold, design: .serif))
                                            .foregroundStyle(Theme.ink)
                                            .multilineTextAlignment(.leading)
                                        Text(story.text)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Theme.inkSoft)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.forward")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.inkSoft.opacity(0.6))
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(Theme.hairline)
                        }
                    }
                    Text(Loc.t("lives.note"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }
}

// MARK: - Pied de page

struct FooterInfo: View {
    let day: LiturgicalDay

    var body: some View {
        VStack(spacing: 4) {
            if day.tone > 0 {
                Text(Loc.t("tone", ["n": String(day.tone)]))
            }
            Text(paschaText)
            Text(day.calendar.label)
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.inkSoft)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var paschaText: String {
        let pd = day.paschaDistance
        if pd == 0 { return Loc.t("pascha.today") }
        let pascha = DateText.dayMonth(Paschalion.pascha(year: day.civil.year))
        if pd < 0 { return Loc.t("pascha.future", ["d": pascha, "n": String(-pd)]) }
        return Loc.t("pascha.past", ["d": pascha, "n": String(pd + 1)])
    }
}
