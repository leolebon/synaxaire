import SwiftUI
#if canImport(Translation)
import Translation
#endif

/// Affiche un texte anglais et, sur iOS 18+, sa traduction française faite sur l'appareil.
struct TranslatableText: View {
    let original: String
    var sourceLanguage = "en"

    @AppStorage(SettingsKey.autoTranslate) private var autoTranslate = true
    @State private var translated: [String]?
    @State private var showOriginal = false
    @State private var failed = false

    private var paragraphs: [String] { HTMLText.paragraphs(original) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if translationSupported && autoTranslate {
                HStack {
                    if translated == nil && !failed {
                        ProgressView().controlSize(.small)
                        Text("Traduction en français…")
                    } else if failed {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Traduction indisponible — texte original")
                    } else {
                        Image(systemName: "character.bubble")
                        Text(showOriginal ? "Texte original (anglais)" : "Traduit automatiquement de l'anglais")
                    }
                    Spacer()
                    if translated != nil {
                        Button(showOriginal ? "Français" : "Original") { showOriginal.toggle() }
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
            } else if sourceLanguage != "fr" {
                Text(translationSupported
                     ? "Texte en anglais (traduction automatique désactivée dans les réglages)."
                     : "Texte en anglais. La traduction automatique nécessite iOS 18.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
            }

            let shown = (translated != nil && !showOriginal) ? (translated ?? paragraphs) : paragraphs
            ForEach(Array(shown.enumerated()), id: \.offset) { _, p in
                Text(p)
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .modifier(TranslationRunner(paragraphs: paragraphs,
                                    sourceLanguage: sourceLanguage,
                                    enabled: autoTranslate && sourceLanguage != "fr",
                                    onResult: { translated = $0 },
                                    onFailure: { failed = true }))
    }

    private var translationSupported: Bool {
        if #available(iOS 18.0, *) { return true }
        return false
    }
}

/// Lance la traduction sur iOS 18 ; ne fait rien sur les versions antérieures.
struct TranslationRunner: ViewModifier {
    let paragraphs: [String]
    let sourceLanguage: String
    let enabled: Bool
    let onResult: ([String]) -> Void
    let onFailure: () -> Void

    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(iOS 18.0, *) {
            if enabled {
                return AnyView(content.modifier(ModernTranslation(paragraphs: paragraphs,
                                                                  sourceLanguage: sourceLanguage,
                                                                  onResult: onResult,
                                                                  onFailure: onFailure)))
            }
        }
        #endif
        return AnyView(content)
    }
}

#if canImport(Translation)
@available(iOS 18.0, *)
private struct ModernTranslation: ViewModifier {
    let paragraphs: [String]
    let sourceLanguage: String
    let onResult: ([String]) -> Void
    let onFailure: () -> Void

    @State private var configuration: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        content
            .onAppear {
                if configuration == nil {
                    configuration = TranslationSession.Configuration(
                        source: Locale.Language(identifier: sourceLanguage),
                        target: Locale.Language(identifier: "fr"))
                }
            }
            .translationTask(configuration) { session in
                let requests = paragraphs.enumerated().map { index, text in
                    TranslationSession.Request(sourceText: text, clientIdentifier: String(index))
                }
                do {
                    let responses = try await session.translations(from: requests)
                    var result = paragraphs
                    for response in responses {
                        if let id = response.clientIdentifier, let i = Int(id), i < result.count {
                            result[i] = response.targetText
                        }
                    }
                    let final = result
                    await MainActor.run { onResult(final) }
                } catch {
                    await MainActor.run { onFailure() }
                }
            }
    }
}
#endif

// MARK: - Écran d'une vie de saint (orthocal.info)

struct StoryScreen: View {
    let story: SaintStory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(story.title)
                    .font(Theme.titleFont(24))
                    .foregroundStyle(Theme.burgundy)
                    .fixedSize(horizontal: false, vertical: true)
                TranslatableText(original: story.text)
                Text("Source : orthocal.info — synaxaire de la tradition grecque.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Theme.parchment.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
