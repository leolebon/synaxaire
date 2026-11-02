import SwiftUI
#if canImport(Translation)
import Translation
#endif

/// Affiche un texte et, sur iOS 18+, sa traduction dans la langue de l'application (faite sur l'appareil).
struct TranslatableText: View {
    let original: String
    var sourceLanguage = "en"

    @AppStorage(SettingsKey.autoTranslate) private var autoTranslate = true
    @State private var translated: [String]?
    @State private var showOriginal = false
    @State private var failed = false

    private var paragraphs: [String] { HTMLText.paragraphs(original) }
    private var needsTranslation: Bool { sourceLanguage != Loc.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if needsTranslation {
                if translationSupported && autoTranslate {
                    HStack {
                        if translated == nil && !failed {
                            ProgressView().controlSize(.small)
                            Text(Loc.t("tr.translating"))
                        } else if failed {
                            Image(systemName: "exclamationmark.triangle")
                            Text(Loc.t("tr.unavailable"))
                        } else {
                            Image(systemName: "character.bubble")
                            Text(Loc.t(showOriginal ? "tr.original" : "tr.auto"))
                        }
                        Spacer()
                        if translated != nil {
                            Button(Loc.t(showOriginal ? "tr.showTranslation" : "tr.showOriginal")) { showOriginal.toggle() }
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
                } else {
                    Text(Loc.t(translationSupported ? "tr.disabled" : "tr.needsIOS18"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSoft)
                }
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
                                    targetLanguage: Loc.language,
                                    enabled: autoTranslate && needsTranslation,
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
    let targetLanguage: String
    let enabled: Bool
    let onResult: ([String]) -> Void
    let onFailure: () -> Void

    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(iOS 18.0, *) {
            if enabled {
                return AnyView(content.modifier(ModernTranslation(paragraphs: paragraphs,
                                                                  sourceLanguage: sourceLanguage,
                                                                  targetLanguage: targetLanguage,
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
    let targetLanguage: String
    let onResult: ([String]) -> Void
    let onFailure: () -> Void

    @State private var configuration: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        content
            .onAppear {
                if configuration == nil {
                    configuration = TranslationSession.Configuration(
                        source: Locale.Language(identifier: sourceLanguage),
                        target: Locale.Language(identifier: targetLanguage))
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
                Text(Loc.t("story.source"))
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
