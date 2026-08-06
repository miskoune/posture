// Draws the app icon — "one-square": a single mint frame, dead straight, on
// dark ink — and writes every size an .iconset wants.
//
//   swift scripts/make-icon.swift build/AppIcon.iconset
//   iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
//
// Everything is CoreGraphics so the icon is reproducible from this file
// alone; no design tool, no SVG renderer, no dependencies.

import AppKit
import CoreGraphics
import Foundation

let master = 1024.0

/// The drafts were drawn on a 100-point grid, top-left origin. This maps a
/// draft point into CoreGraphics' bottom-left master canvas.
func P(_ x: Double, _ y: Double) -> CGPoint {
    CGPoint(x: x * master / 100, y: master - y * master / 100)
}
func L(_ v: Double) -> CGFloat { v * master / 100 }

let mint = CGColor(red: 0.482, green: 0.847, blue: 0.647, alpha: 1)

func drawMaster(into ctx: CGContext) {
    let squircle = CGPath(
        roundedRect: CGRect(x: L(9.77), y: L(9.77), width: L(80.47), height: L(80.47)),
        cornerWidth: L(18), cornerHeight: L(18), transform: nil
    )

    // The soft shadow macOS icons carry in the asset itself.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -L(1.2)), blur: L(3.4),
                  color: CGColor(gray: 0, alpha: 0.30))
    ctx.addPath(squircle)
    ctx.setFillColor(CGColor(gray: 0.15, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    // Dark ink, lit faintly from the top so the ground reads as a surface
    // rather than a hole.
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    // Near-black with a breath of blue, the way Xcode's dark icon sits.
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 0.145, green: 0.157, blue: 0.176, alpha: 1),
            CGColor(red: 0.047, green: 0.051, blue: 0.063, alpha: 1)
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(gradient, start: P(50, 0), end: P(50, 100), options: [])

    // The blueprint grid the Apple developer icons carry — faint, cool,
    // and quieter towards the edges so the centre stays the stage.
    ctx.setStrokeColor(CGColor(red: 0.55, green: 0.66, blue: 0.76, alpha: 0.11))
    ctx.setLineWidth(L(0.35))
    for i in stride(from: 12.5, through: 87.5, by: 12.5) {
        ctx.move(to: P(i, 0)); ctx.addLine(to: P(i, 100))
        ctx.move(to: P(0, i)); ctx.addLine(to: P(100, i))
    }
    ctx.strokePath()
    let vignette = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(gray: 0, alpha: 0),
            CGColor(gray: 0, alpha: 0.22)
        ] as CFArray,
        locations: [0.55, 1]
    )!
    ctx.drawRadialGradient(
        vignette,
        startCenter: P(50, 50), startRadius: 0,
        endCenter: P(50, 50), endRadius: L(62),
        options: [.drawsAfterEndLocation]
    )

    // The mark: one rounded square, perfectly upright. The stroke is turned
    // into a shape so it can hold a gradient — lit mint at the top falling
    // to a deeper green, which is what makes it read as an object instead
    // of a line.
    // Sized against the squircle the way draft 101 was against its tile:
    // the frame takes ~54% of the plate, leaving the grid real margin.
    let frame = CGPath(
        roundedRect: CGRect(x: L(28), y: L(28), width: L(44), height: L(44)),
        cornerWidth: L(8.8), cornerHeight: L(8.8), transform: nil
    )
    let frameShape = frame.copy(
        strokingWithWidth: L(5.3), lineCap: .round, lineJoin: .round, miterLimit: 10
    )

    // The bloom stays tight (the artifact's feGaussianBlur was 2.6/100) —
    // any wider and the halo eats the frame at Dock size.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: L(2.6), color: mint.copy(alpha: 0.55))
    ctx.addPath(frameShape)
    ctx.setFillColor(mint)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(frameShape)
    ctx.clip()
    let mintDepth = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 0.663, green: 0.941, blue: 0.769, alpha: 1),
            CGColor(red: 0.482, green: 0.847, blue: 0.647, alpha: 1),
            CGColor(red: 0.286, green: 0.639, blue: 0.459, alpha: 1)
        ] as CFArray,
        locations: [0, 0.5, 1]
    )!
    ctx.drawLinearGradient(mintDepth, start: P(50, 25), end: P(50, 75), options: [])
    ctx.restoreGState()

    // A hairline of light along the frame's upper edge, the way the Dock's
    // glossier icons catch the room.
    ctx.saveGState()
    ctx.addPath(frameShape)
    ctx.clip()
    ctx.clip(to: CGRect(x: 0, y: master * 0.72, width: master, height: master * 0.28))
    ctx.setLineWidth(L(1.2))
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.35))
    ctx.addPath(
        CGPath(
            roundedRect: CGRect(x: L(28), y: L(28 + 2), width: L(44), height: L(44)),
            cornerWidth: L(8.8), cornerHeight: L(8.8), transform: nil
        )
    )
    ctx.strokePath()
    ctx.restoreGState()

    // Edge light: a bright top lip, a dark bottom one.
    let lip = CGPath(
        roundedRect: CGRect(x: L(10.4), y: L(10.4), width: L(79.2), height: L(79.2)),
        cornerWidth: L(17.5), cornerHeight: L(17.5), transform: nil
    )
    ctx.setLineWidth(L(1.1))
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: master * 0.62, width: master, height: master * 0.38))
    ctx.addPath(lip)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.30))
    ctx.strokePath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: 0, width: master, height: master * 0.30))
    ctx.addPath(lip)
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.30))
    ctx.strokePath()
    ctx.restoreGState()

    ctx.restoreGState()
}

// MARK: - Render and write

guard CommandLine.arguments.count == 2 else {
    print("usage: swift make-icon.swift <output.iconset>")
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let masterCtx = CGContext(
    data: nil, width: Int(master), height: Int(master),
    bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
drawMaster(into: masterCtx)
let masterImage = masterCtx.makeImage()!

func write(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "make-icon", code: 1)
    }
    try png.write(to: url)
}

func scaled(to size: Int) -> CGImage {
    let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.draw(masterImage, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()!
}

for points in [16, 32, 128, 256, 512] {
    try write(scaled(to: points), to: outDir.appendingPathComponent("icon_\(points)x\(points).png"))
    try write(scaled(to: points * 2), to: outDir.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
print("Wrote \(outDir.path)")
