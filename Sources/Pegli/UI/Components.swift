import SwiftUI
import AppKit

// MARK: - Farben

/// Farben je Erscheinungsbild (Apple-Systemfarben, hell/dunkel getrennt) plus Kartenflächen.
/// Flächen sind halbtransparent, damit sie über dem Popover-Material wie über festem Grund funktionieren.
struct Palette {
    let scheme: ColorScheme
    var isDark: Bool { scheme == .dark }

    private func pick(_ light: (Double, Double, Double), _ dark: (Double, Double, Double)) -> Color {
        let c = isDark ? dark : light
        return Color(red: c.0 / 255, green: c.1 / 255, blue: c.2 / 255)
    }

    var green: Color { pick((52, 199, 89), (48, 209, 88)) }
    var mint: Color { pick((0, 190, 160), (99, 230, 190)) }
    var blue: Color { pick((0, 122, 255), (10, 132, 255)) }
    var teal: Color { pick((48, 176, 199), (64, 200, 224)) }
    var cyan: Color { pick((40, 160, 220), (100, 210, 255)) }
    var indigo: Color { pick((88, 86, 214), (125, 122, 255)) }
    var purple: Color { pick((175, 82, 222), (191, 90, 242)) }
    var pink: Color { pick((255, 45, 85), (255, 55, 95)) }
    var orange: Color { pick((255, 149, 0), (255, 159, 10)) }
    var yellow: Color { pick((255, 204, 0), (255, 214, 10)) }
    var red: Color { pick((255, 59, 48), (255, 69, 58)) }
    /// Gelb ist auf hellem Grund als Schrift zu blass → dunkleres Gelb für Text.
    var yellowText: Color { pick((196, 140, 0), (255, 214, 10)) }

    /// Kartenfläche: hell = leicht weiß angehoben, dunkel = leicht aufgehellt.
    var card: Color { isDark ? Color.white.opacity(0.075) : Color.white.opacity(0.62) }
    var cardStroke: Color { isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.06) }
    /// Spur hinter Balken, Ringen, Kernen.
    var track: Color { isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.07) }
    /// Runde Icon-Buttons.
    var button: Color { isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.055) }
    /// Feine Linien in Graphen und zwischen Zeilen.
    var hairline: Color { isDark ? Color.white.opacity(0.11) : Color.black.opacity(0.08) }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette(scheme: .light)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// Setzt die Palette passend zum Farbschema (einmal an der Wurzel).
struct PaletteProvider: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.environment(\.palette, Palette(scheme: scheme))
    }
}

// MARK: - Schrift

enum Fonts {
    static let title = Font.system(size: 12, weight: .semibold)
    static let body = Font.system(size: 11)
    static let bodyBold = Font.system(size: 11, weight: .semibold)
    static let small = Font.system(size: 10)
    static let smallBold = Font.system(size: 10, weight: .semibold)
    /// Kleine Zwischenüberschrift in Details („Apps", „Kerne").
    static let caption = Font.system(size: 9, weight: .semibold)
    /// Große Zahl (abgerundet, feste Ziffernbreite).
    static let value = Font.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit()
    static let valueMedium = Font.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit()
    static let unit = Font.system(size: 10, weight: .semibold, design: .rounded)
}

/// Text aus Teilen: fett = Zahl (primär), sonst sekundär. „11,48 von 16 GB …"
func richText(_ parts: [(String, Bool)]) -> Text {
    parts.reduce(Text(verbatim: "")) { acc, part in
        let t = part.1
            ? Text(verbatim: part.0).fontWeight(.semibold).foregroundStyle(.primary)
            : Text(verbatim: part.0).foregroundStyle(.secondary)
        return Text("\(acc)\(t)")
    }
}

// MARK: - Karten und Kopf

/// Abgerundete Karte mit dezenter Fläche und Haarlinie.
struct Card<Content: View>: View {
    var padding: CGFloat = 10
    @ViewBuilder var content: () -> Content
    @Environment(\.palette) private var palette

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.card)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(palette.cardStroke, lineWidth: 0.5))
            )
    }
}

