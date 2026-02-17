//
//  PlayResolver.swift
//  footballPro
//
//  Resolves play outcomes based on matchups and ratings.
//  Uses authentic STOCK.DAT play routes when available for route-based
//  resolution (blocking matchups, receiver separation, QB reads).
//  Falls back to dice-roll resolution when game files are missing.
//

import Foundation
import CoreGraphics

class PlayResolver {

    /// Fatigue context passed from the game state for rating adjustments
    struct FatigueContext {
        let snapCounts: [UUID: Int]

        /// Calculate fatigue penalty for a player: 0 (fresh) to -10 (exhausted)
        func penalty(for player: Player) -> Int {
            let snaps = snapCounts[player.id] ?? 0
            let threshold = 15 + (player.ratings.stamina - 60) / 10
            guard snaps > threshold else { return 0 }
            return min(10, 3 + (snaps - threshold))
        }

        /// Apply fatigue to a physical rating value
        func adjustedRating(_ rating: Int, for player: Player) -> Int {
            return max(1, rating - penalty(for: player))
        }

        static let none = FatigueContext(snapCounts: [:])
    }

    // MARK: - Route-Based Resolution Data

    /// A receiver option evaluated from STOCK.DAT route data
    private struct ReceiverOption {
        let player: Player
        let routeDepth: CGFloat        // How far downfield (yards)
        let separation: Double          // 0-100 separation score
        let routeType: RouteCategory    // Quick, medium, deep
        let isCheckdown: Bool           // Short safety valve
        let matchedDefender: Player?    // Who's covering them
    }

    /// Categorize routes by depth for QB read logic
    private enum RouteCategory {
        case quick       // < 5 yards (slants, drags, flats)
        case short       // 5-10 yards (curls, outs, hitches)
        case medium      // 10-20 yards (comebacks, posts, corners)
        case deep        // 20+ yards (fly, deep post, fade)

        var accuracyBase: Double {
            switch self {
            case .quick:  return 0.82
            case .short:  return 0.72
            case .medium: return 0.60
            case .deep:   return 0.42
            }
        }
    }

    /// Result of evaluating the offensive line vs defensive front
    private struct TrenchResult {
        let blocksWon: Int             // How many OL won their matchup (0-5)
        let passRushPressure: Double   // 0-1 pressure level
        let timeInPocket: Double       // Seconds before pressure arrives
    }

    // MARK: - Main Resolution

    func resolvePlay(
        offensiveCall: any PlayCall,
        defensiveCall: any DefensiveCall,
        offensiveTeam: Team,
        defensiveTeam: Team,
        fieldPosition: FieldPosition,
        downAndDistance: DownAndDistance,
        weather: Weather,
        isHomePossession: Bool = false,
        fatigue: FatigueContext = .none,
        gameWeather: GameWeather? = nil
    ) -> PlayOutcome {

        // Check for penalty first (5% chance)
        if Double.random(in: 0...1) < 0.05 {
            return resolvePenalty()
        }

        switch offensiveCall.playType {
        case .kneel:
            return resolveKneel(offensiveTeam: offensiveTeam)

        case .spike:
            return resolveSpike(offensiveTeam: offensiveTeam)

        case _ where offensiveCall.playType.isRun:
            return resolveRun(
                playType: offensiveCall.playType,
                offensiveTeam: offensiveTeam,
                defensiveTeam: defensiveTeam,
                defensiveFormation: defensiveCall.formation,
                fieldPosition: fieldPosition,
                isHomePossession: isHomePossession,
                fatigue: fatigue,
                gameWeather: gameWeather
            )

        case _ where offensiveCall.playType.isPass:
            return resolvePass(
                playType: offensiveCall.playType,
                offensiveTeam: offensiveTeam,
                defensiveTeam: defensiveTeam,
                defensiveCall: defensiveCall,
                fieldPosition: fieldPosition,
                weather: weather,
                isHomePossession: isHomePossession,
                fatigue: fatigue,
                gameWeather: gameWeather
            )

        default:
            return PlayOutcome.incomplete()
        }
    }

    // MARK: - STOCK.DAT Route Lookup

    /// Find a matching STOCK.DAT play for the given play type
    private func findStockPlay(playType: PlayType) -> StockPlay? {
        guard let db = StockDATDecoder.shared else { return nil }

        switch playType {
        case _ where playType.isRun:
            let candidates = db.offensivePlays.filter { play in
                let n = play.name.uppercased()
                return n.contains("RM") || n.contains("RR") || n.contains("RL") ||
                       n.contains("RUN") || n.contains("DIVE") || n.contains("SWP") ||
                       n.contains("SWEEP") || n.contains("DRAW") || n.contains("FBD")
            }
            return candidates.isEmpty ? db.randomOffensivePlay() : candidates.randomElement()

        case .shortPass, .mediumPass, .screen:
            let candidates = db.offensivePlays.filter { play in
                let n = play.name.uppercased()
                return n.contains("PS") || n.contains("PML") || n.contains("PMR") ||
                       n.contains("PMM") || n.contains("PSL") || n.contains("PSR") ||
                       n.contains("PSM") || n.contains("PASS")
            }
            return candidates.isEmpty ? db.randomOffensivePlay() : candidates.randomElement()

        case .deepPass, .playAction:
            let candidates = db.offensivePlays.filter { play in
                let n = play.name.uppercased()
                return n.contains("PLR") || n.contains("PLL") || n.contains("PLM") ||
                       n.contains("DEEP") || n.contains("LONG") || n.contains("PSR")
            }
            return candidates.isEmpty ? db.randomOffensivePlay() : candidates.randomElement()

        default:
            return db.randomOffensivePlay()
        }
    }

    /// Find a matching STOCK.DAT defensive play
    private func findStockDefensivePlay(defensiveFormation: DefensiveFormation) -> StockPlay? {
        guard let db = StockDATDecoder.shared else { return nil }

        let formName = defensiveFormation.rawValue.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        let candidates = db.defensivePlays.filter { play in
            play.name.uppercased().contains(formName)
        }
        return candidates.isEmpty ? db.randomDefensivePlay() : candidates.randomElement()
    }

    // MARK: - Trench Evaluation (OL vs DL)

