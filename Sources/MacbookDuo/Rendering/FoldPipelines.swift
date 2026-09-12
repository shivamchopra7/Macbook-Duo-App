import Metal

/// Immutable pipelines are shared; command queues and mutable textures stay per renderer.
@MainActor final class FoldPipelines {
    private static var devices: [ObjectIdentifier:FoldPipelines] = [:]
    let render: MTLRenderPipelineState
    let downsample: MTLComputePipelineState
    static func shared(for device: MTLDevice) throws -> FoldPipelines {
        let key = ObjectIdentifier(device)
        if let existing = devices[key] { return existing }
        let pipelines = try FoldPipelines(device:device)
        devices[key] = pipelines
        return pipelines
    }
    private init(device: MTLDevice) throws {
        let library = try device.makeLibrary(source:FoldShader.source,options:nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name:"foldVertex")
        descriptor.fragmentFunction = library.makeFunction(name:"foldFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        render = try device.makeRenderPipelineState(descriptor:descriptor)
        guard let function = library.makeFunction(name:"foldDownsample") else {
            throw AppError.message(L10n.text("Blur shader unavailable."))
        }
        downsample = try device.makeComputePipelineState(function:function)
    }
}
