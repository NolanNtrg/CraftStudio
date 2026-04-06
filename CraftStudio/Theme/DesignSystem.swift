import SwiftUI

// MARK: - Color Palette

extension Color {
    // Backgrounds
    static let csBackground = Color(red: 250/255, green: 250/255, blue: 250/255)
    static let csSurface = Color.white
    static let csSurfaceSecondary = Color(red: 242/255, green: 242/255, blue: 247/255)
    
    // Accent
    static let csAccent = Color(red: 90/255, green: 200/255, blue: 173/255)
    static let csAccentHover = Color(red: 74/255, green: 184/255, blue: 157/255)
    static let csAccentLight = Color(red: 90/255, green: 200/255, blue: 173/255).opacity(0.12)
    
    // Text
    static let csTextPrimary = Color(red: 28/255, green: 28/255, blue: 30/255)
    static let csTextSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let csTextTertiary = Color(red: 174/255, green: 174/255, blue: 178/255)
    
    // Utility
    static let csBorder = Color(red: 229/255, green: 229/255, blue: 234/255)
    static let csDanger = Color(red: 255/255, green: 105/255, blue: 97/255)
    static let csSuccess = Color(red: 52/255, green: 199/255, blue: 89/255)
}

// MARK: - Design Tokens

enum CSRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 14
    static let extraLarge: CGFloat = 16
    static let pill: CGFloat = 100
}

enum CSSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum CSShadow {
    static let subtle = ShadowStyle(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    static let card = ShadowStyle(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    static let elevated = ShadowStyle(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Font Styles

extension Font {
    static let csTitle = Font.system(size: 24, weight: .bold, design: .rounded)
    static let csHeadline = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let csBody = Font.system(size: 14, weight: .regular, design: .rounded)
    static let csCaption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let csSmall = Font.system(size: 11, weight: .regular, design: .rounded)
    static let csButton = Font.system(size: 14, weight: .semibold, design: .rounded)
}

// MARK: - View Modifiers

struct CSCardModifier: ViewModifier {
    var padding: CGFloat = CSSpacing.lg
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.csSurface)
            .clipShape(RoundedRectangle(cornerRadius: CSRadius.large, style: .continuous))
            .shadow(color: CSShadow.card.color, radius: CSShadow.card.radius, x: CSShadow.card.x, y: CSShadow.card.y)
    }
}

struct CSSubtleShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: CSShadow.subtle.color, radius: CSShadow.subtle.radius, x: CSShadow.subtle.x, y: CSShadow.subtle.y)
    }
}

extension View {
    func csCard(padding: CGFloat = CSSpacing.lg) -> some View {
        modifier(CSCardModifier(padding: padding))
    }
    
    func csSubtleShadow() -> some View {
        modifier(CSSubtleShadowModifier())
    }
}

// MARK: - Sidebar Item

enum SidebarItem: String, CaseIterable, Identifiable {
    case vectorize = "Vectoriser"
    case eraser = "Gommer"
    case converter = "Convertir Audio"
    case print = "Imprimer"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .vectorize: return "wand.and.stars"
        case .eraser: return "eraser.fill"
        case .converter: return "waveform"
        case .print: return "printer.fill"
        }
    }
    
    var description: String {
        switch self {
        case .vectorize: return "Transformez vos images en vecteurs"
        case .eraser: return "Nettoyez vos images facilement"
        case .converter: return "Extrayez l'audio de vos vidéos"
        case .print: return "Imprimez vos modèles"
        }
    }
}
