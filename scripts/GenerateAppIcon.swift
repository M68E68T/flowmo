import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Compiled with BrandMark.swift by build-app.sh; outputs stay in .build.
@main
enum GenerateAppIcon {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(domain: "GenerateAppIcon", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Expected an iconset output directory."])
        }
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = size * scale
                guard let context = CGContext(data: nil, width: pixels, height: pixels,
                                              bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                    throw CocoaError(.coderInvalidValue)
                }
                BrandMark.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels),
                               context: context, style: .appIcon)
                let suffix = scale == 2 ? "@2x" : ""
                let file = folder.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
                guard let image = context.makeImage(),
                      let destination = CGImageDestinationCreateWithURL(file as CFURL,
                                                                       UTType.png.identifier as CFString, 1, nil) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                CGImageDestinationAddImage(destination, image, nil)
                guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
            }
        }
    }
}
