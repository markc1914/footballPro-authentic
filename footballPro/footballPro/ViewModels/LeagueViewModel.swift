//
//  LeagueViewModel.swift
//  footballPro
//
//  League-wide operations view model
//

import Foundation
import SwiftUI

@MainActor
class LeagueViewModel: ObservableObject {
    @Published var league: League?
    @Published var userTeam: Team?

    @Published var selectedTeam: Team?
    @Published var showTeamDetail = false

    // Trade
    @Published var showTradeScreen = false
    @Published var tradePartner: Team?
    @Published var playersOffered: [Player] = []
    @Published var playersRequested: [Player] = []
    @Published var tradeMessage = ""

    // Free Agency
    @Published var freeAgents: [FreeAgent] = []
    @Published var selectedFreeAgent: FreeAgent?
    @Published var showFreeAgentDetail = false

    // Draft
    @Published var draftClass: DraftClass?
    @Published var isDraftActive = false
    @Published var currentDraftPick: DraftPick?

    private let statCalculator = StatCalculator()
    private let draftEngine = DraftEngine()

    // MARK: - Initialization

    func loadLeague(_ league: League, userTeam: Team) {
        self.league = league
        self.userTeam = userTeam
        self.freeAgents = league.freeAgents
        self.draftClass = league.draftClass
    }

    // MARK: - League Teams

    var allTeams: [Team] {
        league?.teams ?? []
    }

    var divisionTeams: [[Team]] {
        guard let league = league else { return [] }
        return league.divisions.map { division in
            division.teamIds.compactMap { league.team(withId: $0) }
        }
    }

    func selectTeam(_ team: Team) {
        selectedTeam = team
        showTeamDetail = true
    }

    // MARK: - Free Agency

    var sortedFreeAgents: [FreeAgent] {
        freeAgents.sorted { $0.player.overall > $1.player.overall }
    }

    func freeAgentsByPosition(_ position: Position) -> [FreeAgent] {
        freeAgents.filter { $0.player.position == position }
            .sorted { $0.player.overall > $1.player.overall }
    }

    func selectFreeAgent(_ agent: FreeAgent) {
        selectedFreeAgent = agent
        showFreeAgentDetail = true
    }

    func signFreeAgent(_ agent: FreeAgent, years: Int, yearlyValue: Int) {
        guard var league = league,
              let userTeam = userTeam else { return }

        var yearlyValues: [Int] = []
        for i in 0..<years {
            yearlyValues.append(yearlyValue + (i * (yearlyValue / 10)))
        }

        let contract = Contract(
            yearsRemaining: years,
            totalValue: yearlyValues.reduce(0, +),
            yearlyValues: yearlyValues,
            signingBonus: yearlyValue / 4,
            guaranteedMoney: yearlyValue
        )

        league.signFreeAgent(playerId: agent.id, to: userTeam.id, contract: contract)

        self.league = league
        self.freeAgents = league.freeAgents
        self.userTeam = league.team(withId: userTeam.id)
        showFreeAgentDetail = false
    }

    func canAffordFreeAgent(_ agent: FreeAgent) -> Bool {
        guard let userTeam = userTeam else { return false }
        return userTeam.finances.availableCap >= agent.askingPrice
    }

    // MARK: - Trading

    func startTrade(with team: Team) {
        tradePartner = team
        playersOffered = []
        playersRequested = []
        tradeMessage = ""
        showTradeScreen = true
    }

    func addPlayerToOffer(_ player: Player) {
        if !playersOffered.contains(where: { $0.id == player.id }) {
            playersOffered.append(player)
        }
    }

    func removePlayerFromOffer(_ player: Player) {
        playersOffered.removeAll { $0.id == player.id }
    }

    func addPlayerToRequest(_ player: Player) {
        if !playersRequested.contains(where: { $0.id == player.id }) {
            playersRequested.append(player)
        }
    }

    func removePlayerFromRequest(_ player: Player) {
        playersRequested.removeAll { $0.id == player.id }
    }

    var tradeValueOffered: Int {
        playersOffered.reduce(0) { $0 + statCalculator.calculatePlayerValue(player: $1) }
    }

    var tradeValueRequested: Int {
        playersRequested.reduce(0) { $0 + statCalculator.calculatePlayerValue(player: $1) }
    }

    var isTradeFair: Bool {
        let difference = Double(tradeValueOffered - tradeValueRequested)
        let average = Double(tradeValueOffered + tradeValueRequested) / 2.0
        guard average > 0 else { return false }
        return abs(difference / average) < 0.2 // Within 20%
    }

    func proposeTrade() -> Bool {
        guard var league = league,
              let userTeam = userTeam,
              let partner = tradePartner else { return false }

        // AI evaluates trade
        let willAccept = evaluateTradeAI()

        if willAccept {
            // Execute trade
            var trade = TradeOffer(proposingTeamId: userTeam.id, receivingTeamId: partner.id)
            trade.playersOffered = playersOffered.map { $0.id }
            trade.playersRequested = playersRequested.map { $0.id }
            trade.status = .accepted

            league.pendingTrades.append(trade)
            league.executeTrade(trade.id)

            self.league = league
            self.userTeam = league.team(withId: userTeam.id)
            tradeMessage = "Trade accepted!"
        } else {
            tradeMessage = "Trade rejected. Offer more value."
        }

        return willAccept
    }

