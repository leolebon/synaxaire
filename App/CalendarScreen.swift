import SwiftUI

/// Calendrier mensuel : fêtes, jours de jeûne, accès au détail de chaque jour.
struct CalendarScreen: View {
    let calendar: ChurchCalendar

    @State private var year: Int
    @State private var month: Int
    @State private var selected: CivilDate?

    init(calendar: ChurchCalendar) {
        self.calendar = calendar
        let t = CivilDate.today()
        _year = State(initialValue: t.year)
        _month = State(initialValue: t.month)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let headers = ["L", "M", "M", "J", "V", "S", "D"]

    private var days: [LiturgicalDay] {
        let count = CivilDate.daysInMonth(year: year, month: month)
        return (1...count).map { LiturgicalDay(civil: CivilDate(year: year, month: month, day: $0), calendar: calendar) }
    }

    /// Nombre de cases vides avant le 1er (semaine commençant le lundi).
    private var leadingBlanks: Int {
        let wd = CivilDate(year: year, month: month, day: 1).weekday // 1 = dimanche
        return (wd + 5) % 7
    }

    var body: some View {
        let days = self.days
        let today = CivilDate.today()
        ScrollView {
            VStack(spacing: 14) {
                header
                VStack(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(headers[i])
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(i == 6 ? Theme.burgundy : Theme.inkSoft)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach((0..<leadingBlanks).map { -1 - $0 }, id: \.self) { _ in
                        Color.clear.frame(height: 54)
                    }
                    ForEach(days) { day in
                        NavigationLink {
                            DayScreen(date: day.civil, calendar: calendar)
                        } label: {
                            DayCell(day: day, isToday: day.civil == today)
                        }
                        .buttonStyle(.plain)
                    }
                }
                }
                .padding(10)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline))

                Legend()

                SectionCard(title: "Fêtes et temps forts du mois", symbol: "star") {
                    let notable = days.filter { $0.rank >= .major || ($0.civil.isSunday && $0.title.hasPrefix("Dimanche")) }
                    if notable.isEmpty {
                        Text("Pas de grande fête ce mois-ci.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    ForEach(notable) { day in
                        NavigationLink {
                            DayScreen(date: day.civil, calendar: calendar)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(day.civil.day)")
                                    .font(Theme.titleFont(18, weight: .bold))
                                    .foregroundStyle(day.rank.color)
                                    .frame(width: 30, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(day.title)
                                        .font(.system(size: 14, weight: day.rank >= .great ? .semibold : .regular, design: .serif))
                                        .foregroundStyle(Theme.ink)
                                        .multilineTextAlignment(.leading)
                                    Text(DateText.weekdayNames[day.civil.weekday].capitalized)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.inkSoft)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.parchment.ignoresSafeArea())
        .navigationTitle("Calendrier")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Aujourd'hui") {
                    let t = CivilDate.today()
                    year = t.year
                    month = t.month
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
            }
            Spacer()
            VStack(spacing: 2) {
                Text(DateText.monthYear(year: year, month: month))
                    .font(Theme.titleFont(22))
                    .foregroundStyle(Theme.ink)
                Text("Pâques \(year) : \(DateText.dayMonth(Paschalion.pascha(year: year)))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 18, weight: .semibold))
            }
        }
        .padding(.top, 8)
        .foregroundStyle(Theme.burgundy)
    }

    private func shift(_ delta: Int) {
        var m = month + delta
        var y = year
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1; y += 1 }
        withAnimation(.easeInOut(duration: 0.2)) {
            month = m
            year = y
        }
    }
}

struct DayCell: View {
    let day: LiturgicalDay
    let isToday: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text("\(day.civil.day)")
                .font(.system(size: 16, weight: isToday || day.rank >= .major ? .bold : .regular, design: .serif))
                .foregroundStyle(numberColor)
                .frame(width: 30, height: 30)
                .background {
                    if isToday { Circle().fill(Theme.burgundy) }
                }
            HStack(spacing: 2) {
                if day.rank >= .great {
                    Text("☩").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.burgundy)
                } else if day.rank >= .major {
                    Circle().fill(Theme.gold).frame(width: 5, height: 5)
                }
            }
            .frame(height: 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(day.fasting.level.isFasting ? day.fasting.level.color : Color.clear)
                .frame(height: 4)
                .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(day.fasting.level == .fastFree ? Theme.gold.opacity(0.10) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(DateText.long(day.civil)), \(day.title), \(day.fasting.level.title)")
    }

    private var numberColor: Color {
        if isToday { return .white }
        if day.rank >= .great || day.civil.isSunday { return Theme.burgundy }
        return Theme.ink
    }
}

struct Legend: View {
    private let levels: [FastLevel] = [.dairy, .fish, .wineOil, .strict]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                ForEach(levels, id: \.self) { level in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(level.color).frame(width: 14, height: 4)
                        Text(level.shortTitle).font(.system(size: 11))
                    }
                }
            }
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Text("☩").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.burgundy)
                    Text("Grande fête").font(.system(size: 11))
                }
                HStack(spacing: 4) {
                    Circle().fill(Theme.gold).frame(width: 6, height: 6)
                    Text("Fête importante").font(.system(size: 11))
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.gold.opacity(0.2)).frame(width: 14, height: 10)
                    Text("Sans jeûne").font(.system(size: 11))
                }
            }
        }
        .foregroundStyle(Theme.inkSoft)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}
