import Foundation
import AppKit
import XCTest
@testable import GenLivePhoto

final class LivePhotoGeneratorTests: XCTestCase {
    func testSanitizedOutputNameRemovesUnsafeCharacters() {
        XCTAssertEqual(
            LivePhotoGenerator.sanitizedOutputName("  我的/实况:照片\n  "),
            "我的-实况-照片"
        )
    }

    func testSanitizedOutputNameReturnsEmptyWhenNoValidCharacters() {
        XCTAssertEqual(LivePhotoGenerator.sanitizedOutputName("../"), "")
    }

    func testSuggestedOutputNameUsesVideoFileNameWithoutExtension() {
        let videoURL = URL(fileURLWithPath: "/tmp/周末散步.mov")
        XCTAssertEqual(LivePhotoGenerator.suggestedOutputName(for: videoURL), "周末散步")
    }

    func testGenerateRejectsMissingOutputName() {
        XCTAssertThrowsError(
            try LivePhotoGenerator().generate(
                imageURL: URL(fileURLWithPath: "/tmp/cover.jpg"),
                videoURL: URL(fileURLWithPath: "/tmp/clip.mov"),
                outputDirectory: URL(fileURLWithPath: "/tmp/output"),
                outputName: "  \n "
            )
        ) { error in
            guard
                let generatorError = error as? LivePhotoGenerator.GeneratorError,
                case .missingOutputName = generatorError
            else {
                return XCTFail("应当在访问源文件或查找工具前拒绝空文件名")
            }
        }
    }