/// Große Zahl mit kleiner Einheit: „33 %".
struct BigValue: View {
    let value: String
    var unit: String? = nil
    var font: Font = Fonts.value
    var color: Color? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(verbatim: value)
                .font(font)
                .foregroundStyle(color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary))
                .contentTransition(.numericText())
            if let unit {
                Text(verbatim: unit).font(Fonts.unit).foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .fixedSize()
    }
}

/// Ring-Anzeige 0...1 mit Symbol in der Mitte (Kopf jeder Karte).
struct RingBadge: View {
    let icon: String
    let tint: Color
    /// nil → nur getönter Kreis ohne Ring (z. B. Netzwerk).
    var value: Double?
    var size: CGFloat = 28
    @Environment(\.palette) private var palette

    var body: some View {
        let line: CGFloat = 3
        ZStack {
            if let value {
                let v = value.isFinite ? min(1, max(0, value)) : 0
                Circle().stroke(tint.opacity(0.18), lineWidth: line)
                Circle()
                    .trim(from: 0, to: v)
                    .stroke(AngularGradient(colors: [tint.opacity(0.75), tint], center: .center,
                                            startAngle: .degrees(0), endAngle: .degrees(360 * max(0.01, v))),
                            style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: v)
            } else {
                Circle().fill(tint.opacity(0.16))
            }
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint)
        }
        .padding(value == nil ? 0 : line / 2)
        .frame(width: size, height: size)
    }
}

/// Runder Icon-Button (Kopfzeile, Aufklapp-Pfeil).
struct CircleIcon: View {
    let systemName: String
    var size: CGFloat = 24
    var active = false
    var activeColor: Color = .accentColor
    @Environment(\.palette) private var palette

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(active ? AnyShapeStyle(Color.white) : AnyShapeStyle(.secondary))
            .frame(width: size, height: size)
            .background(Circle().fill(active ? AnyShapeStyle(activeColor) : AnyShapeStyle(palette.button)))
            .contentShape(Circle())
    }
}

/// Runder Pfeil-Button: zeigt nach rechts, aufgeklappt nach unten.
struct ExpandButton: View {
    let expanded: Bool
    var size: CGFloat = 18
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIcon(systemName: "chevron.right", size: size)
                .rotationEffect(.degrees(expanded ? 90 : 0))
        }
        .buttonStyle(.plain)
        .help(expanded ? "Details ausblenden" : "Details anzeigen")
    }
}

/// „Weitere Informationen ↗"
struct MoreInfoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(verbatim: "Weitere Informationen")
                Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .bold))
            }
            .font(Fonts.smallBold)
            .foregroundStyle(Color.accentColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Kleine Zwischenüberschrift, optional mit Zusatz rechts.
struct Caption<Trailing: View>: View {
    let text: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: text.uppercased())
                .font(Fonts.caption)
                .kerning(0.4)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            trailing()
        }
    }
}

extension Caption where Trailing == EmptyView {
    init(_ text: String) { self.init(text: text) { EmptyView() } }
}

/// „Apps" links, „Weitere Informationen ↗" rechts.
struct AppsHeader: View {
    let onMore: () -> Void
    var body: some View {
        Caption(text: "Apps") { MoreInfoButton(action: onMore) }
    }
}

/// „Weitere Informationen ↗" rechtsbündig.
struct MoreInfoRow: View {
    let action: () -> Void
    var body: some View {
        HStack {
            Spacer()
            MoreInfoButton(action: action)
        }
    }
}

/// Zeile „Bezeichnung … Wert" in den Details, optional mit Farbpunkt.
struct DetailRow: View {
    let label: String
    let value: String
    var dot: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let dot { Circle().fill(dot).frame(width: 6, height: 6) }
            Text(verbatim: label).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 8)
            Text(verbatim: value).fontWeight(.medium).monospacedDigit().lineLimit(1)
        }
        .font(Fonts.body)
    }
}

// MARK: - Apps

