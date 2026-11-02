import SwiftUI

/// Les carêmes de l'année, les semaines sans jeûne et le guide des règles.
struct LentScreen: View {
    let calendar: ChurchCalendar
    @State private var year = CivilDate.today().year
    @State private var expanded: Set<String> = []

    var body: some View {
        let today = CivilDate.today()
        let todayInfo = FastingRules.fasting(civil: today, calendar: calendar)
        let periods = FastCalendar.periods(year: year, calendar: calendar)
        let next = FastCalendar.currentOrNextLent(from: today, calendar: calendar)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    Button {
                        guard let next else { return }
                        reveal(next, proxy: proxy)
                    } label: {
                        SectionCard(title: Loc.t("tab.today"), symbol: todayInfo.level.symbol) {
                            HStack {
                                FastBadge(level: todayInfo.level)
                                Spacer()
                                Text(todayInfo.season.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            if let next {
                                Text(statusText(next, today: today))
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.ink)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 4) {
                                    Text(Loc.t("lent.tapHint"))
                                    Image(systemName: "chevron.down")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.burgundy)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    HStack {
                        Button { year -= 1 } label: { Image(systemName: "chevron.backward") }
                        Spacer()
                        Text(Loc.t("lent.year", ["y": String(year)]))
                            .font(Theme.titleFont(20))
                        Spacer()
                        Button { year += 1 } label: { Image(systemName: "chevron.forward") }
                    }
                    .foregroundStyle(Theme.burgundy)
                    .padding(.horizontal, 8)

                    ForEach(periods) { period in
                        PeriodCard(period: period,
                                   isCurrent: period.contains(today),
                                   expanded: Binding(
                                       get: { expanded.contains(period.id) },
                                       set: { open in
                                           if open { expanded.insert(period.id) } else { expanded.remove(period.id) }
                                       }))
                            .id(period.id)
                    }

                    RulesGuide()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.parchment.ignoresSafeArea())
        .navigationTitle(Loc.t("lent.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statusText(_ p: FastPeriod, today: CivilDate) -> String {
        if p.contains(today) {
            return Loc.t("lent.current", ["s": p.season.title, "d": DateText.dayMonth(p.end), "n": String(p.end.days(since: today) + 1)])
        }
        return Loc.t("lent.next", ["s": p.season.title, "d": DateText.dayMonth(p.start), "n": String(p.start.days(since: today))])
    }

    /// Ouvre la carte du carême, avec ses règles dépliées, et y fait défiler l'écran.
    private func reveal(_ p: FastPeriod, proxy: ScrollViewProxy) {
        if year != p.start.year { year = p.start.year }
        expanded.insert(p.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo(p.id, anchor: .top)
            }
        }
    }
}

struct PeriodCard: View {
    let period: FastPeriod
    let isCurrent: Bool
    @Binding var expanded: Bool

    private var isFastFree: Bool {
        [.publicanWeek, .brightWeek, .trinityWeek, .christmastide].contains(period.season)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(period.season.title)
                        .font(Theme.titleFont(18))
                        .foregroundStyle(isFastFree ? Theme.gold : Theme.burgundy)
                    Text(rangeText)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                if isCurrent {
                    Text(Loc.t("lent.inProgress"))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .foregroundStyle(.white)
                        .background(Theme.burgundy, in: Capsule())
                } else if isFastFree {
                    Image(systemName: "party.popper").foregroundStyle(Theme.gold)
                }
            }
            if !period.season.recommendations.isEmpty {
                DisclosureGroup(isExpanded: $expanded) {
                    TipsList(tips: period.season.recommendations)
                        .padding(.top, 6)
                } label: {
                    Text(Loc.t("rules.recommendations"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.burgundy)
                }
                .tint(Theme.burgundy)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(isCurrent || expanded ? Theme.burgundy : Theme.hairline, lineWidth: isCurrent || expanded ? 2 : 1))
    }

    private var rangeText: String {
        let days = period.end.days(since: period.start) + 1
        return Loc.t("lent.range", ["a": DateText.dayMonthYear(period.start),
                                    "b": DateText.dayMonthYear(period.end),
                                    "n": String(days)])
    }
}

/// Explication des niveaux de jeûne.
struct RulesGuide: View {
    private let levels: [FastLevel] = [.strict, .wineOil, .fish, .dairy, .noFast]

    var body: some View {
        SectionCard(title: Loc.t("lent.guide"), symbol: "questionmark.circle") {
            ForEach(levels, id: \.self) { level in
                VStack(alignment: .leading, spacing: 6) {
                    FastBadge(level: level)
                    Text(level.explanation)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    FoodChips(level: level)
                }
                .padding(.vertical, 4)
                if level != levels.last { Divider().overlay(Theme.hairline) }
            }
            Text(Loc.t("lent.guideNote"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }
}
