import SwiftUI
import UIKit

/// Fiche d'un saint : icône, biographie Wikipédia et lien vers l'article.
struct SaintScreen: View {
    let commemoration: Commemoration
    var wikipediaTitle: String?

    @State private var profile: SaintProfile?
    @State private var image: UIImage?
    @State private var loading = true

    private var source: IconSource {
        if let wikipediaTitle { return .title(wikipediaTitle, fallback: commemoration) }
        return .commemoration(commemoration)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                IconFrame(image: image, initial: commemoration.initial, cornerRadius: 18)
                    .frame(width: 220, height: 290)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                    .padding(.top, 12)

                VStack(spacing: 6) {
                    Text(commemoration.fr)
                        .font(Theme.titleFont(23))
                        .foregroundStyle(Theme.burgundy)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(commemoration.en)
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }

                SectionCard(title: "Biographie", symbol: "text.book.closed") {
                    if loading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Recherche de la biographie…")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    } else if let profile {
                        if profile.title.lowercased() != commemoration.fr.lowercased() {
                            Text("Article : \(profile.title)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.gold)
                        }
                        TranslatableText(original: profile.extract, sourceLanguage: profile.language)
                        if let url = profile.pageURL {
                            Link(destination: url) {
                                Label("Lire l'article complet sur Wikipédia", systemImage: "safari")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding(.top, 4)
                        }
                        Text("Texte et image : Wikipédia (\(profile.language)), licence CC BY-SA. Vérifiez qu'il s'agit bien du saint commémoré : les homonymes sont fréquents.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Aucune biographie trouvée en ligne pour ce saint. Consultez la section « Vies des saints » de la journée, ou le Synaxaire.")
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
            if let url = p?.imageURL, let data = await ImageCache.data(for: url) {
                let img = IconLoader.downscale(data, maxPixel: 900)
                withAnimation(.easeOut(duration: 0.25)) { image = img }
            }
        }
    }
}
