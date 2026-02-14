//
//  ScreenshotCaptureWindow.swift
//  footballPro
//
//  Debug UI: "Capture All Screenshots" button with progress display.
//  Renders all FPS '93 screens to /tmp/fps_screenshots/ for visual comparison.
//

import SwiftUI

struct ScreenshotCaptureWindow: View {
    @Environment(\.dismiss) var dismiss

    @State private var isCapturing = false
    @State private var currentFile = ""
    @State private var currentIndex = 0
    @State private var totalCount = 20
    @State private var capturedCount: Int?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FPSDialog("SCREENSHOT CAPTURE") {
                VStack(spacing: 20) {
                    Text("Capture all game screens for\nside-by-side comparison with FPS '93")
                        .font(RetroFont.body())
                        .foregroundColor(VGA.lightGray)
                        .multilineTextAlignment(.center)

                    Text("Output: /tmp/fps_screenshots/")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.digitalAmber)

                    if isCapturing {
                        VStack(spacing: 8) {
                            ProgressView(value: Double(currentIndex), total: Double(totalCount))
                                .tint(VGA.digitalAmber)

                            Text("\(currentIndex)/\(totalCount): \(currentFile)")
                                .font(RetroFont.small())
                                .foregroundColor(VGA.white)
                        }
                    } else if let count = capturedCount {
                        VStack(spacing: 6) {
                            Text("COMPLETE")
                                .font(RetroFont.header())
                                .foregroundColor(VGA.green)

                            Text("\(count)/\(totalCount) screenshots saved")
                                .font(RetroFont.body())
                                .foregroundColor(VGA.white)
                        }
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(RetroFont.small())
                            .foregroundColor(VGA.brightRed)
                    }

                    HStack(spacing: 16) {
                        FPSButton("CAPTURE ALL") {
                            startCapture()
                        }
                        .opacity(isCapturing ? 0.5 : 1.0)

                        FPSButton("CLOSE") {
                            dismiss()
                        }
                    }
                }
                .padding(20)
            }
            .frame(width: 500, height: 320)
        }
    }

    private func startCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        capturedCount = nil
        errorMessage = nil

        Task {
            let count = await ScreenshotHarness.captureAll { index, total, filename in
                currentIndex = index
                totalCount = total
                currentFile = filename
            }
            capturedCount = count
            isCapturing = false
        }
    }
}
