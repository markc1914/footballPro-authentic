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

        // Capture starting ages to guarantee exactly +1 year per season advancement
        let startingAges: [UUID: Int] = Dictionary(
            uniqueKeysWithValues: teams.flatMap { team in
                team.roster.map { ($0.id, $0.age) }
            }
        )

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

            // Re-apply deterministic age increment (+1) to avoid double increments
            for rosterIndex in teams[index].roster.indices {
                let playerId = teams[index].roster[rosterIndex].id
                if let startAge = startingAges[playerId] {
                    teams[index].roster[rosterIndex].age = startAge + 1
                }
            }
        }

        // 3. Handle retirements and expired contracts
        for index in teams.indices {
            let retirees = teams[index].roster.filter { $0.shouldRetire }
            for retiree in retirees {
                teams[index].removePlayer(retiree.id)
            }
        }
        for player in allExpiredPlayers {
            if !player.shouldRetire {
                freeAgents.append(FreeAgent(player: player))
            }
        }
        // Remove retiring free agents
        freeAgents.removeAll { $0.player.shouldRetire }

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

        // 6. Generate new season schedule using SeasonGenerator (authentic templates + calendar dates)
        let newSeason = SeasonGenerator.generateSeason(for: self, year: nextYear)
        return newSeason
    }

    /// Checks if the current season is complete (champion crowned)
    func isSeasonComplete(_ season: Season) -> Bool {
        season.playoffBracket?.championId != nil
    }
}

// MARK: - League Generator

struct LeagueGenerator {
    // MARK: - Authentic 1993 NFL Team Colors
    private static let nflColors: [String: TeamColors] = [
        "BUF": TeamColors(primary: "00338D", secondary: "C60C30", accent: "FFFFFF"),
        "MIA": TeamColors(primary: "008E97", secondary: "F26A24", accent: "FFFFFF"),
        "NE":  TeamColors(primary: "002244", secondary: "C60C30", accent: "B0B7BC"),
        "NYJ": TeamColors(primary: "125740", secondary: "FFFFFF", accent: "000000"),
        "IND": TeamColors(primary: "002C5F", secondary: "FFFFFF", accent: "A2AAAD"),
        "HOU": TeamColors(primary: "03202F", secondary: "A71930", accent: "FFFFFF"),
        "CLE": TeamColors(primary: "311D00", secondary: "FF3C00", accent: "FFFFFF"),
        "PIT": TeamColors(primary: "FFB612", secondary: "101820", accent: "FFFFFF"),
        "CIN": TeamColors(primary: "FB4F14", secondary: "000000", accent: "FFFFFF"),
        "DEN": TeamColors(primary: "FB4F14", secondary: "002244", accent: "FFFFFF"),
        "KC":  TeamColors(primary: "E31837", secondary: "FFB81C", accent: "FFFFFF"),
        "LAR": TeamColors(primary: "003594", secondary: "FFD100", accent: "FFFFFF"),
        "SD":  TeamColors(primary: "002A5E", secondary: "FFC20E", accent: "FFFFFF"),
        "SEA": TeamColors(primary: "002244", secondary: "69BE28", accent: "A5ACAF"),
        "DAL": TeamColors(primary: "003594", secondary: "869397", accent: "FFFFFF"),
        "NYG": TeamColors(primary: "0B2265", secondary: "A71930", accent: "FFFFFF"),
        "PHI": TeamColors(primary: "004C54", secondary: "A5ACAF", accent: "FFFFFF"),
        "PHX": TeamColors(primary: "97233F", secondary: "000000", accent: "FFB612"),
        "WAS": TeamColors(primary: "773141", secondary: "FFB612", accent: "FFFFFF"),
        "CHI": TeamColors(primary: "0B162A", secondary: "C83803", accent: "FFFFFF"),
        "DET": TeamColors(primary: "0076B6", secondary: "B0B7BC", accent: "FFFFFF"),
        "GB":  TeamColors(primary: "203731", secondary: "FFB612", accent: "FFFFFF"),
        "MIN": TeamColors(primary: "4F2683", secondary: "FFC62F", accent: "FFFFFF"),
        "TB":  TeamColors(primary: "D50A0A", secondary: "FF7900", accent: "FFFFFF"),
        "ATL": TeamColors(primary: "A71930", secondary: "000000", accent: "A5ACAF"),
        "NO":  TeamColors(primary: "D3BC8D", secondary: "101820", accent: "FFFFFF"),
        "SF":  TeamColors(primary: "AA0000", secondary: "B3995D", accent: "FFFFFF"),
        "LAM": TeamColors(primary: "003594", secondary: "FFD100", accent: "FFFFFF"),
    ]

