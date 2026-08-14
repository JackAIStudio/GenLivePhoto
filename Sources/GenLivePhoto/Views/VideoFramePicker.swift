import AppKit
import SwiftUI

struct VideoFrameStrip: View {
    let frames: [ExtractedVideoFrame]
    let selectedTime: Double
    let duration: Double
    let isLoading: Bool
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let progress = duration > 0 ? min(max(selectedTime / duration, 0), 1) : 0
            let selectorWidth: CGFloat = 30
            let selectorCenter = min(
                max(selectorWidth / 2, width * progress),
                max(selectorWidth / 2, width - (selectorWidth / 2))
            )

            ZStack(alignment: .topLeading) {
                thumbnailRow
                    .frame(width: width, height: height)

                selectionMarker
                    .frame(width: selectorWidth, height: height)
                    .position(x: selectorCenter, y: height / 2)
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0, width > 0 else { return }
                        let newProgress = min(max(value.location.x / width, 0), 1)
                        onSeek(duration * newProgress)
                    }
            )
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement()
        .accessibilityLabel("封面选择条")
        .accessibilityHint("左右拖动，选择视频中要作为封面的画面")
        .accessibilityValue("视频第 \(Self.friendlyTime(selectedTime))")
        .accessibilityAdjustableAction { direction in
            let step = max(duration / 100, 1 / 30)
            switch direction {
            case .increment:
                onSeek(min(duration, selectedTime + step))
            case .decrement:
                onSeek(max(0, selectedTime - step))
            @unknown default:
                break
            }
        }
    }

    private var selectionMarker: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(.white, lineWidth: 3)

            Capsule()
                .fill(Color.accentColor)
                .frame(width: 4)
                .padding(.vertical, 7)
        }
        .padding(.vertical, 3)
        .shadow(color: .black.opacity(0.42), radius: 4, y: 1)
    }

    @ViewBuilder
    private var thumbnailRow: some View {
        if frames.isEmpty {
            HStack(spacing: 2) {
                ForEach(0 ..< 10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.secondary.opacity(index.isMultiple(of: 2) ? 0.13 : 0.2))
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        } else {
            HStack(spacing: 2) {
                ForEach(Array(frames.enumerated()), id: \.offset) { _, frame in
                    if let image = NSImage(contentsOf: frame.imageURL) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    }
                }
            }
        }
    }

    nonisolated static func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00.000" }
        let totalMilliseconds = Int((seconds * 1_000).rounded())
        let milliseconds = totalMilliseconds % 1_000
        let totalSeconds = totalMilliseconds / 1_000
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d.%03d", minutes, remainingSeconds, milliseconds)
    }

    nonisolated static func friendlyTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0.0 秒" }
        let totalTenths = Int((seconds * 10).rounded())
        let minutes = totalTenths / 600
        let remainingSeconds = Double(totalTenths % 600) / 10
        if minutes > 0 {
            return String(format: "%d 分 %.1f 秒", minutes, remainingSeconds)
        }
        return String(format: "%.1f 秒", remainingSeconds)
    }
}
