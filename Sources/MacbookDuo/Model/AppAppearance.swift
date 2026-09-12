import AppKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { L10n.text(rawValue.capitalized) }
    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
    var native: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named:.aqua)
        case .dark: return NSAppearance(named:.darkAqua)
        }
    }
}