    /// Evaluate the offensive line vs defensive front matchups using STOCK.DAT assignments.
    /// Returns how many blocks were won and the pass rush pressure level.
    private func evaluateTrench(
        offensiveTeam: Team,
        defensiveTeam: Team,
        stockPlay: StockPlay?,
        isPassPlay: Bool,
        fatigue: FatigueContext
    ) -> TrenchResult {
        // Get OL starters
        let olPositions: [Position] = [.leftTackle, .leftGuard, .center, .rightGuard, .rightTackle]
        let olPlayers = olPositions.compactMap { offensiveTeam.starter(at: $0) }

        // Get DL + edge rushers
        let dlPlayers: [Player] = {
            var dl: [Player] = []
            dl.append(contentsOf: defensiveTeam.players(at: .defensiveEnd).prefix(2))
            dl.append(contentsOf: defensiveTeam.players(at: .defensiveTackle).prefix(2))
            return dl
        }()

        guard !olPlayers.isEmpty && !dlPlayers.isEmpty else {
            return TrenchResult(blocksWon: 3, passRushPressure: 0.3, timeInPocket: 2.8)
        }

        var blocksWon = 0
        var totalPressure: Double = 0
        let matchupCount = min(olPlayers.count, dlPlayers.count)

        // Determine which OL players have blocking assignments from STOCK.DAT
        let hasStockBlocking = stockPlay?.players.contains(where: { $0.hasBlockingAssignment }) ?? false

        for i in 0..<matchupCount {
            let ol = olPlayers[i]
            let dl = dlPlayers[i]

            // OL rating: run block or pass block depending on play type
            let olRating: Int
            if isPassPlay {
                olRating = fatigue.adjustedRating(ol.ratings.passBlock, for: ol)
            } else {
                olRating = fatigue.adjustedRating(ol.ratings.runBlock, for: ol)
            }

            // DL rating: combination of relevant skills
            let dlRushRating = fatigue.adjustedRating(dl.ratings.passRush, for: dl)
            let dlShedRating = fatigue.adjustedRating(dl.ratings.blockShedding, for: dl)
            let dlStrength = fatigue.adjustedRating(dl.ratings.strength, for: dl)
            let dlRating = isPassPlay ?
                (dlRushRating * 2 + dlStrength) / 3 :
                (dlShedRating * 2 + dlStrength) / 3

            // Stock play blocking bonus: if OL has explicit blocking assignment, +5 bonus
            let stockBonus = hasStockBlocking ? 5 : 0

            // Matchup: OL rating + random variance vs DL rating + random variance
            let olScore = Double(olRating + stockBonus) + Double.random(in: -10...10)
            let dlScore = Double(dlRating) + Double.random(in: -10...10)

            if olScore >= dlScore {
                blocksWon += 1
            } else {
                totalPressure += (dlScore - olScore) / 100.0
            }
        }

        // Add LB blitz pressure if they have rush assignments in STOCK.DAT
        if let play = stockPlay {
            let rushingLBs = play.players.filter {
                $0.positionCode == StockPositionType.LB.rawValue && $0.hasRushAssignment
            }
            if !rushingLBs.isEmpty {
                totalPressure += 0.15 * Double(rushingLBs.count)
            }
        }

        let pressureLevel = min(1.0, totalPressure / Double(matchupCount))

        // Time in pocket: 1.5-4.0 seconds, reduced by pressure
        let baseTime = 3.0
        let timeInPocket = max(1.5, baseTime - pressureLevel * 2.0 + Double.random(in: -0.3...0.3))

        return TrenchResult(
            blocksWon: blocksWon,
            passRushPressure: pressureLevel,
            timeInPocket: timeInPocket
        )
    }

    // MARK: - Receiver Evaluation

    /// Evaluate all receivers from STOCK.DAT routes and determine separation against coverage
    private func evaluateReceivers(
        offensiveTeam: Team,
        defensiveTeam: Team,
        stockPlay: StockPlay?,
        defensiveCall: any DefensiveCall,
        fatigue: FatigueContext
    ) -> [ReceiverOption] {
        var options: [ReceiverOption] = []

        // Get all eligible receivers
        let receivers = offensiveTeam.players(at: .wideReceiver) +
                        offensiveTeam.players(at: .tightEnd)
        let rb = offensiveTeam.starter(at: .runningBack)

        // Get defensive backs
        let corners = defensiveTeam.players(at: .cornerback)
        let fs = defensiveTeam.starter(at: .freeSafety)
        let ss = defensiveTeam.starter(at: .strongSafety)
        let allDBs: [Player] = corners + [fs, ss].compactMap { $0 }
        let linebackers = defensiveTeam.players(at: .middleLinebacker) +
                          defensiveTeam.players(at: .outsideLinebacker)

        // If we have STOCK.DAT data, use actual route assignments
        if let play = stockPlay {
            let sortedPlayers = sortOffensivePlayersForRoutes(play.players)

            for (i, stockEntry) in sortedPlayers.enumerated() {
                // Only evaluate players with pass routes
                guard stockEntry.hasPassRoute || !stockEntry.routeWaypoints.isEmpty else { continue }

                // Map stock entry to roster player
                let rosterPlayer: Player?
                switch stockEntry.positionCode {
                case StockPositionType.WR.rawValue:
                    let wrIndex = sortedPlayers.prefix(i + 1).filter { $0.positionCode == StockPositionType.WR.rawValue }.count - 1
                    rosterPlayer = wrIndex < receivers.filter({ $0.position == .wideReceiver }).count ?
                        receivers.filter({ $0.position == .wideReceiver })[wrIndex] : nil
                case StockPositionType.TE.rawValue:
                    rosterPlayer = offensiveTeam.starter(at: .tightEnd)
                case StockPositionType.HB.rawValue, StockPositionType.FB.rawValue:
                    rosterPlayer = rb
                default:
                    continue
                }

                guard let player = rosterPlayer else { continue }

                // Calculate route depth from STOCK.DAT waypoints
                let routeDepth = calculateRouteDepth(stockEntry)
                let routeCategory = categorizeRoute(depth: routeDepth)

                // Match against a defender
                let matchedDefender = assignDefender(
                    receiverIndex: i,
                    allDBs: allDBs,
                    linebackers: linebackers,
                    defensiveCall: defensiveCall,
                    stockEntry: stockEntry
                )

                // Calculate separation score
                let separation = calculateSeparation(
                    receiver: player,
                    defender: matchedDefender,
                    routeCategory: routeCategory,
                    stockEntry: stockEntry,
                    defensiveCall: defensiveCall,
                    fatigue: fatigue
                )

                let isCheckdown = routeCategory == .quick &&
                    (stockEntry.positionCode == StockPositionType.HB.rawValue ||
                     stockEntry.positionCode == StockPositionType.FB.rawValue)

                options.append(ReceiverOption(
                    player: player,
                    routeDepth: routeDepth,
                    separation: separation,
                    routeType: routeCategory,
                    isCheckdown: isCheckdown,
                    matchedDefender: matchedDefender
                ))
            }
        }

        // If no STOCK.DAT routes found, build synthetic options from roster
        if options.isEmpty {
            for (i, receiver) in receivers.prefix(4).enumerated() {
                let depths: [CGFloat] = [8, 14, 22, 5]  // WR1 medium, WR2 deeper, WR3 deep, TE short
                let depth = i < depths.count ? depths[i] : 10
                let category = categorizeRoute(depth: depth)
                let defender = i < allDBs.count ? allDBs[i] : nil

                let separation = calculateSeparation(
                    receiver: receiver,
                    defender: defender,
                    routeCategory: category,
                    stockEntry: nil,
                    defensiveCall: defensiveCall,
                    fatigue: fatigue
                )

                options.append(ReceiverOption(
                    player: receiver,
                    routeDepth: depth,
                    separation: separation,
                    routeType: category,
                    isCheckdown: false,
                    matchedDefender: defender
                ))
            }

            // Add RB as checkdown
            if let runningBack = rb {
                let rbSep = calculateSeparation(
                    receiver: runningBack,
                    defender: linebackers.first,
                    routeCategory: .quick,
                    stockEntry: nil,
                    defensiveCall: defensiveCall,
                    fatigue: fatigue
                )
                options.append(ReceiverOption(
                    player: runningBack,
                    routeDepth: 3,
                    separation: rbSep,
                    routeType: .quick,
                    isCheckdown: true,
                    matchedDefender: linebackers.first
                ))
            }
        }

        return options
    }

