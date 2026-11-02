import SwiftUI
import UIKit

/// Écran complet d'une journée : fête, icône, jeûne, saints et vies des saints.
struct DayScreen: View {
    let date: CivilDate
    let calendar: ChurchCalendar
    var isToday = false

    @State private var stories: [SaintStory] = []
    @State private var storiesState: LoadState = .idle

    enum LoadState { case idle, loading, loaded, failed }

    private var day: LiturgicalDay { LiturgicalDay(civil: date, calendar: calendar) }

    var body: some View {
        let day = self.day
        ScrollView {
            VStack(spacing: 16) {
                HeroHeader(day: day)
                FastingCard(day: day)
                SaintsCard(day: day)
                StoriesCard(stories: stories, state: storiesState, retry: { Task { await loadStories() } })
                FooterInfo(day: day)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.parchment.ignoresSafeArea())
        .navigationTitle(isToday ? "Aujourd'hui" : DateText.dayMonth(date))
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

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(DateText.long(day.civil))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                if let church = DateText.churchLabel(day) {
                    Text("Ménologe : \(church)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSoft.opacity(0.8))
                }
            }
            .padding(.top, 8)

            SaintIcon(source: IconSource.hero(for: day), initial: day.primarySaint?.initial ?? "☦", cornerRadius: 16)
                .frame(width: 190, height: 245)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 6)

            if !day.rank.marks.isEmpty {
                Text(day.rank.marks)
                    .font(.system(size: 14))
                    .foregroundStyle(day.rank.color)
            }

            Text(day.title)
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
    }
}

// MARK: - Jeûne

struct FastingCard: View {
    let day: LiturgicalDay
    @State private var showTips = false

    var body: some View {
        SectionCard(title: "Jeûne du jour", symbol: day.fasting.level.symbol) {
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
                Text("🦐 Les fruits de mer sans sang (crevettes, calamars, poulpe, moules) sont traditionnellement permis les jours de jeûne.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let tips = day.fasting.season.recommendations
            if !tips.isEmpty {
                DisclosureGroup(isExpanded: $showTips) {
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
                    .padding(.top, 6)
                } label: {
                    Text("Recommandations — \(day.fasting.season.title)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.burgundy)
                }
                .tint(Theme.burgundy)
            }
        }
    }
}

// MARK: - Saints

struct SaintsCard: View {
    let day: LiturgicalDay

    var body: some View {
        SectionCard(title: "Saints et mémoires du jour", symbol: "person.3") {
            if day.commemorations.isEmpty {
                Text("Aucune commémoration pour ce jour.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
            }
            VStack(spacing: 0) {
                ForEach(Array(day.commemorations.enumerated()), id: \.offset) { index, c in
                    if c.isFestal {
                        Text(c.fr)
                            .font(.system(size: 14, design: .serif))
                            .italic()
                            .foregroundStyle(Theme.gold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        NavigationLink {
                            SaintScreen(commemoration: c, wikipediaTitle: day.wikipediaTitle(for: c))
                        } label: {
                            SaintRow(commemoration: c, prominent: index == 0 || c == day.primarySaint)
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
            SaintIcon(source: prominent ? IconSource.commemoration(commemoration) : nil,
                      initial: commemoration.initial, cornerRadius: 8)
                .frame(width: 38, height: 48)
            Text(commemoration.fr)
                .font(.system(size: 15, weight: prominent ? .semibold : .regular, design: .serif))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
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
        SectionCard(title: "Vies des saints", symbol: "book.closed") {
            switch state {
            case .idle, .loading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Chargement du synaxaire…")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSoft)
                }
            case .failed:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Impossible de charger les vies des saints. Vérifiez votre connexion.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSoft)
                    Button("Réessayer", action: retry)
                        .font(.system(size: 14, weight: .semibold))
                }
            case .loaded:
                if stories.isEmpty {
                    Text("Pas de récit disponible pour ce jour.")
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
                                    Image(systemName: "chevron.right")
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
                    Text("Textes en anglais d'orthocal.info, traduits automatiquement sur l'iPhone (iOS 18 et plus).")
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
                Text("Ton \(day.tone) de l'Octoèque")
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
        if pd == 0 { return "Le Christ est ressuscité !" }
        let pascha = Paschalion.pascha(year: day.civil.year)
        if pd < 0 { return "Pâques le \(DateText.dayMonth(pascha)) — dans \(-pd) jour\(pd == -1 ? "" : "s")" }
        return "Pâques était le \(DateText.dayMonth(pascha)) (\(pd)e jour)"
    }
}
