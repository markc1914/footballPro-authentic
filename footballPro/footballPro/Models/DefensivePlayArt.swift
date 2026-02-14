//
//  DefensivePlayArt.swift
//  footballPro
//
//  Defensive formations, coverages, and play diagrams
//

import Foundation
import SwiftUI

// MARK: - Defensive Assignment

public enum DefensiveAssignment: String, Codable { // Public
    // Coverage assignments
    case manCoverage = "Man Coverage"
    case zoneCoverage = "Zone Coverage"
    case deepThird = "Deep Third"
    case deepHalf = "Deep Half"
    case flatZone = "Flat Zone"
    case hookZone = "Hook Zone"

    // Rush assignments
    case passRush = "Pass Rush"
    case containRush = "Contain Rush"
    case spyQB = "Spy QB"

    // Run assignments
    case runGap = "Run Gap"
    case edgeContain = "Edge Contain"
    case pursuitAngle = "Pursuit"

    // Blitz
    case blitz = "Blitz"
    case delayed = "Delayed Blitz"
}

// MARK: - Defensive Player Position

public enum DefensivePlayerPosition: String, Codable { // Public
    // Defensive line
    case leftEnd = "LE"
    case leftTackle = "LDT"
    case noseTackle = "NT"
    case rightTackle = "RDT"
    case rightEnd = "RE"

    // Linebackers
    case samLB = "SAM"
    case mikeLB = "MIKE"
    case willLB = "WILL"
    case outsideLB = "OLB"

    // Secondary
    case leftCorner = "LCB"
    case rightCorner = "RCB"
    case slotCorner = "SCB"
    case freeSafety = "FS"
    case strongSafety = "SS"
}

// MARK: - Defensive Route

public struct DefensiveRoute: Identifiable, Codable { // Public
    public let id: UUID
    public let position: DefensivePlayerPosition
    public let assignment: DefensiveAssignment
    public let depth: Int  // Yards from LOS
    public let side: DefensiveSide

    public init(position: DefensivePlayerPosition, assignment: DefensiveAssignment, depth: Int = 5, side: DefensiveSide = .middle) {
        self.id = UUID()
        self.position = position
        self.assignment = assignment
        self.depth = depth
        self.side = side
    }
}

// MARK: - Defensive Side

public enum DefensiveSide: String, Codable { // Public
    case left = "Left"
    case middle = "Middle"
    case right = "Right"
}

// MARK: - Defensive Play Art

public struct DefensivePlayArt: Identifiable, Codable { // Public
    public let id: UUID
    public let playName: String
    public let formation: DefensiveFormation
    public let coverage: String
    public let assignments: [DefensiveRoute]
    public let description: String
    public let blitzCount: Int

    public init(playName: String, formation: DefensiveFormation, coverage: String, assignments: [DefensiveRoute], description: String, blitzCount: Int = 0) {
        self.id = UUID()
        self.playName = playName
        self.formation = formation
        self.coverage = coverage
        self.assignments = assignments
        self.description = description
        self.blitzCount = blitzCount
    }
}

// MARK: - Defensive Play Art Database

public class DefensivePlayArtDatabase { // Public
    public static let shared = DefensivePlayArtDatabase()

    private init() {}

    // MARK: - Base Defenses (4-3)

