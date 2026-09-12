import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    /// Geometry and optics checks specific to the Card effect. Placeholder until implemented.
    static func checkCard(_ device: MTLDevice, _ renderer: FoldRenderer,
                          _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        [:]
    }
}
