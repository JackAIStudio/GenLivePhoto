import AppKit
import AVFoundation
import Foundation

struct ExtractedVideoFrame: Sendable {
    let imageURL: URL
    let actualTime: Double
}

struct VideoInfo: Sendable {
    let duration: Double
    let nominalFrameRate: Double

    var frameStep: Double {
        1 / max(nominalFrameRate, 1)
    }

    var latestFrameTime: Double {
        max(0, duration - (1 / 600))
    }
}

enum VideoFrameExtractor {
    enum ExtractionError: LocalizedError, Sendable {
        case sourceMissing(URL)
        case noVideoTrack
        case invalidTime
        case imageEncodingFailed

        var errorDescription: String? {
            switch self {
            case let .sourceMissing(url):
                "找不到视频文件：\(url.path)"
            case .noVideoTrack:
                "所选文件中没有可用的视频画面。"
            case .invalidTime:
                "无法读取当前画面的时间位置。"
            case .imageEncodingFailed:
                "当前视频画面无法转换为 JPEG 封面。"
            }
        }
    }

    static func loadInfo(
        from videoURL: URL,
        fileManager: FileManager = .default
    ) async throws -> VideoInfo {
        guard fileManager.fileExists(atPath: videoURL.path) else {
            throw ExtractionError.sourceMissing(videoURL)
        }

        let asset = AVURLAsset(url: videoURL)
        let durationTime = try await asset.load(.duration)
        let duration = durationTime.seconds
        guard duration.isFinite, duration > 0 else {
            throw ExtractionError.invalidTime
        }

        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExtractionError.noVideoTrack
        }
        let loadedFrameRate = Double(try await track.load(.nominalFrameRate))
        let frameRate = loadedFrameRate.isFinite && loadedFrameRate > 0 ? loadedFrameRate : 30
        return VideoInfo(duration: duration, nominalFrameRate: frameRate)
    }

    static func extractJPEG(
        from videoURL: URL,
        at seconds: Double,
        maximumSize: CGSize? = nil,
        fileManager: FileManager = .default
    ) async throws -> ExtractedVideoFrame {
        guard fileManager.fileExists(atPath: videoURL.path) else {
            throw ExtractionError.sourceMissing(videoURL)
        }
        guard seconds.isFinite, seconds >= 0 else {
            throw ExtractionError.invalidTime
        }

        let asset = AVURLAsset(url: videoURL)
        guard try await !asset.loadTracks(withMediaType: .video).isEmpty else {
            throw ExtractionError.noVideoTrack
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        if let maximumSize {
            generator.maximumSize = maximumSize
        }

        let requestedTime = CMTime(seconds: seconds, preferredTimescale: 600)
        let (image, actualTime) = try await generator.image(at: requestedTime)
        let imageURL = try writeJPEG(image, fileManager: fileManager)

        let resolvedTime = actualTime.seconds.isFinite ? max(0, actualTime.seconds) : seconds
        return ExtractedVideoFrame(imageURL: imageURL, actualTime: resolvedTime)
    }

    static func extractThumbnailStrip(
        from videoURL: URL,
        info: VideoInfo,
        count: Int = 10,
        fileManager: FileManager = .default
    ) async throws -> [ExtractedVideoFrame] {
        let thumbnailCount = max(2, count)
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 180, height: 120)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        var frames: [ExtractedVideoFrame] = []
        do {
            for index in 0 ..< thumbnailCount {
                try Task.checkCancellation()
                let progress = Double(index) / Double(thumbnailCount - 1)
                let seconds = min(info.latestFrameTime, info.duration * progress)
                let requestedTime = CMTime(seconds: seconds, preferredTimescale: 600)
                let (image, actualTime) = try await generator.image(at: requestedTime)
                let imageURL = try writeJPEG(image, fileManager: fileManager)
                let resolvedTime = actualTime.seconds.isFinite ? max(0, actualTime.seconds) : seconds
                frames.append(ExtractedVideoFrame(imageURL: imageURL, actualTime: resolvedTime))
            }
            return frames
        } catch {
            for frame in frames {
                try? fileManager.removeItem(at: frame.imageURL)
            }
            throw error
        }
    }

    private static func writeJPEG(
        _ image: CGImage,
        fileManager: FileManager
    ) throws -> URL {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let jpegData = representation.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.92]
        ) else {
            throw ExtractionError.imageEncodingFailed
        }

        let frameDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("GenLivePhoto-FrameCovers", isDirectory: true)
        try fileManager.createDirectory(at: frameDirectory, withIntermediateDirectories: true)
        let imageURL = frameDirectory
            .appendingPathComponent("frame-\(UUID().uuidString)")
            .appendingPathExtension("jpg")
        try jpegData.write(to: imageURL, options: .atomic)
        return imageURL
    }
}