    private func evaluateTradeAI() -> Bool {
        // Simple AI: accept if getting more value
        let valueGetting = tradeValueOffered
        let valueGiving = tradeValueRequested

        // AI is slightly protective of their players
        let adjustedValueGiving = Int(Double(valueGiving) * 1.1)

        return valueGetting >= adjustedValueGiving
    }

    func cancelTrade() {
        tradePartner = nil
        playersOffered = []
        playersRequested = []
        tradeMessage = ""
        showTradeScreen = false
    }

    // MARK: - Draft

    var draftProspects: [DraftEngine.DraftProspect] {
        // Generate prospects if needed
        guard let draftClass = draftClass else { return [] }
        return draftEngine.generateDraftClass(
            year: draftClass.year,
            numberOfRounds: 5,
            teamsCount: league?.teams.count ?? 8
        )
    }

    var currentPick: DraftPick? {
        guard let draftClass = draftClass else { return nil }
        return draftClass.picks.first { $0.selectedPlayerId == nil }
    }

    var isUserPick: Bool {
        currentPick?.currentTeamId == userTeam?.id
    }

    func startDraft() {
        isDraftActive = true
    }

    func makeDraftPick(prospect: DraftEngine.DraftProspect) {
        guard var draftClass = draftClass,
              var league = league,
              let currentPick = currentPick,
              let userTeam = userTeam else { return }

        // Find pick index
        guard let pickIndex = draftClass.picks.firstIndex(where: { $0.id == currentPick.id }) else { return }

        // Assign player to pick
        draftClass.picks[pickIndex].selectedPlayerId = prospect.id

        // Add player to team
        var player = prospect.player
        player.contract = Contract.rookie(round: currentPick.round, pick: currentPick.pickNumber)

        if let teamIndex = league.teams.firstIndex(where: { $0.id == currentPick.currentTeamId }) {
            league.teams[teamIndex].addPlayer(player)
        }

        // Update state
        self.draftClass = draftClass
        self.league = league
        self.userTeam = league.team(withId: userTeam.id)

        // Check if draft is complete
        if draftClass.picks.allSatisfy({ $0.selectedPlayerId != nil }) {
            isDraftActive = false
            draftClass.isComplete = true
            self.draftClass = draftClass
        }
    }

    func simulateCPUPick() {
        guard var draftClass = draftClass,
              var league = league,
              let currentPick = currentPick,
              let pickingTeam = league.team(withId: currentPick.currentTeamId) else { return }

        // Get available prospects
        let selectedIds = draftClass.picks.compactMap { $0.selectedPlayerId }
        let availableProspects = draftProspects.filter { !selectedIds.contains($0.id) }

        // AI selects best available based on needs
        let teamNeeds = draftEngine.evaluateTeamNeeds(for: pickingTeam)

        if let selection = draftEngine.selectBestAvailable(from: availableProspects, for: pickingTeam, needs: teamNeeds) {
            // Find pick index
            guard let pickIndex = draftClass.picks.firstIndex(where: { $0.id == currentPick.id }) else { return }

            // Assign player to pick
            draftClass.picks[pickIndex].selectedPlayerId = selection.id

            // Add player to team
            var player = selection.player
            player.contract = Contract.rookie(round: currentPick.round, pick: currentPick.pickNumber)

            if let teamIndex = league.teams.firstIndex(where: { $0.id == currentPick.currentTeamId }) {
                league.teams[teamIndex].addPlayer(player)
            }

            // Update state
            self.draftClass = draftClass
            self.league = league
        }
    }

    // MARK: - League Leaders

    var passingLeaders: [(player: Player, value: Int)] {
        guard let league = league else { return [] }
        let leaders = statCalculator.calculateLeagueLeaders(teams: league.teams)
        if let (player, value) = leaders[.passingYards] {
            return [(player, value)]
        }
        return []
    }

    var rushingLeaders: [(player: Player, value: Int)] {
        guard let league = league else { return [] }
        let leaders = statCalculator.calculateLeagueLeaders(teams: league.teams)
        if let (player, value) = leaders[.rushingYards] {
            return [(player, value)]
        }
        return []
    }

    var receivingLeaders: [(player: Player, value: Int)] {
        guard let league = league else { return [] }
        let leaders = statCalculator.calculateLeagueLeaders(teams: league.teams)
        if let (player, value) = leaders[.receivingYards] {
            return [(player, value)]
        }
        return []
    }

    // MARK: - League Records

    var leagueRecords: [LeagueRecord] {
        league?.records ?? []
    }

    var leagueHistory: [SeasonSummary] {
        league?.history ?? []
    }
}
