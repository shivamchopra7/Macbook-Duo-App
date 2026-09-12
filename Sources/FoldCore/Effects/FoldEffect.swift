import Foundation

/// The catalog of lid effects. `rawValue` is the stable persisted identifier and
/// `shaderIndex` is the explicit numeric contract with the Metal fragment shader.
/// Neither may be renumbered: saved selections and the shader switch depend on both.
public enum FoldEffect: String, CaseIterable, Sendable, Identifiable {
    case duo, ghost, roll, shutter, flex, iris
    case fold, accordion, louver, card, curtain, ripple

    public static let fallback = FoldEffect.duo

    public var id: String { rawValue }
    public var persistedIdentifier: String { rawValue }

    /// Mirrored by `Uniforms.effect` in `FoldShader.source`.
    public var shaderIndex: UInt32 {
        switch self {
        case .duo: return 0
        case .ghost: return 5
        case .roll: return 1
        case .shutter: return 2
        case .flex: return 3
        case .iris: return 4
        case .fold: return 6
        case .accordion: return 7
        case .louver: return 8
        case .card: return 9
        case .curtain: return 10
        case .ripple: return 11
        }
    }

    /// An unreadable or unknown saved selection returns to the default effect.
    public static func resolve(persisted: String?) -> FoldEffect {
        guard let persisted, let effect = FoldEffect(rawValue: persisted) else { return fallback }
        return effect
    }

    /// The shader applies the same rule for an index it does not recognize.
    public static func resolve(shaderIndex: UInt32) -> FoldEffect {
        allCases.first { $0.shaderIndex == shaderIndex } ?? fallback
    }

    public var title: String {
        switch self {
        case .duo: return "Duo"
        case .ghost: return "Ghost"
        case .roll: return "Roll"
        case .shutter: return "Shutter"
        case .flex: return "Flex"
        case .iris: return "Iris"
        case .fold: return "Fold"
        case .accordion: return "Accordion"
        case .louver: return "Louver"
        case .card: return "Card"
        case .curtain: return "Curtain"
        case .ripple: return "Blackhole"
        }
    }

    public var symbol: String {
        switch self {
        case .duo: return "macbook"
        case .ghost: return "aqi.medium"
        case .roll: return "scroll"
        case .shutter: return "square.stack.3d.down.right"
        case .flex: return "rectangle.compress.vertical"
        case .iris: return "camera.aperture"
        case .fold: return "rectangle.split.1x2"
        case .accordion: return "line.3.horizontal"
        case .louver: return "rectangle.stack"
        case .card: return "rectangle.portrait.rotate"
        case .curtain: return "curtains.closed"
        case .ripple: return "hurricane"
        }
    }

    public var summary: String {
        switch self {
        case .duo: return "The desktop swells around the hinge as the lid closes."
        case .ghost: return "The desktop holds its resting plane as the lid tilts and gently falls out of focus."
        case .roll: return "The desktop curls into a roll that travels down to the hinge."
        case .shutter: return "Rigid panels telescope behind each other into the hinge."
        case .flex: return "One bowing flexible display collapses toward the hinge."
        case .iris: return "Eight overlapping blades close an aperture above the hinge."
        case .fold: return "The display creases across the middle and the top half folds down over the bottom."
        case .accordion: return "Pleats zig-zag and gather toward the hinge like a paper fan."
        case .louver: return "Horizontal slats tilt and overlap like closing window blinds."
        case .card: return "The whole desktop tips back as one rigid card in perspective."
        case .curtain: return "Drapes draw together from both sides and settle at the hinge."
        case .ripple: return "The desktop swirls into a black hole opening at the hinge."
        }
    }

    /// Whether the effect divides the display into `EffectOptions.segments` parts.
    public var usesSegments: Bool {
        switch self {
        case .shutter, .accordion, .louver, .curtain: return true
        default: return false
        }
    }

    /// Effects added to the original six, shown as "new" in the interface.
    public var isExpansion: Bool { shaderIndex >= 6 }

    /// Duo can skip the pyramid with Softness off. Effects that minify
    /// the source still need it for prefiltering at zero Softness.
    public var needsPrefilteredSource: Bool { self != .duo }
}
