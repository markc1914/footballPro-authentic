//
//  ScreenshotService.swift
//  footballPro
//
//  Core capture engine for automated screenshot comparison with FPS '93 reference frames.
//  Uses SwiftUI ImageRenderer to render views to PNG files at /tmp/fps_screenshots/.
//

import SwiftUI
import AppKit

@MainActor
struct ScreenshotService {

    static let outputDirectory = "/tmp/fps_screenshots"
    nonisolated static let defaultSize = CGSize(width: 1280, height: 800)

    /// Ensure output directory exists
    static func prepareOutputDirectory() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: outputDirectory) {
            try fm.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
        }
    }

    /// Capture a SwiftUI view to a PNG file.
    /// Returns the full path of the saved file.
    @discardableResult
    static func captureView<V: View>(
        _ view: V,
        filename: String,
        size: CGSize = defaultSize
    ) throws -> String {
        try prepareOutputDirectory()

        let wrappedView = view
            .frame(width: size.width, height: size.height)
            .background(Color.black)
            .preferredColorScheme(.dark)

        let renderer = ImageRenderer(content: wrappedView)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = 2.0 // Retina

        guard let nsImage = renderer.nsImage else {
            throw ScreenshotError.renderFailed(filename)
        }

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw ScreenshotError.encodingFailed(filename)
        }

        let filePath = "\(outputDirectory)/\(filename)"
        try pngData.write(to: URL(fileURLWithPath: filePath))
        print("[Screenshot] Saved: \(filePath) (\(pngData.count / 1024)KB)")
        return filePath
    }
}

// MARK: - Errors

enum ScreenshotError: LocalizedError {
    case renderFailed(String)
    case encodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .renderFailed(let name): return "Failed to render view for \(name)"
        case .encodingFailed(let name): return "Failed to encode PNG for \(name)"
        }
    }
}
