//
//  SimulationEngine.swift
//  footballPro
//
//  Core game simulation logic
//

import Foundation

// MARK: - Simulation Engine

@MainActor
class SimulationEngine: ObservableObject {
    @Published var currentGame: Game?
    @Published var isSimulating = false
    @Published var simulationSpeed: LeagueSettings.SimulationSpeed = .normal

    private let playResolver = PlayResolver()
    private let statCalculator = StatCalculator()
    private let aiCoach = AICoach()

    private var homeTeam: Team?
    private var awayTeam: Team?

    // MARK: - Game Setup

    func setupGame(homeTeam: Team, awayTeam: Team, week: Int, seasonYear: Int, quarterMinutes: Int = 15) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam

        currentGame = Game(
            homeTeamId: homeTeam.id,
            awayTeamId: awayTeam.id,
            week: week,
            seasonYear: seasonYear,
            quarterMinutes: quarterMinutes,
            weather: Weather.forZone(homeTeam.weatherZone)
        )
        currentGame?.gameStatus = .pregame
    }

    func startGame() {
        guard var game = currentGame else { return }
        game.gameStatus = .inProgress
        game.isKickoff = true

        // Coin toss - away team receives
        game.possessingTeamId = game.awayTeamId

        currentGame = game
    }

    // MARK: - Play Execution

    func executePlay(offensiveCall: any PlayCall, defensiveCall: any DefensiveCall) async -> PlayResult? { // Changed to any PlayCall/DefensiveCall
        guard var game = currentGame,
              let homeTeam = homeTeam,
              let awayTeam = awayTeam else { return nil }

        isSimulating = true
        defer { isSimulating = false }

        let offensiveTeam = game.isHomeTeamPossession ? homeTeam : awayTeam
        let defensiveTeam = game.isHomeTeamPossession ? awayTeam : homeTeam

        // Resolve the play (pass home field status and fatigue context)
        let fatigueCtx = PlayResolver.FatigueContext(snapCounts: game.gameSnapCounts)
        let outcome = playResolver.resolvePlay(
            offensiveCall: offensiveCall,
            defensiveCall: defensiveCall,
            offensiveTeam: offensiveTeam,
            defensiveTeam: defensiveTeam,
            fieldPosition: game.fieldPosition,
            downAndDistance: game.downAndDistance,
            weather: game.weather,
            isHomePossession: game.isHomeTeamPossession,
            fatigue: fatigueCtx
        )

        // Create play result
        var result = PlayResult(
            playType: offensiveCall.playType,
            description: outcome.description,
            yardsGained: outcome.yardsGained,
            timeElapsed: outcome.timeElapsed,
            quarter: game.clock.quarter,
            timeRemaining: game.clock.timeRemaining,
            isFirstDown: false,
            isTouchdown: outcome.isTouchdown,
            isTurnover: outcome.isTurnover
        )

        // Update game clock — stops on: incomplete pass, score, turnover, penalty, out of bounds
        let isIncompletePass = !outcome.isComplete && offensiveCall.playType.isPass
        let shouldClockStop = isIncompletePass || outcome.isTouchdown || outcome.isTurnover || outcome.isPenalty || outcome.wentOutOfBounds

        // Track pre-play time for two-minute warning check
        let prePlayTime = game.clock.timeRemaining

        // Always tick the play duration, then set clock state
        game.clock.isRunning = true
        game.clock.tick(seconds: outcome.timeElapsed)
        if shouldClockStop {
            game.clock.isRunning = false
        }

        // Two-minute warning: if clock crossed 2:00 mark in Q2 or Q4
        let postPlayTime = game.clock.timeRemaining
        if game.clock.quarter == 2 && !game.twoMinuteWarningQ2Triggered && prePlayTime > 120 && postPlayTime <= 120 {
            game.twoMinuteWarningQ2Triggered = true
            game.clock.isRunning = false
        } else if game.clock.quarter == 4 && !game.twoMinuteWarningQ4Triggered && prePlayTime > 120 && postPlayTime <= 120 {
            game.twoMinuteWarningQ4Triggered = true
            game.clock.isRunning = false
        }

        // Always update time of possession for the possessing team
        updateTimeOfPossession(for: &game, timeElapsed: outcome.timeElapsed)

        // Always update stats for non-penalty plays (penalties tracked separately)
        if outcome.isPenalty, let penalty = outcome.penalty {
            // Track penalty stats separately — do NOT add to passing/rushing/total yards
            if penalty.isOnOffense {
                if game.isHomeTeamPossession {
                    game.homeTeamStats.penalties += 1
                    game.homeTeamStats.penaltyYards += penalty.yards
                } else {
                    game.awayTeamStats.penalties += 1
                    game.awayTeamStats.penaltyYards += penalty.yards
                }
            } else {
                if game.isHomeTeamPossession {
                    game.awayTeamStats.penalties += 1
                    game.awayTeamStats.penaltyYards += penalty.yards
                } else {
                    game.homeTeamStats.penalties += 1
                    game.homeTeamStats.penaltyYards += penalty.yards
                }
            }
        } else {
            // Non-penalty play: update offensive stats
            updateStats(for: &game, outcome: outcome, offensiveCall: offensiveCall)
        }

        // Increment snap counts for fatigue tracking
        incrementSnapCounts(game: &game)

        // Handle injury
        if outcome.isInjury, let injuredId = outcome.injuredPlayerId {
            let injuryMsg = handleInjury(playerId: injuredId, game: &game)
            result.description += injuryMsg.map { " | \($0)" } ?? ""
        }

        // Handle touchdown (from PlayResolver flagging it directly)
        if outcome.isTouchdown {
            result.scoringPlay = .touchdown
            result.isFirstDown = true
            game.score.addScore(points: 6, isHome: game.isHomeTeamPossession, quarter: game.clock.quarter)
            game.isExtraPoint = true

            // Count first down for touchdown plays
            if game.isHomeTeamPossession {
                game.homeTeamStats.firstDowns += 1
            } else {
                game.awayTeamStats.firstDowns += 1
            }

            // Add play to drive BEFORE ending the drive
            game.currentDrive?.plays.append(result)
            game.endDrive(result: .touchdown)

            currentGame = game
            return result
        }

        // Track OT possessions
        if game.clock.quarter >= 5 && (outcome.isTurnover || outcome.isTouchdown) {
            game.overtimePossessions += 1
        }

        // Handle turnover
        if outcome.isTurnover {
            let driveResult: DriveResult = outcome.turnoverType == .interception ? .interception : .fumble

            // Record turnover for the team that had the ball
            if game.isHomeTeamPossession {
                game.homeTeamStats.turnovers += 1
            } else {
                game.awayTeamStats.turnovers += 1
            }

            // Check for pick-six (interception returned for TD)
            if outcome.isTouchdown && outcome.turnoverType == .interception {
                // Score the defensive touchdown BEFORE switching possession
                // The defense (non-possessing team) scores
                game.score.addScore(points: 6, isHome: !game.isHomeTeamPossession, quarter: game.clock.quarter)

                game.currentDrive?.plays.append(result)
                game.endDrive(result: driveResult)

                // Switch to the team that scored (defense) for the extra point
                game.switchPossession()
                game.isExtraPoint = true

                currentGame = game
                return result
            }

            // Add play to drive BEFORE ending it
            game.currentDrive?.plays.append(result)
            game.endDrive(result: driveResult)

            // switchPossession() already calls fieldPosition.flip() — don't double-flip
            game.switchPossession()

            // Apply interception return yardage to field position
            if outcome.turnoverType == .interception && outcome.yardsGained > 0 {
                game.fieldPosition.advance(yards: outcome.yardsGained)
            }

            game.downAndDistance = .firstDown(at: game.fieldPosition.yardLine)
            game.startDrive()

            currentGame = game
            return result
        }

        // Update field position
        game.fieldPosition.advance(yards: outcome.yardsGained)

        // Check for safety
        if game.fieldPosition.yardLine <= 0 {
            result.scoringPlay = .safety
            game.score.addScore(points: 2, isHome: !game.isHomeTeamPossession, quarter: game.clock.quarter)

            // Add play to drive BEFORE ending it
            game.currentDrive?.plays.append(result)
            game.endDrive(result: .safety)

            // After safety, team that scored gets the ball
            game.switchPossession()
            game.fieldPosition = FieldPosition(yardLine: 20)
            game.downAndDistance = .firstDown(at: 20)
            game.startDrive()

            currentGame = game
            return result
        }

        // Check for touchdown (on run/pass that reaches end zone after field advance)
        if game.fieldPosition.yardLine >= 100 {
            result.isTouchdown = true
            result.isFirstDown = true
            result.scoringPlay = .touchdown
            game.score.addScore(points: 6, isHome: game.isHomeTeamPossession, quarter: game.clock.quarter)
            game.isExtraPoint = true

            // Count first down for touchdown plays
            if game.isHomeTeamPossession {
                game.homeTeamStats.firstDowns += 1
            } else {
                game.awayTeamStats.firstDowns += 1
            }

            // Add play to drive BEFORE ending it
            game.currentDrive?.plays.append(result)
            game.endDrive(result: .touchdown)

            currentGame = game
            return result
        }

        // Track 3rd/4th down attempts BEFORE resolving the down
        let currentDown = game.downAndDistance.down
        if currentDown == 3 {
            if game.isHomeTeamPossession {
                game.homeTeamStats.thirdDownAttempts += 1
            } else {
                game.awayTeamStats.thirdDownAttempts += 1
            }
        } else if currentDown == 4 {
            if game.isHomeTeamPossession {
                game.homeTeamStats.fourthDownAttempts += 1
            } else {
                game.awayTeamStats.fourthDownAttempts += 1
            }
        }

        // Handle penalties — replay the down (don't advance it)
        if outcome.isPenalty, let penalty = outcome.penalty {
            // Apply half-the-distance-to-the-goal when penalty would move past goal line
            let maxYards = penalty.isOnOffense ? game.fieldPosition.yardLine : (100 - game.fieldPosition.yardLine)
            if penalty.yards > maxYards {
                let halfDist = maxYards / 2
                game.fieldPosition.advance(yards: penalty.isOnOffense ? -halfDist : halfDist)
            } else {
                game.fieldPosition.advance(yards: outcome.yardsGained)
            }

            // Defensive penalties with automatic first down
            if !penalty.isOnOffense && penalty.type.isAutoFirstDown {
                game.downAndDistance = .firstDown(at: game.fieldPosition.yardLine)
            } else {
                // Replay the down (don't advance) — update LOS but keep same down
                game.downAndDistance.lineOfScrimmage = game.fieldPosition.yardLine
                if !penalty.isOnOffense {
                    // Defensive penalty: adjust yards to go
                    game.downAndDistance.yardsToGo = max(1, game.downAndDistance.yardsToGo - penalty.yards)
                }
                // Offensive penalty: keep same down and distance (effectively)
            }

            game.currentDrive?.plays.append(result)
            currentGame = game

            // Check for end of quarter
            if game.clock.timeRemaining <= 0 {
                handleEndOfQuarter(game: &game)
                currentGame = game
            }

            return result
        }

        // Update down and distance (non-penalty plays)
        let gotFirstDown = game.downAndDistance.afterPlay(yardsGained: outcome.yardsGained)
        result.isFirstDown = gotFirstDown

        if gotFirstDown {
            if game.isHomeTeamPossession {
                game.homeTeamStats.firstDowns += 1
            } else {
                game.awayTeamStats.firstDowns += 1
            }

            // Track 3rd/4th down conversions
            if currentDown == 3 {
                if game.isHomeTeamPossession {
                    game.homeTeamStats.thirdDownConversions += 1
                } else {
                    game.awayTeamStats.thirdDownConversions += 1
                }
            } else if currentDown == 4 {
                if game.isHomeTeamPossession {
                    game.homeTeamStats.fourthDownConversions += 1
                } else {
                    game.awayTeamStats.fourthDownConversions += 1
                }
            }
        }

        // Check for turnover on downs
        if game.downAndDistance.isTurnoverOnDowns {
            // Add play to drive BEFORE ending it
            game.currentDrive?.plays.append(result)
            game.endDrive(result: .turnoverOnDowns)

            // switchPossession() already calls fieldPosition.flip() — don't double-flip
            game.switchPossession()
            game.downAndDistance = .firstDown(at: game.fieldPosition.yardLine)
            game.startDrive()
        } else {
            // Add play to current drive (normal play)
            game.currentDrive?.plays.append(result)
        }

        // AI timeout check: non-possessing team considers calling a timeout after the play
        let defOwnTimeouts = game.isHomeTeamPossession ? game.awayTimeouts : game.homeTimeouts
        let defOppTimeouts = game.isHomeTeamPossession ? game.homeTimeouts : game.awayTimeouts
        let aiTimeoutSituation = GameSituation(
            down: game.downAndDistance.down,
            yardsToGo: game.downAndDistance.yardsToGo,
            fieldPosition: game.fieldPosition.yardLine,
            quarter: game.clock.quarter,
            timeRemaining: game.clock.timeRemaining,
            scoreDifferential: game.isHomeTeamPossession ?
                game.score.awayScore - game.score.homeScore :
                game.score.homeScore - game.score.awayScore,
            isRedZone: game.fieldPosition.isRedZone,
            ownTimeouts: defOwnTimeouts,
            opponentTimeouts: defOppTimeouts
        )
        let defTimeouts = game.isHomeTeamPossession ? game.awayTimeouts : game.homeTimeouts
        if game.clock.isRunning && aiCoach.shouldCallTimeout(situation: aiTimeoutSituation, timeoutsRemaining: defTimeouts) {
            if game.isHomeTeamPossession {
                game.awayTimeouts -= 1
            } else {
                game.homeTimeouts -= 1
            }
            game.clock.isRunning = false
        }

        // Check for end of quarter
        if game.clock.timeRemaining <= 0 {
            handleEndOfQuarter(game: &game)
        }

        currentGame = game

        // Simulate delay based on speed
        if simulationSpeed != .instant {
            try? await Task.sleep(nanoseconds: UInt64(simulationSpeed.delayMs) * 1_000_000)
        }

        return result
    }

    // MARK: - Special Teams

    func executeKickoff() async -> PlayResult {
        guard var game = currentGame else {
            return PlayResult(
                playType: .kickoff,
                description: "Kickoff error",
                yardsGained: 0,
                timeElapsed: 5,
                quarter: 1,
                timeRemaining: 900,
                isFirstDown: false,
                isTouchdown: false,
                isTurnover: false
            )
        }

        // Kickoff from 35-yard line
        // 60% chance of touchback (modern NFL with kickoff from 35)
        let isTouchback = Double.random(in: 0...1) < 0.60

        let startingYardLine: Int
        let description: String
        let returningTeam = game.isHomeTeamPossession ? awayTeam : homeTeam
        let returner = returningTeam?.starter(at: .wideReceiver)
        let returnerName = "\(returner?.firstName ?? "") \(returner?.lastName ?? "Smith")".trimmingCharacters(in: .whitespaces)

        if isTouchback {
            // Touchback - ball at 25-yard line
            startingYardLine = 25
            description = "Kickoff into the end zone. \(returnerName) takes a knee. Touchback to the 25."
        } else {
            // Return — typical 15-35 yards, rare chance of big return or TD
            let kickLandingSpot = Int.random(in: -5...5) // Lands near goal line
            let baseReturn = Int.random(in: 10...30)
            let bigPlayChance = Double.random(in: 0...1)

            let returnYards: Int
            if bigPlayChance < 0.003 {
                // ~0.3% chance of kick return TD (NFL realistic)
                returnYards = 100
            } else if bigPlayChance < 0.05 {
                // ~3% chance of big return (50-80 yards)
                returnYards = Int.random(in: 50...80)
            } else {
                returnYards = baseReturn
            }

            let rawYardLine = max(1, kickLandingSpot + returnYards)
            if rawYardLine >= 100 {
                // KICK RETURN TOUCHDOWN
                startingYardLine = 100
                description = "Kickoff returned ALL THE WAY by \(returnerName)! TOUCHDOWN!"
            } else {
                startingYardLine = rawYardLine
                description = "Kickoff returned by \(returnerName) to the \(startingYardLine) yard line."
            }
        }

        // Kickoff takes time off the clock
        game.clock.tick(seconds: 5)
        game.isKickoff = false

        let isReturnTD = startingYardLine >= 100

        if isReturnTD {
            // Kick return touchdown — receiving team scores
            // The receiving team is the team that does NOT have possession (kicking team has it)
            game.switchPossession() // Now receiving team has possession
            game.score.addScore(points: 6, isHome: game.isHomeTeamPossession, quarter: game.clock.quarter)
            game.isExtraPoint = true
            game.fieldPosition = FieldPosition(yardLine: 100)
        } else {
            game.fieldPosition = FieldPosition(yardLine: startingYardLine)
            game.downAndDistance = .firstDown(at: startingYardLine)
            game.startDrive()
        }

        currentGame = game

        return PlayResult(
            playType: .kickoff,
            description: description,
            yardsGained: startingYardLine,
            timeElapsed: 5,
            quarter: game.clock.quarter,
            timeRemaining: game.clock.timeRemaining,
            isFirstDown: !isReturnTD,
            isTouchdown: isReturnTD,
            isTurnover: false
        )
    }

    func executeOnsideKick() async -> PlayResult {
        guard var game = currentGame else {
            return PlayResult(
                playType: .onsideKick,
                description: "Onside kick error",
                yardsGained: 0,
                timeElapsed: 5,
                quarter: 1,
                timeRemaining: 900,
                isFirstDown: false,
                isTouchdown: false,
                isTurnover: false
            )
        }

        let kickingTeamName = game.isHomeTeamPossession ? (homeTeam?.name ?? "Home") : (awayTeam?.name ?? "Away")
        let receivingTeamName = game.isHomeTeamPossession ? (awayTeam?.name ?? "Away") : (homeTeam?.name ?? "Home")

        // Onside kick success rate: ~10-15% (NFL average ~10%)
        let successChance = Double.random(in: 0.10...0.15)
        let success = Double.random(in: 0...1) < successChance

        game.clock.tick(seconds: 5)
        game.isKickoff = false

        let description: String
        let startingYardLine: Int

        if success {
            // Kicking team recovers at ~45-50 yard line
            startingYardLine = Int.random(in: 45...50)
            description = "\(kickingTeamName) tries an onside kick... RECOVERED by \(kickingTeamName)! They get the ball at the \(startingYardLine)!"

            // Kicking team keeps possession (no switch needed)
            game.fieldPosition = FieldPosition(yardLine: startingYardLine)
            game.downAndDistance = .firstDown(at: startingYardLine)
            game.startDrive()
        } else {
            // Receiving team gets ball at ~45-50 (better field position than normal kickoff)
            let receiverYardLine = Int.random(in: 45...55)
            description = "\(kickingTeamName) tries an onside kick... \(receivingTeamName) recovers at the \(receiverYardLine)!"

            // Switch to receiving team
            game.switchPossession()
            game.fieldPosition = FieldPosition(yardLine: receiverYardLine)
            game.downAndDistance = .firstDown(at: receiverYardLine)
            game.startDrive()
            startingYardLine = receiverYardLine
        }

        currentGame = game

        return PlayResult(
            playType: .onsideKick,
            description: description,
            yardsGained: startingYardLine,
            timeElapsed: 5,
            quarter: game.clock.quarter,
            timeRemaining: game.clock.timeRemaining,
            isFirstDown: true,
            isTouchdown: false,
            isTurnover: !success
        )
    }

    func executeExtraPoint() async -> Bool {
        guard var game = currentGame,
              let kickingTeam = game.isHomeTeamPossession ? homeTeam : awayTeam else { return false }

        let kicker = kickingTeam.starter(at: .kicker)
        let accuracy = kicker?.ratings.kickAccuracy ?? 70

        // Extra points are from 15 yards (33 yard kick)
        // NFL XP rate is ~94%. Scale slightly by kicker accuracy around that baseline.
        let successChance = 0.94 + Double(accuracy - 70) * 0.002
        let success = Double.random(in: 0...1) < successChance

        if success {
            game.score.addScore(points: 1, isHome: game.isHomeTeamPossession, quarter: game.clock.quarter)
        }

        game.isExtraPoint = false

        // Kickoff to other team
        game.switchPossession()
        game.isKickoff = true

        currentGame = game
        return success
    }

    func executeTwoPointConversion() async -> Bool {
        guard var game = currentGame,
              let offTeam = game.isHomeTeamPossession ? homeTeam : awayTeam,
              let defTeam = game.isHomeTeamPossession ? awayTeam : homeTeam else { return false }

        // Resolve a single play from the 2-yard line
        let tempFieldPos = FieldPosition(yardLine: 98) // 2 yards from end zone
        let tempDown = DownAndDistance.firstDown(at: 98)

        let offCall = StandardPlayCall(formation: .goalLine, playType: .shortPass)
        let defCall = StandardDefensiveCall(formation: .goalLine, coverage: .manCoverage, isBlitzing: false)

        let outcome = playResolver.resolvePlay(
            offensiveCall: offCall,
            defensiveCall: defCall,
            offensiveTeam: offTeam,
            defensiveTeam: defTeam,
            fieldPosition: tempFieldPos,
            downAndDistance: tempDown,
            weather: game.weather
        )

        let success = outcome.isTouchdown || (outcome.isComplete && outcome.yardsGained >= 2)

        if success {
            game.score.addScore(points: 2, isHome: game.isHomeTeamPossession, quarter: game.clock.quarter)
        }

        game.isExtraPoint = false

        // Kickoff to other team
        game.switchPossession()
        game.isKickoff = true

        currentGame = game
        return success
    }

    func executeFieldGoal(from yardLine: Int) async -> Bool {
        guard var game = currentGame,
              let kickingTeam = game.isHomeTeamPossession ? homeTeam : awayTeam else { return false }

        let kicker = kickingTeam.starter(at: .kicker)
        let kickPower = kicker?.ratings.kickPower ?? 70
        let kickAccuracy = kicker?.ratings.kickAccuracy ?? 70

        let distance = 100 - yardLine + 17 // Add 17 for end zone + hold spot

        // Calculate success chance based on distance and ratings
        var successChance: Double
        if distance <= 30 {
            successChance = 0.95
        } else if distance <= 40 {
            successChance = 0.85
        } else if distance <= 50 {
            successChance = 0.70
        } else if distance <= 55 {
            successChance = 0.50
        } else {
            successChance = 0.30
        }

        // Modify by kicker ratings — centered around 1.0 so average kickers don't ruin base rates
        let ratingModifier = 0.85 + Double(kickPower + kickAccuracy) / 1000.0
        successChance *= ratingModifier

        // Weather effects
        if game.weather.affectsKicking {
            successChance *= 0.85
        }

        let success = Double.random(in: 0...1) < successChance

        if success {
            game.score.addScore(points: 3, isHome: game.isHomeTeamPossession, quarter: game.clock.quarter)
            game.endDrive(result: .fieldGoal)

            // After successful FG, kickoff to other team
            game.switchPossession()
            game.isKickoff = true
        } else {
            game.endDrive(result: .turnoverOnDowns)

            // Missed FG - ball goes to other team at spot of kick (or 20 if inside the 20)
            // NFL Rule: If kick is from outside 20, ball at spot. If inside 20, ball at 20.
            let spotOfKick = yardLine
            let twentyYardLine = 80  // 20 yards from opponent's goal (which is 100 - 20)

            if spotOfKick > twentyYardLine {
                // Kick from inside the 20 - other team gets ball at the 20
                game.fieldPosition.yardLine = 100 - 20
            } else {
                // Kick from outside the 20 - other team gets ball at spot of kick
                game.fieldPosition.yardLine = 100 - spotOfKick
            }

            // switchPossession() already flips fieldPosition — don't double-flip
            // Currently yardLine is from kicking team's view (e.g. 100-spot = receiving team's position in kicking view)
            // After switchPossession flips it → spot from receiving team's view (correct)
            game.switchPossession()
            game.downAndDistance = .firstDown(at: game.fieldPosition.yardLine)
            game.startDrive()
        }

        currentGame = game
        return success
    }

    func executePunt() async -> PlayResult {
        guard var game = currentGame,
              let puntingTeam = game.isHomeTeamPossession ? homeTeam : awayTeam,
              let receivingTeam = game.isHomeTeamPossession ? awayTeam : homeTeam else {
            return PlayResult(
                playType: .punt,
                description: "Punt error",
                yardsGained: 0,
                timeElapsed: 5,
                quarter: 1,
                timeRemaining: 900,
                isFirstDown: false,
                isTouchdown: false,
                isTurnover: false
            )
        }

        let punter = puntingTeam.starter(at: .punter)
        let kickPower = punter?.ratings.kickPower ?? 70
        let punterName = "\(punter?.firstName ?? "") \(punter?.lastName ?? "Smith")".trimmingCharacters(in: .whitespaces)

        let returner = receivingTeam.starter(at: .wideReceiver)
        let returnerName = "\(returner?.firstName ?? "") \(returner?.lastName ?? "Jones")".trimmingCharacters(in: .whitespaces)

        // Calculate gross punt distance
        let basePuntDistance = 40 + (kickPower - 70) / 2
        let grossPunt = basePuntDistance + Int.random(in: -10...10)

        // Calculate return yards (can be 0 for fair catch)
        let returnYards = Double.random(in: 0...1) < 0.25 ? 0 : Int.random(in: 0...15)

        // Net punt = gross - return
        let netPunt = grossPunt - returnYards

        // Where does the ball land from punting team's perspective?
        let landingSpot = game.fieldPosition.yardLine + netPunt

        let description: String
        let finalYardLine: Int

        // Check for touchback (punt into end zone)
        if landingSpot >= 100 {
            // Touchback - receiving team gets ball at their 20
            description = "\(punterName) punts \(grossPunt) yards into the end zone. Touchback to the 20."
            finalYardLine = 20

            game.endDrive(result: .punt)
            // switchPossession() flips fieldPosition, so set it AFTER the switch
            game.switchPossession()
            game.fieldPosition = FieldPosition(yardLine: 20)  // Receiving team's own 20
            game.downAndDistance = .firstDown(at: 20)
            game.startDrive()
        } else {
            // Normal punt - convert to receiving team's perspective
            game.endDrive(result: .punt)
            // landingSpot is from punting team's view; flip to receiving team's view
            game.fieldPosition.yardLine = 100 - landingSpot
            // switchPossession() also flips fieldPosition, so pre-set to the raw value
            // After switchPossession flips: 100 - (100 - landingSpot) = landingSpot from punting view
            // But we want receiving team's perspective: 100 - landingSpot
            // So set to landingSpot (punting view), let switchPossession flip it
            game.fieldPosition.yardLine = landingSpot
            game.switchPossession()  // This flips yardLine to 100 - landingSpot (receiving team's view)

            finalYardLine = game.fieldPosition.yardLine
            game.downAndDistance = .firstDown(at: finalYardLine)
            game.startDrive()

            if returnYards == 0 {
                description = "\(punterName) punts \(grossPunt) yards. Fair catch by \(returnerName) at the \(finalYardLine)."
            } else {
                description = "\(punterName) punts \(grossPunt) yards. Return of \(returnYards) by \(returnerName) to the \(finalYardLine)."
            }
        }

        currentGame = game

        return PlayResult(
            playType: .punt,
            description: description,
            yardsGained: netPunt,
            timeElapsed: 5,
            quarter: game.clock.quarter,
            timeRemaining: game.clock.timeRemaining,
            isFirstDown: false,
            isTouchdown: false,
            isTurnover: false
        )
    }

    // MARK: - Game Flow

    private func handleEndOfQuarter(game: inout Game) {
        if game.clock.quarter == 2 {
            // Halftime — reset timeouts and fatigue
            game.gameStatus = .halftime
            game.homeTimeouts = 3
            game.awayTimeouts = 3
            game.resetSnapCounts()
            game.clock.nextQuarter()
        } else if game.clock.quarter == 4 {
            // End of regulation
            if game.score.isTied {
                // Start overtime: 15:00 clock, coin-toss possession
                game.clock.nextQuarter()
                game.overtimePossessions = 0
                // Coin toss for OT — flip possession randomly
                if Bool.random() { game.switchPossession() }
                game.isKickoff = true
            } else {
                game.gameStatus = .final
            }
        } else if game.clock.quarter >= 5 {
            // End of overtime period
            if !game.score.isTied {
                game.gameStatus = .final
            } else {
                // Still tied — sudden death: next score wins
                game.clock.nextQuarter()
            }
        } else {
            game.clock.nextQuarter()
        }
    }

    func startSecondHalf() {
        guard var game = currentGame else { return }

        game.gameStatus = .inProgress
        // Note: quarter was already advanced to 3 in handleEndOfQuarter
        // Just reset the clock for Q3
        game.clock.timeRemaining = game.clock.quarterLengthSeconds

        // NFL Rule: Team that RECEIVED the opening kickoff, KICKS OFF to start second half
        // Opening kickoff went to away team, so home team receives second half kickoff
        // (We need to track who received opening kickoff - for now, switch from whoever has it)
        game.switchPossession()
        game.isKickoff = true

        currentGame = game
    }

    // MARK: - Stats

    private func updateStats(for game: inout Game, outcome: PlayOutcome, offensiveCall: any PlayCall) { // Changed to any PlayCall
        let yards = outcome.yardsGained
        let isSack = offensiveCall.playType.isPass && !outcome.isComplete && yards < 0 && !outcome.isTurnover

        if game.isHomeTeamPossession {
            game.homeTeamStats.totalYards += yards
            if isSack {
                // NFL rules: sack yards count as rushing yards lost, not passing
                game.homeTeamStats.rushingYards += yards
            } else if offensiveCall.playType.isPass {
                game.homeTeamStats.passingYards += yards
            } else if offensiveCall.playType.isRun {
                game.homeTeamStats.rushingYards += yards
            }
        } else {
            game.awayTeamStats.totalYards += yards
            if isSack {
                game.awayTeamStats.rushingYards += yards
            } else if offensiveCall.playType.isPass {
                game.awayTeamStats.passingYards += yards
            } else if offensiveCall.playType.isRun {
                game.awayTeamStats.rushingYards += yards
            }
        }

        // Update individual player stats
        updatePlayerStats(outcome: outcome, offensiveCall: offensiveCall, isSack: isSack)
    }

    /// Accumulate individual player stats from play outcome
    private func updatePlayerStats(outcome: PlayOutcome, offensiveCall: any PlayCall, isSack: Bool) {
        // Passer stats
        if let passerId = outcome.passerId {
            updatePlayerStat(playerId: passerId) { player in
                player.seasonStats.passAttempts += 1
                if outcome.isComplete {
                    player.seasonStats.passCompletions += 1
                    player.seasonStats.passingYards += outcome.yardsGained
                    if outcome.isTouchdown { player.seasonStats.passingTouchdowns += 1 }
                }
                if outcome.isTurnover && outcome.turnoverType == .interception {
                    player.seasonStats.interceptions += 1
                }
                if isSack {
                    player.seasonStats.sacks += 1
                }
            }
        }

        // Rusher stats
        if let rusherId = outcome.rusherId, offensiveCall.playType.isRun {
            updatePlayerStat(playerId: rusherId) { player in
                player.seasonStats.rushAttempts += 1
                player.seasonStats.rushingYards += outcome.yardsGained
                if outcome.isTouchdown { player.seasonStats.rushingTouchdowns += 1 }
                if outcome.isTurnover && outcome.turnoverType == .fumble {
                    player.seasonStats.fumbles += 1
                    player.seasonStats.fumblesLost += 1
                }
            }
        }

        // Receiver stats
        if let receiverId = outcome.receiverId, offensiveCall.playType.isPass {
            updatePlayerStat(playerId: receiverId) { player in
                player.seasonStats.targets += 1
                if outcome.isComplete {
                    player.seasonStats.receptions += 1
                    player.seasonStats.receivingYards += outcome.yardsGained
                    if outcome.isTouchdown { player.seasonStats.receivingTouchdowns += 1 }
                }
            }
        }

        // Tackler stats
        if let tacklerId = outcome.primaryTacklerId, outcome.isComplete || isSack {
            updatePlayerStat(playerId: tacklerId) { player in
                player.seasonStats.totalTackles += 1
                player.seasonStats.soloTackles += 1
                if isSack { player.seasonStats.defSacks += 1.0 }
                if outcome.isTurnover && outcome.turnoverType == .interception {
                    player.seasonStats.interceptionsDef += 1
                }
                if outcome.isTurnover && outcome.turnoverType == .fumble {
                    player.seasonStats.forcedFumbles += 1
                }
                if outcome.yardsGained < 0 { player.seasonStats.tacklesForLoss += 1 }
            }
        }
    }

    /// Find a player by UUID in either team's roster and apply a mutation
    private func updatePlayerStat(playerId: UUID, update: (inout Player) -> Void) {
        if let idx = homeTeam?.roster.firstIndex(where: { $0.id == playerId }) {
            update(&homeTeam!.roster[idx])
        } else if let idx = awayTeam?.roster.firstIndex(where: { $0.id == playerId }) {
            update(&awayTeam!.roster[idx])
        }
    }

    // MARK: - Injury Handling

    /// Process an injury from a play outcome using authentic INJURY.DAT names
    private func handleInjury(playerId: UUID, game: inout Game) -> String? {
        // Roll severity: 60% minor, 25% moderate, 12% major, 3% season-ending
        let roll = Double.random(in: 0...1)
        let injuryType: InjuryType
        if roll < 0.60 { injuryType = .minor }
        else if roll < 0.85 { injuryType = .moderate }
        else if roll < 0.97 { injuryType = .major }
        else { injuryType = .seasonEnding }

        let weeks = Int.random(in: injuryType.recoveryWeeks)

        // Load authentic injury name from INJURY.DAT
        let injuries = InjuryDecoder.loadDefault()
        let injuryName: String
        if !injuries.isEmpty {
            // Pick a random injury of matching severity
            let targetSeverity: GameInjury.InjurySeverity
            switch injuryType {
            case .minor: targetSeverity = .minor
            case .moderate: targetSeverity = .moderate
            case .major: targetSeverity = .major
            case .seasonEnding: targetSeverity = .severe
            }
            let matching = injuries.filter { $0.severity == targetSeverity }
            injuryName = (matching.randomElement() ?? injuries.randomElement()!).name
        } else {
            injuryName = injuryType.rawValue
        }

        // Update the player's status
        var playerName = "Unknown"
        var jerseyNum = 0
        updatePlayerStat(playerId: playerId) { player in
            player.status.injuryType = injuryType
            player.status.health = 40
            player.status.weeksInjured = weeks
            playerName = player.fullName
            jerseyNum = player.jerseyNumber
        }

        return "INJURY — #\(jerseyNum) \(playerName) (\(injuryName), out \(weeks) week\(weeks == 1 ? "" : "s"))"
    }

    private func updateTimeOfPossession(for game: inout Game, timeElapsed: Int) {
        if game.isHomeTeamPossession {
            game.homeTeamStats.timeOfPossession += timeElapsed
        } else {
            game.awayTeamStats.timeOfPossession += timeElapsed
        }
    }

    // MARK: - Fatigue Tracking

    /// Increment snap counts for all starters on the field after each play
    private func incrementSnapCounts(game: inout Game) {
        let offensiveTeam = game.isHomeTeamPossession ? homeTeam : awayTeam
        let defensiveTeam = game.isHomeTeamPossession ? awayTeam : homeTeam

        var onFieldIds: [UUID] = []

        // Offensive starters
        if let team = offensiveTeam {
            let offPositions: [Position] = [.quarterback, .runningBack, .fullback, .wideReceiver, .tightEnd,
                                             .leftTackle, .leftGuard, .center, .rightGuard, .rightTackle]
            for pos in offPositions {
                if let player = team.starter(at: pos) {
                    onFieldIds.append(player.id)
                }
            }
        }

        // Defensive starters
        if let team = defensiveTeam {
            let defPositions: [Position] = [.defensiveEnd, .defensiveTackle, .outsideLinebacker, .middleLinebacker,
                                             .cornerback, .freeSafety, .strongSafety]
            for pos in defPositions {
                if let player = team.starter(at: pos) {
                    onFieldIds.append(player.id)
                }
            }
        }

        game.incrementSnapCounts(playerIds: onFieldIds)
    }

    /// Get fatigue penalty for a specific player from the current game state
    func fatiguePenalty(for player: Player) -> Int {
        guard let game = currentGame else { return 0 }
        return game.fatiguePenalty(for: player.id, stamina: player.ratings.stamina)
    }

    // MARK: - CPU Play Calling

    func getCPUOffensiveCall(for team: Team, situation: GameSituation) -> any PlayCall { // Changed to any PlayCall
        aiCoach.selectOffensivePlay(for: team, situation: situation)
    }

    func getCPUDefensiveCall(for team: Team, situation: GameSituation) -> any DefensiveCall { // Changed to any DefensiveCall
        aiCoach.selectDefensivePlay(for: team, situation: situation)
    }

    // MARK: - Simulation

    func simulateToEnd() async {
        guard var game = currentGame else { return }

        var playCount = 0
        let maxPlays = 300 // Safeguard - typical game is ~150 plays total

        while game.gameStatus != .final && playCount < maxPlays {
            playCount += 1

            // Yield every 20 plays to keep UI responsive but fast
            if playCount % 20 == 0 {
                await Task.yield()
            }

            // Handle halftime
            if game.gameStatus == .halftime {
                startSecondHalf()
                guard let updatedGame = currentGame else { break }
                game = updatedGame
                continue
            }

            // Simulate one play at a time
            if game.isKickoff {
                // Check if AI should attempt onside kick
                let kickingScoreDiff = game.isHomeTeamPossession ?
                    game.score.homeScore - game.score.awayScore :
                    game.score.awayScore - game.score.homeScore
                let kickSituation = GameSituation(
                    down: 1, yardsToGo: 10, fieldPosition: 35,
                    quarter: game.clock.quarter,
                    timeRemaining: game.clock.timeRemaining,
                    scoreDifferential: kickingScoreDiff,
                    isRedZone: false
                )
                if aiCoach.shouldAttemptOnsideKick(situation: kickSituation) {
                    _ = await executeOnsideKick()
                } else {
                    _ = await executeKickoff()
                }
            } else if game.isExtraPoint {
                _ = await executeExtraPoint()
            } else {
                guard let offTeam = game.isHomeTeamPossession ? homeTeam : awayTeam,
                      let defTeam = game.isHomeTeamPossession ? awayTeam : homeTeam else {
                    break
                }

                let simOwnTimeouts = game.isHomeTeamPossession ? game.homeTimeouts : game.awayTimeouts
                let simOppTimeouts = game.isHomeTeamPossession ? game.awayTimeouts : game.homeTimeouts
                let situation = GameSituation(
                    down: game.downAndDistance.down,
                    yardsToGo: game.downAndDistance.yardsToGo,
                    fieldPosition: game.fieldPosition.yardLine,
                    quarter: game.clock.quarter,
                    timeRemaining: game.clock.timeRemaining,
                    scoreDifferential: game.isHomeTeamPossession ?
                        game.score.homeScore - game.score.awayScore :
                        game.score.awayScore - game.score.homeScore,
                    isRedZone: game.fieldPosition.isRedZone,
                    ownTimeouts: simOwnTimeouts,
                    opponentTimeouts: simOppTimeouts
                )

                // Handle 4th down decisions
                if game.downAndDistance.down == 4 {
                    let kicker = offTeam.starter(at: .kicker)
                    let decision = aiCoach.fourthDownDecision(situation: situation, kicker: kicker)

                    switch decision {
                    case .punt:
                        _ = await executePunt()
                        guard let updatedGame = currentGame else { break }
                        game = updatedGame
                        continue
                    case .fieldGoal:
                        _ = await executeFieldGoal(from: game.fieldPosition.yardLine)
                        guard let updatedGame = currentGame else { break }
                        game = updatedGame
                        continue
                    case .goForIt:
                        break // Fall through to normal play execution
                    }
                }

                let offCall = getCPUOffensiveCall(for: offTeam, situation: situation)
                let defCall = getCPUDefensiveCall(for: defTeam, situation: situation)

                _ = await executePlay(offensiveCall: offCall, defensiveCall: defCall)
            }

            guard let updatedGame = currentGame else { break }
            game = updatedGame
        }

        // If we hit max plays, force game to end
        if playCount >= maxPlays {
            currentGame?.gameStatus = .final
        }
    }
}

