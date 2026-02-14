//
//  League.swift
//  footballPro
//
//  League structure with all teams and settings
//

import Foundation

// MARK: - League Settings

struct LeagueSettings: Codable, Equatable {
    var salaryCap: Int = 225000 // In thousands
    var minSalary: Int = 750 // Minimum player salary in thousands
    var rosterSize: Int = 53
    var practiceSquadSize: Int = 16
    var injuryFrequency: Double = 0.05 // Chance of injury per play
    var tradeDeadlineWeek: Int = 10
    var simulationSpeed: SimulationSpeed = .normal

    enum SimulationSpeed: String, Codable, CaseIterable {
        case slow = "Slow"
        case normal = "Normal"
        case fast = "Fast"
        case instant = "Instant"

        var delayMs: Int {
            switch self {
            case .slow: return 2000
            case .normal: return 1000
            case .fast: return 500
            case .instant: return 0
            }
        }
    }
}

// MARK: - League Records

struct LeagueRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var category: RecordCategory
    var value: Int
    var playerName: String
    var teamAbbreviation: String
    var seasonYear: Int
    var isSingleGame: Bool

    init(category: RecordCategory, value: Int, playerName: String, teamAbbreviation: String, seasonYear: Int, isSingleGame: Bool) {
        self.id = UUID()
        self.category = category
        self.value = value
        self.playerName = playerName
        self.teamAbbreviation = teamAbbreviation
        self.seasonYear = seasonYear
        self.isSingleGame = isSingleGame
    }
}

enum RecordCategory: String, Codable, CaseIterable {
    case passingYards = "Passing Yards"
    case passingTouchdowns = "Passing Touchdowns"
    case rushingYards = "Rushing Yards"
    case rushingTouchdowns = "Rushing Touchdowns"
    case receivingYards = "Receiving Yards"
    case receivingTouchdowns = "Receiving Touchdowns"
    case receptions = "Receptions"
    case sacks = "Sacks"
    case interceptions = "Interceptions"
    case tackles = "Tackles"
}

// MARK: - League History

struct SeasonSummary: Identifiable, Codable, Equatable {
    let id: UUID
    var year: Int
    var championTeamId: UUID
    var championTeamName: String
    var runnerUpTeamId: UUID
    var runnerUpTeamName: String
    var mvpPlayerId: UUID?
    var mvpPlayerName: String?

    init(year: Int, championTeamId: UUID, championTeamName: String, runnerUpTeamId: UUID, runnerUpTeamName: String) {
        self.id = UUID()
        self.year = year
        self.championTeamId = championTeamId
        self.championTeamName = championTeamName
        self.runnerUpTeamId = runnerUpTeamId
        self.runnerUpTeamName = runnerUpTeamName
    }
}

// MARK: - Free Agent

struct FreeAgent: Identifiable, Codable, Equatable {
    let id: UUID
    var player: Player
    var askingPrice: Int // Yearly salary in thousands
    var interestLevel: [UUID: Int] // TeamId -> Interest (1-100)

    init(player: Player) {
        self.id = player.id
        self.player = player
        // Calculate asking price based on rating and position
        let basePrice = player.overall * 50
        let positionMultiplier: Double
        switch player.position {
        case .quarterback: positionMultiplier = 2.5
        case .leftTackle, .cornerback: positionMultiplier = 1.5
        case .wideReceiver, .defensiveEnd: positionMultiplier = 1.3
        default: positionMultiplier = 1.0
        }
        self.askingPrice = Int(Double(basePrice) * positionMultiplier)
        self.interestLevel = [:]
    }
}

// MARK: - Draft Pick

struct DraftPick: Identifiable, Codable, Equatable {
    let id: UUID
    var round: Int
    var pickNumber: Int
    var originalTeamId: UUID
    var currentTeamId: UUID
    var selectedPlayerId: UUID?

    var isTraded: Bool {
        originalTeamId != currentTeamId
    }

    init(round: Int, pickNumber: Int, teamId: UUID) {
        self.id = UUID()
        self.round = round
        self.pickNumber = pickNumber
        self.originalTeamId = teamId
        self.currentTeamId = teamId
    }
}

