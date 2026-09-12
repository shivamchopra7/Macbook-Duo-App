import AppKit
import MetalKit
import CoreVideo
import FoldCore

final class FoldRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    private let downsamplePipeline: MTLComputePipelineState
    private var blurPyramid: MTLTexture?
    private var blurLevels: [MTLTexture] = []
    private var blurredRevision: UInt64?
    private var renderedRevision: UInt64?
    private var renderedUniforms: FoldUniforms?
    private var cache: CVMetalTextureCache?
    private var importedBuffer: CVPixelBuffer?
    private var importedTexture: CVMetalTexture?
    private var importedRevision: UInt64?
    private let inFlight = DispatchSemaphore(value: 3)
    var frames: FrameStore?
    var fallback: MTLTexture?
    var parameters: () -> FoldUniforms = { FoldUniforms() }
    var animatedState: (() -> FoldVisualState?)?
    var blendsWithDesktop = false
    private var animation = FoldVisualAnimation()
    private var presentationGeneration: UInt64 = 0
    private var needsPresentationCallback = true
    var reportsEveryPresentation = false
    var pausesWhenSettled = false
    var keepsAnimating: () -> Bool = { false }
    var onFailure: ((String) -> Void)?
    var onPresented: (() -> Void)?
    private(set) var progress: Double = 0
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private(set) var drawnFrames = 0
    private(set) var skippedFrames = 0
    private(set) var blurBuildCount = 0
    private(set) var textureImportCount = 0
    private(set) var lastGPUTimeMS: Double = 0
    var transientTextureBytes: Int { blurPyramid?.allocatedSize ?? 0 }

    @MainActor init(device: MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else { throw AppError.message(L10n.text("Metal command queue unavailable.")) }
        self.queue = queue
        let pipelines = try FoldPipelines.shared(for:device)
        pipeline = pipelines.render
        downsamplePipeline = pipelines.downsample
        super.init()
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache) == kCVReturnSuccess else {
            throw AppError.message(L10n.text("Metal texture cache unavailable."))
        }
    }

    func configure(_ view: MTKView) {
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 60
        view.delegate = self
        view.isPaused = false
        view.enableSetNeedsDisplay = false
    }

    /// Preview timing follows the same options as the live overlay.
    func apply(options: EffectOptions) { animation.apply(options) }

    func resetProgress(to value: Double) {
        progress = value; lastTime = ProcessInfo.processInfo.systemUptime
        renderedUniforms = nil
        animation.reset()
        invalidatePresentation()
    }

    func invalidatePresentation() { presentationGeneration &+= 1; needsPresentationCallback = true }

    /// Completed or queued Metal commands retain their own resources. Clearing
    /// our references lets the desktop's full-size buffers retire after the last
    /// command, while keeping the compiled pipelines ready for the next movement.
    func releaseTransientResources() {
        invalidatePresentation()
        blurLevels.removeAll(); blurPyramid = nil; blurredRevision = nil
        importedTexture = nil; importedBuffer = nil; importedRevision = nil
        renderedUniforms = nil; renderedRevision = nil
        if let cache { CVMetalTextureCacheFlush(cache,0) }
    }

    /// The same captured frame can be presented at several lid angles. Import it
    /// once, retaining both its pixel buffer and Core Video texture until replaced.
    func importFrame(_ pixelBuffer: CVPixelBuffer, revision: UInt64) throws -> CVMetalTexture {
        if importedRevision == revision, importedBuffer === pixelBuffer, let importedTexture { return importedTexture }
        guard let cache else { throw AppError.message(L10n.text("Metal texture cache unavailable.")) }
        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,cache,pixelBuffer,
            nil,.bgra8Unorm,CVPixelBufferGetWidth(pixelBuffer),CVPixelBufferGetHeight(pixelBuffer),0,&cvTexture)
        guard result == kCVReturnSuccess, let cvTexture, CVMetalTextureGetTexture(cvTexture) != nil else {
            throw AppError.message(L10n.text("The current desktop frame could not be prepared for Metal."))
        }
        importedBuffer = pixelBuffer; importedTexture = cvTexture; importedRevision = revision
        textureImportCount += 1
        return cvTexture
    }

    func wake(_ view: MTKView) {
        guard view.window?.occlusionState.contains(.visible) == true else { return }
        if view.isPaused { lastTime = ProcessInfo.processInfo.systemUptime; animation.prime(at:lastTime) }
        view.isPaused = false
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { renderedUniforms = nil }

    func draw(in view: MTKView) {
        dispatchPrecondition(condition:.onQueue(.main))
        guard view.window?.isVisible == true, inFlight.wait(timeout: .now()) == .success else { return }
        var committed = false
        defer { if !committed { inFlight.signal() } }
        let frame = frames?.get()
        let pixelBuffer = frame?.0
        let revision = pixelBuffer == nil ? 0 : frame!.1
        guard pixelBuffer != nil || fallback != nil else { return }
        let now = ProcessInfo.processInfo.systemUptime
        var uniforms = parameters()
        let target = uniforms.progress > 0 ? FoldVisualState(progress:Double(uniforms.progress),
            defocus:Double(max(0,uniforms.defocus)),
            tilt:Double(uniforms.tilt >= 0 ? uniforms.tilt : uniforms.progress * .pi/2),
            referenceAngle:Double(uniforms.referenceAngle)) : .clear
        let visual = animatedState?() ?? animation.sample(target:target,at:now)
        progress = visual.progress
        lastTime = now
        uniforms.progress = Float(visual.progress)
        uniforms.defocus = Float(visual.defocus)
        uniforms.tilt = Float(visual.tilt)
        uniforms.referenceAngle = Float(visual.referenceAngle)
        uniforms.coverage = blendsWithDesktop ? Float(visual.coverage) : 1
        uniforms.size = SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height))
        let settled = visual.isNear(target) && !keepsAnimating()
        if renderedRevision == revision && renderedUniforms == uniforms {
            skippedFrames += 1
            if pausesWhenSettled && settled { view.isPaused = true }
            return
        }
        var cvTexture: CVMetalTexture?
        var texture = fallback
        if let pixelBuffer {
            do {
                cvTexture = try importFrame(pixelBuffer,revision:revision)
                texture = cvTexture.flatMap { CVMetalTextureGetTexture($0) }
            } catch { onFailure?(error.localizedDescription); return }
        }
        guard let texture else { return }
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let command = queue.makeCommandBuffer() else { return }
        do { try encode(command: command, pass: pass, texture: texture, uniforms: uniforms, sourceRevision:revision) }
        catch { blurredRevision = nil; renderedUniforms = nil; onFailure?(error.localizedDescription); return }
        let retainedTexture = cvTexture
        let generation = presentationGeneration
        let reportsPresentation = onPresented != nil && (needsPresentationCallback || reportsEveryPresentation)
        command.addCompletedHandler { [weak self, inFlight, pixelBuffer, retainedTexture] buffer in
            withExtendedLifetime((pixelBuffer, retainedTexture)) {}
            inFlight.signal()
            // Normal successful frames need no UI work after the first reveal.
            // Errors always return to main; synthetic checks retain every callback.
            guard reportsPresentation || buffer.status == .error else { return }
            DispatchQueue.main.async {
                guard let self, self.presentationGeneration == generation else { return }
                if buffer.status == .error {
                    self.blurredRevision = nil; self.renderedUniforms = nil
                    self.onFailure?(buffer.error?.localizedDescription ?? L10n.text("Metal rendering failed."))
                }
                self.lastGPUTimeMS = max(0, (buffer.gpuEndTime-buffer.gpuStartTime)*1000)
                if buffer.status == .completed { self.onPresented?() }
            }
        }
        command.present(drawable)
        committed = true
        command.commit()
        needsPresentationCallback = false
        drawnFrames += 1
        renderedRevision = revision; renderedUniforms = uniforms
        if pausesWhenSettled && settled { view.isPaused = true }
    }

    /// Rebuild on each new source frame. Reuse it when only the fold angle changes.
    /// All passes use this renderer's serial queue and tracked resources. Ending each
    /// encoder orders writes before the next level reads the same texture allocation.
    private func prepareBlur(command: MTLCommandBuffer, input: MTLTexture, revision: UInt64?) throws -> MTLTexture {
        if blurPyramid?.width != input.width || blurPyramid?.height != input.height || blurPyramid?.pixelFormat != input.pixelFormat {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: input.pixelFormat,
                width: input.width, height: input.height, mipmapped: true)
            descriptor.mipmapLevelCount = min(9, descriptor.mipmapLevelCount)
            descriptor.storageMode = .private
            descriptor.usage = [.shaderRead, .shaderWrite, .pixelFormatView]
            guard let texture = device.makeTexture(descriptor: descriptor) else {
                throw AppError.message(L10n.text("Blur texture allocation failed."))
            }
            var levels: [MTLTexture] = []
            for level in 0..<texture.mipmapLevelCount {
                guard let view = texture.makeTextureView(pixelFormat: texture.pixelFormat, textureType: .type2D,
                    levels: level..<(level+1), slices: 0..<1) else { throw AppError.message(L10n.text("Blur level unavailable.")) }
                levels.append(view)
            }
            blurPyramid = texture; blurLevels = levels
            blurredRevision = nil
        }
        if let revision, blurredRevision == revision, let pyramid = blurPyramid { return pyramid }
        guard let pyramid = blurPyramid, let blit = command.makeBlitCommandEncoder() else {
            throw AppError.message(L10n.text("Blur copy encoder unavailable."))
        }
        blit.copy(from: input, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(),
            sourceSize: MTLSize(width: input.width, height: input.height, depth: 1),
            to: pyramid, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin())
        blit.endEncoding()
        for level in 1..<blurLevels.count {
            guard let encoder = command.makeComputeCommandEncoder() else { throw AppError.message(L10n.text("Blur encoder unavailable.")) }
            encoder.setComputePipelineState(downsamplePipeline)
            encoder.setTexture(blurLevels[level-1], index: 0)
            encoder.setTexture(blurLevels[level], index: 1)
            encoder.dispatchThreads(MTLSize(width: blurLevels[level].width, height: blurLevels[level].height, depth: 1),
                threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
            encoder.endEncoding()
        }
        blurredRevision = revision
        blurBuildCount += 1
        return pyramid
    }

    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, texture: MTLTexture, uniforms: FoldUniforms, sourceRevision: UInt64? = nil) throws {
        let moving = uniforms.progress > 0.00001 && uniforms.progress < 1 && uniforms.fadeOnly < 0.5
        // Duo skips the pyramid at zero Softness. Geometrically minified effects,
        // including Ghost, still need it to keep fine source pixels stable.
        let needsBlur = moving && (uniforms.blur > 0 || uniforms.selectedEffect.needsPrefilteredSource)
        let blurred = needsBlur ? try prepareBlur(command: command, input: texture, revision:sourceRevision) : texture
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { throw AppError.message(L10n.text("Render encoder unavailable.")) }
        var uniforms = uniforms
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentTexture(blurred, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<FoldUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }
}
