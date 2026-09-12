import AppKit
import MetalKit
import CoreVideo

extension FoldRenderer {
    func makeSyntheticFrame() throws -> CVPixelBuffer {
        let input = try makePreviewTexture()
        let w = input.width, h = input.height
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:w,height:h,mipmapped:false)
        descriptor.usage = .renderTarget; descriptor.storageMode = .shared
        guard let target = device.makeTexture(descriptor:descriptor), let command = queue.makeCommandBuffer() else {
            throw AppError.message(L10n.text("Cannot create the overlay test frame."))
        }
        let pass = MTLRenderPassDescriptor();pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
        try encode(command:command,pass:pass,texture:input,uniforms:FoldUniforms())
        command.commit();command.waitUntilCompleted()
        guard command.status == .completed else { throw AppError.message(L10n.text("Test frame rendering failed.")) }
        var pixel: CVPixelBuffer?
        let attributes: [String:Any] = [kCVPixelBufferMetalCompatibilityKey as String:true,
                                       kCVPixelBufferIOSurfacePropertiesKey as String:[:]]
        guard CVPixelBufferCreate(kCFAllocatorDefault,w,h,kCVPixelFormatType_32BGRA,attributes as CFDictionary,&pixel) == kCVReturnSuccess,
              let pixel else { throw AppError.message(L10n.text("Test pixel buffer unavailable.")) }
        CVPixelBufferLockBaseAddress(pixel,[])
        target.getBytes(CVPixelBufferGetBaseAddress(pixel)!,bytesPerRow:CVPixelBufferGetBytesPerRow(pixel),from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)
        CVPixelBufferUnlockBaseAddress(pixel,[])
        return pixel
    }

    func makePreviewTexture(width: Int = 1440, height: Int = 936) throws -> MTLTexture {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width*4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw AppError.message(L10n.text("Preview image could not be created."))
        }
        context.scaleBy(x: CGFloat(width)/1440, y: CGFloat(height)/936)
        let colors = [NSColor(red: 0.07, green: 0.13, blue: 0.18, alpha: 1).cgColor,
                      NSColor(red: 0.18, green: 0.47, blue: 0.48, alpha: 1).cgColor,
                      NSColor(red: 0.89, green: 0.68, blue: 0.48, alpha: 1).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0,0.6,1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 720,y: 936), end: CGPoint(x: 720,y: 0), options: [])
        for i in 0..<6 {
            let path = CGMutablePath()
            let y = Double(i)*60
            path.move(to: CGPoint(x:0,y:y))
            path.addCurve(to: CGPoint(x:1440,y:y+190), control1: CGPoint(x:480,y:y+430), control2: CGPoint(x:1000,y:y-180))
            path.addLine(to: CGPoint(x:1440,y:0));path.addLine(to:.zero);path.closeSubpath()
            context.setFillColor(NSColor(red:0.06,green:0.19+Double(i)*0.012,blue:0.24+Double(i)*0.012,alpha:0.30).cgColor)
            context.addPath(path);context.fillPath()
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let title: [NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:116,weight:.light), .foregroundColor:NSColor.white.withAlphaComponent(0.9)]
        let caption: [NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:23,weight:.medium), .foregroundColor:NSColor.white.withAlphaComponent(0.8)]
        let previewTitle = "Macbook Duo" as NSString
        let titleWidth = previewTitle.size(withAttributes:title).width
        previewTitle.draw(at:CGPoint(x:(1440-titleWidth)/2,y:530),withAttributes:title)
        let previewCaption = L10n.text("A little motion. A different feeling.") as NSString
        let captionWidth = previewCaption.size(withAttributes:caption).width
        previewCaption.draw(at:CGPoint(x:(1440-captionWidth)/2,y:493),withAttributes:caption)
        NSColor.white.withAlphaComponent(0.16).setFill()
        NSBezierPath(roundedRect:NSRect(x:490,y:28,width:460,height:78),xRadius:23,yRadius:23).fill()
        for i in 0..<7 {
            NSColor(calibratedHue:CGFloat(i)/9,saturation:0.35,brightness:0.95,alpha:0.9).setFill()
            NSBezierPath(roundedRect:NSRect(x:511+i*62,y:41,width:49,height:49),xRadius:13,yRadius:13).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let image = context.makeImage() else { throw AppError.message(L10n.text("Preview image is unavailable.")) }
        return try MTKTextureLoader(device:device).newTexture(cgImage:image,options:[.SRGB:false,.origin:MTKTextureLoader.Origin.topLeft])
    }
}