    /// Calculate route depth in yards from STOCK.DAT waypoints
    private func calculateRouteDepth(_ entry: StockPlayerEntry) -> CGFloat {
        // Use the deepest waypoint or route phase position
        var maxDepth: CGFloat = 0

        // Route phase position (PH3) gives the route endpoint
        if let routePhase = entry.routePhasePosition {
            let relativeDepth = routePhase.y - (-141)  // Relative to LOS
            maxDepth = max(maxDepth, abs(relativeDepth) * 0.1)  // Convert stock units to yards
        }

        // Check waypoints for deeper targets
        for wp in entry.routeWaypoints {
            let relativeDepth = wp.y - (-141)
            maxDepth = max(maxDepth, abs(relativeDepth) * 0.1)
        }

        // If no route data, estimate from post-snap position
        if maxDepth == 0, let postSnap = entry.postSnapPosition {
            let relativeDepth = postSnap.y - (-141)
            maxDepth = abs(relativeDepth) * 0.1
        }

        // Clamp to reasonable range (1-50 yards)
        return max(1, min(50, maxDepth))
    }

    /// Categorize a route by its depth
    private func categorizeRoute(depth: CGFloat) -> RouteCategory {
        switch depth {
        case ..<5:  return .quick
        case ..<10: return .short
        case ..<20: return .medium
        default:    return .deep
        }
    }

    /// Assign a defender to cover this receiver based on defensive alignment
    private func assignDefender(
        receiverIndex: Int,
        allDBs: [Player],
        linebackers: [Player],
        defensiveCall: any DefensiveCall,
        stockEntry: StockPlayerEntry
    ) -> Player? {
        // TEs and RBs are typically covered by LBs or safeties
        if stockEntry.positionCode == StockPositionType.TE.rawValue ||
           stockEntry.positionCode == StockPositionType.HB.rawValue ||
           stockEntry.positionCode == StockPositionType.FB.rawValue {
            // Safety or LB coverage
            if defensiveCall.coverage == .manCoverage {
                return linebackers.first ?? allDBs.last
            } else {
                return allDBs.count > 2 ? allDBs[allDBs.count - 1] : linebackers.first
            }
        }

        // WRs matched by CBs in man, zone drops otherwise
        if defensiveCall.coverage == .manCoverage {
            return receiverIndex < allDBs.count ? allDBs[receiverIndex] : allDBs.last
        } else {
            // In zone, closest defender is less predictable
            return receiverIndex < allDBs.count ? allDBs[receiverIndex] : allDBs.randomElement()
        }
    }

    /// Calculate receiver separation score (0-100) based on matchup
    private func calculateSeparation(
        receiver: Player,
        defender: Player?,
        routeCategory: RouteCategory,
        stockEntry: StockPlayerEntry?,
        defensiveCall: any DefensiveCall,
        fatigue: FatigueContext
    ) -> Double {
        // Receiver skills
        let recSpeed = fatigue.adjustedRating(receiver.ratings.speed, for: receiver)
        let recAgility = fatigue.adjustedRating(receiver.ratings.agility, for: receiver)
        let recRouteRun = fatigue.adjustedRating(receiver.ratings.routeRunning, for: receiver)
        let recRelease = fatigue.adjustedRating(receiver.ratings.release, for: receiver)

        // Route sharpness: intelligence/route running affects how cleanly they run the route
        let routeSharpness = Double(recRouteRun + recAgility) / 200.0  // 0.3-1.0 range

        // Base separation by route type
        var separation: Double
        switch routeCategory {
        case .quick:
            // Quick routes get fast separation but modest depth
            separation = 50.0 + routeSharpness * 20.0
        case .short:
            separation = 40.0 + routeSharpness * 25.0
        case .medium:
            separation = 35.0 + routeSharpness * 25.0 + Double(recSpeed - 70) * 0.3
        case .deep:
            // Deep routes heavily favor speed
            separation = 25.0 + Double(recSpeed - 70) * 0.8 + routeSharpness * 15.0
        }

        // Defender matchup reduces separation
        if let def = defender {
            let defSpeed = fatigue.adjustedRating(def.ratings.speed, for: def)
            let defAgility = fatigue.adjustedRating(def.ratings.agility, for: def)

            if defensiveCall.coverage == .manCoverage {
                let defManCov = fatigue.adjustedRating(def.ratings.manCoverage, for: def)
                let defPress = fatigue.adjustedRating(def.ratings.press, for: def)

                // Man coverage: direct matchup, press at line hurts separation
                let coverageSkill = Double(defManCov * 2 + defSpeed + defAgility) / 4.0
                separation -= coverageSkill * 0.4

                // Press vs release at the line of scrimmage
                let pressRelease = Double(recRelease - defPress) * 0.15
                separation += pressRelease
            } else {
                // Zone coverage: defender reads QB then reacts
                let defZoneCov = fatigue.adjustedRating(def.ratings.zoneCoverage, for: def)
                let defRecognition = fatigue.adjustedRating(def.ratings.playRecognition, for: def)

                let zonePenalty = Double(defZoneCov + defRecognition) / 200.0 * 20.0
                separation -= zonePenalty

                // Zone tends to give up short/medium routes but covers deep better
                switch routeCategory {
                case .quick, .short:
                    separation += 5.0  // Zone gives up underneath
                case .medium:
                    break  // Neutral
                case .deep:
                    separation -= 8.0  // Deep zones are effective
                }
            }
        }

        // STOCK.DAT route bonus: having explicit waypoints means a designed route
        if let entry = stockEntry, !entry.routeWaypoints.isEmpty {
            separation += 3.0  // Small bonus for designed route structure
        }

        // Coverage scheme modifiers
        switch defensiveCall.coverage {
        case .coverTwo:
            if routeCategory == .deep { separation -= 5.0 }  // Two deep safeties
            if routeCategory == .short { separation += 3.0 }  // Vulnerable underneath
        case .coverThree:
            if routeCategory == .deep { separation -= 8.0 }  // Three deep defenders
            if routeCategory == .quick { separation += 5.0 }  // Vulnerable to quick game
        case .coverFour:
            if routeCategory == .deep { separation -= 10.0 }  // Four deep
            if routeCategory == .quick { separation += 7.0 }
        case .blitz, .zoneBlitz:
            separation += 10.0  // Fewer defenders in coverage
        default:
            break
        }

        // Clamp to 0-100
        return max(0, min(100, separation + Double.random(in: -8...8)))
    }

