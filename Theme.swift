import SwiftUI

struct Theme {
    static let background = Color.themeBackground
    static let surface = Color.themeSurface
    static let sidebar = Color.themeSidebar
    static let accent = Color.indigo
    static let userBubble = Color.indigo.opacity(0.8)
    static let assistantBubble = Color.themeSurface
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
}

extension Color {
    // Define fallbacks using standard UI colors so that strictly asset catalogs aren't needed
    static var themeBackground: Color {
        Color(UIColor.systemBackground)
    }
    static var themeSurface: Color {
        Color(UIColor.secondarySystemBackground)
    }
    static var themeSidebar: Color {
        Color(UIColor.tertiarySystemBackground)
    }
}
