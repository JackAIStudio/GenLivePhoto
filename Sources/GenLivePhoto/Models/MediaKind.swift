import Foundation
import UniformTypeIdentifiers

enum MediaKind: String, Sendable {
    case image
    case video

    var title: String {
        switch self {
        case .image: "封面照片"
        case .video: "动态视频"
        }
    }

    var prompt: String {
        switch self {
        case .image: "拖入照片，或从视频选取画面"
        case .video: "拖入 MOV、MP4 或 M4V"
        }
    }

    var systemImage: String {
        switch self {
        case .image: "photo"
        case .video: "video"
        }
    }

    var allowedExtensions: Set<String> {
        switch self {
        case .image: ["jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "bmp", "gif", "webp"]
        case .video: ["mov", "mp4", "m4v"]
        }
    }

    var allowedContentTypes: [UTType] {
        switch self {
        case .image: [.image]
        case .video: [.movie, .mpeg4Movie]
        }
    }

    func accepts(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        switch self {
        case .image:
            return allowedExtensions.contains(fileExtension)
                || UTType(filenameExtension: fileExtension)?.conforms(to: .image) == true
        case .video:
            return allowedExtensions.contains(fileExtension)
        }
    }
}