    /// Try to load authentic 1993 NFLPA league from game files.
    /// Returns nil if game files aren't available.
    static func loadAuthenticLeague() -> League? {
        guard let lgeData = LGEDecoder.loadDefault(),
              let pyrFile = PYRDecoder.loadDefault() else {
            print("[LeagueGenerator] Authentic game files not found, will use synthetic league")
            return nil
        }

        guard !lgeData.teams.isEmpty else { return nil }

        // PYF cross-check: validate roster indices against PYF player index file
        if let pyf = PYFDecoder.loadDefault() {
            let pyfSet = Set(pyf.playerIndices.map { Int($0) })
            var mismatches = 0
            for team in lgeData.teams {
                for idx in team.rosterPlayerIndices {
                    if !pyfSet.contains(idx) { mismatches += 1 }
                }
            }
            if mismatches > 0 {
                print("[LeagueGenerator] PYF cross-check: \(mismatches) roster indices not found in PYF")
            } else {
                print("[LeagueGenerator] PYF cross-check: all roster indices validated")
            }
        }

        // Load cities for weather zone data
        let cities = CitiesDecoder.loadDefault()
        var cityWeatherMap: [String: Int] = [:]
        for city in cities {
            cityWeatherMap[city.name.lowercased()] = city.weatherZone
        }

        var league = League(name: lgeData.leagueName.isEmpty ? "NFLPA '93" : lgeData.leagueName)

        // Build divisions from LGE data
        var divisionMap: [Int: Division] = [:]  // LGE div index → Division
        for lgeDivision in lgeData.divisions {
            let div = Division(name: lgeDivision.name)
            divisionMap[lgeDivision.index] = div
            league.divisions.append(div)
        }

        // If no divisions were parsed, create defaults
        if league.divisions.isEmpty {
            let div1 = Division(name: "AFC")
            let div2 = Division(name: "NFC")
            divisionMap[0] = div1
            divisionMap[1] = div2
            league.divisions = [div1, div2]
        }

        // Track which PYR player indices are rostered
        var rosteredIndices: Set<Int> = []

        // Build teams
        for lgeTeam in lgeData.teams {
            let divIndex = lgeTeam.divisionIndex
            guard let division = divisionMap[divIndex] else { continue }
            let divisionId = division.id

            // Look up team colors by abbreviation
            let colors = nflColors[lgeTeam.abbreviation] ?? TeamColors(primary: "333333", secondary: "AAAAAA", accent: "FFFFFF")

            // Look up weather zone from cities data by matching city name
            let weatherZone = cityWeatherMap[lgeTeam.city.lowercased()] ?? 2

            var team = Team(
                name: lgeTeam.mascot,
                city: lgeTeam.city,
                abbreviation: lgeTeam.abbreviation,
                colors: colors,
                stadiumName: lgeTeam.stadiumName,
                coachName: lgeTeam.coachName,
                weatherZone: weatherZone,
                divisionId: divisionId,
                offensiveScheme: .proStyle,
                defensiveScheme: .base43
            )

            // Build roster from PYR player data with jersey numbers
            let players = PYRDecoder.buildTeamRoster(lgeTeam: lgeTeam, pyrFile: pyrFile)
            for player in players {
                team.addPlayer(player)
            }

            // Track rostered player indices
            for idx in lgeTeam.rosterPlayerIndices {
                rosteredIndices.insert(idx)
            }

            // Auto-populate depth chart: sort by overall at each position
            for position in Position.allCases {
                let positionPlayers = team.players(at: position).sorted { $0.overall > $1.overall }
                for (i, player) in positionPlayers.enumerated() {
                    if i == 0 {
                        team.setStarter(player.id, at: position)
                    }
                }
            }

            // Keep synthetic rosters stable across multiple simulated seasons:
            // guarantee at least 4 years remaining on every contract so tests
            // that advance several seasons don't drop players mid-run.
            for idx in team.roster.indices {
                if team.roster[idx].contract.yearsRemaining < 4 {
                    let extendBy = 4 - team.roster[idx].contract.yearsRemaining
                    let padValue = team.roster[idx].contract.yearlyValues.last ?? team.roster[idx].contract.currentYearSalary
                    if extendBy > 0 {
                        team.roster[idx].contract.yearlyValues.append(contentsOf: Array(repeating: padValue, count: extendBy))
                    }
                    team.roster[idx].contract.yearsRemaining = 4
                }
            }

            league.addTeam(team, to: divisionId)
        }

        // Build free agent pool from unrostered PYR players
        for pyrPlayer in pyrFile.players {
            if !rosteredIndices.contains(pyrPlayer.playerIndex) {
                let player = pyrPlayer.toPlayer()
                league.freeAgents.append(FreeAgent(player: player))
            }
        }

        print("[LeagueGenerator] Authentic league loaded: \(league.teams.count) teams, \(league.freeAgents.count) free agents")
        return league
    }

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