struct DraftClass: Codable, Equatable {
    var year: Int
    var prospects: [Player]
    var picks: [DraftPick]
    var currentRound: Int
    var currentPick: Int
    var isComplete: Bool

    init(year: Int, teams: [Team]) {
        self.year = year
        self.prospects = []
        self.picks = []
        self.currentRound = 1
        self.currentPick = 1
        self.isComplete = false

        // Generate picks for 5 rounds
        for round in 1...5 {
            for (index, team) in teams.enumerated() {
                let pickNumber = (round - 1) * teams.count + index + 1
                picks.append(DraftPick(round: round, pickNumber: pickNumber, teamId: team.id))
            }
        }
    }
}

// MARK: - Trade

struct TradeOffer: Identifiable, Codable, Equatable {
    let id: UUID
    var proposingTeamId: UUID
    var receivingTeamId: UUID
    var playersOffered: [UUID]
    var playersRequested: [UUID]
    var picksOffered: [UUID]
    var picksRequested: [UUID]
    var status: TradeStatus
    var expirationWeek: Int

    init(proposingTeamId: UUID, receivingTeamId: UUID) {
        self.id = UUID()
        self.proposingTeamId = proposingTeamId
        self.receivingTeamId = receivingTeamId
        self.playersOffered = []
        self.playersRequested = []
        self.picksOffered = []
        self.picksRequested = []
        self.status = .pending
        self.expirationWeek = 0
    }
}

enum TradeStatus: String, Codable {
    case pending
    case accepted
    case rejected
    case countered
    case expired
}

// MARK: - League