/// Icon-Cache für .app-Bundles. Icons werden als 8-Bit-sRGB-Bitmap (32 pt @2x) abgelegt:
/// klein im Speicher und kein HDR-Rendering (sonst erzeugt ImageRenderer blasse 16-Bit-PQ-Bilder).
@MainActor
enum AppIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(for path: String) -> NSImage {
        if let cached = cache[path] { return cached }
        let image = rasterize(NSWorkspace.shared.icon(forFile: path), points: 32, scale: 2)
        if cache.count > 200 { cache.removeAll() }
        cache[path] = image
        return image
    }

    private static func rasterize(_ source: NSImage, points: CGFloat, scale: CGFloat) -> NSImage {
        let px = Int(points * scale)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return source }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        NSGraphicsContext.restoreGraphicsState()
        guard let cg = ctx.makeImage() else { return source }
        return NSImage(cgImage: cg, size: NSSize(width: points, height: points))
    }
}

struct AppRow: View {
    let app: AppUsage
    let value: String
    /// Anteil 0...1 für den feinen Balken unter dem Namen.
    var share: Double = 0
    var tint: Color = .accentColor
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let path = app.bundlePath {
                    Image(nsImage: AppIcons.icon(for: path)).resizable().interpolation(.high)
                } else {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 15, height: 15)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(palette.button))
                }
            }
            .frame(width: 15, height: 15)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: app.name).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 8)
                    Text(verbatim: value).fontWeight(.medium).monospacedDigit().foregroundStyle(.secondary)
                }
                UsageBar(value: share, height: 2, tint: tint)
            }
        }
        .font(Fonts.body)
    }
}

/// Liste der Top-Apps; leer → Hinweis. `share` liefert den Balkenanteil je App.
struct AppList: View {
    let apps: [AppUsage]
    var tint: Color = .accentColor
    let share: (AppUsage) -> Double
    let value: (AppUsage) -> String

    var body: some View {
        if apps.isEmpty {
            Text(verbatim: "Wird ermittelt …").font(Fonts.body).foregroundStyle(.secondary)
        } else {
            VStack(spacing: 5) {
                ForEach(apps) { AppRow(app: $0, value: value($0), share: share($0), tint: tint) }
            }
        }
    }
}

// MARK: - Balken

/// Kapselbalken 0...1 mit Verlauf.
struct UsageBar: View {
    let value: Double
    var height: CGFloat = 5
    var tint: Color = .accentColor
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            let v = value.isFinite ? min(1, max(0, value)) : 0
            let w = v > 0 ? max(height, geo.size.width * v) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(palette.track)
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: w)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.35), value: value)
    }
}

/// Gestapelter Kapselbalken: Segmente (Anteil 0...1, Farbe) nebeneinander, Rest = Spur.
struct StackedBar: View {
    let segments: [(Double, Color)]
    var height: CGFloat = 6
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1.5) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    let f = seg.0.isFinite ? min(1, max(0, seg.0)) : 0
                    if f > 0.004 {
                        Rectangle().fill(seg.1).frame(width: max(2, geo.size.width * f))
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: geo.size.width, height: height, alignment: .leading)
            .background(palette.track)
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}

/// Schmale vertikale Kapseln je Kern.
struct CoreBars: View {
    let values: [Double]
    var height: CGFloat = 28
    var tint: Color = .accentColor
    var tint2: Color = .accentColor
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                GeometryReader { geo in
                    let f = v.isFinite ? min(1, max(0, v)) : 0
                    let r = min(5, geo.size.width / 2)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: r, style: .continuous).fill(palette.track)
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .fill(LinearGradient(colors: [tint2, tint], startPoint: .bottom, endPoint: .top))
                            .frame(height: f > 0 ? max(4, geo.size.height * f) : 0)
                    }
                }
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.35), value: values)
    }
}

