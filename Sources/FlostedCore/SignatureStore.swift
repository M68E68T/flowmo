import Foundation
import CoreGraphics

/// Keeps drawn or imported signatures so they can be reused across documents.
/// The folder is a parameter so tests stay out of the real Application Support.
public struct SignatureStore {
    public let folder: URL

    public init(folder: URL? = nil) {
        if let folder { self.folder = folder } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.folder = base.appendingPathComponent("Flosted/Signatures", isDirectory: true)
        }
    }

    @discardableResult
    public func save(_ image: CGImage, id: String = UUID().uuidString) throws -> String {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try ImageConverter.encode(image, as: .png)
        try data.write(to: folder.appendingPathComponent(id + ".png"))
        return id
    }

    /// Unreadable files are skipped rather than failing the whole load: one
    /// damaged signature must not keep the editor from opening.
    public func load() -> [String: CGImage] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var result: [String: CGImage] = [:]
        for file in files where file.pathExtension.lowercased() == "png" {
            if let image = try? ImageConverter.decode(file) {
                result[file.deletingPathExtension().lastPathComponent] = image
            }
        }
        return result
    }

    public func remove(id: String) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(id + ".png"))
    }

    /// Turns the paper white of a photographed signature transparent. Pixels
    /// brighter than `threshold` become clear, darker ones keep their colour,
    /// and the band just below it fades out so edges do not look cut out.
    public static func removingWhiteBackground(_ image: CGImage, threshold: Double = 0.72) throws -> CGImage {
        let width = image.width, height = image.height
        let context = try ImageTools.canvas(width, height)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.data else { throw ConversionError.encoding }
        let limit = min(max(threshold, 0.05), 0.99)
        let fade = max(0.04, limit * 0.18)
        let bytes = pixels.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
        for row in 0..<height {
            for column in 0..<width {
                let offset = row * context.bytesPerRow + column * 4
                let r = Double(bytes[offset]) / 255, g = Double(bytes[offset + 1]) / 255, b = Double(bytes[offset + 2]) / 255
                let brightness = 0.299 * r + 0.587 * g + 0.114 * b
                guard brightness > limit - fade else { continue }
                let alpha = brightness >= limit ? 0 : (limit - brightness) / fade
                // The context is premultiplied, so the colour channels scale too.
                bytes[offset] = UInt8(r * alpha * 255)
                bytes[offset + 1] = UInt8(g * alpha * 255)
                bytes[offset + 2] = UInt8(b * alpha * 255)
                bytes[offset + 3] = UInt8(alpha * 255)
            }
        }
        guard let result = context.makeImage() else { throw ConversionError.encoding }
        return result
    }
}
