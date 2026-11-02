import SwiftUI
import WidgetKit

struct SettingsScreen: View {
    @AppStorage(SettingsKey.calendar) private var calendarRaw = ChurchCalendar.newCalendar.rawValue
    @AppStorage(SettingsKey.autoTranslate) private var autoTranslate = true
    @State private var cacheCleared = false

    var body: some View {
        Form {
            Section {
                Picker("Calendrier", selection: $calendarRaw) {
                    ForEach(ChurchCalendar.allCases) { cal in
                        Text(cal.label).tag(cal.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Text((ChurchCalendar(rawValue: calendarRaw) ?? .newCalendar).explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Calendrier liturgique")
            } footer: {
                Text("Pâques et les fêtes mobiles sont identiques dans les deux calendriers. Le widget a son propre réglage : touchez-le longuement puis « Modifier le widget ».")
            }

            Section {
                Toggle("Traduire en français", isOn: $autoTranslate)
            } header: {
                Text("Vies des saints")
            } footer: {
                Text("Les vies d'orthocal.info et certaines biographies sont en anglais. Sur iOS 18 et plus, l'iPhone les traduit lui-même (la première fois, il peut proposer de télécharger la langue).")
            }

            Section("Ajouter le widget") {
                Label("Touchez longuement l'écran d'accueil, puis « Modifier » › « Ajouter un widget ».", systemImage: "1.circle")
                Label("Cherchez « Synaxaire » et choisissez une taille (petit, moyen, grand).", systemImage: "2.circle")
                Label("Pour l'écran verrouillé : touchez longuement l'écran verrouillé › « Personnaliser ».", systemImage: "3.circle")
            }
            .font(.subheadline)

            Section("Sources") {
                SourceRow(title: "Synaxaire (ménologe)", detail: "Commémorations de la tradition grecque/antiochienne, d'après orthocal.info (licence MIT), traduites en français.")
                SourceRow(title: "Règles de jeûne", detail: "Typikon de la Grande Église ; vérifiées jour par jour contre le calendrier de l'Archevêché grec-orthodoxe (goarch.org), 2025-2035.")
                SourceRow(title: "Vies des saints", detail: "orthocal.info, tradition grecque (chargées à la demande).")
                SourceRow(title: "Icônes et biographies", detail: "Wikipédia et Wikimedia Commons (CC BY-SA). La recherche est automatique : vérifiez qu'il s'agit du bon saint.")
            }

            Section {
                Button(cacheCleared ? "Cache vidé" : "Vider le cache des images et textes") {
                    clearCache()
                }
                .disabled(cacheCleared)
            } footer: {
                Text("Synaxaire — calendrier orthodoxe. Fait pour un usage personnel.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.parchment.ignoresSafeArea())
        .navigationTitle("Réglages")
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

private struct SourceRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
