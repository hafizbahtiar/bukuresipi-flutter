// Usage: swift svg2png.swift <size> <in.svg> <out.png> ... : renders each SVG with a transparent background.
import AppKit
let a = CommandLine.arguments, size = Int(a[1])!
var i = 2
while i + 1 < a.count {
    guard let img = NSImage(contentsOf: URL(fileURLWithPath: a[i])) else { fatalError("cannot read \(a[i])") }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[i + 1]))
    i += 2
}