    /// Sort stock play offensive players for route evaluation
    private func sortOffensivePlayersForRoutes(_ players: [StockPlayerEntry]) -> [StockPlayerEntry] {
        // Filter to skill positions with routes
        return players.filter { entry in
            let isSkill = entry.positionCode == StockPositionType.WR.rawValue ||
                          entry.positionCode == StockPositionType.TE.rawValue ||
                          entry.positionCode == StockPositionType.HB.rawValue ||
                          entry.positionCode == StockPositionType.FB.rawValue
            return isSkill
        }.sorted { a, b in
            // WRs first, then TEs, then backs
            a.positionCode < b.positionCode
        }
    }

    // MARK: - Run Resolution (Route-Based)

    private func resolveRun(
        playType: PlayType,
        offensiveTeam: Team,
        defensiveTeam: Team,
        defensiveFormation: DefensiveFormation,
        fieldPosition: FieldPosition,
        isHomePossession: Bool = false,
        fatigue: FatigueContext = .none,
        gameWeather: GameWeather? = nil
    ) -> PlayOutcome {

        // Get key players
        let rb = offensiveTeam.starter(at: .runningBack)

        let dt1 = defensiveTeam.starter(at: .defensiveTackle)
        let dt2 = defensiveTeam.players(at: .defensiveTackle).dropFirst().first
        let mlb = defensiveTeam.starter(at: .middleLinebacker)
        let olb1 = defensiveTeam.starter(at: .outsideLinebacker)
        let allDefenders = [dt1, dt2, mlb, olb1].compactMap { $0 }

        // --- Route-based blocking evaluation using STOCK.DAT ---
        let stockPlay = findStockPlay(playType: playType)
        let trench = evaluateTrench(
            offensiveTeam: offensiveTeam,
            defensiveTeam: defensiveTeam,
            stockPlay: stockPlay,
            isPassPlay: false,
            fatigue: fatigue
        )

        // Hole quality determines base yardage potential
        let holeYards: Double
        switch trench.blocksWon {
        case 5:     holeYards = Double.random(in: 5...12)    // Dominant blocking
        case 4:     holeYards = Double.random(in: 3...8)     // Big hole
        case 3:     holeYards = Double.random(in: 2...6)     // Decent hole
        case 2:     holeYards = Double.random(in: 0...4)     // Small crease
        case 1:     holeYards = Double.random(in: -1...2)    // Minimal space
        default:    holeYards = Double.random(in: -3...1)    // Stuffed/penetration
        }

        // RB ability to exploit the hole
        let rbSpeedRating = rb.map { fatigue.adjustedRating($0.ratings.speed, for: $0) } ?? 60
        let rbVisionRating = rb.map { fatigue.adjustedRating($0.ratings.ballCarrierVision, for: $0) } ?? 60
        let rbElusiveRating = rb.map { fatigue.adjustedRating($0.ratings.elusiveness, for: $0) } ?? 60

        // Vision helps the RB find the right hole; without it, good blocking is wasted
        let visionBonus = (Double(rbVisionRating) - 60.0) / 60.0 * holeYards * 0.3
        var yards = Int(holeYards + visionBonus)

        // Second level: LB pursuit vs RB elusiveness
        let lbPursuit = allDefenders.isEmpty ? 70 :
            allDefenders.map { fatigue.adjustedRating($0.ratings.pursuit, for: $0) }.reduce(0, +) / allDefenders.count
        let lbRecognition = allDefenders.isEmpty ? 70 :
            allDefenders.map { fatigue.adjustedRating($0.ratings.playRecognition, for: $0) }.reduce(0, +) / allDefenders.count

        // If RB got past the line (yards > 2), contest at second level
        if yards > 2 {
            let secondLevelContest = Double(rbElusiveRating + rbSpeedRating) / 2.0 -
                                     Double(lbPursuit + lbRecognition) / 2.0
            if secondLevelContest > 10 {
                // RB wins second level, potential extra yards
                yards += Int(Double.random(in: 2...6) * (secondLevelContest / 40.0))
            } else if secondLevelContest < -10 {
                // LB reads it well, limits gain
                yards = min(yards, Int.random(in: 2...5))
            }
        }

        // Safety angle: if past LBs (yards > 8), check safety pursuit for breakaway
        if yards > 8 {
            let fs = defensiveTeam.starter(at: .freeSafety)
            let ss = defensiveTeam.starter(at: .strongSafety)
            let safetySpeed = max(
                fs.map { fatigue.adjustedRating($0.ratings.speed, for: $0) } ?? 70,
                ss.map { fatigue.adjustedRating($0.ratings.speed, for: $0) } ?? 70
            )
            if rbSpeedRating > safetySpeed + Int.random(in: -5...10) {
                // Breakaway potential
                yards += Int.random(in: 10...30)
            }
        }

        // Break tackle check: RB's breakTackle + trucking can add extra yards
        if let runner = rb {
            let breakChance = Double(runner.ratings.breakTackle + runner.ratings.trucking) / 400.0 * 0.20
            if Double.random(in: 0...1) < breakChance {
                yards += Int.random(in: 3...8)
            }
        }

        // Formation matchup modifier
        let formationModifier: Double
        switch defensiveFormation {
        case .goalLine, .goalLineDef: formationModifier = 0.5
        case .base43, .base34, .base46, .base44, .flex: formationModifier = 0.85
        case .nickel, .base33: formationModifier = 1.0
        case .dime, .prevent: formationModifier = 1.25
        }
        yards = Int(Double(yards) * formationModifier)

        // Home field advantage
        if isHomePossession { yards += Double.random(in: 0...1) < 0.3 ? 1 : 0 }

        // Weather speed modifier
        if let gw = gameWeather {
            yards = Int(Double(yards) * gw.speedModifier)
        }

        // Play type specific adjustments
        switch playType {
        case .qbSneak:
            yards = max(-1, min(yards, 2))
        case .draw:
            if Double.random(in: 0...1) < 0.3 {
                yards = Int.random(in: -2...1)
            } else if Double.random(in: 0...1) < 0.1 {
                yards += Int.random(in: 8...20)
            }
        case .sweep, .outsideRun:
            if trench.blocksWon < 2 && Double.random(in: 0...1) < 0.3 {
                yards = Int.random(in: -4...0)  // Edge not sealed
            } else if trench.blocksWon >= 4 && Double.random(in: 0...1) < 0.15 {
                yards += Int.random(in: 10...25)  // Big play on the edge
            }
        default:
            break
        }

        // Pick a tackler — bias toward front-seven players who won their matchup
        let tackler: Player? = {
            if trench.blocksWon <= 2 {
                // DL penetration — DL makes the tackle
                return [dt1, dt2].compactMap { $0 }.randomElement()
            } else if yards <= 4 {
                return [mlb, olb1].compactMap { $0 }.randomElement() ?? allDefenders.randomElement()
            } else {
                // Deeper play — safety or LB in pursuit
                let safeties = [defensiveTeam.starter(at: .freeSafety),
                                defensiveTeam.starter(at: .strongSafety)].compactMap { $0 }
                return (safeties + allDefenders).randomElement()
            }
        }()

        // Check for fumble
        let carryingSkill = Double(rb?.ratings.carrying ?? 70)
        var fumbleChance = 0.02 * (1.0 - carryingSkill / 200.0)
        if let hitPwr = tackler?.ratings.hitPower {
            fumbleChance *= (1.0 + Double(hitPwr - 70) / 200.0)
        }
        if let gw = gameWeather { fumbleChance *= gw.fumbleModifier }

        if Double.random(in: 0...1) < fumbleChance {
            let recovered = Double.random(in: 0...1) < 0.45
            return PlayOutcome(
                yardsGained: min(yards, 3),
                timeElapsed: Int.random(in: 5...10),
                isComplete: true,
                isTouchdown: false,
                isTurnover: !recovered,
                turnoverType: recovered ? nil : .fumble,
                isPenalty: false,
                penalty: nil,
                isInjury: false,
                injuredPlayerId: nil,
                wentOutOfBounds: false,
                passerId: nil,
                rusherId: rb?.id,
                receiverId: nil,
                primaryTacklerId: tackler?.id,
                description: generateRunDescription(rb: rb, yards: yards, fumble: true, recovered: recovered)
            )
        }

        // Cap yards at distance to end zone
        yards = min(yards, fieldPosition.yardsToEndZone)
        let isTouchdown = fieldPosition.yardLine + yards >= 100

        let timeElapsed = yards > 0 ? Int.random(in: 25...40) : Int.random(in: 5...15)
        let injuryResult = checkForInjury(ballCarrierId: rb?.id, tacklerId: tackler?.id, isBigHit: yards <= 0, gameWeather: gameWeather)

        let oobChance: Double
        switch playType {
        case .sweep, .outsideRun, .qbScramble: oobChance = 0.25
        default: oobChance = 0.05
        }
        let wentOOB = Double.random(in: 0...1) < oobChance

        return PlayOutcome(
            yardsGained: yards,
            timeElapsed: timeElapsed,
            isComplete: true,
            isTouchdown: isTouchdown,
            isTurnover: false,
            turnoverType: nil,
            isPenalty: false,
            penalty: nil,
            isInjury: injuryResult.isInjury,
            injuredPlayerId: injuryResult.injuredPlayerId,
            wentOutOfBounds: wentOOB,
            passerId: nil,
            rusherId: rb?.id,
            receiverId: nil,
            primaryTacklerId: tackler?.id,
            description: generateRunDescription(rb: rb, yards: yards)
        )
    }

