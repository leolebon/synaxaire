import SwiftUI
import UIKit

/// Fiche d'un saint : icône, nom et biographie Wikipédia, lien vers l'article.
struct SaintScreen: View {
    let commemoration: Commemoration
    var wikipediaTitle: String?

    @State private var profile: SaintProfile?
    @State private var image: UIImage?
    @State private var loading = true

    private var source: IconSource { .saint(commemoration, knownTitle: wikipediaTitle) }

    /// Nom dans la langue de l'app : nos noms pour fr/en, Wikipédia sinon.
    private var displayName: String {
        if Loc.language != "fr" && Loc.language != "en", let p = profile, p.language == Loc.language { return p.name }
        return commemoration.displayName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                IconFrame(image: image, initial: commemoration.initial, cornerRadius: 18)
                    .iconSize(IconSize.detail)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                    .padding(.top, 12)

                VStack(spacing: 6) {
                    Text(displayName)
                        .font(Theme.titleFont(23))
                        .foregroundStyle(Theme.burgundy)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if displayName != commemoration.en {
                        Text(commemoration.en)
                            .font(.system(size: 13))
                            .italic()
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                }

                SectionCard(title: Loc.t("saint.bio"), symbol: "text.book.closed") {
                    if loading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(Loc.t("saint.searching"))
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    } else if let profile {
                        Text(Loc.t("saint.article", ["t": profile.title]))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                        TranslatableText(original: profile.extract, sourceLanguage: profile.language)
                        if let url = profile.pageURL {
                            Link(destination: url) {
                                Label(Loc.t("saint.readMore"), systemImage: "safari")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding(.top, 4)
                        }
                        Text(Loc.t("saint.license", ["l": profile.language]))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(Loc.t("saint.notFound"))
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.parchment.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loading = true
            let p = await IconLoader.profile(for: source)
            profile = p
            loading = false
            let img = await IconLoader.image(for: p, maxPixel: 900)
            withAnimation(.easeOut(duration: 0.25)) { image = img }
        }
    }
}
