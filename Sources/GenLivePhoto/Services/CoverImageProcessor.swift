import AppKit
import CoreGraphics
import Foundation
import ImageIO

enum CoverImageProcessor {
    enum ProcessingError: LocalizedError, Sendable {
        case sourceMissing(URL)
        case unreadableImage(URL)
        case conversionFailed

        var errorDescription: String? {
            switch self {
            case let .sourceMissing(url):
                "找不到封面图片：\(url.path)"
            case let .unreadableImage(url):
                "无法读取这张封面图片：\(url.lastPathComponent)"
            case .conversionFailed:
                "封面图片无法转换为 JPEG。"
            }
        }
    }

    static let livePhotoExtensions: Set<String> = ["jpg", "jpeg", "heic", "heif"]

    static func needsConversion(_ url: URL) -> Bool {
        !livePhotoExtensions.contains(url.pathExtension.lowercased())
    }

    static func writeJPEG(
        from sourceURL: URL,
        to destinationURL: URL,
        fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw ProcessingError.sourceMissing(sourceURL)
        }
        guard
            let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
            CGImageSourceGetCount(imageSource) > 0
        else {
            throw ProcessingError.unreadableImage(sourceURL)
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let sourceWidth = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let sourceHeight = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let maximumDimension = max(sourceWidth, sourceHeight)
        guard maximumDimension > 0 else {
            throw ProcessingError.unreadableImage(sourceURL)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension
        ]
        guard let sourceImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw ProcessingError.unreadableImage(sourceURL)
        }

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: sourceImage.width,
                height: sourceImage.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else {
            throw ProcessingError.conversionFailed
        }

        let imageRect = CGRect(x: 0, y: 0, width: sourceImage.width, height: sourceImage.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(imageRect)
        context.interpolationQuality = .high
        context.draw(sourceImage, in: imageRect)

        guard
            let flattenedImage = context.makeImage(),
            let jpegData = NSBitmapImageRep(cgImage: flattenedImage).representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.94]
            )
        else {
            throw ProcessingError.conversionFailed
        }

        try jpegData.write(to: destinationURL, options: .atomic)
    }
}