    func testUniqueDestinationDoesNotOverwriteExistingPackage() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("GenLivePhotoTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        try fileManager.createDirectory(
            at: directory.appendingPathComponent("演示.pvt", isDirectory: true),
            withIntermediateDirectories: true
        )
        let destination = LivePhotoGenerator.uniqueDestination(in: directory, baseName: "演示")
        XCTAssertEqual(destination.lastPathComponent, "演示 2.pvt")
    }

    func testMediaKindAcceptsExpectedExtensions() {
        XCTAssertTrue(MediaKind.image.accepts(URL(fileURLWithPath: "/tmp/cover.HEIC")))
        XCTAssertTrue(MediaKind.image.accepts(URL(fileURLWithPath: "/tmp/cover.PNG")))
        XCTAssertTrue(MediaKind.image.accepts(URL(fileURLWithPath: "/tmp/cover.webp")))
        XCTAssertTrue(MediaKind.video.accepts(URL(fileURLWithPath: "/tmp/clip.mov")))
        XCTAssertFalse(MediaKind.image.accepts(URL(fileURLWithPath: "/tmp/clip.mov")))
    }

    func testCoverProcessorConvertsTransparentPNGToJPEG() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("GenLivePhotoCoverTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("transparent.png")
        let destinationURL = directory.appendingPathComponent("converted.jpg")
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: 8,
                height: 8,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let transparentImage = context.makeImage()
        else {
            return XCTFail("无法创建 PNG 测试图片")
        }
        guard let pngData = NSBitmapImageRep(cgImage: transparentImage).representation(
            using: .png,
            properties: [:]
        ) else {
            return XCTFail("无法编码 PNG 测试图片")
        }
        try pngData.write(to: sourceURL)

        try CoverImageProcessor.writeJPEG(from: sourceURL, to: destinationURL)

        XCTAssertTrue(fileManager.fileExists(atPath: destinationURL.path))
        guard
            let convertedData = try? Data(contentsOf: destinationURL),
            let convertedBitmap = NSBitmapImageRep(data: convertedData),
            let backgroundColor = convertedBitmap.colorAt(x: 4, y: 4)?.usingColorSpace(.sRGB)
        else {
            return XCTFail("转换结果不是可读取的 JPEG")
        }
        XCTAssertGreaterThan(backgroundColor.redComponent, 0.9)
        XCTAssertGreaterThan(backgroundColor.greenComponent, 0.9)
        XCTAssertGreaterThan(backgroundColor.blueComponent, 0.9)
        XCTAssertEqual(backgroundColor.alphaComponent, 1, accuracy: 0.01)
    }

    func testFramePickerFormatsSubsecondTime() {
        XCTAssertEqual(VideoFrameStrip.formattedTime(62.345), "01:02.345")
        XCTAssertEqual(VideoFrameStrip.formattedTime(.nan), "00:00.000")
        XCTAssertEqual(VideoFrameStrip.friendlyTime(62.345), "1 分 2.3 秒")
        XCTAssertEqual(VideoFrameStrip.friendlyTime(2.333), "2.3 秒")
    }

    func testVideoInfoUsesSourceFrameRateForFrameStepping() {
        let info = VideoInfo(duration: 2, nominalFrameRate: 24)
        XCTAssertEqual(info.frameStep, 1 / 24, accuracy: 0.000_001)
        XCTAssertLessThan(info.latestFrameTime, info.duration)
    }

    func testFrameExtractorCreatesReadableJPEGWhenFixtureIsProvided() async throws {
        guard let videoPath = ProcessInfo.processInfo.environment["GENLIVEPHOTO_FRAME_VIDEO"] else {
            throw XCTSkip("未提供视频帧提取测试素材")
        }

        let frame = try await VideoFrameExtractor.extractJPEG(
            from: URL(fileURLWithPath: videoPath),
            at: 0.5
        )
        defer { try? FileManager.default.removeItem(at: frame.imageURL) }

        XCTAssertEqual(frame.imageURL.pathExtension, "jpg")
        XCTAssertNotNil(NSImage(contentsOf: frame.imageURL))
        XCTAssertGreaterThanOrEqual(frame.actualTime, 0)

        let info = try await VideoFrameExtractor.loadInfo(
            from: URL(fileURLWithPath: videoPath)
        )
        XCTAssertGreaterThan(info.duration, 0)
        XCTAssertGreaterThan(info.nominalFrameRate, 0)

        let thumbnails = try await VideoFrameExtractor.extractThumbnailStrip(
            from: URL(fileURLWithPath: videoPath),
            info: info,
            count: 5
        )
        defer {
            for thumbnail in thumbnails {
                try? FileManager.default.removeItem(at: thumbnail.imageURL)
            }
        }
        XCTAssertEqual(thumbnails.count, 5)
        XCTAssertTrue(thumbnails.allSatisfy { NSImage(contentsOf: $0.imageURL) != nil })
    }

    func testIntegrationGeneratesPVTPackageWhenFixturesAreProvided() throws {
        let environment = ProcessInfo.processInfo.environment
        guard
            let imagePath = environment["GENLIVEPHOTO_INTEGRATION_IMAGE"],
            let videoPath = environment["GENLIVEPHOTO_INTEGRATION_VIDEO"]
        else {
            throw XCTSkip("未提供集成测试素材")
        }

        let fileManager = FileManager.default
        let outputDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("GenLivePhotoIntegration-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: outputDirectory) }

        let result = try LivePhotoGenerator().generate(
            imageURL: URL(fileURLWithPath: imagePath),
            videoURL: URL(fileURLWithPath: videoPath),
            outputDirectory: outputDirectory,
            outputName: "真实素材验证"
        )

        XCTAssertTrue(fileManager.fileExists(atPath: result.path))
        let packageFiles = try fileManager.contentsOfDirectory(atPath: result.path)
        XCTAssertTrue(packageFiles.contains("metadata.plist"))
        XCTAssertTrue(packageFiles.contains(where: { $0.hasSuffix(".jpg") || $0.hasSuffix(".heic") }))
        XCTAssertTrue(packageFiles.contains(where: { $0.hasSuffix(".mov") || $0.hasSuffix(".mp4") }))
    }
}