    // MARK: - Pass Resolution (Route-Based)

    private func resolvePass(
        playType: PlayType,
        offensiveTeam: Team,
        defensiveTeam: Team,
        defensiveCall: any DefensiveCall,
        fieldPosition: FieldPosition,
        weather: Weather,
        isHomePossession: Bool = false,
        fatigue: FatigueContext = .none,
        gameWeather: GameWeather? = nil
    ) -> PlayOutcome {

        let qb = offensiveTeam.starter(at: .quarterback)
        let de1 = defensiveTeam.starter(at: .defensiveEnd)
        let cb1 = defensiveTeam.starter(at: .cornerback)
        let cb2 = defensiveTeam.players(at: .cornerback).dropFirst().first
        let fs = defensiveTeam.starter(at: .freeSafety)
        let ss = defensiveTeam.starter(at: .strongSafety)

        // --- Step 1: Evaluate the trenches (pass rush vs pass protection) ---
        let stockPlay = findStockPlay(playType: playType)
        let trench = evaluateTrench(
            offensiveTeam: offensiveTeam,
            defensiveTeam: defensiveTeam,
            stockPlay: stockPlay,
            isPassPlay: true,
            fatigue: fatigue
        )

        // --- Step 2: Sack check based on trench result ---
        // High pressure + few blocks won = sack territory
        var sackChance = trench.passRushPressure * 0.25
        if defensiveCall.isBlitzing {
            sackChance += 0.10
        }
        // Clamp sack chance
        sackChance = max(0.03, min(0.25, sackChance))

        if Double.random(in: 0...1) < sackChance {
            let sackYards = Int.random(in: -12...(-4))

            // Strip sack fumble chance
            if Double.random(in: 0...1) < 0.10 {
                let defenseRecovers = Double.random(in: 0...1) < 0.65
                let desc = defenseRecovers
                    ? "\(qb?.fullName ?? "QB") STRIP SACKED! Fumble recovered by defense!"
                    : "\(qb?.fullName ?? "QB") stripped on the sack, but recovers the fumble"
                return PlayOutcome(
                    yardsGained: sackYards,
                    timeElapsed: Int.random(in: 5...10),
                    isComplete: false,
                    isTouchdown: false,
                    isTurnover: defenseRecovers,
                    turnoverType: defenseRecovers ? .fumble : nil,
                    isPenalty: false,
                    penalty: nil,
                    isInjury: false,
                    injuredPlayerId: nil,
                    wentOutOfBounds: false,
                    passerId: qb?.id,
                    rusherId: nil,
                    receiverId: nil,
                    primaryTacklerId: de1?.id,
                    description: desc
                )
            }

            let sackInjury = checkForInjury(ballCarrierId: qb?.id, tacklerId: de1?.id, isBigHit: true, gameWeather: gameWeather)
            return PlayOutcome(
                yardsGained: sackYards,
                timeElapsed: Int.random(in: 5...10),
                isComplete: false,
                isTouchdown: false,
                isTurnover: false,
                turnoverType: nil,
                isPenalty: false,
                penalty: nil,
                isInjury: sackInjury.isInjury,
                injuredPlayerId: sackInjury.injuredPlayerId,
                wentOutOfBounds: false,
                passerId: qb?.id,
                rusherId: nil,
                receiverId: nil,
                primaryTacklerId: de1?.id,
                description: "\(qb?.fullName ?? "QB") sacked for a loss of \(abs(sackYards)) yards"
            )
        }

        // --- Step 3: QB scramble check ---
        let isPressured = trench.passRushPressure > 0.5
        if isPressured && Double.random(in: 0...1) < 0.10 {
            let qbSpeed = qb?.ratings.speed ?? 60
            let qbAgility = qb?.ratings.agility ?? 60
            let scrambleBonus = Double(qbSpeed + qbAgility - 120) / 80.0
            var scrambleYards = Int(Double.random(in: 2...8) + scrambleBonus)
            scrambleYards = max(0, min(scrambleYards, fieldPosition.yardsToEndZone))
            let isTD = fieldPosition.yardLine + scrambleYards >= 100
            let scrambleOOB = Double.random(in: 0...1) < 0.25
            let scrambleInjury = checkForInjury(ballCarrierId: qb?.id, tacklerId: de1?.id, isBigHit: false, gameWeather: gameWeather)

            return PlayOutcome(
                yardsGained: scrambleYards,
                timeElapsed: Int.random(in: 5...12),
                isComplete: true,
                isTouchdown: isTD,
                isTurnover: false,
                turnoverType: nil,
                isPenalty: false,
                penalty: nil,
                isInjury: scrambleInjury.isInjury,
                injuredPlayerId: scrambleInjury.injuredPlayerId,
                wentOutOfBounds: scrambleOOB,
                passerId: nil,
                rusherId: qb?.id,
                receiverId: nil,
                primaryTacklerId: de1?.id,
                description: "\(qb?.fullName ?? "QB") scrambles for \(scrambleYards) yards\(isTD ? " TOUCHDOWN!" : "")"
            )
        }

        // --- Step 4: Evaluate receivers from STOCK.DAT routes ---
        let receiverOptions = evaluateReceivers(
            offensiveTeam: offensiveTeam,
            defensiveTeam: defensiveTeam,
            stockPlay: stockPlay,
            defensiveCall: defensiveCall,
            fatigue: fatigue
        )

        // --- Step 5: QB reads receivers in priority order ---
        // QB Intelligence/Awareness determines how many reads he can make before pressure arrives
        let qbAwareness = qb.map { fatigue.adjustedRating($0.ratings.awareness, for: $0) } ?? 70
        let readSpeed = Double(qbAwareness) / 100.0  // 0.5-1.0 for typical range

        // Sort by separation (best option first), but QB reads are limited by time
        let sortedOptions = receiverOptions.sorted { $0.separation > $1.separation }
        let maxReads = isPressured ?
            max(1, Int(readSpeed * 2)) :   // Under pressure: 1-2 reads
            max(2, Int(readSpeed * 4))     // Clean pocket: 2-4 reads

        // QB scans available reads. Under pressure, may have to throw to checkdown.
        let selectedReceiver: ReceiverOption?
        if isPressured && trench.timeInPocket < 2.0 {
            // Extreme pressure: throw to first available or checkdown
            let checkdown = sortedOptions.first(where: { $0.isCheckdown })
            selectedReceiver = checkdown ?? sortedOptions.first
        } else {
            // Normal reads: scan up to maxReads receivers
            let availableReads = Array(sortedOptions.prefix(maxReads))
            // Pick the best open receiver QB can see
            selectedReceiver = availableReads.first(where: { $0.separation > 40 }) ??
                               availableReads.first
        }

        guard let target = selectedReceiver else {
            // No receiver found — throwaway
            return PlayOutcome(
                yardsGained: 0,
                timeElapsed: Int.random(in: 4...8),
                isComplete: false,
                isTouchdown: false,
                isTurnover: false,
                turnoverType: nil,
                isPenalty: false,
                penalty: nil,
                isInjury: false,
                injuredPlayerId: nil,
                wentOutOfBounds: false,
                passerId: qb?.id,
                rusherId: nil,
                receiverId: nil,
                primaryTacklerId: nil,
                description: "\(qb?.fullName ?? "QB") throws it away, no receivers open"
            )
        }

        let targetReceiver = target.player

        // --- Step 6: Throw accuracy based on QB ratings + route depth ---
        let qbAccuracy: Int
        if let q = qb {
            let fatPen = fatigue.penalty(for: q)
            switch target.routeType {
            case .quick:
                qbAccuracy = max(1, q.ratings.throwAccuracyShort - fatPen)
            case .short:
                qbAccuracy = max(1, q.ratings.throwAccuracyShort - fatPen)
            case .medium:
                qbAccuracy = max(1, q.ratings.throwAccuracyMid - fatPen)
            case .deep:
                qbAccuracy = max(1, q.ratings.throwAccuracyDeep - fatPen)
            }
        } else {
            qbAccuracy = 70
        }

        // QB needs arm strength for deep throws
        let qbThrowPower = qb.map { fatigue.adjustedRating($0.ratings.throwPower, for: $0) } ?? 70
        var throwPowerPenalty: Double = 0
        if target.routeType == .deep && qbThrowPower < 75 {
            throwPowerPenalty = Double(75 - qbThrowPower) * 0.5  // Weak arm hurts deep balls
        }

        // --- Step 7: Completion probability from separation + accuracy ---
        // Separation is the primary factor; QB accuracy modifies it
        let separationFactor = target.separation / 100.0  // 0-1
        let accuracyFactor = Double(qbAccuracy) / 100.0   // 0.5-1.0

        // Base completion = route accuracy base * separation * QB accuracy
        var completionChance = target.routeType.accuracyBase *
            (0.4 + separationFactor * 0.6) *
            (0.5 + accuracyFactor * 0.5)

        // Pressure penalty on accuracy
        if isPressured {
            completionChance *= 0.80
        }

        // Throw power penalty for underthrown deep balls
        completionChance -= throwPowerPenalty / 100.0

        // Weather modifier
        if let gw = gameWeather {
            completionChance *= gw.completionModifier
        } else if weather.affectsPassing {
            completionChance *= 0.80
        }

        // Home field advantage
        if isHomePossession { completionChance += 0.03 }

        // Play action bonus
        if playType == .playAction {
            let paRating = qb?.ratings.playAction ?? 50
            completionChance += 0.02 + Double(paRating - 50) / 1000.0
        }

        // Screen passes are high-percentage short throws
        if playType == .screen { completionChance += 0.12 }

        // Catch in traffic: when separation is low, receiver's hands matter more
        if target.separation < 35 {
            let citBonus = Double(targetReceiver.ratings.catchInTraffic - 60) / 400.0
            completionChance += citBonus

            // Spectacular catch chance on contested throws
            if target.routeType == .deep {
                completionChance += Double(targetReceiver.ratings.spectacularCatch - 60) / 600.0
            }
        }

        // Prevent formation gives up short passes
        if defensiveCall.formation == .prevent {
            completionChance += 0.10
        }

        // Clamp to reasonable range
        completionChance = max(0.20, min(0.88, completionChance))

        let isComplete = Double.random(in: 0...1) < completionChance

        if !isComplete {
            // --- Interception check ---
            var intChance = 0.025
            if target.routeType == .deep { intChance = 0.05 }
            if isPressured { intChance += 0.03 }
            if target.separation < 25 { intChance += 0.02 }  // Tight coverage = tipped balls
            if defensiveCall.coverage == .coverFour { intChance += 0.02 }
            if defensiveCall.coverage == .manCoverage { intChance += 0.015 }
            if qbAwareness < 70 { intChance += 0.02 }

            // Defender ball skills affect INT chance
            if let defender = target.matchedDefender {
                let ballSkills = Double(defender.ratings.catching + defender.ratings.playRecognition) / 200.0
                intChance *= (0.7 + ballSkills * 0.6)
            }

            if Double.random(in: 0...1) < intChance {
                let interceptor = target.matchedDefender ??
                    [cb1, cb2, fs, ss].compactMap { $0 }.randomElement()
                let interceptorSpeed = Double(interceptor?.ratings.speed ?? 70)
                let speedFactor = interceptorSpeed / 80.0

                let pickSixRoll = Double.random(in: 0...1)
                let returnYards: Int
                let isPickSix: Bool
                if pickSixRoll < 0.03 {
                    returnYards = fieldPosition.yardsToEndZone
                    isPickSix = true
                } else {
                    let baseReturn = Double.random(in: 0...30) * speedFactor
                    returnYards = min(Int(baseReturn), fieldPosition.yardsToEndZone)
                    isPickSix = (fieldPosition.yardLine + returnYards) >= 100
                }

                let intDesc: String
                if isPickSix {
                    intDesc = "\(qb?.fullName ?? "QB") pass INTERCEPTED by \(interceptor?.fullName ?? "defender")! Returned for a TOUCHDOWN!"
                } else if returnYards > 0 {
                    intDesc = "\(qb?.fullName ?? "QB") pass INTERCEPTED by \(interceptor?.fullName ?? "defender")! Returned \(returnYards) yards."
                } else {
                    intDesc = "\(qb?.fullName ?? "QB") pass INTERCEPTED by \(interceptor?.fullName ?? "defender")!"
                }

                return PlayOutcome(
                    yardsGained: returnYards,
                    timeElapsed: Int.random(in: 4...8),
                    isComplete: false,
                    isTouchdown: isPickSix,
                    isTurnover: true,
                    turnoverType: .interception,
                    isPenalty: false,
                    penalty: nil,
                    isInjury: false,
                    injuredPlayerId: nil,
                    wentOutOfBounds: false,
                    passerId: qb?.id,
                    rusherId: nil,
                    receiverId: targetReceiver.id,
                    primaryTacklerId: interceptor?.id,
                    description: intDesc
                )
            }

            // Pass breakup
            let breakupDesc = isPressured ?
                "\(qb?.fullName ?? "QB") throws it away under pressure" :
                "Pass incomplete to \(targetReceiver.fullName)"

            return PlayOutcome(
                yardsGained: 0,
                timeElapsed: Int.random(in: 4...8),
                isComplete: false,
                isTouchdown: false,
                isTurnover: false,
                turnoverType: nil,
                isPenalty: false,
                penalty: nil,
                isInjury: false,
                injuredPlayerId: nil,
                wentOutOfBounds: false,
                passerId: qb?.id,
                rusherId: nil,
                receiverId: targetReceiver.id,
                primaryTacklerId: nil,
                description: breakupDesc
            )
        }

        // --- Step 8: Calculate yards from route depth + YAC ---
        // Air yards = route depth (where the catch happens)
        let airYards = Int(target.routeDepth)

        // YAC: receiver speed + separation - nearest defender tackling ability
        let recSpeed = Double(fatigue.adjustedRating(targetReceiver.ratings.speed, for: targetReceiver))
        let defTackleSkill: Double
        if let defender = target.matchedDefender {
            defTackleSkill = Double(fatigue.adjustedRating(defender.ratings.tackle, for: defender) +
                                    fatigue.adjustedRating(defender.ratings.pursuit, for: defender)) / 2.0
        } else {
            defTackleSkill = 70.0
        }

        let yacBase = (recSpeed - defTackleSkill) / 10.0 + target.separation / 20.0
        let yac = max(0, Int(yacBase + Double.random(in: -2...4)))

        var totalYards = airYards + yac
        totalYards = max(1, totalYards)  // Minimum 1 yard on completion

        // Cap at end zone
        totalYards = min(totalYards, fieldPosition.yardsToEndZone)
        let isTouchdown = fieldPosition.yardLine + totalYards >= 100

        let timeElapsed = Int.random(in: 5...15)

        // Pick a tackler — the matched defender or nearest DB
        let dbTackler = target.matchedDefender ??
            [cb1, cb2, fs, ss].compactMap { $0 }.randomElement()

        let passInjury = checkForInjury(ballCarrierId: targetReceiver.id, tacklerId: dbTackler?.id, isBigHit: false, gameWeather: gameWeather)

        return PlayOutcome(
            yardsGained: totalYards,
            timeElapsed: timeElapsed,
            isComplete: true,
            isTouchdown: isTouchdown,
            isTurnover: false,
            turnoverType: nil,
            isPenalty: false,
            penalty: nil,
            isInjury: passInjury.isInjury,
            injuredPlayerId: passInjury.injuredPlayerId,
            wentOutOfBounds: false,
            passerId: qb?.id,
            rusherId: nil,
            receiverId: targetReceiver.id,
            primaryTacklerId: dbTackler?.id,
            description: generatePassDescription(qb: qb, receiver: targetReceiver, yards: totalYards, touchdown: isTouchdown)
        )
    }

