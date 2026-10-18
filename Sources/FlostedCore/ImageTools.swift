import Foundation
import CoreGraphics

public struct RGB: Sendable, Equatable {
    public var red: Double, green: Double, blue: Double
    public init(_ red: Double, _ green: Double, _ blue: Double) { self.red = red; self.green = green; self.blue = blue }
    public var cgColor: CGColor { CGColor(red: red, green: green, blue: blue, alpha: 1) }
}
public struct BackgroundStyle: Sendable {
    public var first = RGB(1, 0.45, 0.16)
    public var second = RGB(0.97, 0.19, 0.29)
    public var third: RGB?
    public var gradient = true
    public var aspect: Double = 0
    public var padding: Double = 80
    public var cornerRadius: Double = 28
    public var shadow: Double = 24
    public init() {}
}
public enum ImageTools {
    /// Selection is normalized in bottom-left view coordinates.
    public static func crop(_ image: CGImage, selection: CGRect) throws -> CGImage {
        let normalized = selection.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !normalized.isNull, normalized.width > 0, normalized.height > 0 else { throw ConversionError.encoding }
        let pixels = CGRect(x: normalized.minX * Double(image.width), y: (1 - normalized.maxY) * Double(image.height),
            width: normalized.width * Double(image.width), height: normalized.height * Double(image.height)).integral
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let result = image.cropping(to: pixels) else { throw ConversionError.encoding }; return result
    }
    public static func resize(_ image: CGImage, scale: Double) throws -> CGImage {
        let factor = min(1, max(0.01, scale))
        let width = max(1, Int(Double(image.width) * factor)), height = max(1, Int(Double(image.height) * factor))
        let context = try canvas(width, height); context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let result = context.makeImage() else { throw ConversionError.encoding }; return result
    }
    public static func background(_ image: CGImage, style: BackgroundStyle, backdrop: CGImage? = nil, previewLimit: Double? = nil) throws -> CGImage {
        var width = Double(image.width) + style.padding * 2, height = Double(image.height) + style.padding * 2
        if style.aspect > 0 {
            if width / height < style.aspect { width = height * style.aspect } else { height = width / style.aspect }
        }
        let factor = previewLimit.map { min(1, $0 / max(width, height)) } ?? 1
        width = ceil(width * factor); height = ceil(height * factor)
        let context = try canvas(Int(width), Int(height))
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        if style.gradient, let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [style.first.cgColor, style.second.cgColor] as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        } else { context.setFillColor(style.first.cgColor); context.fill(rect) }
        if let third=style.third,style.gradient,backdrop == nil {
            let clear=CGColor(red:third.red,green:third.green,blue:third.blue,alpha:0)
            if let glow=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[third.cgColor,clear] as CFArray,locations:[0,1]) {
                context.drawRadialGradient(glow,startCenter:CGPoint(x:width,y:0),startRadius:0,endCenter:CGPoint(x:width,y:0),endRadius:max(width,height)*0.85,options:[])
            }
        }
        if let backdrop {
            let fit=max(width/Double(backdrop.width),height/Double(backdrop.height))
            let size=CGSize(width:Double(backdrop.width)*fit,height:Double(backdrop.height)*fit)
            context.saveGState();context.clip(to:rect)
            context.draw(backdrop,in:CGRect(x:(width-size.width)/2,y:(height-size.height)/2,width:size.width,height:size.height));context.restoreGState()
        }
        let imageRect = CGRect(x: (width - Double(image.width) * factor) / 2, y: (height - Double(image.height) * factor) / 2,
            width: Double(image.width) * factor, height: Double(image.height) * factor)
        let radius = min(style.cornerRadius * factor, min(imageRect.width, imageRect.height) / 2)
        let path = CGPath(roundedRect: imageRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -style.shadow * factor / 3), blur: style.shadow * factor, color: CGColor(gray: 0, alpha: 0.4))
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.addPath(path); context.fillPath()
        context.restoreGState(); context.addPath(path); context.clip()
        context.interpolationQuality = .high; context.draw(image, in: imageRect)
        guard let result = context.makeImage() else { throw ConversionError.encoding }; return result
    }
    /// Transparent RGBA drawing surface, bottom-left origin. Public because the
    /// annotation renderer and the signature pad both draw into one.
    public static func canvas(_ width: Int, _ height: Int) throws -> CGContext {
        guard width > 0, height > 0, Double(width) * Double(height) <= 100_000_000 else { throw ConversionError.tooLarge }
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ConversionError.encoding }
        return context
    }
}
