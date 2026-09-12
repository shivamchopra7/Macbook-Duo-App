import Foundation

/// How fold progress advances between an open lid and a closed one.
/// Every curve is monotonic and pinned at 0 and 1, so the exact-open and
/// closed branches of the shader stay reachable regardless of the choice.
public enum FoldCurve: String, CaseIterable, Sendable, Identifiable {
    case smooth, gentle, linear, brisk

    public static let fallback = FoldCurve.smooth

    public var id: String { rawValue }

    public static func resolve(persisted: String?) -> FoldCurve {
        guard let persisted, let curve = FoldCurve(rawValue: persisted) else { return fallback }
        return curve
    }

    public var title: String {
        switch self {
        case .smooth: return "Smooth"
        case .gentle: return "Gentle"
        case .linear: return "Linear"
        case .brisk: return "Brisk"
        }
    }

    public var symbol: String {
        switch self {
        case .smooth: return "point.bottomleft.forward.to.point.topright.scurvepath"
        case .gentle: return "wave.3.right"
        case .linear: return "line.diagonal"
        case .brisk: return "bolt"
        }
    }

    public var summary: String {
        switch self {
        case .smooth: return "Eases in and out, matching the original feel."
        case .gentle: return "Starts slowly and gathers pace toward closure."
        case .linear: return "Tracks the lid angle one-to-one."
        case .brisk: return "Responds immediately, then settles."
        }
    }

    public func apply(_ t: Double) -> Double {
        guard t.isFinite else { return 0 }
        let x = min(1, max(0, t))
        switch self {
        case .smooth: return x * x * (3 - 2 * x)
        case .gentle: return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
        case .linear: return x
        case .brisk: return 1 - (1 - x) * (1 - x)
        }
    }
}

/// User-adjustable parameters shared by every effect. The struct is a value:
/// callers make a changed copy rather than mutating shared state.
public struct EffectOptions: Equatable, Sendable {
    public static let intensityRange: ClosedRange<Double> = 0...1
    public static let segmentRange: ClosedRange<Int> = 2...8
    public static let responseRange: ClosedRange<TimeInterval> = 0.02...0.12
    public static let clearRange: ClosedRange<TimeInterval> = 0.3...1.2

    /// Exaggeration of each effect's geometry. 0.5 reproduces the original tuning.
    public let intensity: Double
    /// Panel, pleat or slat count for segmented effects.
    public let segments: Int
    public let curve: FoldCurve
    /// Time constant of the motion smoothing while the lid moves.
    public let responseTime: TimeInterval
    /// Length of the shared return-to-clear animation.
    public let clearDuration: TimeInterval

    public static let `default` = EffectOptions()

    public init(intensity: Double = 0.5, segments: Int = 4, curve: FoldCurve = .smooth,
                responseTime: TimeInterval = 0.045, clearDuration: TimeInterval = 0.6) {
        self.intensity = Self.clamp(intensity, Self.intensityRange, fallback: 0.5)
        self.segments = min(Self.segmentRange.upperBound, max(Self.segmentRange.lowerBound, segments))
        self.curve = curve
        self.responseTime = Self.clamp(responseTime, Self.responseRange, fallback: 0.045)
        self.clearDuration = Self.clamp(clearDuration, Self.clearRange, fallback: 0.6)
    }

    public var shaderIntensity: Float { Float(intensity) }
    public var shaderSegments: UInt32 { UInt32(segments) }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(range.upperBound, max(range.lowerBound, value))
    }
}
