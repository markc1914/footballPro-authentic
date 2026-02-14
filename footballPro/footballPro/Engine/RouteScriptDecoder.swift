import Foundation

// MARK: - Constants
/// Dimensions of the play grid
private let GRID_ROWS = 20
private let GRID_COLS = 18
/// Size of each cell record in bytes
private let CELL_SIZE = 6

// MARK: - Action Codes
/// Interpreted action codes from PRF 6-byte cells
enum ActionCode: UInt8, CustomStringConvertible {
    case zero       = 0x00
    case moveA      = 0x02
    case moveB      = 0x03
    case moveC      = 0x04
    case moveD      = 0x05
    case breakRoute = 0x0A // "BREAK" in Python script
    case cut        = 0x0C
    case posA       = 0x10 // Likely a position indicator
    case posB       = 0x13
    case special    = 0x16
    case hold       = 0x17
    case holdPlus1  = 0x18
    case deep       = 0x19
    case block      = 0x1A

    var description: String {
        switch self {
        case .zero: return "ZERO"
        case .moveA: return "MOVE_A"
        case .moveB: return "MOVE_B"
        case .moveC: return "MOVE_C"
        case .moveD: return "MOVE_D"
        case .breakRoute: return "BREAK"
        case .cut: return "CUT"
        case .posA: return "POS_A"
        case .posB: return "POS_B"
        case .special: return "SPECIAL"
        case .hold: return "HOLD"
        case .holdPlus1: return "HOLD+1"
        case .deep: return "DEEP"
        case .block: return "BLOCK"
        }
    }
}

// MARK: - RouteCell
/// Represents a single 6-byte cell record from the PRF data
struct RouteCell {
    let bytes: Data // Store the raw 6 bytes

    // Individual action and state bytes
    private var rawAction0: UInt8 { bytes[0] }
    private var rawState0: UInt8  { bytes[1] }
    private var rawAction1: UInt8 { bytes[2] }
    private var rawState1: UInt8  { bytes[3] }
    private var rawAction2: UInt8 { bytes[4] }
    private var rawState2: UInt8  { bytes[5] }

    // Convenience properties for action/state pairs
    var actionStatePair0: (action: ActionCode?, state: UInt8) { (ActionCode(rawValue: rawAction0), rawState0) }
    var actionStatePair1: (action: ActionCode?, state: UInt8) { (ActionCode(rawValue: rawAction1), rawState1) }
    var actionStatePair2: (action: ActionCode?, state: UInt8) { (ActionCode(rawValue: rawAction2), rawState2) }
    
    // Helper to get all actions in this cell
    var activeActions: [ActionCode] {
        var actions: [ActionCode] = []
        if let action = actionStatePair0.action, action != .zero, actionStatePair0.state == 0x0a { actions.append(action) }
        if let action = actionStatePair1.action, action != .zero, actionStatePair1.state == 0x0a { actions.append(action) }
        if let action = actionStatePair2.action, action != .zero, actionStatePair2.state == 0x0a { actions.append(action) }
        return actions
    }

    // A cell is considered active if any of its state bytes indicate activity (0x0a)
    var isActive: Bool {
        return rawState0 == 0x0a || rawState1 == 0x0a || rawState2 == 0x0a
    }

    init?(data: Data) {
        guard data.count == CELL_SIZE else { return nil }
        self.bytes = data
    }
}

// MARK: - RouteScriptDecoder
/// Decodes the raw script payload of a play into a grid of RouteCells.
/// The full semantic translation to PlayRoute objects will be implemented here.
struct RouteScriptDecoder {

    /// Known formation codes from the original game.
    enum Formation: UInt16 {
        case iForm = 0x8501
        case shotgun = 0x8505
        case specialTeams = 0x0101 // Added for special teams plays
        // Add other formations as they are analyzed
    }

    /// Extracts the 20x18 grid of 6-byte RouteCells for a specific play
    /// from the raw PRF data.
    static func extractPlayGrid(from prfData: Data, prfBaseOffset: Int, playIndex: Int) -> [[RouteCell]]? {
        guard playIndex >= 0 && playIndex < 7 else { return nil }

        var grid: [[RouteCell]] = []
        let recordsPerGroup = 7
        let groupSize = CELL_SIZE * recordsPerGroup

        for row in 0..<GRID_ROWS {
            var rowCells: [RouteCell] = []
            for col in 0..<GRID_COLS {
                let groupIndex = row * GRID_COLS + col
                let groupOffset = prfBaseOffset + groupIndex * groupSize
                let recordOffset = groupOffset + playIndex * CELL_SIZE

                guard recordOffset + CELL_SIZE <= prfData.count else {
                    print("Error: Attempted to read past PRF data bounds at offset \(recordOffset)")
                    return nil
                }

                let cellData = prfData.subdata(in: recordOffset..<(recordOffset + CELL_SIZE))
                if let cell = RouteCell(data: cellData) {
                    rowCells.append(cell)
                } else {
                    print("Error: Failed to create RouteCell from data at offset \(recordOffset)")
                    return nil
                }
            }
            grid.append(rowCells)
        }
        return grid
    }

