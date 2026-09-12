import Foundation
import CoreVideo

final class FrameStore: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: CVPixelBuffer?
    private var revision: UInt64 = 0
    private var acceptedStream: ObjectIdentifier?
    func put(_ value: CVPixelBuffer) {
        lock.lock(); buffer = value; revision &+= 1; lock.unlock()
    }
    func get() -> (CVPixelBuffer?, UInt64) {
        lock.lock(); defer { lock.unlock() }; return (buffer, revision)
    }
    var hasFrame: Bool { lock.lock(); defer { lock.unlock() }; return buffer != nil }
    func acceptStream(_ stream: ObjectIdentifier) {
        lock.lock(); acceptedStream = stream; buffer = nil; revision &+= 1; lock.unlock()
    }
    func invalidateStream() {
        lock.lock(); acceptedStream = nil; buffer = nil; revision &+= 1; lock.unlock()
    }
    /// Check identity and replace the frame under the same lock as stop().
    /// Nil means rejected; true means this stream has just regained a frame.
    func put(_ value: CVPixelBuffer, from stream: ObjectIdentifier) -> Bool? {
        lock.lock(); defer { lock.unlock() }
        guard acceptedStream == stream else { return nil }
        let first = buffer == nil
        buffer = value; revision &+= 1
        return first
    }
    func clear(from stream: ObjectIdentifier) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard acceptedStream == stream else { return false }
        let changed = buffer != nil; buffer = nil; revision &+= 1
        return changed
    }
}
