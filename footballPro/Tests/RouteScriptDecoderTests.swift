import XCTest
import Foundation
@testable import footballPro // This imports the main module where RouteScriptDecoder resides

class RouteScriptDecoderTests: XCTestCase {

    // Helper to get the URL for the FBPRO_ORIGINAL directory
    private func getFBPROOriginalURL() throws -> URL {
        // Try to locate FBPRO_ORIGINAL relative to the project root,
        // as it's not typically bundled with the test target directly in Xcode
        // and its location has been consistently referenced.
        let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fbproOriginalPath = projectRoot
            .appendingPathComponent("footballPro")
            .appendingPathComponent("FBPRO_ORIGINAL")
        
        if FileManager.default.fileExists(atPath: fbproOriginalPath.path) {
            return fbproOriginalPath
        }

        // Fallback: If for some reason the above doesn't work (e.g. current directory changes)
        // This hardcoded path comes from the initial folder structure and other markdown files.
        let absolutePathFromContext = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")
        if FileManager.default.fileExists(atPath: absolutePathFromContext.path) {
            return absolutePathFromContext
        }

        XCTFail("Could not find FBPRO_ORIGINAL directory. Please ensure it exists at the expected location: \(fbproOriginalPath.path) or \(absolutePathFromContext.path)")
        
        // This line is needed to satisfy the compiler, but XCTFail will stop execution
        throw XCTTestError.resourceNotFound 
    }
    
    // Custom error for resource not found
    enum XCTTestError: Error {
        case resourceNotFound
    }


    func testExtractPlayGrid() throws {
        let fbproOriginalURL = try getFBPROOriginalURL()
        let off1PrfURL = fbproOriginalURL.appendingPathComponent("OFF1.PRF")

        XCTAssertTrue(FileManager.default.fileExists(atPath: off1PrfURL.path), "OFF1.PRF file should exist at \(off1PrfURL.path)")

        let prfData = try Data(contentsOf: off1PrfURL)
        let prfBaseOffset = 0x28 // As identified in decode_prf.py in the header

        // Test for each of the 7 plays in the PRF file
        for playIndex in 0..<7 {
            let grid = RouteScriptDecoder.extractPlayGrid(from: prfData, prfBaseOffset: prfBaseOffset, playIndex: playIndex)

            XCTAssertNotNil(grid, "Grid should not be nil for play index \(playIndex)")
            XCTAssertEqual(grid?.count, 20, "Grid should have 20 rows for play index \(playIndex)")
            XCTAssertEqual(grid?.first?.count, 18, "Grid rows should have 18 columns for play index \(playIndex)")
        }
    }

    func testDecodeWithFormation() throws {
        let fbproOriginalURL = try getFBPROOriginalURL()
        let off1PrfURL = fbproOriginalURL.appendingPathComponent("OFF1.PRF")
        let prfData = try Data(contentsOf: off1PrfURL)
        let prfBaseOffset = 0x28

        // Extract grid for the first play (index 0)
        guard let grid = RouteScriptDecoder.extractPlayGrid(from: prfData, prfBaseOffset: prfBaseOffset, playIndex: 0) else {
            XCTFail("Failed to extract play grid for test.")
            return
        }

        // Decode the grid using a known formation code for testing (e.g., I-Form)
        let iFormFormationCode: UInt16 = 0x8501
        let playRoutes = RouteScriptDecoder.decode(grid: grid, formationCode: iFormFormationCode)

        // Assert that the decoder produced some routes.
        // The verbose output for play 0 showed 4 active columns, but the logic might find more or less.
        // A simple, non-empty check is a good starting point.
        XCTAssertFalse(playRoutes.isEmpty, "The decode function should produce PlayRoute objects.")

        // We could also check if we got roughly the expected number of players.
        // The logic identifies players with state 0x0a in the formation row.
        // From the verbose log, we can count these. For Play 0, Row 3:
        // Cols 0, 1, 2, 5 have state 0x0a. That's 4 players.
        // Our logic should identify these. Let's assert that.
        XCTAssertEqual(playRoutes.count, 4, "Should identify 4 active players for Play 0 in OFF1.PRF")
    }
}
