//
//  PlayRoute.swift
//  footballPro
//
//  Defines receiver routes and player assignments for play diagrams
//

import Foundation
import SwiftUI

// MARK: - Route Type

public enum RouteType: String, Codable { // Public
    // Receiver routes
    case fly = "Fly"              // Straight downfield
    case post = "Post"            // 12 yards, cut 45° inside
    case corner = "Corner"        // 12 yards, cut 45° outside
    case out = "Out"              // 10 yards, cut 90° outside
    case slant = "Slant"          // 5 yards, cut 45° inside
    case curl = "Curl"            // 15 yards, turn back to QB
    case comeBack = "Comeback"    // 12 yards, turn back to QB
    case drag = "Drag"            // Horizontal route across field
    case flat = "Flat"            // Short route to sideline
    case hitch = "Hitch"          // 8 yards, stop and face QB
    case fade = "Fade"            // Deep route to sideline
    case wheel = "Wheel"          // Start inside, break outside deep
    case cut = "Cut"              // Generic cut, if specific type unknown (newly added)

    // Blocking assignments
    case block = "Block"
    case passBlock = "Pass Block"
    case runBlock = "Run Block"

    // Running back routes
    case swing = "Swing"          // Out to flat
    case angle = "Angle"          // Diagonal route
    case delay = "Delay"          // Delayed route after fake block

    // Special
    case motionLeft = "Motion Left"
    case motionRight = "Motion Right"
}

// MARK: - Play Route

public struct PlayRoute: Identifiable, Codable { // Public
    public let id: UUID
    public let position: PlayerPosition   // Which player runs this route
    public let route: RouteType
    public let depth: Int                 // Yards downfield
    public let direction: RouteDirection  // Left, right, or straight

    public init(position: PlayerPosition, route: RouteType, depth: Int = 10, direction: RouteDirection = .straight) {
        self.id = UUID()
        self.position = position
        self.route = route
        self.depth = depth
        self.direction = direction
    }
}

// MARK: - Player Position

public enum PlayerPosition: String, Codable { // Public
    case leftTackle = "LT"
    case leftGuard = "LG"
    case center = "C"
    case rightGuard = "RG"
    case rightTackle = "RT"
    case quarterback = "QB"
    case runningBack = "RB"
    case fullback = "FB"
    case wideReceiverLeft = "WR1"
    case wideReceiverRight = "WR2"
    case slotReceiver = "WR3"
    case tightEnd = "TE"
    // New: Special Teams Player
    case specialTeamsPlayer = "STP"
}

// MARK: - Route Direction

public enum RouteDirection: String, Codable { // Public
    case straight = "Straight"
    case left = "Left"
    case right = "Right"
    case inside = "Inside"
    case outside = "Outside"
}

// MARK: - Play Art

public struct PlayArt: Identifiable, Codable { // Public
    public let id: UUID
    public let playName: String
    public let playType: PlayType
    public let formation: OffensiveFormation
    public let routes: [PlayRoute]
    public let description: String
    public let expectedYards: Int

    public init(playName: String, playType: PlayType, formation: OffensiveFormation, routes: [PlayRoute], description: String, expectedYards: Int = 5) {
        self.id = UUID()
        self.playName = playName
        self.playType = playType
        self.formation = formation
        self.routes = routes
        self.description = description
        self.expectedYards = expectedYards
    }
}

// MARK: - Play Art Database

public class PlayArtDatabase { // Public
    public static let shared = PlayArtDatabase()

    private init() {}

    // MARK: - Pass Plays

