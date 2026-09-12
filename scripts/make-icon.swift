// Renders the Macbook Duo app icon (.icns), the asset-catalog AppIcon set and
// the menu-bar mark, so the brand assets are reproducible:
//
//   swift scripts/make-icon.swift [Resources] [--from icon.png]
//
// Without --from the icon artwork is drawn from code. With --from, the given
// 1024x1024 PNG is used as the icon source instead; the menu-bar mark is
// always drawn from code. Both modes write MacbookDuo.icns, MacbookDuoIcon.png,
// MacbookDuoMark.png and Assets.xcassets/AppIcon.appiconset/*.png.
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

// MARK: - Command line

struct Options {
    var root = URL(fileURLWithPath: "Resources", isDirectory: true)
    var source: URL?
}

func parseOptions(_ arguments: [String]) -> Options {
    var options = Options()
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        if argument == "--from" {
            guard index+1 < arguments.count else { fail("--from needs a PNG path") }
            options.source = URL(fileURLWithPath: arguments[index+1]); index += 2
        } else if argument.hasPrefix("--") {
            fail("Unknown option \(argument). Usage: swift scripts/make-icon.swift [Resources] [--from icon.png]")
        } else {
            options.root = URL(fileURLWithPath: argument, isDirectory: true); index += 1
        }
    }
    return options
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1)
}

/// Loads a supplied 1024x1024 icon and returns a drawing closure that scales it.
func loadSource(_ url: URL) -> (CGContext, CGFloat) -> Void {
    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fail("Could not read an image from \(url.path)")
    }
    guard cgImage.width == 1024, cgImage.height == 1024 else {
        fail("The --from image must be 1024x1024 pixels; \(url.lastPathComponent) is \(cgImage.width)x\(cgImage.height)")
    }
    return { context, size in
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
    }
}

// MARK: - Output

/// macOS icon slots shared by the .iconset (for iconutil) and the asset catalog.
let slots: [(point: Int, scale: Int)] = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]

func slotSuffix(_ slot: (point: Int, scale: Int)) -> String {
    slot.scale == 1 ? "\(slot.point)" : "\(slot.point)@\(slot.scale)x"
}

func writeIconset(root: URL, draw: (CGContext, CGFloat) -> Void) throws {
    let iconset = root.appendingPathComponent("MacbookDuo.iconset", isDirectory: true)
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    for slot in slots {
        try write(render(size: slot.point*slot.scale, draw: draw), to: iconset.appendingPathComponent("icon_\(slotSuffix(slot)).png"))
    }
    let iconutil = Process(); iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("MacbookDuo.icns").path]
    try iconutil.run(); iconutil.waitUntilExit()
    try? FileManager.default.removeItem(at: iconset)
    guard iconutil.terminationStatus == 0 else { fail("iconutil failed with status \(iconutil.terminationStatus)") }
}

func writeAssetCatalog(root: URL, draw: (CGContext, CGFloat) -> Void) throws {
    let appiconset = root.appendingPathComponent("Assets.xcassets/AppIcon.appiconset", isDirectory: true)
    try FileManager.default.createDirectory(at: appiconset, withIntermediateDirectories: true)
    var images: [[String: Any]] = []
    for slot in slots {
        let filename = "icon_\(slot.point)x\(slot.point)\(slot.scale == 1 ? "" : "@\(slot.scale)x").png"
        try write(render(size: slot.point*slot.scale, draw: draw), to: appiconset.appendingPathComponent(filename))
        images.append(["filename": filename, "idiom": "mac", "scale": "\(slot.scale)x", "size": "\(slot.point)x\(slot.point)"])
    }
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: appiconset.appendingPathComponent("Contents.json"))
    let catalogInfo: [String: Any] = ["info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: catalogInfo, options: [.prettyPrinted, .sortedKeys])
        .write(to: root.appendingPathComponent("Assets.xcassets/Contents.json"))
}

let options = parseOptions(Array(CommandLine.arguments.dropFirst()))
let root = options.root
let iconDraw: (CGContext, CGFloat) -> Void = options.source.map(loadSource) ?? drawIcon
do {
    try writeIconset(root: root, draw: iconDraw)
    try writeAssetCatalog(root: root, draw: iconDraw)
    try write(render(size: 176, draw: drawMark), to: root.appendingPathComponent("MacbookDuoMark.png"))
    try write(render(size: 1024, draw: iconDraw), to: root.appendingPathComponent("MacbookDuoIcon.png"))
} catch {
    fail("Writing icon assets failed: \(error.localizedDescription)")
}
let mode = options.source.map { "from \($0.lastPathComponent)" } ?? "from code"
print("Wrote MacbookDuo.icns, MacbookDuoIcon.png, MacbookDuoMark.png and Assets.xcassets/AppIcon.appiconset (\(mode)) in \(root.path)")