// MARK: - Game Situation

public struct GameSituation { // Made public
    public var down: Int
    public var yardsToGo: Int
    public var fieldPosition: Int
    public var quarter: Int
    public var timeRemaining: Int
    public var scoreDifferential: Int
    public var isRedZone: Bool
    public var ownTimeouts: Int
    public var opponentTimeouts: Int

    /// Convenience init that defaults timeouts to 3 (backward compatible)
    public init(down: Int, yardsToGo: Int, fieldPosition: Int, quarter: Int,
                timeRemaining: Int, scoreDifferential: Int, isRedZone: Bool,
                ownTimeouts: Int = 3, opponentTimeouts: Int = 3) {
        self.down = down
        self.yardsToGo = yardsToGo
        self.fieldPosition = fieldPosition
        self.quarter = quarter
        self.timeRemaining = timeRemaining
        self.scoreDifferential = scoreDifferential
        self.isRedZone = isRedZone
        self.ownTimeouts = ownTimeouts
        self.opponentTimeouts = opponentTimeouts
    }

    public var isLateGame: Bool {
        quarter == 4 && timeRemaining < 300
    }

    public var isTwoMinuteWarning: Bool {
        (quarter == 2 || quarter == 4) && timeRemaining <= 120
    }

    public var needsTouchdown: Bool {
        isLateGame && scoreDifferential < -3
    }

    public var shouldRunClock: Bool {
        isLateGame && scoreDifferential > 0
    }
}