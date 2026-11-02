import SwiftUI
import WidgetKit

@main
struct SynaxaireApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Réglages partagés de l'application.
enum SettingsKey {
    static let calendar = "calendar"
    static let autoTranslate = "autoTranslate"
}

struct RootView: View {
    @AppStorage(SettingsKey.calendar) private var calendarRaw = ChurchCalendar.newCalendar.rawValue
    @State private var tab = 0
    @State private var today = CivilDate.today()
    @Environment(\.scenePhase) private var scenePhase

    private var calendar: ChurchCalendar { ChurchCalendar(rawValue: calendarRaw) ?? .newCalendar }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                DayScreen(date: today, calendar: calendar, isToday: true)
            }
            .tabItem { Label("Aujourd'hui", systemImage: "sun.max") }
            .tag(0)

            NavigationStack {
                CalendarScreen(calendar: calendar)
            }
            .tabItem { Label("Calendrier", systemImage: "calendar") }
            .tag(1)

            NavigationStack {
                LentScreen(calendar: calendar)
            }
            .tabItem { Label("Carêmes", systemImage: "leaf") }
            .tag(2)

            NavigationStack {
                SettingsScreen()
            }
            .tabItem { Label("Réglages", systemImage: "gearshape") }
            .tag(3)
        }
        .tint(Theme.burgundy)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { today = CivilDate.today() }
        }
        .onChange(of: calendarRaw) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onOpenURL { _ in tab = 0 }
    }
}