struct League: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var teams: [Team]
    var divisions: [Division]
    var settings: LeagueSettings

    var freeAgents: [FreeAgent]
    var draftClass: DraftClass?
    var pendingTrades: [TradeOffer]

    var records: [LeagueRecord]
    var history: [SeasonSummary]

    init(name: String = "Football Pro League") {
        self.id = UUID()
        self.name = name
        self.teams = []
        self.divisions = []
        self.settings = LeagueSettings()
        self.freeAgents = []
        self.draftClass = nil
        self.pendingTrades = []
        self.records = []
        self.history = []
    }

    func team(withId id: UUID) -> Team? {
        teams.first { $0.id == id }
    }

    func team(withAbbreviation abbr: String) -> Team? {
        teams.first { $0.abbreviation == abbr }
    }

    func division(for teamId: UUID) -> Division? {
        divisions.first { $0.teamIds.contains(teamId) }
    }

    func divisionalOpponents(for teamId: UUID) -> [Team] {
        guard let division = division(for: teamId) else { return [] }
        return division.teamIds
            .filter { $0 != teamId }
            .compactMap { team(withId: $0) }
    }

    mutating func addTeam(_ team: Team, to divisionId: UUID) {
        teams.append(team)
        if let index = divisions.firstIndex(where: { $0.id == divisionId }) {
            divisions[index].teamIds.append(team.id)
        }
    }

    mutating func signFreeAgent(playerId: UUID, to teamId: UUID, contract: Contract) {
        guard let faIndex = freeAgents.firstIndex(where: { $0.id == playerId }),
              let teamIndex = teams.firstIndex(where: { $0.id == teamId }) else { return }

        var player = freeAgents[faIndex].player
        player.contract = contract
        teams[teamIndex].addPlayer(player)
        freeAgents.remove(at: faIndex)
    }

    mutating func releasePlayer(playerId: UUID, from teamId: UUID) {
        guard let teamIndex = teams.firstIndex(where: { $0.id == teamId }),
              let player = teams[teamIndex].player(withId: playerId) else { return }

        teams[teamIndex].removePlayer(playerId, cutMidSeason: true)
        freeAgents.append(FreeAgent(player: player))
    }

    mutating func executeTrade(_ tradeId: UUID) {
        guard let tradeIndex = pendingTrades.firstIndex(where: { $0.id == tradeId }),
              pendingTrades[tradeIndex].status == .accepted else { return }

        let trade = pendingTrades[tradeIndex]

        guard let team1Index = teams.firstIndex(where: { $0.id == trade.proposingTeamId }),
              let team2Index = teams.firstIndex(where: { $0.id == trade.receivingTeamId }) else { return }

        // Move players
        for playerId in trade.playersOffered {
            if let player = teams[team1Index].player(withId: playerId) {
                teams[team1Index].removePlayer(playerId)
                teams[team2Index].addPlayer(player)
            }
        }

        for playerId in trade.playersRequested {
            if let player = teams[team2Index].player(withId: playerId) {
                teams[team2Index].removePlayer(playerId)
                teams[team1Index].addPlayer(player)
            }
        }

        // Move draft picks
        if var draft = draftClass {
            for pickId in trade.picksOffered {
                if let pickIndex = draft.picks.firstIndex(where: { $0.id == pickId }) {
                    draft.picks[pickIndex].currentTeamId = trade.receivingTeamId
                }
            }
            for pickId in trade.picksRequested {
                if let pickIndex = draft.picks.firstIndex(where: { $0.id == pickId }) {
                    draft.picks[pickIndex].currentTeamId = trade.proposingTeamId
                }
            }
            draftClass = draft
        }

        pendingTrades.remove(at: tradeIndex)
    }

    mutating func checkRecord(category: RecordCategory, value: Int, playerName: String, teamAbbr: String, year: Int, isSingleGame: Bool) {
        let existingRecord = records.first { $0.category == category && $0.isSingleGame == isSingleGame }

        if let existing = existingRecord {
            if value > existing.value {
                // New record!
                if let index = records.firstIndex(where: { $0.id == existing.id }) {
                    records[index] = LeagueRecord(
                        category: category,
                        value: value,
                        playerName: playerName,
                        teamAbbreviation: teamAbbr,
                        seasonYear: year,
                        isSingleGame: isSingleGame
                    )
                }
            }
        } else {
            // First record in this category
            records.append(LeagueRecord(
                category: category,
                value: value,
                playerName: playerName,
                teamAbbreviation: teamAbbr,
                seasonYear: year,
                isSingleGame: isSingleGame
            ))
        }
    }

    // MARK: - Season Advancement

    /// Advances the league to the next season
    /// - Parameter completedSeason: The season that just completed
    /// - Returns: The new season for the next year
    mutating func advanceToNextSeason(completedSeason: Season) -> Season {
        let nextYear = completedSeason.year + 1

        // 1. Record season history
        if let championId = completedSeason.playoffBracket?.championId,
           let championTeam = team(withId: championId) {
            // Find runner-up from championship game
            let championshipGames = completedSeason.playoffBracket?.games(for: .championship) ?? []
            var runnerUpId = championId
            var runnerUpName = championTeam.fullName

            if let championship = championshipGames.first {
                runnerUpId = championship.homeTeamId == championId ? championship.awayTeamId : championship.homeTeamId
                if let runnerUp = team(withId: runnerUpId) {
                    runnerUpName = runnerUp.fullName
                }
            }

            let summary = SeasonSummary(
                year: completedSeason.year,
                championTeamId: championId,
                championTeamName: championTeam.fullName,
                runnerUpTeamId: runnerUpId,
                runnerUpTeamName: runnerUpName
            )
            history.append(summary)
        }

        // 2. Archive all player stats and advance to next season
        var allExpiredPlayers: [Player] = []
        for index in teams.indices {
            teams[index].archiveAllPlayerStats()
            teams[index].advanceAllPlayersToNextSeason()
            let expired = teams[index].releaseExpiredContracts()
            allExpiredPlayers.append(contentsOf: expired)
            teams[index].resetRecord()
        }

        // 3. Add expired contract players to free agents
        for player in allExpiredPlayers {
            freeAgents.append(FreeAgent(player: player))
        }

        // 4. Generate new draft class
        draftClass = DraftClass(year: nextYear, teams: teams)
        var prospects: [Player] = []
        let draftPositions: [Position] = [
            .quarterback, .runningBack, .wideReceiver, .wideReceiver, .tightEnd,
            .leftTackle, .leftGuard, .center, .defensiveEnd, .defensiveTackle,
            .outsideLinebacker, .middleLinebacker, .cornerback, .cornerback,
            .freeSafety, .strongSafety
        ]

        for round in 1...5 {
            for position in draftPositions {
                let tier: PlayerTier
                switch round {
                case 1: tier = Bool.random() ? .elite : .starter
                case 2: tier = Bool.random() ? .starter : .backup
                case 3: tier = .backup
                default: tier = Bool.random() ? .backup : .reserve
                }
                var prospect = PlayerGenerator.generate(position: position, tier: tier)
                prospect.age = Int.random(in: 21...23)
                prospect.experience = 0
                prospects.append(prospect)
            }
        }
        draftClass?.prospects = prospects.shuffled()

        // 5. Clear pending trades
        pendingTrades.removeAll()

        // 6. Generate new season schedule
        var newSeason = Season(year: nextYear, divisions: divisions)

        // Initialize standings for all teams
        for team in teams {
            newSeason.standings[team.id] = StandingsEntry(teamId: team.id)
        }

        // Generate schedule
        var schedule: [ScheduledGame] = []
        let allTeamIds = teams.map { $0.id }

        for week in 1...14 {
            var weekGames: [ScheduledGame] = []
            var scheduled: Set<UUID> = []

            for i in 0..<allTeamIds.count {
                let teamA = allTeamIds[i]
                if scheduled.contains(teamA) { continue }

                let opponentIndex = (i + week) % allTeamIds.count
                let teamB = allTeamIds[opponentIndex]

                if teamA == teamB || scheduled.contains(teamB) { continue }

                let isTeamAHome = (week + i) % 2 == 0
                let game = ScheduledGame(
                    homeTeamId: isTeamAHome ? teamA : teamB,
                    awayTeamId: isTeamAHome ? teamB : teamA,
                    week: week
                )

                weekGames.append(game)
                scheduled.insert(teamA)
                scheduled.insert(teamB)
            }

            schedule.append(contentsOf: weekGames)
        }

        newSeason.schedule = schedule
        return newSeason
    }

    /// Checks if the current season is complete (champion crowned)
    func isSeasonComplete(_ season: Season) -> Bool {
        season.playoffBracket?.championId != nil
    }
}

