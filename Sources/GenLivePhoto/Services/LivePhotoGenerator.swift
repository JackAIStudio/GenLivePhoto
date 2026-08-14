import Foundation

struct LivePhotoGenerator: Sendable {
    struct Tool: Sendable {
        let executableURL: URL
        let leadingArguments: [String]
        let displayName: String
    }

    enum GeneratorError: LocalizedError, Sendable {
        case toolNotFound
        case unsupportedFile(URL)
        case sourceMissing(URL)
        case missingOutputName
        case missingGeneratedPackage(String)
        case commandFailed(Int32, String)

        var errorDescription: String? {
            switch self {
            case .toolNotFound:
                "找不到 MakeLive。请先安装 uv，或执行“uv tool install makelive”。"
            case let .unsupportedFile(url):
                "不支持的文件格式：\(url.lastPathComponent)"
            case let .sourceMissing(url):
                "找不到源文件：\(url.path)"
            case .missingOutputName:
                "请先填写实况照片名称。"
            case let .missingGeneratedPackage(name):
                "MakeLive 已结束，但没有找到生成结果：\(name).pvt"
            case let .commandFailed(code, output):
                "MakeLive 生成失败（退出码 \(code)）。\n\(output)"
            }
        }
    }

    static func locateTool(fileManager: FileManager = .default) -> Tool? {
        let userDirectory = fileManager.homeDirectoryForCurrentUser
        let candidates: [(URL, [String], String)] = [
            (userDirectory.appendingPathComponent(".local/bin/makelive"), [], "MakeLive"),
            (URL(fileURLWithPath: "/opt/homebrew/bin/makelive"), [], "MakeLive"),
            (URL(fileURLWithPath: "/usr/local/bin/makelive"), [], "MakeLive"),
            (userDirectory.appendingPathComponent(".local/bin/uvx"), ["makelive"], "uvx makelive"),
            (URL(fileURLWithPath: "/opt/homebrew/bin/uvx"), ["makelive"], "uvx makelive"),
            (URL(fileURLWithPath: "/usr/local/bin/uvx"), ["makelive"], "uvx makelive")
        ]

        for (url, arguments, name) in candidates where fileManager.isExecutableFile(atPath: url.path) {
            return Tool(executableURL: url, leadingArguments: arguments, displayName: name)
        }
        return nil
    }

    static func sanitizedOutputName(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\0")
            .union(.newlines)
            .union(.controlCharacters)
        let edgeCharacters = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: ".-"))
        let cleaned = value
            .components(separatedBy: invalidCharacters)
            .map { $0.trimmingCharacters(in: edgeCharacters) }
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return cleaned
    }

    static func suggestedOutputName(for videoURL: URL) -> String {
        let videoName = videoURL.deletingPathExtension().lastPathComponent
        let suggestedName = sanitizedOutputName(videoName)
        return suggestedName.isEmpty ? "实况照片" : suggestedName
    }

    static func uniqueDestination(
        in directory: URL,
        baseName: String,
        fileManager: FileManager = .default
    ) -> URL {
        let initial = directory.appendingPathComponent("\(baseName).pvt", isDirectory: true)
        guard fileManager.fileExists(atPath: initial.path) else { return initial }

        var index = 2
        while true {
            let candidate = directory.appendingPathComponent("\(baseName) \(index).pvt", isDirectory: true)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    func generate(
        imageURL: URL,
        videoURL: URL,
        outputDirectory: URL,
        outputName: String
    ) throws -> URL {
        guard MediaKind.image.accepts(imageURL) else {
            throw GeneratorError.unsupportedFile(imageURL)
        }
        guard MediaKind.video.accepts(videoURL) else {
            throw GeneratorError.unsupportedFile(videoURL)
        }
        let safeName = Self.sanitizedOutputName(outputName)
        guard !safeName.isEmpty else {
            throw GeneratorError.missingOutputName
        }
        guard let tool = Self.locateTool() else {
            throw GeneratorError.toolNotFound
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: imageURL.path) else {
            throw GeneratorError.sourceMissing(imageURL)
        }
        guard fileManager.fileExists(atPath: videoURL.path) else {
            throw GeneratorError.sourceMissing(videoURL)
        }
        let stagingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("GenLivePhoto-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDirectory) }

        let stagedImage: URL
        if CoverImageProcessor.needsConversion(imageURL) {
            stagedImage = stagingDirectory
                .appendingPathComponent(safeName)
                .appendingPathExtension("jpg")
            try CoverImageProcessor.writeJPEG(from: imageURL, to: stagedImage)
        } else {
            stagedImage = stagingDirectory
                .appendingPathComponent(safeName)
                .appendingPathExtension(imageURL.pathExtension.lowercased())
            try fileManager.copyItem(at: imageURL, to: stagedImage)
        }
        let stagedVideo = stagingDirectory
            .appendingPathComponent(safeName)
            .appendingPathExtension(videoURL.pathExtension.lowercased())
        try fileManager.copyItem(at: videoURL, to: stagedVideo)

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = tool.executableURL
        process.currentDirectoryURL = stagingDirectory
        process.arguments = tool.leadingArguments + [
            "-p",
            "-m",
            stagedImage.lastPathComponent,
            stagedVideo.lastPathComponent
        ]
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let commandOutput = String(data: outputData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw GeneratorError.commandFailed(process.terminationStatus, commandOutput)
        }

        let generatedPackage = stagingDirectory
            .appendingPathComponent("\(safeName).pvt", isDirectory: true)
        guard fileManager.fileExists(atPath: generatedPackage.path) else {
            throw GeneratorError.missingGeneratedPackage(safeName)
        }

        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let destination = Self.uniqueDestination(in: outputDirectory, baseName: safeName)
        try fileManager.copyItem(at: generatedPackage, to: destination)
        return destination
    }
}
