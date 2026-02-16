import XCTest
@testable import footballPro

final class ScreenshotHarnessTests: XCTestCase {
    /// Capture all reference screens to /tmp/fps_screenshots.
    func testCaptureAllScreens() async throws {
        let count = await ScreenshotHarness.captureAll()
        XCTAssertGreaterThan(count, 0, "ScreenshotHarness should capture at least one screenshot")
    }
}