    // A struct to hold the state of a player being tracked through the grid
    private struct TrackedPlayer {
        let position: PlayerPosition // Unique identifier for the player slot
        var currentGridPosition: (row: Int, col: Int) // Current (row, col)
        var path: [(row: Int, col: Int, cell: RouteCell)] = [] // Sequence of (coords, cell)
    }

    /// Decodes a 20x18 grid of RouteCells into a list of PlayRoute objects,
    /// considering the play's formation.
    static func decode(grid: [[RouteCell]], formationCode: UInt16) -> [PlayRoute] {
        guard grid.count == GRID_ROWS && grid.allSatisfy({ $0.count == GRID_COLS }) else {
            print("Error: Invalid grid dimensions for decoding.")
            return []
        }

        var trackedPlayers: [TrackedPlayer] = []
        let formationRow = 3

        // 1. Initial player identification and their starting positions from the first FORMATION row
        for col in 0..<GRID_COLS {
            let cell = grid[formationRow][col]
            if cell.isActive { // Check if the cell is active using the new property
                let action = cell.actionStatePair0.action // Use the first action for initial mapping
                let playerPosition = mapColumnToPlayerPosition(col, action, formationCode: formationCode)
                
                var player = TrackedPlayer(position: playerPosition, currentGridPosition: (formationRow, col))
                player.path.append((row: formationRow, col: col, cell: cell)) // Append the whole cell
                trackedPlayers.append(player)
            }
        }

        // 2. Trace routes for each identified player across all rows
        for row in 0..<GRID_ROWS {
            if [3, 7, 11, 15].contains(row) { continue } // Skip FORM rows

            var availableCellsInRow: [(col: Int, cell: RouteCell)] = []
            for col in 0..<GRID_COLS {
                let cell = grid[row][col]
                if cell.isActive { // Check if the cell is active using the new property
                    availableCellsInRow.append((col, cell))
                }
            }
            
            // For each tracked player, find the closest available active cell in the current row,
            // prioritizing movement direction.
            for playerIndex in 0..<trackedPlayers.count {
                var player = trackedPlayers[playerIndex]
                
                var bestMatchCol: Int? = nil
                var minDistance: Int = .max
                var matchedAvailableIndex: Int? = nil

                // Determine previous horizontal movement direction if available
                var previousDirection: HorizontalDirection = .straight
                if player.path.count >= 1 { // Need at least one step in path to infer direction
                    let lastPathStep = player.path.last!
                    if lastPathStep.col < player.currentGridPosition.col {
                        previousDirection = .left
                    } else if lastPathStep.col > player.currentGridPosition.col {
                        previousDirection = .right
                    } else {
                        previousDirection = .straight
                    }
                }

                // First pass: look for a cell in the same direction as previous movement
                var preferredMatches: [(col: Int, idx: Int)] = []
                for (idx, (col, _)) in availableCellsInRow.enumerated() {
                    let deltaCol = col - player.currentGridPosition.col

                    let isMovingLeft = (previousDirection == .left && deltaCol < 0)
                    let isMovingRight = (previousDirection == .right && deltaCol > 0)
                    let isMovingStraight = (previousDirection == .straight && deltaCol == 0)
                    
                    if isMovingLeft || isMovingRight || isMovingStraight {
                        preferredMatches.append((col, idx))
                    }
                }

                if !preferredMatches.isEmpty {
                    // Find the closest among preferred matches
                    for (col, idx) in preferredMatches {
                        let distance = abs(col - player.currentGridPosition.col)
                        if distance < minDistance {
                            minDistance = distance
                            bestMatchCol = col
                            matchedAvailableIndex = idx
                        }
                    }
                }
                
                // If no match in preferred direction, or if no previous direction / no preferred matches,
                // do a second pass considering all directions (current 'closest cell' logic)
                if bestMatchCol == nil {
                    minDistance = .max // Reset minDistance
                    for (idx, (col, _)) in availableCellsInRow.enumerated() {
                        let distance = abs(player.currentGridPosition.col - col)
                        if distance < minDistance {
                            minDistance = distance
                            bestMatchCol = col
                            matchedAvailableIndex = idx
                        }
                    }
                }
                
                if let matchedCol = bestMatchCol, let idx = matchedAvailableIndex {
                    let matchedCell = availableCellsInRow[idx].cell
                    player.currentGridPosition = (row, matchedCol)
                    player.path.append((row: row, col: matchedCol, cell: matchedCell)) // Append the whole cell
                    availableCellsInRow.remove(at: idx)
                }
                trackedPlayers[playerIndex] = player
            }
        }
        
        // 3. Convert tracked paths into PlayRoute objects by interpreting the action sequences.
        return trackedPlayers.compactMap { player in
            return interpretRoute(for: player)
        }
    }

