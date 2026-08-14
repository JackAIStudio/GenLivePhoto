import AppKit
import SwiftUI

private enum CoverMode: Equatable {
    case videoFrame
    case image(URL)
}

struct ContentView: View {
    @State private var videoURL: URL?
    @State private var videoInfo: VideoInfo?
    @State private var coverMode: CoverMode?
    @State private var selectedFrameTime = 0.0
    @State private var framePreviewURL: URL?
    @State private var thumbnailFrames: [ExtractedVideoFrame] = []
    @State private var isPreparingVideo = false
    @State private var isLoadingThumbnails = false
    @State private var isUpdatingFrame = false
    @State private var isVideoDropTargeted = false
    @State private var isCoverDropTargeted = false
    @State private var mediaErrorMessage: String?

    @State private var outputName = ""
    @State private var outputDirectory: URL
    @State private var isGenerating = false
    @State private var generatedURL: URL?
    @State private var generationErrorMessage: String?
    @State private var dependencyName: String?
    @State private var dependencyCheckFinished = false

    @State private var videoPreparationTask: Task<Void, Never>?
    @State private var framePreviewTask: Task<Void, Never>?
    @State private var videoRequestID = UUID()
    @State private var frameRequestID = UUID()
    @FocusState private var isOutputNameFocused: Bool

