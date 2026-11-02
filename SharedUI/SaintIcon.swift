import SwiftUI
import UIKit

/// Source d'une icône : article Wikipédia connu, ou recherche à partir d'une commémoration.
enum IconSource: Equatable {
    case title(String, fallback: Commemoration?)
    case commemoration(Commemoration)

    static func hero(for day: LiturgicalDay) -> IconSource? {
        if let t = day.heroWikipediaTitle { return .title(t, fallback: day.primarySaint) }
        if let c = day.primarySaint { return .commemoration(c) }
        return nil
    }
}

enum IconLoader {
    /// Charge la fiche Wikipédia correspondant à la source.
    static func profile(for source: IconSource) async -> SaintProfile? {
        switch source {
        case .title(let title, let fallback):
            let p = await WikipediaService.shared.profile(forTitle: title)
            if p?.imageURL == nil, let fallback {
                return await WikipediaService.shared.profile(for: fallback) ?? p
            }
            return p
        case .commemoration(let c):
            return await WikipediaService.shared.profile(for: c)
        }
    }

    /// Charge l'image (réduite) d'une source.
    static func image(for source: IconSource, maxPixel: CGFloat = 700) async -> UIImage? {
        guard let profile = await profile(for: source), let url = profile.imageURL,
              let data = await ImageCache.data(for: url) else { return nil }
        return downscale(data, maxPixel: maxPixel)
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
struct SaintIcon: View {
    let source: IconSource?
    var initial: String = "☦"
    var cornerRadius: CGFloat = 14

    @State private var image: UIImage?

    var body: some View {
        IconFrame(image: image, initial: initial, cornerRadius: cornerRadius)
            .task(id: source) {
                image = nil
                guard let source else { return }
                let loaded = await IconLoader.image(for: source)
                withAnimation(.easeOut(duration: 0.25)) { image = loaded }
            }
    }
}
