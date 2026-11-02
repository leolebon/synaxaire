import SwiftUI
import UIKit

/// Source d'une icône : un saint du ménologe, ou une fête dont l'article est connu.
enum IconSource: Equatable {
    case saint(Commemoration, knownTitle: String?)
    case feast(String, fallback: Commemoration?)

    static func hero(for day: LiturgicalDay) -> IconSource? {
        if let t = day.feastWikipediaTitle { return .feast(t, fallback: day.primarySaint) }
        if let c = day.primarySaint { return .saint(c, knownTitle: day.primarySaintWikipediaTitle) }
        return nil
    }
}

enum IconLoader {
    /// Fiche Wikipédia de la source, dans la langue de l'application.
    static func profile(for source: IconSource, language: String = Loc.language) async -> SaintProfile? {
        switch source {
        case .feast(let title, let fallback):
            let p = await WikipediaService.shared.profile(for: nil, knownTitle: title, language: language)
            if p?.imageURL == nil, let fallback {
                return await WikipediaService.shared.profile(for: fallback, knownTitle: nil, language: language) ?? p
            }
            return p
        case .saint(let c, let known):
            return await WikipediaService.shared.profile(for: c, knownTitle: known, language: language)
        }
    }

    /// Image principale (réduite) de l'article.
    static func image(for profile: SaintProfile?, maxPixel: CGFloat = 700) async -> UIImage? {
        guard let url = profile?.imageURL, let data = await ImageCache.data(for: url) else { return nil }
        return downscale(data, maxPixel: maxPixel)
    }

    static func image(for source: IconSource, maxPixel: CGFloat = 700) async -> UIImage? {
        await image(for: await profile(for: source), maxPixel: maxPixel)
    }

    static func downscale(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxPixel, longest > 0 else { return image }
        let scale = maxPixel / longest
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

/// Icône chargée de façon asynchrone, avec motif de remplacement.
/// `onProfile` transmet la fiche trouvée (pour afficher le nom localisé).
struct SaintIcon: View {
    let source: IconSource?
    var initial: String = "☦"
    var cornerRadius: CGFloat = 14
    var onProfile: ((SaintProfile?) -> Void)? = nil

    @State private var image: UIImage?

    var body: some View {
        IconFrame(image: image, initial: initial, cornerRadius: cornerRadius)
            .task(id: source) {
                image = nil
                guard let source else { return }
                let profile = await IconLoader.profile(for: source)
                onProfile?(profile)
                let loaded = await IconLoader.image(for: profile)
                withAnimation(.easeOut(duration: 0.25)) { image = loaded }
            }
    }
}
