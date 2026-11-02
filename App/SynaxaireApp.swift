import SwiftUI
import WidgetKit

@main
struct SynaxaireApp: App {
    init() {
        Loc.language = UserDefaults.standard.string(forKey: SettingsKey.language) ?? Loc.deviceLanguage
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Réglages enregistrés de l'application.
enum SettingsKey {
    static let calendar = "calendar"
    static let autoTranslate = "autoTranslate"
    static let language = "language"
}

struct RootView: View {
    @AppStorage(SettingsKey.calendar) private var calendarRaw = ChurchCalendar.newCalendar.rawValue
    @AppStorage(SettingsKey.language) private var language = Loc.deviceLanguage
    @State private var tab = 0
    @State private var today = CivilDate.today()
    @Environment(\.scenePhase) private var scenePhase

    private var calendar: ChurchCalendar { ChurchCalendar(rawValue: calendarRaw) ?? .newCalendar }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                DayScreen(date: today, calendar: calendar, isToday: true)
            }
            .tabItem { Label(Loc.t("tab.today"), systemImage: "sun.max") }
            .tag(0)

            NavigationStack {
                CalendarScreen(calendar: calendar)
            }
            .tabItem { Label(Loc.t("tab.calendar"), systemImage: "calendar") }
            .tag(1)

            NavigationStack {
                LentScreen(calendar: calendar)
            }
            .tabItem { Label(Loc.t("tab.lent"), systemImage: "leaf") }
            .tag(2)

            NavigationStack {
                SettingsScreen()
            }
            .tabItem { Label(Loc.t("tab.settings"), systemImage: "gearshape") }
            .tag(3)
        }
        .id(language)
        .tint(Theme.burgundy)
        .environment(\.layoutDirection, Loc.isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: language))
        .onAppear { Loc.language = language }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { today = CivilDate.today() }
        }
        .onChange(of: calendarRaw) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onOpenURL { _ in tab = 0 }
    }
}
