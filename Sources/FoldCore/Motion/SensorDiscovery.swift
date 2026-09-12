import Foundation

/// Decides how long to keep looking for the lid-angle sensor before calling it
/// absent. Discovery can fail transiently right after launch or after a wake,
/// so a single empty result must not be reported as unsupported hardware — but
/// Macs without the sensor (the M1 MacBook Air and the 13-inch M1/M2 MacBook
/// Pro among them) will never produce one, and those users deserve a definite
/// answer instead of a spinner that never resolves.
public struct SensorDiscovery: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        /// Try discovery again after this delay.
        case retry(after: TimeInterval)
        /// This Mac has no continuous lid-angle sensor.
        case unsupported
    }

    public static let defaultAttempts = 4
    public static let defaultDelay: TimeInterval = 0.75

    public let maximumAttempts: Int
    public let retryDelay: TimeInterval
    public private(set) var attempts = 0

    public init(maximumAttempts: Int = SensorDiscovery.defaultAttempts,
                retryDelay: TimeInterval = SensorDiscovery.defaultDelay) {
        self.maximumAttempts = max(1, maximumAttempts)
        self.retryDelay = retryDelay.isFinite && retryDelay > 0 ? retryDelay : SensorDiscovery.defaultDelay
    }

    /// A device was found: discovery starts over for the next disconnection.
    public mutating func reset() { attempts = 0 }

    /// No device matched. Returns whether to look again or give up.
    public mutating func failed() -> Outcome {
        attempts += 1
        return attempts >= maximumAttempts ? .unsupported : .retry(after: retryDelay)
    }

    /// True once `failed()` has returned `.unsupported`.
    public var hasGivenUp: Bool { attempts >= maximumAttempts }
}