    public var passingPlays: [PlayArt] {
        [
            // Four Verticals
            PlayArt(
                playName: "Four Verticals",
                playType: .deepPass,
                formation: .shotgun,
                routes: [
                    PlayRoute(position: .wideReceiverLeft, route: .fly, depth: 30, direction: .straight),
                    PlayRoute(position: .wideReceiverRight, route: .fly, depth: 30, direction: .straight),
                    PlayRoute(position: .slotReceiver, route: .post, depth: 25, direction: .inside),
                    PlayRoute(position: .tightEnd, route: .corner, depth: 20, direction: .outside),
                    PlayRoute(position: .runningBack, route: .block)
                ],
                description: "All receivers run deep routes stretching the defense vertically",
                expectedYards: 15
            ),

            // Slants
            PlayArt(
                playName: "Slants",
                playType: .shortPass,
                formation: .shotgun,
                routes: [
                    PlayRoute(position: .wideReceiverLeft, route: .slant, depth: 5, direction: .inside),
                    PlayRoute(position: .wideReceiverRight, route: .slant, depth: 5, direction: .inside),
                    PlayRoute(position: .slotReceiver, route: .slant, depth: 7, direction: .inside),
                    PlayRoute(position: .tightEnd, route: .flat, depth: 5, direction: .outside),
                    PlayRoute(position: .runningBack, route: .swing, depth: 3, direction: .outside)
                ],
                description: "Quick slant routes attacking the middle of the field",
                expectedYards: 6
            ),

            // Curl Flat
            PlayArt(
                playName: "Curl Flat",
                playType: .mediumPass,
                formation: .singleback,
                routes: [
                    PlayRoute(position: .wideReceiverLeft, route: .curl, depth: 15, direction: .straight),
                    PlayRoute(position: .wideReceiverRight, route: .curl, depth: 12, direction: .straight),
                    PlayRoute(position: .tightEnd, route: .flat, depth: 5, direction: .outside),
                    PlayRoute(position: .runningBack, route: .flat, depth: 5, direction: .left)
                ],
                description: "Receivers curl back to QB with flat routes underneath",
                expectedYards: 10
            ),

            // Post Corner
            PlayArt(
                playName: "Post Corner",
                playType: .deepPass,
                formation: .shotgun,
                routes: [
                    PlayRoute(position: .wideReceiverLeft, route: .post, depth: 20, direction: .inside),
                    PlayRoute(position: .wideReceiverRight, route: .corner, depth: 18, direction: .outside),
                    PlayRoute(position: .slotReceiver, route: .drag, depth: 8, direction: .right),
                    PlayRoute(position: .runningBack, route: .wheel, depth: 15, direction: .outside)
                ],
                description: "Deep post-corner combination to attack Cover 2",
                expectedYards: 18
            )
        ]
    }

    // MARK: - Run Plays

    public var runningPlays: [PlayArt] {
        [
            // Power Run
            PlayArt(
                playName: "Power Right",
                playType: .insideRun,
                formation: .singleback,
                routes: [
                    PlayRoute(position: .leftGuard, route: .runBlock),
                    PlayRoute(position: .rightGuard, route: .runBlock),
                    PlayRoute(position: .center, route: .runBlock),
                    PlayRoute(position: .fullback, route: .runBlock),
                    PlayRoute(position: .runningBack, route: .angle, depth: 5, direction: .right)
                ],
                description: "Power run behind pulling guard",
                expectedYards: 4
            ),

            // Sweep
            PlayArt(
                playName: "Sweep Left",
                playType: .outsideRun,
                formation: .iFormation,
                routes: [
                    PlayRoute(position: .leftTackle, route: .runBlock),
                    PlayRoute(position: .leftGuard, route: .runBlock),
                    PlayRoute(position: .runningBack, route: .flat, depth: 2, direction: .left)
                ],
                description: "Outside run to the edge",
                expectedYards: 5
            ),

            // Draw
            PlayArt(
                playName: "Draw",
                playType: .draw,
                formation: .shotgun,
                routes: [
                    PlayRoute(position: .runningBack, route: .delay, depth: 8, direction: .straight),
                    PlayRoute(position: .wideReceiverLeft, route: .fly, depth: 20, direction: .straight),
                    PlayRoute(position: .wideReceiverRight, route: .fly, depth: 20, direction: .straight)
                ],
                description: "Fake pass, delayed handoff to RB",
                expectedYards: 6
            )
        ]
    }

    // MARK: - Screen Plays

    public var screenPlays: [PlayArt] {
        [
            PlayArt(
                playName: "RB Screen",
                playType: .screen,
                formation: .shotgun,
                routes: [
                    PlayRoute(position: .runningBack, route: .swing, depth: 5, direction: .left),
                    PlayRoute(position: .wideReceiverLeft, route: .flat, depth: 3, direction: .left),
                    PlayRoute(position: .wideReceiverRight, route: .fly, depth: 25, direction: .straight)
                ],
                description: "Screen pass to RB behind blockers",
                expectedYards: 8
            )
        ]
    }

    // MARK: - Quick Select Plays (matched to GameDayView buttons)

