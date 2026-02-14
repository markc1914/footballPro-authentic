//
//  TeamViewModel.swift
//  footballPro
//
//  Team management view model
//

import Foundation
import SwiftUI

@MainActor
class TeamViewModel: ObservableObject {
    @Published var team: Team?
    @Published var selectedPlayer: Player?
    @Published var selectedPosition: Position?

    @Published var sortOption: RosterSortOption = .position
    @Published var filterPosition: Position?

    @Published var showPlayerDetail = false
    @Published var showDepthChart = false
    @Published var showFinances = false

    // MARK: - Initialization

    func loadTeam(_ team: Team) {
        self.team = team
    }

    // MARK: - Roster Display

    enum RosterSortOption: String, CaseIterable {
        case position = "Position"
        case overall = "Overall"
        case name = "Name"
        case salary = "Salary"
        case age = "Age"
    }

    var sortedRoster: [Player] {
        guard let team = team else { return [] }

        var players = team.roster

        // Filter by position if set
        if let filterPos = filterPosition {
            players = players.filter { $0.position == filterPos }
        }

        // Sort
        switch sortOption {
        case .position:
            players.sort { positionOrder($0.position) < positionOrder($1.position) }
        case .overall:
            players.sort { $0.overall > $1.overall }
        case .name:
            players.sort { $0.lastName < $1.lastName }
        case .salary:
            players.sort { $0.contract.capHit > $1.contract.capHit }
        case .age:
            players.sort { $0.age < $1.age }
        }

        return players
    }

    private func positionOrder(_ position: Position) -> Int {
        let order: [Position] = [
            .quarterback, .runningBack, .fullback, .wideReceiver, .tightEnd,
            .leftTackle, .leftGuard, .center, .rightGuard, .rightTackle,
            .defensiveEnd, .defensiveTackle, .outsideLinebacker, .middleLinebacker,
            .cornerback, .freeSafety, .strongSafety,
            .kicker, .punter
        ]
        return order.firstIndex(of: position) ?? 99
    }

    var offensivePlayers: [Player] {
        sortedRoster.filter { $0.position.isOffense }
    }

    var defensivePlayers: [Player] {
        sortedRoster.filter { $0.position.isDefense }
    }

    var specialTeamsPlayers: [Player] {
        sortedRoster.filter { $0.position.isSpecialTeams }
    }

    // MARK: - Depth Chart

    var depthChartPositions: [Position] {
        Position.allCases.filter { !$0.isSpecialTeams }
    }

    func playersAtPosition(_ position: Position) -> [Player] {
        guard let team = team else { return [] }
        return team.players(at: position).sorted { $0.overall > $1.overall }
    }

    func starterAtPosition(_ position: Position) -> Player? {
        team?.starter(at: position)
    }

    func setStarter(_ player: Player, at position: Position) {
        team?.setStarter(player.id, at: position)
    }

    func depthString(for player: Player) -> String {
        guard let team = team,
              let depth = team.depthChart.depthPosition(for: player.id, at: player.position) else {
            return ""
        }

        switch depth {
        case 1: return "Starter"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(depth)th"
        }
    }

    // MARK: - Player Selection

    func selectPlayer(_ player: Player) {
        selectedPlayer = player
        showPlayerDetail = true
    }

    func clearSelection() {
        selectedPlayer = nil
        showPlayerDetail = false
    }

    // MARK: - Team Stats

    var teamOverallRating: Int {
        team?.overallRating ?? 0
    }

    var offensiveRating: Int {
        team?.offensiveRating ?? 0
    }

    var defensiveRating: Int {
        team?.defensiveRating ?? 0
    }

    var specialTeamsRating: Int {
        team?.specialTeamsRating ?? 0
    }

    var rosterCount: Int {
        team?.roster.count ?? 0
    }

    var injuredCount: Int {
        team?.injuredPlayers.count ?? 0
    }

    // MARK: - Finances

    var salaryCap: Int {
        team?.finances.salaryCap ?? 0
    }

    var currentPayroll: Int {
        team?.finances.currentPayroll ?? 0
    }

    var availableCap: Int {
        team?.finances.availableCap ?? 0
    }

    var deadMoney: Int {
        team?.finances.deadMoney ?? 0
    }

    var capPercentageUsed: Double {
        team?.finances.capPercentageUsed ?? 0
    }

    var topPaidPlayers: [Player] {
        guard let team = team else { return [] }
        return team.roster.sorted { $0.contract.capHit > $1.contract.capHit }.prefix(10).map { $0 }
    }

    // MARK: - Roster Actions

    func releasePlayer(_ player: Player) {
        guard var team = team else { return }
        team.removePlayer(player.id, cutMidSeason: true)
        self.team = team
        clearSelection()
    }

    func extendContract(_ player: Player, years: Int, yearlyValue: Int) {
        guard var team = team,
              let index = team.roster.firstIndex(where: { $0.id == player.id }) else { return }

        var newYearlyValues: [Int] = []
        for i in 0..<years {
            newYearlyValues.append(yearlyValue + (i * (yearlyValue / 10)))
        }

        let newContract = Contract(
            yearsRemaining: years,
            totalValue: newYearlyValues.reduce(0, +),
            yearlyValues: newYearlyValues,
            signingBonus: yearlyValue / 4,
            guaranteedMoney: yearlyValue * 2
        )

        team.roster[index].contract = newContract
        self.team = team
    }

    // MARK: - Position Groups Display

    struct PositionGroup: Identifiable {
        let id = UUID()
        let name: String
        let positions: [Position]
    }

    var positionGroups: [PositionGroup] {
        [
            PositionGroup(name: "Quarterbacks", positions: [.quarterback]),
            PositionGroup(name: "Running Backs", positions: [.runningBack, .fullback]),
            PositionGroup(name: "Receivers", positions: [.wideReceiver, .tightEnd]),
            PositionGroup(name: "Offensive Line", positions: [.leftTackle, .leftGuard, .center, .rightGuard, .rightTackle]),
            PositionGroup(name: "Defensive Line", positions: [.defensiveEnd, .defensiveTackle]),
            PositionGroup(name: "Linebackers", positions: [.outsideLinebacker, .middleLinebacker]),
            PositionGroup(name: "Secondary", positions: [.cornerback, .freeSafety, .strongSafety]),
            PositionGroup(name: "Special Teams", positions: [.kicker, .punter])
        ]
    }

    func playersInGroup(_ group: PositionGroup) -> [Player] {
        guard let team = team else { return [] }
        return team.roster.filter { group.positions.contains($0.position) }
            .sorted { $0.overall > $1.overall }
    }
}
