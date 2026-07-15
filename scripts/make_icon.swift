// Generiše assets/AppIcon.icns bez Xcode-a: AppKit crtanje + sips + iconutil.
// Pokretanje: swift scripts/make_icon.swift
import AppKit
import Foundation

let canvas: CGFloat = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
rep.size = NSSize(width: canvas, height: canvas)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS squircle: artwork sa ~10% margine, radius ~22.5% ivice
let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
let radius = rect.width * 0.225
let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

let gradient = NSGradient(
    starting: NSColor(calibratedRed: 0.95, green: 0.26, blue: 0.32, alpha: 1),
    ending: NSColor(calibratedRed: 0.55, green: 0.06, blue: 0.16, alpha: 1)
)!
gradient.draw(in: squircle, angle: -90)

// beli "timer" SF Symbol u sredini
guard let symbol = NSImage(systemSymbolName: "timer", accessibilityDescription: nil),
      let configured = symbol.withSymbolConfiguration(.init(pointSize: 600, weight: .medium)) else {
    fatalError("SF Symbol 'timer' unavailable")
}
let tinted = NSImage(size: configured.size)
tinted.lockFocus()
configured.draw(in: NSRect(origin: .zero, size: configured.size))
NSColor.white.set()
NSRect(origin: .zero, size: configured.size).fill(using: .sourceAtop)
tinted.unlockFocus()

let glyphWidth = rect.width * 0.58
let aspect = configured.size.height / configured.size.width
let glyphRect = NSRect(
    x: (canvas - glyphWidth) / 2,
    y: (canvas - glyphWidth * aspect) / 2,
    width: glyphWidth,
    height: glyphWidth * aspect
)
tinted.draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: 1)

NSGraphicsContext.restoreGraphicsState()

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let root = scriptDir.deletingLastPathComponent()
let assets = root.appendingPathComponent("assets")
let iconset = assets.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let master = assets.appendingPathComponent("AppIcon-1024.png")
try rep.representation(using: .png, properties: [:])!.write(to: master)

func run(_ args: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = args
    try! process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        fatalError("failed: \(args.joined(separator: " "))")
    }
}

for size in [16, 32, 128, 256, 512] {
    run(["sips", "-z", "\(size)", "\(size)", master.path,
         "--out", iconset.appendingPathComponent("icon_\(size)x\(size).png").path])
    run(["sips", "-z", "\(size * 2)", "\(size * 2)", master.path,
         "--out", iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png").path])
}

run(["iconutil", "-c", "icns", iconset.path,
     "-o", assets.appendingPathComponent("AppIcon.icns").path])
try? FileManager.default.removeItem(at: iconset)
try? FileManager.default.removeItem(at: master)
print("OK: assets/AppIcon.icns")