    /// All plays indexed by their quick-select button name
    private lazy var quickSelectPlays: [String: PlayArt] = {
        var plays: [String: PlayArt] = [:]

        // RUNNING
        plays["HB Dive"] = PlayArt(
            playName: "HB Dive", playType: .insideRun, formation: .singleback,
            routes: [
                PlayRoute(position: .runningBack, route: .angle, depth: 4, direction: .straight),
                PlayRoute(position: .leftGuard, route: .runBlock),
                PlayRoute(position: .center, route: .runBlock),
                PlayRoute(position: .rightGuard, route: .runBlock)
            ],
            description: "Quick inside handoff between the tackles", expectedYards: 3
        )
        plays["HB Stretch"] = PlayArt(
            playName: "HB Stretch", playType: .outsideRun, formation: .singleback,
            routes: [
                PlayRoute(position: .runningBack, route: .flat, depth: 3, direction: .right),
                PlayRoute(position: .rightTackle, route: .runBlock),
                PlayRoute(position: .tightEnd, route: .runBlock)
            ],
            description: "Outside zone stretch to the edge", expectedYards: 5
        )
        plays["Power O"] = PlayArt(
            playName: "Power O", playType: .insideRun, formation: .iFormation,
            routes: [
                PlayRoute(position: .runningBack, route: .angle, depth: 5, direction: .right),
                PlayRoute(position: .fullback, route: .runBlock),
                PlayRoute(position: .leftGuard, route: .runBlock),
                PlayRoute(position: .rightGuard, route: .runBlock)
            ],
            description: "Power run behind pulling guard and lead blocker", expectedYards: 4
        )
        plays["Counter"] = PlayArt(
            playName: "Counter", playType: .insideRun, formation: .iFormation,
            routes: [
                PlayRoute(position: .runningBack, route: .angle, depth: 4, direction: .left),
                PlayRoute(position: .fullback, route: .runBlock),
                PlayRoute(position: .rightGuard, route: .runBlock)
            ],
            description: "Misdirection run opposite the flow", expectedYards: 5
        )
        plays["Sweep"] = PlayArt(
            playName: "Sweep", playType: .outsideRun, formation: .singleback,
            routes: [
                PlayRoute(position: .runningBack, route: .flat, depth: 2, direction: .left),
                PlayRoute(position: .leftTackle, route: .runBlock),
                PlayRoute(position: .leftGuard, route: .runBlock)
            ],
            description: "Outside run to the edge with pulling linemen", expectedYards: 5
        )
        plays["Draw"] = PlayArt(
            playName: "Draw", playType: .draw, formation: .shotgun,
            routes: [
                PlayRoute(position: .runningBack, route: .delay, depth: 8, direction: .straight),
                PlayRoute(position: .wideReceiverLeft, route: .fly, depth: 20, direction: .straight),
                PlayRoute(position: .wideReceiverRight, route: .fly, depth: 20, direction: .straight)
            ],
            description: "Fake pass, delayed handoff to RB", expectedYards: 6
        )
        plays["QB Sneak"] = PlayArt(
            playName: "QB Sneak", playType: .insideRun, formation: .singleback,
            routes: [
                PlayRoute(position: .quarterback, route: .angle, depth: 2, direction: .straight),
                PlayRoute(position: .center, route: .runBlock),
                PlayRoute(position: .leftGuard, route: .runBlock),
                PlayRoute(position: .rightGuard, route: .runBlock)
            ],
            description: "QB pushes forward behind the center", expectedYards: 1
        )
        plays["Scramble"] = PlayArt(
            playName: "Scramble", playType: .insideRun, formation: .shotgun,
            routes: [
                PlayRoute(position: .quarterback, route: .angle, depth: 6, direction: .right),
                PlayRoute(position: .wideReceiverLeft, route: .fly, depth: 15, direction: .straight),
                PlayRoute(position: .wideReceiverRight, route: .fly, depth: 15, direction: .straight)
            ],
            description: "QB scramble out of the pocket", expectedYards: 5
        )

        // SHORT PASS
        plays["Slant"] = PlayArt(
            playName: "Slant", playType: .shortPass, formation: .shotgun,
            routes: [
                PlayRoute(position: .wideReceiverLeft, route: .slant, depth: 5, direction: .inside),
                PlayRoute(position: .wideReceiverRight, route: .slant, depth: 5, direction: .inside),
                PlayRoute(position: .slotReceiver, route: .drag, depth: 6, direction: .right),
                PlayRoute(position: .tightEnd, route: .flat, depth: 5, direction: .outside),
                PlayRoute(position: .runningBack, route: .block)
            ],
            description: "Quick slant routes across the middle", expectedYards: 6
        )
        plays["Curl"] = PlayArt(
            playName: "Curl", playType: .shortPass, formation: .singleback,
            routes: [
                PlayRoute(position: .wideReceiverLeft, route: .curl, depth: 12, direction: .straight),
                PlayRoute(position: .wideReceiverRight, route: .curl, depth: 10, direction: .straight),
                PlayRoute(position: .tightEnd, route: .flat, depth: 5, direction: .outside),
                PlayRoute(position: .runningBack, route: .swing, depth: 3, direction: .left)
            ],
            description: "Receivers curl back toward the QB", expectedYards: 8
        )
        plays["Flat"] = PlayArt(
            playName: "Flat", playType: .shortPass, formation: .shotgun,
            routes: [
                PlayRoute(position: .runningBack, route: .flat, depth: 4, direction: .right),
                PlayRoute(position: .tightEnd, route: .flat, depth: 5, direction: .right),
                PlayRoute(position: .wideReceiverLeft, route: .slant, depth: 8, direction: .inside),
                PlayRoute(position: .wideReceiverRight, route: .hitch, depth: 6, direction: .straight)
            ],
            description: "Short flat routes to the sideline", expectedYards: 5
        )
        plays["Screen"] = PlayArt(
            playName: "Screen", playType: .screen, formation: .shotgun,
            routes: [
                PlayRoute(position: .runningBack, route: .swing, depth: 5, direction: .left),
                PlayRoute(position: .wideReceiverLeft, route: .flat, depth: 3, direction: .left),
                PlayRoute(position: .wideReceiverRight, route: .fly, depth: 25, direction: .straight)
            ],
            description: "Screen pass to RB behind blockers", expectedYards: 8
        )
        plays["Quick Out"] = PlayArt(
            playName: "Quick Out", playType: .shortPass, formation: .shotgun,
            routes: [
                PlayRoute(position: .wideReceiverLeft, route: .out, depth: 5, direction: .outside),
                PlayRoute(position: .wideReceiverRight, route: .out, depth: 5, direction: .outside),
                PlayRoute(position: .slotReceiver, route: .slant, depth: 6, direction: .inside),
                PlayRoute(position: .runningBack, route: .block)
            ],
            description: "Quick out routes to both sidelines", expectedYards: 5
        )

        // MED PASS
        plays["Dig"] = PlayArt(
            playName: "Dig", playType: .mediumPass, formation: .shotgun,
            routes: [
                PlayRoute(position: .wideReceiverLeft, route: .drag, depth: 12, direction: .right),
                PlayRoute(position: .wideReceiverRight, route: .curl, depth: 14, direction: .straight),
                PlayRoute(position: .slotReceiver, route: .post, depth: 10, direction: .inside),
                PlayRoute(position: .tightEnd, route: .flat, depth: 6, direction: .outside),
                PlayRoute(position: .runningBack, route: .block)
            ],
            description: "In-breaking dig route over the middle", expectedYards: 12
        )
        plays["Post"] = PlayArt(
            playName: "Post", playType: .mediumPass, formation: .shotgun,
            routes: [
                PlayRoute(position: .wideReceiverLeft, route: .post, depth: 15, direction: .inside),
                PlayRoute(position: .wideReceiverRight, route: .corner, depth: 12, direction: .outside),
                PlayRoute(position: .slotReceiver, route: .drag, depth: 8, direction: .right),
                PlayRoute(position: .runningBack, route: .swing, depth: 4, direction: .left)
            ],
            description: "Post route attacking the deep middle", expectedYards: 15
        )
        plays["Corner"] = PlayArt(
            playName: "Corner", playType: .mediumPass, formation: .shotgun,
            routes: [
                PlayRoute(position: .wideReceiverLeft, route: .corner, depth: 15, direction: .outside),
                PlayRoute(position: .wideReceiverRight, route: .post, depth: 12, direction: .inside),
                PlayRoute(position: .tightEnd, route: .curl, depth: 10, direction: .straight),
                PlayRoute(position: .runningBack, route: .block)
            ],
            description: "Corner route to the back pylon", expectedYards: 14
        )
        plays["Comeback"] = PlayArt(
            playName: "Comeback", playType: .mediumPass, formation: .shotgun,
            routes: [
                PlayRoute(position: .wideReceiverLeft, route: .comeBack, depth: 14, direction: .outside),
                PlayRoute(position: .wideReceiverRight, route: .comeBack, depth: 14, direction: .outside),
                PlayRoute(position: .slotReceiver, route: .slant, depth: 8, direction: .inside),
                PlayRoute(position: .runningBack, route: .flat, depth: 4, direction: .right)
            ],
            description: "Comeback routes to the sideline", expectedYards: 10
        )
        plays["Crosser"] = PlayArt(
            playName: "Crosser", playType: .mediumPass, formation: .shotgun,
            routes: [
                PlayRoute(position: .wideReceiverLeft, route: .drag, depth: 10, direction: .right),
                PlayRoute(position: .wideReceiverRight, route: .drag, depth: 12, direction: .left),
                PlayRoute(position: .slotReceiver, route: .post, depth: 15, direction: .inside),
                PlayRoute(position: .tightEnd, route: .flat, depth: 5, direction: .outside),
                PlayRoute(position: .runningBack, route: .block)
            ],
            description: "Crossing routes from both sides", expectedYards: 11
        )

        // DEEP PASS
        plays["Go Route"] = PlayArt(
            playName: "Go Route", playType: .deepPass, formation: .shotgun,
            routes: [
                PlayRoute(position: .wideReceiverLeft, route: .fly, depth: 30, direction: .straight),
                PlayRoute(position: .wideReceiverRight, route: .fly, depth: 30, direction: .straight),
                PlayRoute(position: .slotReceiver, route: .post, depth: 20, direction: .inside),
                PlayRoute(position: .runningBack, route: .block)
            ],
            description: "Receivers run straight downfield", expectedYards: 20
        )
        plays["Seam"] = PlayArt(
            playName: "Seam", playType: .deepPass, formation: .shotgun,
            routes: [
                PlayRoute(position: .tightEnd, route: .fly, depth: 25, direction: .straight),
                PlayRoute(position: .slotReceiver, route: .fly, depth: 22, direction: .straight),
                PlayRoute(position: .wideReceiverLeft, route: .post, depth: 18, direction: .inside),
                PlayRoute(position: .wideReceiverRight, route: .corner, depth: 18, direction: .outside),
                PlayRoute(position: .runningBack, route: .block)
            ],
            description: "Seam routes splitting the safeties", expectedYards: 18
        )
        plays["Play Action"] = PlayArt(
            playName: "Play Action", playType: .deepPass, formation: .singleback,
            routes: [
                PlayRoute(position: .wideReceiverLeft, route: .post, depth: 20, direction: .inside),
                PlayRoute(position: .wideReceiverRight, route: .corner, depth: 18, direction: .outside),
                PlayRoute(position: .tightEnd, route: .drag, depth: 12, direction: .right),
                PlayRoute(position: .runningBack, route: .angle, depth: 3, direction: .right)
            ],
            description: "Fake handoff, deep pass downfield", expectedYards: 15
        )
        plays["Bootleg"] = PlayArt(
            playName: "Bootleg", playType: .mediumPass, formation: .singleback,
            routes: [
                PlayRoute(position: .quarterback, route: .flat, depth: 5, direction: .right),
                PlayRoute(position: .tightEnd, route: .flat, depth: 8, direction: .right),
                PlayRoute(position: .wideReceiverRight, route: .corner, depth: 15, direction: .outside),
                PlayRoute(position: .wideReceiverLeft, route: .drag, depth: 10, direction: .right),
                PlayRoute(position: .runningBack, route: .angle, depth: 3, direction: .left)
            ],
            description: "QB rolls out with multiple options", expectedYards: 10
        )
        plays["Hail Mary"] = PlayArt(
            playName: "Hail Mary", playType: .deepPass, formation: .shotgun,
            routes: [
                PlayRoute(position: .wideReceiverLeft, route: .fly, depth: 40, direction: .straight),
                PlayRoute(position: .wideReceiverRight, route: .fly, depth: 40, direction: .straight),
                PlayRoute(position: .slotReceiver, route: .fly, depth: 38, direction: .straight),
                PlayRoute(position: .tightEnd, route: .fly, depth: 35, direction: .straight),
                PlayRoute(position: .runningBack, route: .block)
            ],
            description: "All receivers go deep — last resort!", expectedYards: 30
        )

        return plays
    }()

    /// Look up play art by the quick-select button name
    public func playArtForQuickSelect(_ name: String) -> PlayArt? {
        return quickSelectPlays[name]
    }

    // MARK: - Get Play Art

    public func getPlayArt(for playType: PlayType) -> [PlayArt] {
        switch playType {
        case .shortPass, .mediumPass, .deepPass, .playAction:
            return passingPlays
        case .insideRun, .outsideRun, .draw, .counter, .sweep, .qbSneak:
            return runningPlays
        case .screen:
            return screenPlays
        default:
            return []
        }
    }

    public func randomPlay(for playType: PlayType) -> PlayArt? {
        getPlayArt(for: playType).randomElement()
    }
}