    // MARK: - Penalty Resolution

    /// Weighted penalty type selection matching approximate NFL frequency
    private func weightedRandomPenalty() -> PenaltyType {
        // Weights summing to 100 for clarity
        let weightedPenalties: [(PenaltyType, Double)] = [
            (.holding, 25),              // Offensive holding: most common NFL penalty
            (.falseStart, 20),           // False start: second most common
            (.offside, 15),              // Offside/encroachment
            (.passInterference, 10),     // Defensive pass interference
            (.illegalBlock, 4),          // Illegal block in the back
            (.roughingThePasser, 5),     // Roughing the passer
            (.facemask, 5),              // Facemask
            (.delay, 4),                 // Delay of game
            (.illegalMotion, 3),         // Illegal motion/shift
            (.unsportsmanlike, 3),       // Unsportsmanlike conduct
            (.intentionalGrounding, 3),  // Intentional grounding
            (.horseCollar, 3),           // Horse collar tackle
        ]

        let totalWeight = weightedPenalties.reduce(0.0) { $0 + $1.1 }
        var pick = Double.random(in: 0..<totalWeight)
        for (penalty, weight) in weightedPenalties {
            pick -= weight
            if pick <= 0 { return penalty }
        }
        return weightedPenalties.last!.0
    }

    private func resolvePenalty() -> PlayOutcome {
        let penaltyType = weightedRandomPenalty()

        // Assign penalty to the CORRECT side based on penalty type
        let isOnOffense: Bool
        if penaltyType.isAlwaysOffense {
            isOnOffense = true
        } else if penaltyType.isAlwaysDefense {
            isOnOffense = false
        } else if penaltyType == .holding {
            // Holding is overwhelmingly offensive in the NFL (~80%)
            isOnOffense = Double.random(in: 0...1) < 0.80
        } else {
            // Other ambiguous penalties (facemask, etc.): random side
            isOnOffense = Bool.random()
        }

        let penalty = Penalty(
            type: penaltyType,
            yards: penaltyType.yards,
            isOnOffense: isOnOffense,
            isDeclined: false
        )

        let yardEffect = isOnOffense ? -penalty.yards : penalty.yards

        return PlayOutcome(
            yardsGained: yardEffect,
            timeElapsed: Int.random(in: 5...10),
            isComplete: false,
            isTouchdown: false,
            isTurnover: false,
            turnoverType: nil,
            isPenalty: true,
            penalty: penalty,
            isInjury: false,
            injuredPlayerId: nil,
            wentOutOfBounds: false,
            passerId: nil,
            rusherId: nil,
            receiverId: nil,
            primaryTacklerId: nil,
            description: "FLAG: \(penalty.description)"
        )
    }