    init() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        _outputDirectory = State(initialValue: downloads.appendingPathComponent("GenLivePhoto"))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if videoURL == nil {
                        emptyVideoState
                    } else {
                        videoWorkspace
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 26)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }

            statusArea
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: generatedURL)
        .animation(.easeInOut(duration: 0.2), value: generationErrorMessage)
        .task {
            dependencyName = LivePhotoGenerator.locateTool()?.displayName
            dependencyCheckFinished = true
        }
        .onDisappear {
            cleanUpVideoResources()
        }
    }

    private var header: some View {
        workflowProgress
    }

    private var workflowProgress: some View {
        HStack(spacing: 0) {
            workflowStep(
                number: 1,
                title: "选择视频",
                systemImage: "video.fill",
                isComplete: videoURL != nil,
                isCurrent: videoURL == nil
            )
            workflowConnector(isComplete: videoURL != nil)
            workflowStep(
                number: 2,
                title: "选择封面",
                systemImage: "photo.fill",
                isComplete: hasUsableCover,
                isCurrent: videoURL != nil && !hasUsableCover
            )
            workflowConnector(isComplete: videoURL != nil && hasUsableCover)
            workflowStep(
                number: 3,
                title: "生成实况照片",
                systemImage: "livephoto",
                isComplete: generatedURL != nil,
                isCurrent: videoURL != nil && hasUsableCover && generatedURL == nil
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }

    private func workflowStep(
        number: Int,
        title: String,
        systemImage: String,
        isComplete: Bool,
        isCurrent: Bool
    ) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isComplete || isCurrent ? Color.accentColor : Color.secondary.opacity(0.13))
                    .frame(width: 28, height: 28)

                Image(systemName: isComplete ? "checkmark" : systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isComplete || isCurrent ? .white : .secondary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("第 \(number) 步")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.callout.weight(isCurrent ? .semibold : .medium))
                    .foregroundStyle(isCurrent || isComplete ? .primary : .secondary)
            }
        }
        .fixedSize()
    }

    private func workflowConnector(isComplete: Bool) -> some View {
        Capsule()
            .fill(isComplete ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.16))
            .frame(maxWidth: .infinity)
            .frame(height: 2)
            .padding(.horizontal, 14)
    }

    private var emptyVideoState: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("添加素材")
                    .font(.title2.bold())
                Text("视频和封面照片可以按任意顺序选择")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
                videoInputCard
                coverInputCard
            }

            Label("选择视频后，也可以直接使用视频中的某一帧作为封面", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var videoInputCard: some View {
        inputCard(
            number: 1,
            title: "视频",
            description: "MOV、MP4 或 M4V",
            systemImage: "video.fill",
            isTargeted: isVideoDropTargeted,
            preview: nil,
            fileName: nil,
            buttonTitle: "选择视频…",
            action: pickVideo
        )
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: MediaKind.video.accepts) else { return false }
            selectVideo(url)
            return true
        } isTargeted: { isTargeted in
            isVideoDropTargeted = isTargeted
        }
    }

    private var coverInputCard: some View {
        let coverURL: URL? = if case let .image(url) = coverMode { url } else { nil }
        let preview = coverURL.flatMap(NSImage.init(contentsOf:))

        return inputCard(
            number: 2,
            title: "封面",
            description: "PNG、JPG、HEIC 等",
            systemImage: "photo.fill",
            isTargeted: isCoverDropTargeted,
            preview: preview,
            fileName: coverURL?.lastPathComponent,
            buttonTitle: coverURL == nil ? "选择照片…" : "更换照片…",
            action: pickCoverImage
        )
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: MediaKind.image.accepts) else { return false }
            selectCoverImage(url)
            return true
        } isTargeted: { isTargeted in
            isCoverDropTargeted = isTargeted
        }
    }

    private func inputCard(
        number: Int,
        title: String,
        description: String,
        systemImage: String,
        isTargeted: Bool,
        preview: NSImage?,
        fileName: String?,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor, in: Circle())
                Text(title)
                    .font(.headline)
                Spacer()
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Group {
                if let preview {
                    Image(nsImage: preview)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 138)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.07))
                        Image(systemName: systemImage)
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 138, maxHeight: 138)

            if let fileName {
                Label(fileName, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("可以选择文件，也可以拖放到这里")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if number == 1 {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else {
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 278, alignment: .topLeading)
        .background(
            isTargeted ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.18),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [7] : [])
                )
        }
    }

    private var videoWorkspace: some View {
        VStack(alignment: .leading, spacing: 18) {
            videoSummary

            if let mediaErrorMessage, framePreviewURL == nil {
                mediaErrorCard(mediaErrorMessage)
            } else {
                coverEditor
                outputSettings
                actionArea
            }
        }
    }

    private var videoSummary: some View {
        HStack(spacing: 12) {
            Text("1")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "video.fill")
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(videoURL?.lastPathComponent ?? "")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let videoInfo {
                    Text("视频时长 \(VideoFrameStrip.formattedTime(videoInfo.duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("正在读取视频…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("更换视频…", action: pickVideo)
                .disabled(isGenerating)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }

    private var coverEditor: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("2")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.accentColor, in: Circle())
                    Text("选择封面")
                        .font(.title3.bold())
                }
                Text("使用视频中的画面，或选择一张单独的照片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                coverSourceButton(
                    title: "视频画面",
                    description: "从时间轴选取一帧",
                    systemImage: "film.fill",
                    isSelected: coverMode == .videoFrame,
                    action: useVideoFrame
                )

                coverSourceButton(
                    title: "本地照片",
                    description: "选择已有图片文件",
                    systemImage: "photo.fill",
                    isSelected: isUsingImageCover,
                    action: pickCoverImage
                )
            }

            coverPreview

            if coverMode == .videoFrame {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        Label("左右拖动画面，选择喜欢的封面", systemImage: "hand.draw")
                            .font(.callout.weight(.medium))
                        Spacer()
                        Text("视频第 \(VideoFrameStrip.friendlyTime(selectedFrameTime))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    VideoFrameStrip(
                        frames: thumbnailFrames,
                        selectedTime: selectedFrameTime,
                        duration: videoInfo?.duration ?? 0,
                        isLoading: isLoadingThumbnails,
                        onSeek: selectFrame
                    )
                    .disabled(isPreparingVideo || isGenerating)
                }

                HStack(spacing: 10) {
                    Text("精细调整")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        stepFrame(by: -1)
                    } label: {
                        Label("早一点", systemImage: "arrow.left")
                    }
                    .help("选择视频中稍早一点的画面")
                    .disabled(selectedFrameTime <= 0)

                    Button {
                        stepFrame(by: 1)
                    } label: {
                        Label("晚一点", systemImage: "arrow.right")
                    }
                    .help("选择视频中稍晚一点的画面")
                    .disabled(selectedFrameTime >= (videoInfo?.latestFrameTime ?? 0))

                }
                .buttonStyle(.bordered)
                .disabled(isPreparingVideo || isGenerating)
            } else {
                HStack(spacing: 10) {
                    Label(selectedCoverImageName ?? "已选择封面照片", systemImage: "photo.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("更换照片…", action: pickCoverImage)
                }
                .buttonStyle(.bordered)
                .disabled(isGenerating)
            }

            if let mediaErrorMessage, framePreviewURL != nil {
                Label(mediaErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(22)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
    }

    private var isUsingImageCover: Bool {
        if case .image = coverMode { return true }
        return false
    }

    private var selectedCoverImageName: String? {
        if case let .image(url) = coverMode { return url.lastPathComponent }
        return nil
    }

    private func coverSourceButton(
        title: String,
        description: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.45))
            }
            .padding(13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(
            isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.15),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .disabled(isGenerating)
    }

    private var coverPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.92))

            if let image = currentCoverPreviewImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在准备封面画面…")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            if isUpdatingFrame {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(12)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 310, maxHeight: 340)
        .clipped()
    }

    private var currentCoverPreviewImage: NSImage? {
        switch coverMode {
        case let .image(url):
            NSImage(contentsOf: url)
        case .videoFrame:
            framePreviewURL.flatMap(NSImage.init(contentsOf:))
        case nil:
            nil
        }
    }

    private var outputSettings: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("3")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.accentColor, in: Circle())
                    Text("生成实况照片")
                        .font(.title3.bold())
                }
                Text("已使用视频名称，你也可以换一个更容易找到的名字")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 13) {
                GridRow {
                    Text("名称")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 7) {
                        TextField("实况照片名称", text: $outputName)
                            .textFieldStyle(.roundedBorder)
                            .focused($isOutputNameFocused)
                            .onSubmit {
                                if canGenerate {
                                    generate()
                                }
                            }
                        Text(".pvt")
                            .foregroundStyle(.tertiary)
                    }
                }

                GridRow {
                    Text("位置")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 9) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                        Text(outputDirectory.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("更改…", action: pickOutputDirectory)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
    }

    private var actionArea: some View {
        VStack(spacing: 9) {
            Button(action: generate) {
                HStack(spacing: 9) {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "livephoto")
                    }
                    Text(isGenerating ? "正在创建…" : "创建实况照片")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canGenerate)

            Text(actionHint)
                .font(.caption)
                .foregroundStyle(canGenerate ? Color.secondary : Color.orange)
        }
    }

    private var hasValidOutputName: Bool {
        !LivePhotoGenerator.sanitizedOutputName(outputName).isEmpty
    }

    private var hasUsableCover: Bool {
        switch coverMode {
        case .videoFrame:
            framePreviewURL != nil && videoInfo != nil
        case let .image(url):
            FileManager.default.fileExists(atPath: url.path)
        case nil:
            false
        }
    }

    private var canGenerate: Bool {
        videoURL != nil
            && hasUsableCover
            && dependencyName != nil
            && hasValidOutputName
            && !isPreparingVideo
            && !isUpdatingFrame
            && !isGenerating
    }

    private var actionHint: String {
        if !dependencyCheckFinished {
            return "正在检查生成环境…"
        }
        if dependencyName == nil {
            return "缺少实况照片生成组件，请先安装 MakeLive。"
        }
        if isPreparingVideo {
            return "正在读取视频，请稍候。"
        }
        if !hasUsableCover {
            return "请先选好封面画面。"
        }
        if !hasValidOutputName {
            return "请给实况照片起一个名字。"
        }
        return "已有同名结果时，会自动追加序号。"
    }

    @ViewBuilder
    private var statusArea: some View {
        if let generatedURL {
            Divider()
            successCard(generatedURL)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let generationErrorMessage {
            Divider()
            generationErrorCard(generationErrorMessage)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func successCard(_ url: URL) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 3) {
                Text("实况照片已创建")
                    .font(.headline)
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button("在访达中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Button("导入照片") {
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(17)
        .frame(maxWidth: 900)
        .background(Color.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 30)
        .padding(.vertical, 14)
    }

    private func generationErrorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "xmark.octagon.fill")
                .font(.title2)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text("没有创建成功")
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(17)
        .frame(maxWidth: 900)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 30)
        .padding(.vertical, 14)
    }

    private func mediaErrorCard(_ message: String) -> some View {
        VStack(spacing: 13) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.orange)
            Text("无法读取这个视频")
                .font(.title3.bold())
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            Button("选择其他视频…", action: pickVideo)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(24)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
    }

    private func pickVideo() {
        let panel = NSOpenPanel()
        panel.title = "选择视频"
        panel.prompt = "选择"
        panel.allowedContentTypes = MediaKind.video.allowedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectVideo(url)
    }

    private func pickCoverImage() {
        let panel = NSOpenPanel()
        panel.title = "选择封面照片"
        panel.prompt = "使用照片"
        panel.allowedContentTypes = MediaKind.image.allowedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url, MediaKind.image.accepts(url) else { return }

        selectCoverImage(url)
    }

    private func selectCoverImage(_ url: URL) {
        guard MediaKind.image.accepts(url) else { return }
        framePreviewTask?.cancel()
        frameRequestID = UUID()
        isUpdatingFrame = false
        coverMode = .image(url)
        mediaErrorMessage = nil
        clearResultStatus()
    }

    private func selectVideo(_ url: URL) {
        guard MediaKind.video.accepts(url) else { return }
        let existingCoverMode = coverMode
        cleanUpVideoResources()

        videoURL = url
        outputName = LivePhotoGenerator.suggestedOutputName(for: url)
        videoInfo = nil
        if case let .image(imageURL) = existingCoverMode,
           FileManager.default.fileExists(atPath: imageURL.path) {
            coverMode = .image(imageURL)
        } else {
            coverMode = .videoFrame
        }
        selectedFrameTime = 0
        mediaErrorMessage = nil
        isPreparingVideo = true
        isLoadingThumbnails = true
        clearResultStatus()

        let requestID = UUID()
        videoRequestID = requestID
        videoPreparationTask = Task {
            do {
                let info = try await VideoFrameExtractor.loadInfo(from: url)
                try Task.checkCancellation()
                guard videoRequestID == requestID else { return }

                videoInfo = info
                let initialTime = min(info.latestFrameTime, info.duration / 2)
                selectedFrameTime = initialTime

                let preview = try await VideoFrameExtractor.extractJPEG(
                    from: url,
                    at: initialTime,
                    maximumSize: CGSize(width: 1_600, height: 1_000)
                )
                guard !Task.isCancelled, videoRequestID == requestID else {
                    try? FileManager.default.removeItem(at: preview.imageURL)
                    return
                }

                replaceFramePreview(with: preview.imageURL)
                selectedFrameTime = preview.actualTime
                isPreparingVideo = false

                do {
                    let frames = try await VideoFrameExtractor.extractThumbnailStrip(
                        from: url,
                        info: info
                    )
                    guard !Task.isCancelled, videoRequestID == requestID else {
                        removeFrames(frames)
                        return
                    }
                    removeFrames(thumbnailFrames)
                    thumbnailFrames = frames
                } catch is CancellationError {
                    return
                } catch {
                    guard videoRequestID == requestID else { return }
                    mediaErrorMessage = "画面预览暂时不可用，仍可拖动选择封面。"
                }
                isLoadingThumbnails = false
            } catch is CancellationError {
                return
            } catch {
                guard videoRequestID == requestID else { return }
                mediaErrorMessage = error.localizedDescription
                isPreparingVideo = false
                isLoadingThumbnails = false
            }
        }
    }

    private func selectFrame(_ time: Double) {
        guard let videoURL, let videoInfo, coverMode == .videoFrame else { return }
        let clampedTime = min(max(0, time), videoInfo.latestFrameTime)
        selectedFrameTime = clampedTime
        clearResultStatus()

        framePreviewTask?.cancel()
        let requestID = UUID()
        frameRequestID = requestID
        isUpdatingFrame = true
        mediaErrorMessage = nil

        framePreviewTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(120))
                try Task.checkCancellation()
                let preview = try await VideoFrameExtractor.extractJPEG(
                    from: videoURL,
                    at: clampedTime,
                    maximumSize: CGSize(width: 1_600, height: 1_000)
                )
                guard !Task.isCancelled, frameRequestID == requestID else {
                    try? FileManager.default.removeItem(at: preview.imageURL)
                    return
                }
                replaceFramePreview(with: preview.imageURL)
                selectedFrameTime = preview.actualTime
                isUpdatingFrame = false
            } catch is CancellationError {
                return
            } catch {
                guard frameRequestID == requestID else { return }
                mediaErrorMessage = "这个位置的画面读取失败，请稍微移动选择位置后重试。"
                isUpdatingFrame = false
            }
        }
    }

    private func stepFrame(by count: Int) {
        guard let videoInfo else { return }
        selectFrame(selectedFrameTime + (Double(count) * videoInfo.frameStep))
    }

    private func useVideoFrame() {
        coverMode = .videoFrame
        mediaErrorMessage = nil
        clearResultStatus()
        if framePreviewURL == nil {
            selectFrame(selectedFrameTime)
        }
    }

    private func pickOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择保存位置"
        panel.prompt = "选择"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = outputDirectory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputDirectory = url
    }

    private func generate() {
        guard
            let videoURL,
            let coverMode,
            let videoInfo,
            hasValidOutputName
        else {
            isOutputNameFocused = true
            return
        }

        let destinationDirectory = outputDirectory
        let destinationName = outputName
        let captureTime = min(selectedFrameTime, videoInfo.latestFrameTime)

        isGenerating = true
        clearResultStatus()

        Task {
            var temporaryImageURL: URL?
            defer {
                if let temporaryImageURL {
                    try? FileManager.default.removeItem(at: temporaryImageURL)
                }
            }

            do {
                let imageURL: URL
                switch coverMode {
                case let .image(url):
                    imageURL = url
                case .videoFrame:
                    let frame = try await VideoFrameExtractor.extractJPEG(
                        from: videoURL,
                        at: captureTime
                    )
                    temporaryImageURL = frame.imageURL
                    imageURL = frame.imageURL
                }

                let result = try await Task.detached(priority: .userInitiated) {
                    try LivePhotoGenerator().generate(
                        imageURL: imageURL,
                        videoURL: videoURL,
                        outputDirectory: destinationDirectory,
                        outputName: destinationName
                    )
                }.value
                generatedURL = result
            } catch {
                generationErrorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func replaceFramePreview(with url: URL) {
        if let framePreviewURL, framePreviewURL != url {
            try? FileManager.default.removeItem(at: framePreviewURL)
        }
        framePreviewURL = url
    }

    private func clearResultStatus() {
        generatedURL = nil
        generationErrorMessage = nil
    }

    private func cleanUpVideoResources() {
        videoPreparationTask?.cancel()
        framePreviewTask?.cancel()
        videoPreparationTask = nil
        framePreviewTask = nil
        isUpdatingFrame = false

        if let framePreviewURL {
            try? FileManager.default.removeItem(at: framePreviewURL)
        }
        framePreviewURL = nil
        removeFrames(thumbnailFrames)
        thumbnailFrames = []
    }

    private func removeFrames(_ frames: [ExtractedVideoFrame]) {
        for frame in frames {
            try? FileManager.default.removeItem(at: frame.imageURL)
        }
    }
}
