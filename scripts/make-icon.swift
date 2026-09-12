// Renders the Macbook Duo app icon (.icns) and menu-bar mark from code, so the
// brand assets are reproducible: swift scripts/make-icon.swift
import AppKit

func squircle(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func render(size: Int, draw: (CGContext, CGFloat) -> Void) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size*4,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setAllowsAntialiasing(true); context.interpolationQuality = .high
    draw(context, CGFloat(size))
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) throws {
    try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: url)
}

/// The icon: a deep liquid-glass tile with a lid folding over a glowing display.
func drawIcon(_ c: CGContext, _ s: CGFloat) {
    let u = s/1024
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let tile = CGRect(x: 100*u, y: 100*u, width: 824*u, height: 824*u)
    c.saveGState()
    c.addPath(squircle(tile, radius: 186*u)); c.clip()
    let back = CGGradient(colorsSpace: space, colors: [
        NSColor(red: 0.09, green: 0.10, blue: 0.24, alpha: 1).cgColor,
        NSColor(red: 0.16, green: 0.24, blue: 0.62, alpha: 1).cgColor,
        NSColor(red: 0.20, green: 0.63, blue: 0.94, alpha: 1).cgColor] as CFArray, locations: [0, 0.55, 1])!
    c.drawLinearGradient(back, start: CGPoint(x: tile.minX, y: tile.minY), end: CGPoint(x: tile.maxX, y: tile.maxY), options: [])
    // Soft caustic glow low-left, like light through glass.
    let glow = CGGradient(colorsSpace: space, colors: [
        NSColor(red: 0.55, green: 0.85, blue: 1, alpha: 0.55).cgColor,
        NSColor(red: 0.55, green: 0.85, blue: 1, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(glow, startCenter: CGPoint(x: 330*u, y: 300*u), startRadius: 0,
                         endCenter: CGPoint(x: 330*u, y: 300*u), endRadius: 520*u, options: [])
    // Base: the keyboard deck.
    let deck = CGRect(x: 232*u, y: 300*u, width: 560*u, height: 60*u)
    c.setFillColor(NSColor(white: 1, alpha: 0.28).cgColor)
    c.addPath(squircle(deck, radius: 30*u)); c.fillPath()
    // Display: a tall glass panel with the desktop glow inside.
    let display = CGRect(x: 262*u, y: 360*u, width: 500*u, height: 330*u)
    c.setFillColor(NSColor(white: 1, alpha: 0.16).cgColor)
    c.addPath(squircle(display, radius: 34*u)); c.fillPath()
    c.saveGState()
    c.addPath(squircle(display.insetBy(dx: 18*u, dy: 18*u), radius: 22*u)); c.clip()
    let screen = CGGradient(colorsSpace: space, colors: [
        NSColor(red: 1.0, green: 0.62, blue: 0.32, alpha: 1).cgColor,
        NSColor(red: 0.97, green: 0.35, blue: 0.55, alpha: 1).cgColor,
        NSColor(red: 0.45, green: 0.30, blue: 0.95, alpha: 1).cgColor] as CFArray, locations: [0, 0.5, 1])!
    c.drawLinearGradient(screen, start: CGPoint(x: display.minX, y: display.minY), end: CGPoint(x: display.maxX, y: display.maxY), options: [])
    c.restoreGState()
    // The lid: a tilted glass sheet folding over the display (perspective via affine skew).
    c.saveGState()
    c.translateBy(x: 512*u, y: 690*u)
    c.concatenate(CGAffineTransform(a: 0.92, b: 0, c: 0, d: 0.42, tx: 0, ty: 0))
    let lid = CGRect(x: -250*u, y: -20*u, width: 500*u, height: 330*u)
    c.setFillColor(NSColor(white: 1, alpha: 0.34).cgColor)
    c.addPath(squircle(lid, radius: 34*u)); c.fillPath()
    c.setStrokeColor(NSColor(white: 1, alpha: 0.75).cgColor); c.setLineWidth(6*u)
    c.addPath(squircle(lid.insetBy(dx: 3*u, dy: 3*u), radius: 32*u)); c.strokePath()
    // Specular streak across the lid.
    c.saveGState(); c.addPath(squircle(lid, radius: 34*u)); c.clip()
    let streak = CGGradient(colorsSpace: space, colors: [
        NSColor(white: 1, alpha: 0).cgColor, NSColor(white: 1, alpha: 0.55).cgColor, NSColor(white: 1, alpha: 0).cgColor] as CFArray, locations: [0.35, 0.5, 0.65])!
    c.drawLinearGradient(streak, start: CGPoint(x: lid.minX, y: lid.minY), end: CGPoint(x: lid.maxX, y: lid.maxY), options: [])
    c.restoreGState()
    c.restoreGState()
    // Hinge line and top rim highlight of the tile.
    c.setStrokeColor(NSColor(white: 1, alpha: 0.5).cgColor); c.setLineWidth(8*u)
    c.move(to: CGPoint(x: 262*u, y: 690*u)); c.addLine(to: CGPoint(x: 762*u, y: 690*u)); c.strokePath()
    c.restoreGState()
    let rim = CGGradient(colorsSpace: space, colors: [NSColor(white: 1, alpha: 0.45).cgColor, NSColor(white: 1, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
    c.saveGState(); c.addPath(squircle(tile, radius: 186*u)); c.clip()
    c.drawLinearGradient(rim, start: CGPoint(x: tile.midX, y: tile.maxY), end: CGPoint(x: tile.midX, y: tile.maxY-120*u), options: [])
    c.restoreGState()
}

/// Menu-bar template mark: a laptop with the lid mid-fold, single color.
func drawMark(_ c: CGContext, _ s: CGFloat) {
    let u = s/88
    c.setFillColor(NSColor.black.cgColor); c.setStrokeColor(NSColor.black.cgColor)
    c.setLineWidth(6*u); c.setLineCap(.round); c.setLineJoin(.round)
    c.addPath(squircle(CGRect(x: 8*u, y: 14*u, width: 72*u, height: 8*u), radius: 4*u)); c.fillPath()
    c.addPath(squircle(CGRect(x: 18*u, y: 24*u, width: 52*u, height: 36*u), radius: 6*u)); c.strokePath()
    c.move(to: CGPoint(x: 18*u, y: 60*u)); c.addLine(to: CGPoint(x: 34*u, y: 76*u)); c.addLine(to: CGPoint(x: 66*u, y: 76*u)); c.addLine(to: CGPoint(x: 70*u, y: 60*u))
    c.strokePath()
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources", isDirectory: true)
let iconset = root.appendingPathComponent("MacbookDuo.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (name, size) in [("16",16),("16@2x",32),("32",32),("32@2x",64),("128",128),("128@2x",256),("256",256),("256@2x",512),("512",512),("512@2x",1024)] {
    try write(render(size: size, draw: drawIcon), to: iconset.appendingPathComponent("icon_\(name).png"))
}
try write(render(size: 176, draw: drawMark), to: root.appendingPathComponent("MacbookDuoMark.png"))
try write(render(size: 1024, draw: drawIcon), to: root.appendingPathComponent("MacbookDuoIcon.png"))
let iconutil = Process(); iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("MacbookDuo.icns").path]
try iconutil.run(); iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print("Wrote MacbookDuo.icns, MacbookDuoIcon.png and MacbookDuoMark.png in \(root.path)")
