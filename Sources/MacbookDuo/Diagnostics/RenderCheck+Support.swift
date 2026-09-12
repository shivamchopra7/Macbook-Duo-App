import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw AppError.message(message) }
    }

    static func target(_ device: MTLDevice, _ width: Int, _ height: Int, shared: Bool = true) throws -> MTLTexture {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]; d.storageMode = shared ? .shared : .private
        guard let texture = device.makeTexture(descriptor: d) else { throw AppError.message("Test texture unavailable.") }
        return texture
    }

    static func encode(_ renderer: FoldRenderer, _ source: MTLTexture, _ output: MTLTexture,
                       _ uniforms: FoldUniforms, revision: UInt64? = nil) throws -> MTLCommandBuffer {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        guard let command = renderer.queue.makeCommandBuffer() else { throw AppError.message("Test command unavailable.") }
        var u = uniforms; u.size = SIMD2(Float(output.width), Float(output.height))
        try renderer.encode(command: command, pass: pass, texture: source, uniforms: u, sourceRevision:revision)
        command.commit()
        return command
    }

    static func read(_ target: MTLTexture, _ command: MTLCommandBuffer) throws -> Frame {
        command.waitUntilCompleted()
        try require(command.status == .completed, command.error?.localizedDescription ?? "GPU command failed.")
        let w = target.width, h = target.height
        var pixels = [UInt8](repeating: 0, count: w*h*4)
        target.getBytes(&pixels, bytesPerRow: w*4, from: MTLRegionMake2D(0,0,w,h), mipmapLevel: 0)
        try require(stride(from: 3, to: pixels.count, by: 4).allSatisfy { pixels[$0] == 255 }, "Overlay lost opacity.")
        return Frame(pixels: pixels, width: w, height: h, gpuMS: (command.gpuEndTime-command.gpuStartTime)*1000)
    }

    static func render(_ renderer: FoldRenderer, _ source: MTLTexture, _ output: MTLTexture,
                       _ uniforms: FoldUniforms, revision: UInt64? = nil) throws -> Frame {
        try read(output, encode(renderer, source, output, uniforms,revision:revision))
    }

    static func save(_ frame: Frame, _ url: URL) throws {
        let provider = CGDataProvider(data: Data(frame.pixels) as CFData)!
        let bitmap = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little)
        let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.width*4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: bitmap, provider: provider, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent)!
        try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: url)
    }

    static func fixture(_ device: MTLDevice, width: Int, height: Int,
                        pixel: (Int, Int) -> UInt8) throws -> MTLTexture {
        let texture = try target(device, width, height)
        var bytes = [UInt8](repeating: 255, count: width*height*4)
        for y in 0..<height { for x in 0..<width {
            let index = (y*width+x)*4, value = pixel(x,y)
            bytes[index] = value; bytes[index+1] = value; bytes[index+2] = value
        } }
        texture.replace(region: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width*4)
        return texture
    }

    static func glyphBounds(_ frame: Frame) throws -> (x: Int, y: Int, width: Int, height: Int) {
        var xs: [Int] = [], ys: [Int] = []
        for y in (frame.height*2/3)..<(frame.height*97/100) {
            for x in (frame.width*2/5)..<(frame.width*3/5) where frame.gray(x,y) < 80 { xs.append(x); ys.append(y) }
        }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            throw AppError.message("The hinge glyph disappeared.")
        }
        return (minX, minY, maxX-minX+1, maxY-minY+1)
    }

    static func variation(_ frame: Frame, rows: Range<Int>) -> Double {
        var total = 0, count = 0
        for y in rows { for x in (frame.width/4)..<(frame.width*3/4) {
            total += abs(frame.gray(x+1,y)-frame.gray(x,y)); count += 1
        } }
        return Double(total)/Double(count)
    }

    static func meanAbsDiff(_ a: Frame, _ b: Frame) -> Double {
        var total = 0.0
        for i in stride(from: 0, to: a.pixels.count, by: 4) { total += abs(Double(a.pixels[i])-Double(b.pixels[i])) }
        return total/Double(a.pixels.count/4)
    }

    static func rowMean(_ f: Frame, _ y: Int, _ x: Range<Int>? = nil) -> Double {
        let span = x ?? 0..<f.width
        return Double(span.reduce(0) { $0+f.gray($1,y) })/Double(span.count)
    }

    static func topLit(_ f: Frame, x: Int, threshold: Int = 24) -> Int {
        for y in 0..<f.height where f.gray(x,y) > threshold { return y }
        return f.height
    }

    static func litCount(_ f: Frame, row y: Int, threshold: Int = 24) -> Int {
        (0..<f.width).reduce(0) { $0+(f.gray($1,y) > threshold ? 1 : 0) }
    }

    static func brightCount(_ f: Frame, _ threshold: Int) -> Int {
        stride(from: 0, to: f.pixels.count, by: 4).reduce(0) { $0+(Int(f.pixels[$1]) > threshold ? 1 : 0) }
    }

    static func brightCentroid(_ f: Frame, _ threshold: Int) -> (x: Double, y: Double, count: Int) {
        var sx = 0.0, sy = 0.0, n = 0
        for y in 0..<f.height { for x in 0..<f.width where f.gray(x,y) > threshold {
            sx += Double(x); sy += Double(y); n += 1
        } }
        return (n == 0 ? 0 : sx/Double(n), n == 0 ? 0 : sy/Double(n), n)
    }

    /// Row index of a height fraction measured up from the hinge.
    static func row(_ height: Double, _ h: Int) -> Int {
        min(h-1, max(0, Int((1-height)*Double(h))))
    }

    /// Bands of rows whose mean exceeds a level, collapsed to their centres.
    static func brightRows(_ f: Frame, above level: Double, rows: Range<Int>,
                           columns: Range<Int>? = nil) -> [Int] {
        var groups: [[Int]] = []
        for y in rows {
            guard rowMean(f,y,columns) > level else { continue }
            if let last = groups.last?.last, y == last+1 { groups[groups.count-1].append(y) } else { groups.append([y]) }
        }
        return groups.map { $0.reduce(0,+)/$0.count }
    }

    /// True when a rectangle of the output still holds the source rectangle,
    /// optionally shifted down by a whole number of rows.
    static func identical(_ f: Frame, _ source: [UInt8], rows: Range<Int>,
                          columns: Range<Int>, shiftedBy: Int = 0) -> Bool {
        for y in rows {
            let from = y-shiftedBy
            if from < 0 || from >= f.height { return false }
            for x in columns {
                let a = (y*f.width+x)*4, b = (from*f.width+x)*4
                for channel in 0..<4 where f.pixels[a+channel] != source[b+channel] { return false }
            }
        }
        return true
    }

    /// Screen pixel for a polar sample around the iris centre, in height units.
    static func irisPoint(_ radius: Double, _ angle: Double, _ f: Frame) -> (Int, Int)? {
        let aspect = Double(f.width)/Double(f.height)
        let uvx = 0.5+radius*cos(angle)/aspect, height = 0.14+radius*sin(angle)
        let x = Int(uvx*Double(f.width)), y = Int((1-height)*Double(f.height))
        guard x >= 0, x < f.width, y >= 0, y < f.height else { return nil }
        return (x,y)
    }

    static func edgeRamp(_ frame: Frame, horizontal: Bool) -> Int {
        let length = horizontal ? frame.width : frame.height
        let values = (0..<(length/3)).map { horizontal ? frame.gray($0,frame.height/2) : frame.gray(frame.width/2,$0) }
        return values.filter { $0 > 25 && $0 < 230 }.count
    }
}