    // MARK: - Kneel Resolution

    private func resolveKneel(offensiveTeam: Team) -> PlayOutcome {
        let qb = offensiveTeam.starter(at: .quarterback)
        let qbName = qb?.fullName ?? "Quarterback"

        return PlayOutcome(
            yardsGained: -1,
            timeElapsed: Int.random(in: 38...42), // ~40 seconds off clock
            isComplete: true,
            isTouchdown: false,
            isTurnover: false,
            turnoverType: nil,
            isPenalty: false,
            penalty: nil,
            isInjury: false,
            injuredPlayerId: nil,
            wentOutOfBounds: false,
            passerId: nil,
            rusherId: qb?.id,
            receiverId: nil,
            primaryTacklerId: nil,
            description: "\(qbName) takes a knee"
        )
    }

    // MARK: - Spike Resolution

    private func resolveSpike(offensiveTeam: Team) -> PlayOutcome {
        let qb = offensiveTeam.starter(at: .quarterback)
        let qbName = qb?.fullName ?? "Quarterback"

        return PlayOutcome(
            yardsGained: 0,
            timeElapsed: Int.random(in: 2...4), // ~3 seconds off clock
            isComplete: false, // Spike is an incomplete pass — clock stops
            isTouchdown: false,
            isTurnover: false,
            turnoverType: nil,
            isPenalty: false,
            penalty: nil,
            isInjury: false,
            injuredPlayerId: nil,
            wentOutOfBounds: false,
            passerId: qb?.id,
            rusherId: nil,
            receiverId: nil,
            primaryTacklerId: nil,
            description: "\(qbName) spikes the ball to stop the clock"
        )
    }

