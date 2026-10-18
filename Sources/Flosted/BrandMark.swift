import AppKit

/// Static artwork only: unlike EmbeddedWheel, this has no tracking or drop targets.
/// The app and the build-time icon generator use this same vector drawing.
enum BrandMark {
    enum Style { case appIcon, mark, template }

    static let accent = NSColor(srgbRed: 0.87, green: 0.23, blue: 0.015, alpha: 1)

    static func image(side: CGFloat, style: Style) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            draw(in: rect, context: context, style: style)
            return true
        }
        image.isTemplate = style == .template
        image.accessibilityDescription = "Flosted"
        return image
    }

    static func draw(in rect: CGRect, context: CGContext, style: Style) {
        context.saveGState()
        defer { context.restoreGState() }
        let side = min(rect.width, rect.height)
        // Quartz shadows ignore the drawing transform; scale them explicitly.
        let shadowScale = side / 1024
        context.translateBy(x: rect.midX - side / 2, y: rect.midY - side / 2)
        context.scaleBy(x: side / 1024, y: side / 1024)
        context.setAllowsAntialiasing(true)

        if style == .appIcon {
            let tile = CGPath(roundedRect: CGRect(x: 64, y: 64, width: 896, height: 896),
                              cornerWidth: 200, cornerHeight: 200, transform: nil)
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -12 * shadowScale), blur: 22 * shadowScale,
                              color: color(0.15, 0.17, 0.20, 0.20))
            context.addPath(tile)
            context.setFillColor(color(0.94, 0.94, 0.94))
            context.fillPath()
            context.restoreGState()
            gradient(in: tile, context: context,
                     top: color(0.995, 0.985, 0.965), bottom: color(0.85, 0.87, 0.90))
            context.addPath(tile)
            context.setStrokeColor(color(1, 1, 1, 0.85))
            context.setLineWidth(3)
            context.strokePath()
        }

        let outer: CGFloat = style == .appIcon ? 342 : 468
        let inner: CGFloat = style == .appIcon ? 166 : 224
        let gap: CGFloat = style == .template ? 8 : 5
        for index in 0..<4 {
            // The first quarter is the upper-right accent, in AppKit coordinates.
            let low = (CGFloat(index) * 90 + gap) * .pi / 180
            let high = (CGFloat(index + 1) * 90 - gap) * .pi / 180
            let path = sector(outer: outer, inner: inner, low: low, high: high,
                              corner: style == .appIcon ? 28 : 36)
            if style == .template {
                context.addPath(path)
                context.setFillColor(color(0, 0, 0))
                context.fillPath()
                continue
            }

            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -8 * shadowScale), blur: 14 * shadowScale,
                              color: color(0.22, 0.18, 0.14, 0.23))
            context.addPath(path)
            context.setFillColor(index == 0 ? accent.cgColor : color(0.83, 0.82, 0.80))
            context.fillPath()
            context.restoreGState()

            gradient(in: path, context: context,
                     top: index == 0 ? color(1, 0.48, 0.20) : color(1, 0.995, 0.98),
                     bottom: index == 0 ? accent.cgColor : color(0.71, 0.73, 0.75),
                     outer: outer)
            context.addPath(path)
            context.setStrokeColor(index == 0 ? color(1, 0.82, 0.65, 0.65) : color(1, 1, 1, 0.90))
            context.setLineWidth(style == .appIcon ? 2.5 : 3.5)
            context.strokePath()
        }
    }

    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat,
                              _ alpha: CGFloat = 1) -> CGColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha).cgColor
    }

    private static func gradient(in path: CGPath, context: CGContext,
                                 top: CGColor, bottom: CGColor, outer: CGFloat = 448) {
        context.saveGState()
        defer { context.restoreGState() }
        context.addPath(path)
        context.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [top, bottom] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 380, y: 512 + outer),
                                   end: CGPoint(x: 640, y: 512 - outer),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private static func sector(outer: CGFloat, inner: CGFloat, low: CGFloat,
                               high: CGFloat, corner: CGFloat) -> CGPath {
        func point(_ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
            CGPoint(x: 512 + radius * cos(angle), y: 512 + radius * sin(angle))
        }
        let oa = corner / outer, ia = corner / inner
        let path = CGMutablePath()
        path.move(to: point(outer, high - oa))
        path.addArc(center: CGPoint(x: 512, y: 512), radius: outer,
                    startAngle: high - oa, endAngle: low + oa, clockwise: true)
        path.addQuadCurve(to: point(outer - corner, low), control: point(outer, low))
        path.addLine(to: point(inner + corner, low))
        path.addQuadCurve(to: point(inner, low + ia), control: point(inner, low))
        path.addArc(center: CGPoint(x: 512, y: 512), radius: inner,
                    startAngle: low + ia, endAngle: high - ia, clockwise: false)
        path.addQuadCurve(to: point(inner + corner, high), control: point(inner, high))
        path.addLine(to: point(outer - corner, high))
        path.addQuadCurve(to: point(outer, high - oa), control: point(outer, high))
        path.closeSubpath()
        return path
    }
}