/// Segmentanzeige (Temperatur): `filled` von `count` Kapseln in `color`.
struct SegmentBar: View {
    let filled: Int
    var count: Int = 4
    let color: Color
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule().fill(i < filled ? AnyShapeStyle(color.gradient) : AnyShapeStyle(palette.track))
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Graphen

/// Weicher Flächengraph (neuester Wert rechts): Linie + Verlaufsfläche, feine Hilfslinien.
struct AreaGraph: View {
    let values: [Double]
    var capacity: Int = Monitor.historyLength
    /// nil = Werte sind 0...1; sonst Maximum für die Skala.
    var maxValue: Double? = nil
    var color: Color = .accentColor
    var secondary: [Double]? = nil
    var secondaryColor: Color = .accentColor
    @Environment(\.palette) private var palette

    var body: some View {
        Canvas { ctx, size in
            let top = maxValue ?? 1
            let inset: CGFloat = 1.5
            let h = size.height - inset * 2

            // Hilfslinien bei 50 % und 100 %.
            for f in [0.0, 0.5] {
                let y = inset + CGFloat(f) * h
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(line, with: .color(palette.hairline), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
            }

            func points(_ vals: [Double]) -> [CGPoint] {
                let vals = Array(vals.suffix(capacity))
                guard !vals.isEmpty else { return [] }
                let step = size.width / CGFloat(max(1, capacity - 1))
                let start = size.width - CGFloat(vals.count - 1) * step
                return vals.enumerated().map { i, v in
                    let f = top > 0 ? min(1, max(0, v.isFinite ? v / top : 0)) : 0
                    return CGPoint(x: start + CGFloat(i) * step, y: inset + h - CGFloat(f) * h)
                }
            }

            func draw(_ vals: [Double], _ c: Color, fillOpacity: Double) {
                let pts = points(vals)
                guard let first = pts.first, let last = pts.last else { return }
                let line = Self.smooth(pts)
                var area = line
                area.addLine(to: CGPoint(x: last.x, y: size.height))
                area.addLine(to: CGPoint(x: first.x, y: size.height))
                area.closeSubpath()
                ctx.fill(area, with: .linearGradient(
                    Gradient(colors: [c.opacity(fillOpacity), c.opacity(0.02)]),
                    startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
                ctx.stroke(line, with: .color(c), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }

            draw(values, color, fillOpacity: 0.38)
            if let secondary { draw(secondary, secondaryColor, fillOpacity: 0.22) }
        }
    }

    /// Weiche Kurve durch alle Punkte (Catmull-Rom, auf die Fläche begrenzt).
    static func smooth(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard pts.count > 1 else {
            if let only = pts.first { p.move(to: only); p.addLine(to: only) }
            return p
        }
        p.move(to: pts[0])
        let minY = pts.map(\.y).min() ?? 0, maxY = pts.map(\.y).max() ?? 0
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(pts.count - 1, i + 2)]
            let t: CGFloat = 1 / 6
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) * t, y: min(maxY, max(minY, p1.y + (p2.y - p0.y) * t)))
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) * t, y: min(maxY, max(minY, p2.y - (p3.y - p1.y) * t)))
            p.addCurve(to: p2, control1: c1, control2: c2)
        }
        return p
    }
}

/// Balken-Verlauf (Speicherdruck): eine feine Kapsel je Messung.
struct BarGraph: View {
    let values: [Double]
    var capacity: Int = Monitor.historyLength
    var color: Color = .accentColor
    @Environment(\.palette) private var palette

    var body: some View {
        Canvas { ctx, size in
            let slot = size.width / CGFloat(max(1, capacity))
            let bw = max(1, slot * 0.62)
            let vals = values.suffix(capacity)
            // Ruhige Grundfläche statt Einzelspuren.
            ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6), with: .color(palette.track.opacity(0.6)))
            let start = size.width - CGFloat(vals.count) * slot
            for (i, v) in vals.enumerated() {
                // Mindesthöhe, damit „Normal" sichtbar bleibt.
                let f = max(0.15, min(1, max(0, v.isFinite ? v : 0)))
                let bh = CGFloat(f) * (size.height - 4)
                let rect = CGRect(x: start + CGFloat(i) * slot, y: size.height - 2 - bh, width: bw, height: bh)
                ctx.fill(Path(roundedRect: rect, cornerRadius: bw / 2), with: .color(color))
            }
        }
    }
}
