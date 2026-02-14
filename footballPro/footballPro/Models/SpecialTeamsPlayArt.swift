//
//  SpecialTeamsPlayArt.swift
//  footballPro
//
//  Special teams formations and play diagrams
//

import Foundation
import SwiftUI

// MARK: - Special Teams Type

enum SpecialTeamsType: String, Codable {
    case punt = "Punt"
    case fieldGoal = "Field Goal"
    case kickoff = "Kickoff"
    case puntReturn = "Punt Return"
    case kickoffReturn = "Kickoff Return"
    case fieldGoalBlock = "FG Block"
}

// MARK: - Special Teams Position

enum SpecialTeamsPosition: String, Codable {
    // Kicking team
    case kicker = "K"
    case punter = "P"
    case holder = "H"
    case longSnapper = "LS"
    case gunner = "G"
    case upback = "UB"
    case wing = "W"

    // Return team
    case returner = "R"
    case viceroy = "V"
    case jammer = "J"
}

// MARK: - Special Teams Assignment

enum SpecialTeamsAssignment: String, Codable {
    case kick = "Kick"
    case snap = "Snap"
    case hold = "Hold"
    case protect = "Protect"
    case coverage = "Coverage"
    case contain = "Contain"
    case rush = "Rush"
    case returnBlock = "Return Block"
    case returnBall = "Return Ball"
}

// MARK: - Special Teams Route

struct SpecialTeamsRoute: Identifiable, Codable {
    let id: UUID
    let position: SpecialTeamsPosition
    let assignment: SpecialTeamsAssignment
    let side: String

    init(position: SpecialTeamsPosition, assignment: SpecialTeamsAssignment, side: String = "middle") {
        self.id = UUID()
        self.position = position
        self.assignment = assignment
        self.side = side
    }
}

// MARK: - Special Teams Play Art

struct SpecialTeamsPlayArt: Identifiable, Codable {
    let id: UUID
    let playName: String
    let type: SpecialTeamsType
    let assignments: [SpecialTeamsRoute]
    let description: String

    init(playName: String, type: SpecialTeamsType, assignments: [SpecialTeamsRoute], description: String) {
        self.id = UUID()
        self.playName = playName
        self.type = type
        self.assignments = assignments
        self.description = description
    }
}

// MARK: - Special Teams Database

class SpecialTeamsPlayArtDatabase {
    static let shared = SpecialTeamsPlayArtDatabase()

    private init() {}

    // MARK: - Punt Plays

    var puntPlays: [SpecialTeamsPlayArt] {
        [
            SpecialTeamsPlayArt(
                playName: "Standard Punt",
                type: .punt,
                assignments: [
                    SpecialTeamsRoute(position: .punter, assignment: .kick, side: "middle"),
                    SpecialTeamsRoute(position: .longSnapper, assignment: .snap, side: "middle"),
                    SpecialTeamsRoute(position: .gunner, assignment: .coverage, side: "left"),
                    SpecialTeamsRoute(position: .gunner, assignment: .coverage, side: "right"),
                    SpecialTeamsRoute(position: .wing, assignment: .protect, side: "left"),
                    SpecialTeamsRoute(position: .wing, assignment: .protect, side: "right")
                ],
                description: "Standard punt formation with 2 gunners for coverage"
            ),

            SpecialTeamsPlayArt(
                playName: "Directional Punt",
                type: .punt,
                assignments: [
                    SpecialTeamsRoute(position: .punter, assignment: .kick, side: "right"),
                    SpecialTeamsRoute(position: .longSnapper, assignment: .snap, side: "middle"),
                    SpecialTeamsRoute(position: .gunner, assignment: .coverage, side: "right"),
                    SpecialTeamsRoute(position: .gunner, assignment: .coverage, side: "right")
                ],
                description: "Punt aimed toward sideline to limit return"
            )
        ]
    }

    // MARK: - Field Goal Plays

    var fieldGoalPlays: [SpecialTeamsPlayArt] {
        [
            SpecialTeamsPlayArt(
                playName: "Field Goal",
                type: .fieldGoal,
                assignments: [
                    SpecialTeamsRoute(position: .kicker, assignment: .kick, side: "middle"),
                    SpecialTeamsRoute(position: .holder, assignment: .hold, side: "middle"),
                    SpecialTeamsRoute(position: .longSnapper, assignment: .snap, side: "middle"),
                    SpecialTeamsRoute(position: .wing, assignment: .protect, side: "left"),
                    SpecialTeamsRoute(position: .wing, assignment: .protect, side: "right")
                ],
                description: "Standard field goal attempt"
            )
        ]
    }

    // MARK: - Kickoff Plays

    var kickoffPlays: [SpecialTeamsPlayArt] {
        [
            SpecialTeamsPlayArt(
                playName: "Deep Kickoff",
                type: .kickoff,
                assignments: [
                    SpecialTeamsRoute(position: .kicker, assignment: .kick, side: "middle"),
                    SpecialTeamsRoute(position: .wing, assignment: .coverage, side: "left"),
                    SpecialTeamsRoute(position: .wing, assignment: .coverage, side: "right")
                ],
                description: "Kick deep into end zone for touchback or coverage"
            ),

            SpecialTeamsPlayArt(
                playName: "Onside Kick",
                type: .kickoff,
                assignments: [
                    SpecialTeamsRoute(position: .kicker, assignment: .kick, side: "right"),
                    SpecialTeamsRoute(position: .wing, assignment: .coverage, side: "right")
                ],
                description: "Short kick attempt to recover possession"
            )
        ]
    }

    // MARK: - Return Plays

    var puntReturnPlays: [SpecialTeamsPlayArt] {
        [
            SpecialTeamsPlayArt(
                playName: "Middle Return",
                type: .puntReturn,
                assignments: [
                    SpecialTeamsRoute(position: .returner, assignment: .returnBall, side: "middle"),
                    SpecialTeamsRoute(position: .viceroy, assignment: .returnBlock, side: "left"),
                    SpecialTeamsRoute(position: .viceroy, assignment: .returnBlock, side: "right")
                ],
                description: "Return up the middle with wall blocking"
            ),

            SpecialTeamsPlayArt(
                playName: "Fair Catch",
                type: .puntReturn,
                assignments: [
                    SpecialTeamsRoute(position: .returner, assignment: .returnBall, side: "middle")
                ],
                description: "Signal fair catch, no return"
            )
        ]
    }

    var kickoffReturnPlays: [SpecialTeamsPlayArt] {
        [
            SpecialTeamsPlayArt(
                playName: "Middle Return",
                type: .kickoffReturn,
                assignments: [
                    SpecialTeamsRoute(position: .returner, assignment: .returnBall, side: "middle"),
                    SpecialTeamsRoute(position: .viceroy, assignment: .returnBlock, side: "left"),
                    SpecialTeamsRoute(position: .viceroy, assignment: .returnBlock, side: "right")
                ],
                description: "Return up the middle behind blockers"
            )
        ]
    }

    // MARK: - Get Special Teams Plays

    func getSpecialTeamsPlays(for type: SpecialTeamsType) -> [SpecialTeamsPlayArt] {
        switch type {
        case .punt:
            return puntPlays
        case .fieldGoal:
            return fieldGoalPlays
        case .kickoff:
            return kickoffPlays
        case .puntReturn:
            return puntReturnPlays
        case .kickoffReturn:
            return kickoffReturnPlays
        case .fieldGoalBlock:
            return []  // TODO: Add block plays
        }
    }
}
