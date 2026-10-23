import AppKit

/// Menüleisten-Icon: „CPU / MEM / HD" mit je einem Mini-Balken. Template-Bild (hell/dunkel automatisch).
enum StatusIconRenderer {
    static let size = NSSize(width: 38, height: 20)

    static func image(cpu: Double, memory: Double, disk: Double) -> NSImage {
        let values = [cpu, memory, disk].map { $0.isFinite ? min(1, max(0, $0)) : 0 }
        let image = NSImage(size: size, flipped: true) { rect in
            draw(values: values, in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = tr("CPU \(Format.percent(values[0])), Speicher \(Format.percent(values[1])), Laufwerk \(Format.percent(values[2]))",
                                            "CPU \(Format.percent(values[0])), memory \(Format.percent(values[1])), disk \(Format.percent(values[2]))")
        return image
    }

    private static func draw(values: [Double], in rect: NSRect) {
        let labels = ["CPU", "MEM", "HD"]
        let font = NSFont.systemFont(ofSize: 5.8, weight: .heavy)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let labelWidth: CGFloat = 16
        let barX = labelWidth + 2
        let barWidth = rect.width - barX - 0.5
        let barHeight: CGFloat = 3.4
        let rowHeight = rect.height / 3

        for i in 0..<3 {
            let midY = rowHeight * (CGFloat(i) + 0.5)
            // Großbuchstaben optisch mittig: Grundlinie = Mitte + halbe Versalhöhe.
            let baseline = midY + font.capHeight / 2
            let label = labels[i] as NSString
            let textWidth = label.size(withAttributes: attrs).width
            label.draw(at: NSPoint(x: max(0, (labelWidth - textWidth) / 2), y: baseline - font.ascender),
                       withAttributes: attrs)

            let track = NSRect(x: barX, y: midY - barHeight / 2, width: barWidth, height: barHeight)
            NSColor.black.withAlphaComponent(0.3).setFill()
            NSBezierPath(roundedRect: track, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()

            let v = CGFloat(values[i])
            if v > 0 {
                var fill = track
                fill.size.width = max(barHeight, barWidth * v)
                NSColor.black.setFill()
                NSBezierPath(roundedRect: fill, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()
            }
        }
    }
}