    public var fourThreePlays: [DefensivePlayArt] {
        [
            DefensivePlayArt(
                playName: "Cover 2",
                formation: .base43,
                coverage: "2 Deep Safeties",
                assignments: [
                    DefensiveRoute(position: .leftEnd, assignment: .passRush, depth: 0, side: .left),
                    DefensiveRoute(position: .leftTackle, assignment: .passRush, depth: 0, side: .left),
                    DefensiveRoute(position: .rightTackle, assignment: .passRush, depth: 0, side: .right),
                    DefensiveRoute(position: .rightEnd, assignment: .passRush, depth: 0, side: .right),
                    DefensiveRoute(position: .samLB, assignment: .flatZone, depth: 5, side: .left),
                    DefensiveRoute(position: .mikeLB, assignment: .hookZone, depth: 10, side: .middle),
                    DefensiveRoute(position: .willLB, assignment: .flatZone, depth: 5, side: .right),
                    DefensiveRoute(position: .leftCorner, assignment: .flatZone, depth: 5, side: .left),
                    DefensiveRoute(position: .rightCorner, assignment: .flatZone, depth: 5, side: .right),
                    DefensiveRoute(position: .freeSafety, assignment: .deepHalf, depth: 20, side: .left),
                    DefensiveRoute(position: .strongSafety, assignment: .deepHalf, depth: 20, side: .right)
                ],
                description: "2 deep safeties split the field, corners play flat zones",
                blitzCount: 0
            ),

            DefensivePlayArt(
                playName: "Cover 3",
                formation: .base43,
                coverage: "3 Deep Zones",
                assignments: [
                    DefensiveRoute(position: .leftEnd, assignment: .passRush, depth: 0, side: .left),
                    DefensiveRoute(position: .leftTackle, assignment: .passRush, depth: 0, side: .left),
                    DefensiveRoute(position: .rightTackle, assignment: .passRush, depth: 0, side: .right),
                    DefensiveRoute(position: .rightEnd, assignment: .passRush, depth: 0, side: .right),
                    DefensiveRoute(position: .samLB, assignment: .flatZone, depth: 5, side: .left),
                    DefensiveRoute(position: .mikeLB, assignment: .hookZone, depth: 10, side: .middle),
                    DefensiveRoute(position: .willLB, assignment: .flatZone, depth: 5, side: .right),
                    DefensiveRoute(position: .leftCorner, assignment: .deepThird, depth: 20, side: .left),
                    DefensiveRoute(position: .rightCorner, assignment: .deepThird, depth: 20, side: .right),
                    DefensiveRoute(position: .freeSafety, assignment: .deepThird, depth: 20, side: .middle),
                    DefensiveRoute(position: .strongSafety, assignment: .hookZone, depth: 10, side: .middle)
                ],
                description: "3 deep zones (corners + safety), excellent run support",
                blitzCount: 0
            ),

            DefensivePlayArt(
                playName: "Cover 1 Blitz",
                formation: .base43,
                coverage: "Man + 1 Deep Safety",
                assignments: [
                    DefensiveRoute(position: .leftEnd, assignment: .passRush, depth: 0, side: .left),
                    DefensiveRoute(position: .leftTackle, assignment: .passRush, depth: 0, side: .left),
                    DefensiveRoute(position: .rightTackle, assignment: .passRush, depth: 0, side: .right),
                    DefensiveRoute(position: .rightEnd, assignment: .passRush, depth: 0, side: .right),
                    DefensiveRoute(position: .samLB, assignment: .blitz, depth: 0, side: .left),
                    DefensiveRoute(position: .mikeLB, assignment: .blitz, depth: 0, side: .middle),
                    DefensiveRoute(position: .willLB, assignment: .manCoverage, depth: 10, side: .right),
                    DefensiveRoute(position: .leftCorner, assignment: .manCoverage, depth: 15, side: .left),
                    DefensiveRoute(position: .rightCorner, assignment: .manCoverage, depth: 15, side: .right),
                    DefensiveRoute(position: .freeSafety, assignment: .deepHalf, depth: 25, side: .middle),
                    DefensiveRoute(position: .strongSafety, assignment: .manCoverage, depth: 10, side: .middle)
                ],
                description: "Aggressive man coverage with 2 LB blitz",
                blitzCount: 2
            )
        ]
    }

    // MARK: - Nickel Defenses

    public var nickelPlays: [DefensivePlayArt] {
        [
            DefensivePlayArt(
                playName: "Nickel Cover 2",
                formation: .nickel,
                coverage: "2 Deep Safeties",
                assignments: [
                    DefensiveRoute(position: .leftEnd, assignment: .passRush, depth: 0, side: .left),
                    DefensiveRoute(position: .leftTackle, assignment: .passRush, depth: 0, side: .left),
                    DefensiveRoute(position: .rightTackle, assignment: .passRush, depth: 0, side: .right),
                    DefensiveRoute(position: .rightEnd, assignment: .passRush, depth: 0, side: .right),
                    DefensiveRoute(position: .mikeLB, assignment: .hookZone, depth: 10, side: .middle),
                    DefensiveRoute(position: .willLB, assignment: .hookZone, depth: 10, side: .middle),
                    DefensiveRoute(position: .leftCorner, assignment: .flatZone, depth: 5, side: .left),
                    DefensiveRoute(position: .rightCorner, assignment: .flatZone, depth: 5, side: .right),
                    DefensiveRoute(position: .slotCorner, assignment: .flatZone, depth: 5, side: .middle),
                    DefensiveRoute(position: .freeSafety, assignment: .deepHalf, depth: 20, side: .left),
                    DefensiveRoute(position: .strongSafety, assignment: .deepHalf, depth: 20, side: .right)
                ],
                description: "Nickel package with 5 DBs, good against pass",
                blitzCount: 0
            )
        ]
    }

    // MARK: - Get Defensive Plays

    public func getDefensivePlays(for formation: DefensiveFormation) -> [DefensivePlayArt] {
        switch formation {
        case .base43:
            return fourThreePlays
        case .base34:
            return fourThreePlays  // Reuse for now
        case .nickel:
            return nickelPlays
        case .dime:
            return nickelPlays  // Reuse for now
        case .goalLine, .prevent:
            return fourThreePlays  // Reuse for now
        }
    }

    public func randomDefensivePlay(for formation: DefensiveFormation) -> DefensivePlayArt? {
        getDefensivePlays(for: formation).randomElement()
    }
}