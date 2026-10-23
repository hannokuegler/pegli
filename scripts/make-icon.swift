// Rendert das App-Icon (grüne Balken auf dunklem abgerundetem Quadrat) als .iconset.
// Aufruf: swift scripts/make-icon.swift <ziel.iconset>  → danach iconutil -c icns (siehe make-icon.sh)
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    // macOS-Raster: 824/1024 Fläche, Rand für den Schatten.
    let inset = s * 100 / 1024
    let tile = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = tile.width * 0.225
    let tilePath = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.02,
                  color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(CGColor(srgbRed: 0.11, green: 0.12, blue: 0.14, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Leichter Verlauf von oben.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let grad = CGGradient(colorsSpace: cs, colors: [
        CGColor(srgbRed: 0.20, green: 0.22, blue: 0.25, alpha: 1),
        CGColor(srgbRed: 0.09, green: 0.10, blue: 0.11, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    ctx.restoreGState()

    // Drei Pegli-Balken mit Hintergrundspur.
    let levels: [CGFloat] = [0.55, 0.85, 0.35]
    let area = tile.insetBy(dx: tile.width * 0.2, dy: tile.height * 0.2)
    let gap = area.width * 0.12
    let barW = (area.width - 2 * gap) / 3
    for (i, level) in levels.enumerated() {
        let x = area.minX + CGFloat(i) * (barW + gap)
        let track = CGRect(x: x, y: area.minY, width: barW, height: area.height)
        let r = barW * 0.28
        ctx.addPath(CGPath(roundedRect: track, cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.08))
        ctx.fillPath()

        let bar = CGRect(x: x, y: area.minY, width: barW, height: max(area.height * level, 2 * r))
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: bar, cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.clip()
        let g = CGGradient(colorsSpace: cs, colors: [
            CGColor(srgbRed: 0.45, green: 0.92, blue: 0.50, alpha: 1),
            CGColor(srgbRed: 0.16, green: 0.70, blue: 0.33, alpha: 1),
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: bar.maxY), end: CGPoint(x: 0, y: bar.minY), options: [])
        ctx.restoreGState()
    }

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try render(base * scale).write(to: out.appendingPathComponent(name))
    }
}
print("Iconset: \(out.path)")
