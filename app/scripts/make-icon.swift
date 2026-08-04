// Draws the app icon — the little man engraved full-size in stone, lit from
// behind — and writes every size an .iconset wants.
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

// Seeded, so the marble comes out identical on every run.
var rngState: UInt64 = 42
func rnd() -> Double {
    rngState = rngState &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Double(rngState >> 11) / Double(UInt64.max >> 11)
}

/// The drafts were drawn on a 100-point grid, top-left origin. This maps a
/// draft point into CoreGraphics' bottom-left master canvas.
func P(_ x: Double, _ y: Double) -> CGPoint {
    CGPoint(x: x * master / 100, y: master - y * master / 100)
}
func L(_ v: Double) -> CGFloat { v * master / 100 }

let ink = CGColor(red: 0.090, green: 0.098, blue: 0.110, alpha: 1)

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
    ctx.setFillColor(CGColor(gray: 0.85, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    // Stone: a vertical gradient…
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    // Lit from the top-left, falling away to a deep stone-green: the
    // gradient is the depth, so it has to be visible at Dock size.
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 0.992, green: 0.984, blue: 0.956, alpha: 1),
            CGColor(red: 0.851, green: 0.839, blue: 0.776, alpha: 1),
            CGColor(red: 0.478, green: 0.514, blue: 0.416, alpha: 1)
        ] as CFArray,
        locations: [0, 0.45, 1]
    )!
    ctx.drawLinearGradient(gradient, start: P(24, 0), end: P(76, 100), options: [])

    // A soft spotlight behind the man, so the stone has depth and the
    // figure sits in a pool of light.
    let spotlight = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(gray: 1, alpha: 0.55),
            CGColor(gray: 1, alpha: 0)
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        spotlight,
        startCenter: P(50, 38), startRadius: 0,
        endCenter: P(50, 38), endRadius: L(44),
        options: []
    )

    // And a vignette pressing the corners down, so the light pools centre.
    let vignette = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(gray: 0, alpha: 0),
            CGColor(gray: 0.08, alpha: 0.22)
        ] as CFArray,
        locations: [0.62, 1]
    )!
    ctx.drawRadialGradient(
        vignette,
        startCenter: P(50, 46), startRadius: 0,
        endCenter: P(50, 46), endRadius: L(64),
        options: [.drawsAfterEndLocation]
    )

    // …speckled with fine mineral noise…
    for _ in 0..<24_000 {
        let g = 0.30 + rnd() * 0.32
        ctx.setFillColor(CGColor(gray: g, alpha: 0.028 + rnd() * 0.05))
        let d = L(0.08 + rnd() * 0.22)
        ctx.fillEllipse(in: CGRect(x: L(rnd() * 100), y: L(rnd() * 100), width: d, height: d))
    }

    // …and a few veins.
    func vein(_ a: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ b: CGPoint, width: Double, alpha: Double) {
        ctx.setStrokeColor(CGColor(gray: 0.58, alpha: alpha))
        ctx.setLineWidth(L(width))
        ctx.setLineCap(.round)
        ctx.move(to: a)
        ctx.addCurve(to: b, control1: c1, control2: c2)
        ctx.strokePath()
    }
    vein(P(16, 18), P(44, 30), P(34, 48), P(28, 76), width: 1.1, alpha: 0.28)
    vein(P(64, 8), P(72, 28), P(84, 34), P(92, 44), width: 0.9, alpha: 0.24)
    vein(P(70, 60), P(62, 74), P(74, 84), P(80, 94), width: 0.8, alpha: 0.20)

    // The engraved man, full size, with a settled shadow.
    ctx.setShadow(offset: CGSize(width: 0, height: -L(0.7)), blur: L(1.4),
                  color: CGColor(gray: 0, alpha: 0.32))
    ctx.setStrokeColor(ink)
    ctx.setFillColor(ink)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // The drafts' glyph, at a scale that fills the squircle comfortably.
    func M(_ x: Double, _ y: Double) -> CGPoint {
        P(50 + (x - 50) * 0.92, 51.5 + (y - 54) * 0.92)
    }
    let headRadius = L(9.5 * 0.92)
    let head = M(50, 26)
    ctx.fillEllipse(in: CGRect(
        x: head.x - headRadius, y: head.y - headRadius,
        width: headRadius * 2, height: headRadius * 2
    ))
    ctx.setLineWidth(L(9.5 * 0.92))
    for limb in [
        [M(50, 41), M(50, 62)],
        [M(50, 47.5), M(35, 58)],
        [M(50, 47.5), M(65, 58)],
        [M(50, 62), M(38.5, 82)],
        [M(50, 62), M(61.5, 82)]
    ] {
        ctx.move(to: limb[0])
        ctx.addLine(to: limb[1])
        ctx.strokePath()
    }

    // Edge light: a bright top lip, a dark bottom one.
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    let lip = CGPath(
        roundedRect: CGRect(x: L(10.4), y: L(10.4), width: L(79.2), height: L(79.2)),
        cornerWidth: L(17.5), cornerHeight: L(17.5), transform: nil
    )
    ctx.setLineWidth(L(1.1))
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: master * 0.62, width: master, height: master * 0.38))
    ctx.addPath(lip)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.45))
    ctx.strokePath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: 0, width: master, height: master * 0.30))
    ctx.addPath(lip)
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.16))
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