    /// Interprets a player's sequence of actions (including coordinates and full cells) to determine the final PlayRoute.
    private static func interpretRoute(for player: TrackedPlayer) -> PlayRoute? {
        guard let initialPathStep = player.path.first,
              let lastPathStep = player.path.last else {
            // If a player has no recorded path (no actions), they might just be a static blocker.
            // Create a default blocking assignment for them.
            return PlayRoute(position: player.position, route: .passBlock, depth: 0)
        }

        // Collect all distinct active actions from all action-state pairs in the path
        var allActiveActions: [ActionCode] = []
        for step in player.path {
            allActiveActions.append(contentsOf: step.cell.activeActions)
        }
        
        var routeType: RouteType = .block // Default
        var routeDirection: RouteDirection = .straight // Default

        // --- High-level Route Type Inference ---
        // Prioritize blocking/holding
        if allActiveActions.contains(.block) || allActiveActions.contains(.hold) || allActiveActions.contains(.holdPlus1) {
            routeType = .passBlock // Assume run block is not explicitly encoded in these actions
        } else if allActiveActions.contains(.special) {
            routeType = .swing // Special actions could mean a swing or similar dynamic route
        } else if allActiveActions.contains(.cut) || allActiveActions.contains(.breakRoute) {
            // Check for deep cuts (e.g., Post, Corner) vs short cuts (e.g., Out)
            if allActiveActions.contains(.deep) || lastPathStep.row >= 12 { // Deeper phases (Phase 3+) often mean deeper routes
                // Determine if it's an inside (Post) or outside (Corner) cut based on overall horizontal movement
                let firstCol = initialPathStep.col
                let lastCol = lastPathStep.col
                if lastCol < firstCol { // Moved left relative to start
                    routeType = .corner // Assumes a corner route if moving outside
                } else if lastCol > firstCol { // Moved right relative to start
                    routeType = .post // Assumes a post route if moving inside
                } else {
                    routeType = .cut // Default cut if no clear lateral
                }
            } else {
                routeType = .out // Shorter cut
            }
        } else if allActiveActions.contains(.deep) {
            routeType = .fly // Straight deep route
        } else if allActiveActions.contains(where: { $0.rawValue >= ActionCode.moveA.rawValue && $0.rawValue <= ActionCode.moveD.rawValue }) {
            // Generic movement actions without specific cuts or deep indicators
            routeType = .fly // Consider it a straight route initially
        }
        
        // --- Depth Calculation ---
        let finalRow = lastPathStep.row
        let depthYards = (finalRow / 4) * 8 // Roughly 8 yards per phase, needs more fine-tuning

        // --- Direction Calculation (Horizontal Movement based on start/end of path) ---
        let firstCol = initialPathStep.col
        let lastCol = lastPathStep.col
        if lastCol < firstCol {
            routeDirection = .left
        } else if lastCol > firstCol {
            routeDirection = .right
        } else {
            routeDirection = .straight
        }
        
        return PlayRoute(position: player.position, route: routeType, depth: depthYards, direction: routeDirection)
    }

    // Add this helper enum inside RouteScriptDecoder
    private enum HorizontalDirection {
        case left, right, straight
    }

    /// Maps a grid column to a `PlayerPosition` based on the play's formation code.
    private static func mapColumnToPlayerPosition(_ column: Int, _ prfAction: ActionCode?, formationCode: UInt16) -> PlayerPosition {
        let formation = Formation(rawValue: formationCode)

        switch formation {
        case .iForm:
            switch column {
            case 3: return .leftTackle
            case 4: return .leftGuard
            case 5: return .center
            case 6: return .rightGuard
            case 7: return .rightTackle
            case 8: return .tightEnd
            case 9: return .quarterback
            case 10: return .fullback
            case 11: return .runningBack
            case 1, 14: return .wideReceiverLeft
            default: return .wideReceiverRight
            }
        case .shotgun:
            switch column {
            case 3: return .leftTackle
            case 4: return .leftGuard
            case 5: return .center
            case 6: return .rightGuard
            case 7: return .rightTackle
            case 9: return .quarterback
            case 10: return .runningBack
            case 1: return .wideReceiverLeft
            case 8: return .slotReceiver
            case 14: return .wideReceiverRight
            default: return .tightEnd
            }
        case .specialTeams:
            // Basic mapping for special teams. Many players are generic.
            // Note: PlayerPosition does not have "Kicker" or "Punter" yet. Using QB as placeholder.
            switch column {
            case 8, 9, 10: return .quarterback // Placeholder for Kicker, Holder, Long Snapper (center of formation)
            case 0, 17: return .wideReceiverLeft // Very wide players (returners or gunners). Using existing WR types for now.
            default: return .specialTeamsPlayer // Generic special teams player
            }
        default:
            switch column {
            case 0...2: return .wideReceiverLeft
            case 3: return .leftTackle
            case 4: return .leftGuard
            case 5: return .center
            case 6: return .rightGuard
            case 7: return .rightTackle
            case 8: return .tightEnd
            case 9, 10:
                return prfAction == .posA ? .quarterback : .runningBack
            case 11...15: return .wideReceiverRight
            default: return .slotReceiver
            }
        }
    }
}