import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift make-icon.swift <output.iconset>")
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func render(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    let scale = CGFloat(pixels) / 1024
    context.cgContext.scaleBy(x: scale, y: scale)
    let background = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 205, yRadius: 205)
    NSGradient(colors: [.white, NSColor(white: 0.3, alpha: 1), .black],
               atLocations: [0, 0.4, 1], colorSpace: .deviceRGB)?.draw(in: background, angle: -70)
    NSColor.white.withAlphaComponent(0.18).setStroke()
    background.lineWidth = 3
    background.stroke()

    let branch = NSBezierPath()
    branch.move(to: NSPoint(x: 512, y: 285))
    branch.line(to: NSPoint(x: 512, y: 460))
    branch.curve(to: NSPoint(x: 338, y: 674), controlPoint1: NSPoint(x: 512, y: 565), controlPoint2: NSPoint(x: 338, y: 563))
    branch.move(to: NSPoint(x: 512, y: 460))
    branch.curve(to: NSPoint(x: 686, y: 674), controlPoint1: NSPoint(x: 512, y: 565), controlPoint2: NSPoint(x: 686, y: 563))
    branch.lineWidth = 65
    branch.lineCapStyle = .round
    NSColor.white.setStroke()
    branch.stroke()
    for point in [NSPoint(x: 512, y: 285), NSPoint(x: 338, y: 702), NSPoint(x: 686, y: 702)] {
        let ring = NSBezierPath(ovalIn: NSRect(x: point.x - 67, y: point.y - 67, width: 134, height: 134))
        NSColor.white.setFill()
        ring.fill()
    }
    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    return png
}

for size in [16, 32, 128, 256, 512] {
    try render(pixels: size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(pixels: size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
