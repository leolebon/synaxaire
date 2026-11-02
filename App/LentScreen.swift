import SwiftUI

/// Les carêmes de l'année, les semaines sans jeûne et le guide des règles.
struct LentScreen: View {
    let calendar: ChurchCalendar
    @State private var year = CivilDate.today().year

    var body: some View {
        let today = CivilDate.today()
        let todayInfo = FastingRules.fasting(civil: today, calendar: calendar)
        let periods = FastCalendar.periods(year: year, calendar: calendar)
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: "Aujourd'hui", symbol: todayInfo.level.symbol) {
                    HStack {
                        FastBadge(level: todayInfo.level)
                        Spacer()
                        Text(todayInfo.season.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    if let next = FastCalendar.currentOrNextLent(from: today, calendar: calendar) {
                        Text(next.contains(today)
                             ? "\(next.season.title) en cours jusqu'au \(DateText.dayMonth(next.end)) (encore \(next.end.days(since: today) + 1) jours)."
                             : "Prochain carême : \(next.season.title), le \(DateText.dayMonth(next.start)) (dans \(next.start.days(since: today)) jours).")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack {
                    Button { year -= 1 } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text("Année \(String(year))")
                        .font(Theme.titleFont(20))
                    Spacer()
                    Button { year += 1 } label: { Image(systemName: "chevron.right") }
                }
                .foregroundStyle(Theme.burgundy)
                .padding(.horizontal, 8)

                ForEach(periods) { period in
                    PeriodCard(period: period, isCurrent: period.contains(today))
                }

                RulesGuide()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.parchment.ignoresSafeArea())
        .navigationTitle("Carêmes et jeûnes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PeriodCard: View {
    let period: FastPeriod
    let isCurrent: Bool
    @State private var expanded = false

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
                    Text("EN COURS")
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
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(period.season.recommendations, id: \.self) { tip in
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
                    Text("Règles et recommandations")
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
            .strokeBorder(isCurrent ? Theme.burgundy : Theme.hairline, lineWidth: isCurrent ? 2 : 1))
    }

    private var rangeText: String {
        let days = period.end.days(since: period.start) + 1
        if period.start == period.end { return DateText.long(period.start) }
        return "Du \(DateText.dayMonth(period.start)) \(period.start.year) au \(DateText.dayMonth(period.end)) \(period.end.year) · \(days) jours"
    }
}

/// Explication des niveaux de jeûne.
struct RulesGuide: View {
    private let levels: [FastLevel] = [.strict, .wineOil, .fish, .dairy, .noFast]

    var body: some View {
        SectionCard(title: "Comprendre les niveaux de jeûne", symbol: "questionmark.circle") {
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
            Text("Règles selon le Typikon de la Grande Église, telles que publiées par l'Archevêché grec-orthodoxe (GOARCH). Le jeûne est une aide spirituelle, non une fin en soi : malades, femmes enceintes, enfants, personnes âgées et voyageurs l'adaptent avec la bénédiction de leur père spirituel.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }
}
