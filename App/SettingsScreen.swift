import SwiftUI
import WidgetKit

struct SettingsScreen: View {
    @AppStorage(SettingsKey.calendar) private var calendarRaw = ChurchCalendar.newCalendar.rawValue
    @AppStorage(SettingsKey.autoTranslate) private var autoTranslate = true
    @AppStorage(SettingsKey.language) private var language = Loc.deviceLanguage
    @State private var cacheCleared = false

    private struct Source: Identifiable {
        let id: String
        let url: String
    }

    private let sources: [Source] = [
        Source(id: "menologion", url: "https://github.com/brianglass/orthocal-python"),
        Source(id: "fasting", url: "https://www.goarch.org/chapel/calendar"),
        Source(id: "lives", url: "https://orthocal.info"),
        Source(id: "icons", url: "https://www.wikipedia.org"),
    ]

    var body: some View {
        Form {
            Section {
                Picker(Loc.t("settings.language"), selection: Binding(
                    get: { language },
                    set: { newValue in
                        // La langue est appliquée avant que l'interface ne se reconstruise.
                        Loc.language = newValue
                        language = newValue
                        WidgetCenter.shared.reloadAllTimelines()
                    })) {
                    ForEach(Loc.languages) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
            } header: {
                Text(Loc.t("settings.language"))
            } footer: {
                Text(Loc.t("settings.languageFooter"))
            }

            Section {
                Picker(Loc.t("settings.calendar"), selection: $calendarRaw) {
                    ForEach(ChurchCalendar.allCases) { cal in
                        Text(cal.label).tag(cal.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Text((ChurchCalendar(rawValue: calendarRaw) ?? .newCalendar).explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(Loc.t("settings.calendar"))
            } footer: {
                Text(Loc.t("settings.calendarFooter") + " " + Loc.t("settings.widgetOwnSettings"))
            }

            Section {
                Toggle(Loc.t("settings.translate"), isOn: $autoTranslate)
            } header: {
                Text(Loc.t("section.lives"))
            } footer: {
                Text(Loc.t("settings.translateFooter"))
            }

            Section(Loc.t("settings.widget")) {
                Label(Loc.t("settings.widget.ios1"), systemImage: "1.circle")
                Label(Loc.t("settings.widget.ios2"), systemImage: "2.circle")
                Label(Loc.t("settings.widget.ios3"), systemImage: "3.circle")
            }
            .font(.subheadline)

            Section(Loc.t("settings.sources")) {
                ForEach(sources) { source in
                    if let url = URL(string: source.url) {
                        // Ouvre le lien dans le navigateur par défaut de l'appareil.
                        Link(destination: url) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(Loc.t("source.\(source.id).title"))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text(Loc.t("source.\(source.id).detail"))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                    Text(url.host ?? source.url)
                                        .font(.caption)
                                        .foregroundStyle(Theme.burgundy)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.forward.square")
                                    .foregroundStyle(Theme.burgundy)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            Section {
                Button(Loc.t(cacheCleared ? "settings.cacheCleared" : "settings.clearCache")) {
                    clearCache()
                }
                .disabled(cacheCleared)
            } footer: {
                Text(Loc.t("settings.footer"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.parchment.ignoresSafeArea())
        .navigationTitle(Loc.t("tab.settings"))
    }

    private func clearCache() {
        let fm = FileManager.default
        if let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? fm.removeItem(at: base.appendingPathComponent("Synaxaire", isDirectory: true))
        }
        URLCache.shared.removeAllCachedResponses()
        cacheCleared = true
        WidgetCenter.shared.reloadAllTimelines()
    }
}
