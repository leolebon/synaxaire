import SwiftUI
import UIKit

// MARK: - Couleurs

enum Theme {
    /// Couleur adaptative clair / sombre.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }

    static let burgundy = adaptive(light: 0x7A1F2B, dark: 0xD9707C)
    static let gold = adaptive(light: 0xA8801E, dark: 0xE2C064)
    static let goldBright = Color(UIColor(hex: 0xD4AF37))
    static let parchment = adaptive(light: 0xF7F1E3, dark: 0x16110F)
    static let card = adaptive(light: 0xFFFBF2, dark: 0x241C19)
    static let ink = adaptive(light: 0x2B1D16, dark: 0xF2E8D8)
    static let inkSoft = adaptive(light: 0x6E5B4E, dark: 0xBFAE9B)
    static let hairline = adaptive(light: 0xE4D6B8, dark: 0x3D312A)

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

/// Tailles standard des icônes (format portrait 3:4).
enum IconSize {
    static let hero = CGSize(width: 150, height: 200)
    static let gallery = CGSize(width: 96, height: 128)
    static let row = CGSize(width: 36, height: 48)
    static let detail = CGSize(width: 210, height: 280)
    static let widgetSmall = CGSize(width: 42, height: 56)
    static let widgetMedium = CGSize(width: 84, height: 112)
    static let widgetLarge = CGSize(width: 96, height: 128)
    static let widgetTile = CGSize(width: 66, height: 88)
}

extension View {
    /// Applique une taille d'icône standard.
    func iconSize(_ size: CGSize) -> some View {
        frame(width: size.width, height: size.height)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension FastLevel {
    var color: Color {
        switch self {
        case .noFast: return Theme.adaptive(light: 0x4F7A4A, dark: 0x8CC084)
        case .fastFree: return Theme.adaptive(light: 0xB8862B, dark: 0xE8C063)
        case .dairy: return Theme.adaptive(light: 0xC49A2C, dark: 0xF0CF6A)
        case .fish: return Theme.adaptive(light: 0x2F6690, dark: 0x7FB5E0)
        case .wineOil: return Theme.adaptive(light: 0x8E2C48, dark: 0xE07A98)
        case .strict: return Theme.adaptive(light: 0x4B3B6B, dark: 0xA996D6)
        }
    }
}

extension FeastRank {
    var color: Color {
        switch self {
        case .pascha, .great: return Theme.burgundy
        case .holyWeek: return Theme.adaptive(light: 0x3B2A4D, dark: 0xB7A3D8)
        case .major: return Theme.gold
        case .sunday: return Theme.burgundy.opacity(0.85)
        case .saint, .ordinary: return Theme.inkSoft
        }
    }

    /// Nombre de croix affichées (indication typiconale simplifiée).
    var marks: String {
        switch self {
        case .pascha: return "☩☩☩"
        case .great: return "☩☩"
        case .major, .holyWeek: return "☩"
        default: return ""
        }
    }
}

// MARK: - Composants

/// Badge coloré du niveau de jeûne.
struct FastBadge: View {
    let level: FastLevel
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.symbol)
            Text(compact ? level.shortTitle : level.title)
                .lineLimit(1)
        }
        .font(.system(size: compact ? 11 : 13, weight: .semibold))
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.vertical, compact ? 3 : 5)
        .foregroundStyle(level.color)
        .background(level.color.opacity(0.14), in: Capsule())
    }
}

/// Pastilles des aliments permis / interdits.
struct FoodChips: View {
    let level: FastLevel

    private let categories: [FoodCategory] = [.meat, .dairy, .eggs, .fish, .oil, .wine]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(categories) { cat in
                let ok = level.allowed.contains(cat)
                VStack(spacing: 2) {
                    Text(cat.emoji)
                        .font(.system(size: 18))
                        .grayscale(ok ? 0 : 1)
                        .opacity(ok ? 1 : 0.35)
                        .overlay {
                            if !ok {
                                Rectangle().fill(Theme.burgundy).frame(height: 2).rotationEffect(.degrees(-35))
                            }
                        }
                    Text(cat.label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(ok ? Theme.ink : Theme.inkSoft.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(cat.label) : \(Loc.t(ok ? "food.allowed" : "food.forbidden"))")
            }
        }
    }
}

/// Cadre d'icône : l'image remplit exactement la taille donnée par le parent et ne déborde jamais.
struct IconFrame: View {
    let image: UIImage?
    var initial: String = "☦"
    var cornerRadius: CGFloat = 14

    var body: some View {
        Color.clear
            .overlay(alignment: .top) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    IconPlaceholder(initial: initial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Theme.goldBright, Theme.gold.opacity(0.6), Theme.goldBright],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct IconPlaceholder: View {
    var initial: String

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                LinearGradient(colors: [Color(UIColor(hex: 0x5C1621)), Color(UIColor(hex: 0x2E0B10))],
                               startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(RadialGradient(colors: [Theme.goldBright.opacity(0.9), Theme.goldBright.opacity(0.25)],
                                         center: .center, startRadius: 2, endRadius: s * 0.32))
                    .frame(width: s * 0.62, height: s * 0.62)
                    .offset(y: -s * 0.08)
                Text(initial)
                    .font(.system(size: s * 0.3, weight: .bold, design: .serif))
                    .foregroundStyle(Color(UIColor(hex: 0x3A0E15)))
                    .offset(y: -s * 0.08)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

extension Commemoration {
    /// Initiale du nom du saint pour le motif de remplacement.
    var initial: String {
        searchQuery.first.map { String($0).uppercased() } ?? "☦"
    }
}

/// Carte de section avec titre.
struct SectionCard<Content: View>: View {
    let title: String
    var symbol: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).foregroundStyle(Theme.gold) }
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(Theme.gold)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }
}
