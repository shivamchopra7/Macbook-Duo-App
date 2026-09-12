import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    /// Resource retirement must neither pin a stopped capture's textures nor
    /// invalidate already queued GPU work or reuse a stale revision on restart.
    static func checkResourceReuse(_ device: MTLDevice, _ renderer: FoldRenderer) throws -> [String:Any] {
        func buffer() throws -> CVPixelBuffer {
            var result: CVPixelBuffer?
            let attributes: [String:Any] = [kCVPixelBufferMetalCompatibilityKey as String:true,
                kCVPixelBufferIOSurfacePropertiesKey as String:[:]]
            try require(CVPixelBufferCreate(kCFAllocatorDefault,64,64,kCVPixelFormatType_32BGRA,
                attributes as CFDictionary,&result) == kCVReturnSuccess,"Test pixel buffer unavailable.")
            guard let result else { throw AppError.message("Test pixel buffer missing.") }
            CVPixelBufferLockBaseAddress(result,[])
            let bytes = CVPixelBufferGetBaseAddress(result)!.assumingMemoryBound(to:UInt8.self)
            bytes.initialize(repeating:200,count:CVPixelBufferGetBytesPerRow(result)*64)
            CVPixelBufferUnlockBaseAddress(result,[])
            return result
        }
        let pixelBuffer = try buffer()
        let secondRendererStarted = ProcessInfo.processInfo.systemUptime
        let secondRenderer = try FoldRenderer(device:device)
        let secondRendererMS = (ProcessInfo.processInfo.systemUptime-secondRendererStarted)*1000
        try require(secondRenderer.pipeline === renderer.pipeline,"Renderers rebuilt an immutable pipeline for the same device.")
        try require(secondRenderer.queue !== renderer.queue,"Renderers must keep independent serial command queues.")

        let store = FrameStore(), oldStream = NSObject(), newStream = NSObject()
        let oldID = ObjectIdentifier(oldStream), newID = ObjectIdentifier(newStream)
        store.acceptStream(oldID)
        try require(store.put(pixelBuffer,from:oldID) == true,"First capture frame was not detected.")
        try require(store.put(pixelBuffer,from:oldID) == false,"Repeated frame delivery repeatedly notified main.")
        store.invalidateStream()
        try require(store.put(pixelBuffer,from:oldID) == nil && !store.hasFrame,"A stopped stream resurrected a frame.")
        store.acceptStream(newID)
        try require(store.put(pixelBuffer,from:oldID) == nil,"A replaced stream delivered into the new capture.")
        try require(store.put(pixelBuffer,from:newID) == true,"Replacement capture lost its first frame.")
        try require(!store.clear(from:oldID) && store.hasFrame,"An old stream cleared the replacement frame.")
        try require(store.clear(from:newID) && !store.hasFrame,"An unavailable stream retained a frame.")
        try require(!store.clear(from:newID),"Repeated unavailable frames repeatedly notified main.")
        try require(store.put(pixelBuffer,from:newID) == true,"Capture recovery lost its first-frame notification.")
        // Race normal callbacks against stop-style invalidation. Both operations
        // must use one lock; a separate identity check followed by put can fail.
        // These threads only retain this immutable generated buffer; none writes pixels.
        struct ReadOnlyBuffer: @unchecked Sendable { let value: CVPixelBuffer }
        let sharedBuffer = ReadOnlyBuffer(value:pixelBuffer)
        for _ in 0..<100 {
            store.acceptStream(oldID)
            DispatchQueue.concurrentPerform(iterations:64) { index in
                if index == 31 { store.invalidateStream() }
                else { _ = store.put(sharedBuffer.value,from:oldID) }
            }
            try require(!store.hasFrame,"A concurrent old callback survived stream invalidation.")
        }
        let importsBefore = renderer.textureImportCount
        let imported = try renderer.importFrame(pixelBuffer,revision:4000)
        for _ in 0..<120 { _ = try renderer.importFrame(pixelBuffer,revision:4000) }
        try require(renderer.textureImportCount == importsBefore+1,"Repeated presentations reimported the same captured frame.")
        _ = try renderer.importFrame(pixelBuffer,revision:4001)
        try require(renderer.textureImportCount == importsBefore+2,"A recycled capture buffer did not import its new revision.")
        let texture = CVMetalTextureGetTexture(imported)!
        var u = FoldUniforms();u.progress = 0.5
        let plate = try target(device,64,64)
        let reference = try render(renderer,texture,plate,u,revision:4001)
        let retainedBytes = renderer.transientTextureBytes
        try require(retainedBytes > 0,"Blur resource test did not allocate a pyramid.")
        let command = try encode(renderer,texture,plate,u,revision:4001)
        renderer.releaseTransientResources()
        try require(renderer.transientTextureBytes == 0,"Hidden renderer retained its blur pyramid.")
        let completed = try read(plate,command)
        try require(completed.pixels == reference.pixels,"Retiring resources invalidated queued GPU work.")
        let rebuilt = try render(renderer,texture,plate,u,revision:4001)
        try require(rebuilt.pixels == reference.pixels,"Rebuilding a retired pyramid changed its pixels.")
        _ = try renderer.importFrame(pixelBuffer,revision:4001)
        try require(renderer.textureImportCount == importsBefore+3,"Clearing retained a stale captured texture import.")
        return ["sameFramePresentations":121,"importsForSameFrame":1,"newRevisionReimported":true,
            "sharedPipelines":true,"independentQueues":true,"secondRendererInitializationMS":secondRendererMS,
            "captureStopRaceRounds":100,"callbacksPerRound":64,"oldStreamRejected":true,"firstFrameRecovery":true,
            "retiredBlurBytes":retainedBytes,"queuedWorkSurvivesRetirement":true,"rebuiltPixelsIdentical":true]
    }
}