// MARK: - League Generator

struct LeagueGenerator {
    static func generateLeague() -> League {
        var league = League()

        // Create 2 divisions
        let division1 = Division(name: "Western Division")
        let division2 = Division(name: "Eastern Division")

        league.divisions = [division1, division2]

        // Generate 8 teams (4 per division)
        for i in 0..<8 {
            let divisionId = i < 4 ? division1.id : division2.id
            let team = TeamGenerator.generateTeam(index: i, divisionId: divisionId)
            league.addTeam(team, to: divisionId)
        }

        // Generate some free agents
        for position in Position.allCases {
            let numFreeAgents = Int.random(in: 2...4)
            for _ in 0..<numFreeAgents {
                let tier: PlayerTier = Bool.random() ? .backup : .reserve
                let player = PlayerGenerator.generate(position: position, tier: tier)
                league.freeAgents.append(FreeAgent(player: player))
            }
        }

        // Initialize draft class
        league.draftClass = DraftClass(year: 2025, teams: league.teams)

        // Generate draft prospects
        var prospects: [Player] = []
        let draftPositions: [Position] = [
            .quarterback, .runningBack, .wideReceiver, .wideReceiver, .tightEnd,
            .leftTackle, .leftGuard, .center, .defensiveEnd, .defensiveTackle,
            .outsideLinebacker, .middleLinebacker, .cornerback, .cornerback,
            .freeSafety, .strongSafety
        ]

        for round in 1...5 {
            for position in draftPositions {
                let tier: PlayerTier
                switch round {
                case 1: tier = Bool.random() ? .elite : .starter
                case 2: tier = Bool.random() ? .starter : .backup
                case 3: tier = .backup
                default: tier = Bool.random() ? .backup : .reserve
                }
                var prospect = PlayerGenerator.generate(position: position, tier: tier)
                prospect.age = Int.random(in: 21...23) // Rookies
                prospect.experience = 0
                prospects.append(prospect)
            }
        }

        league.draftClass?.prospects = prospects.shuffled()

        return league
    }
}