    // MARK: - Injury Check

    private struct InjuryCheckResult {
        let isInjury: Bool
        let injuredPlayerId: UUID?
    }

    /// Roll for injury. Base ~1.5% per play; big hits (sacks, TFLs) bump to ~3%.
    /// Weather modifiers: cold +25%, mud +20%, turf +15%
    private func checkForInjury(ballCarrierId: UUID?, tacklerId: UUID?, isBigHit: Bool, gameWeather: GameWeather? = nil) -> InjuryCheckResult {
        var baseChance = isBigHit ? 0.03 : 0.015
        // Apply weather/field condition injury modifier
        if let gw = gameWeather {
            baseChance *= gw.injuryModifier
        }
        guard Double.random(in: 0...1) < baseChance else {
            return InjuryCheckResult(isInjury: false, injuredPlayerId: nil)
        }
        // Injured player is the ball carrier (more common) or tackler
        let injuredId = Double.random(in: 0...1) < 0.80 ? ballCarrierId : tacklerId
        return InjuryCheckResult(isInjury: injuredId != nil, injuredPlayerId: injuredId)
    }

    // MARK: - Description Generation

    private func generateRunDescription(rb: Player?, yards: Int, fumble: Bool = false, recovered: Bool = true) -> String {
        let name = rb?.fullName ?? "Running back"

        if fumble {
            if recovered {
                return "\(name) runs for \(yards) yards, FUMBLES but recovers"
            } else {
                return "\(name) runs for \(yards) yards, FUMBLES! Recovered by defense"
            }
        }

        if yards <= 0 {
            return "\(name) stuffed for no gain"
        } else if yards <= 3 {
            return "\(name) runs up the middle for \(yards) yards"
        } else if yards <= 10 {
            return "\(name) finds a hole for \(yards) yards"
        } else {
            return "\(name) breaks free for a \(yards) yard gain!"
        }
    }

    private func generatePassDescription(qb: Player?, receiver: Player?, yards: Int, touchdown: Bool) -> String {
        let qbName = qb?.fullName ?? "Quarterback"
        let recName = receiver?.fullName ?? "receiver"

        if touchdown {
            return "\(qbName) finds \(recName) for a \(yards) yard TOUCHDOWN!"
        } else if yards <= 5 {
            return "\(qbName) completes a short pass to \(recName) for \(yards) yards"
        } else if yards <= 15 {
            return "\(qbName) hits \(recName) over the middle for \(yards) yards"
        } else {
            return "\(qbName) connects deep with \(recName) for \(yards) yards!"
        }
    }
}
