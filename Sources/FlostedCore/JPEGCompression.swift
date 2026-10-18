import Foundation
import CoreGraphics

/// The exact same bytes and quality calculation drive preview and saving.
public enum JPEGCompression {
    public struct Result {
        public let data: Data
        public let quality: Double
    }

    public static func encode(_ image: CGImage, quality: Double, targetBytes: Int = 0) throws -> Result {
        let quality = min(1, max(0.05, quality))
        let data = try ImageConverter.encode(image, as: .jpg, quality: quality)
        guard targetBytes > 0, data.count > targetBytes else { return Result(data: data, quality: quality) }
        var low = 0.05, high = quality
        var best = Result(data: try ImageConverter.encode(image, as: .jpg, quality: low), quality: low)
        guard best.data.count <= targetBytes else { throw ConversionError.sizeLimit }
        for _ in 0..<8 {
            try Task.checkCancellation()
            let mid = (low + high) / 2
            let attempt = try ImageConverter.encode(image, as: .jpg, quality: mid)
            if attempt.count <= targetBytes { best = Result(data: attempt, quality: mid); low = mid }
            else { high = mid }
        }
        return best
    }

    public static func byteLimit(kilobytes: Int) -> Int { max(0, min(kilobytes, 1_000_000)) * 1000 }
}
