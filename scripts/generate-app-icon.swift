#!/usr/bin/env swift

import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("用法：generate-app-icon.swift <输出 PNG 路径>\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let canvasPixels = 1_024
let canvasSize = NSSize(width: canvasPixels, height: canvasPixels)
guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: canvasPixels,
        pixelsHigh: canvasPixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ),
    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
else {
    FileHandle.standardError.write(Data("无法创建 App 图标画布。\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
defer { NSGraphicsContext.restoreGraphicsState() }

graphicsContext.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(origin: .zero, size: canvasSize).fill()

let tileRect = NSRect(x: 62, y: 62, width: 900, height: 900)
let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: 205, yRadius: 205)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
shadow.shadowBlurRadius = 34
shadow.shadowOffset = NSSize(width: 0, height: -15)
shadow.set()
NSColor(calibratedRed: 0.96, green: 0.35, blue: 0.18, alpha: 1).setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()

let rearFrame = NSBezierPath(
    roundedRect: NSRect(x: 365, y: 455, width: 370, height: 270),
    xRadius: 58,
    yRadius: 58
)
rearFrame.lineWidth = 34
NSColor.white.withAlphaComponent(0.58).setStroke()
rearFrame.stroke()

let frontFrame = NSBezierPath(
    roundedRect: NSRect(x: 285, y: 305, width: 440, height: 325),
    xRadius: 64,
    yRadius: 64
)
NSColor(calibratedWhite: 1, alpha: 0.98).setFill()
frontFrame.fill()

let play = NSBezierPath()
play.move(to: NSPoint(x: 465, y: 395))
play.line(to: NSPoint(x: 465, y: 535))
play.line(to: NSPoint(x: 585, y: 465))
play.close()
NSColor(calibratedRed: 0.96, green: 0.35, blue: 0.18, alpha: 1).setFill()
play.fill()

guard
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("无法生成 App 图标 PNG。\n".utf8))
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try pngData.write(to: outputURL, options: .atomic)
