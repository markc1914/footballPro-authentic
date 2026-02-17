//
//  Team.swift
//  footballPro
//
//  Team model with roster, depth chart, and finances
//

import Foundation
import SwiftUI

// MARK: - Team Colors

public struct TeamColors: Codable, Equatable { // Public
    public var primary: String // Hex color
    public var secondary: String // Hex color
    public var accent: String // Hex color

    public var primaryColor: Color {
        Color(hex: primary)
    }

    public var secondaryColor: Color {
        Color(hex: secondary)
    }

    public var accentColor: Color {
        Color(hex: accent)
    }
}

public extension Color { // Public extension
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Roster Slot System (FPS '93 authentic 47-slot structure)

/// The type of a roster slot — assigned to a specific position, open (flex), or injured reserve.
public enum SlotType: Codable, Equatable {
    case assigned(Position)
    case open
    case injuredReserve
}

/// A single slot in the 47-slot roster structure.
/// 34 assigned (position-specific) + 11 open (any position) + 2 IR.
public struct RosterSlot: Codable, Equatable, Identifiable {
    public let id: UUID
    public let slotType: SlotType
    public var playerId: UUID?

    public init(id: UUID = UUID(), slotType: SlotType, playerId: UUID? = nil) {
        self.id = id
        self.slotType = slotType
        self.playerId = playerId
    }

    public var isEmpty: Bool { playerId == nil }
}

/// Generates the authentic FPS '93 47-slot roster template.
/// 34 assigned: QB(2), RB(3), WR/TE(5), OL(6), DL(4), LB(5), DB(7), K(1), P(1)
/// 11 open slots, 2 IR slots.
public struct RosterSlotTemplate {
    public static let assignedSlots: [(Position, Int)] = [
        (.quarterback, 2),
        (.runningBack, 2),
        (.fullback, 1),
        (.wideReceiver, 3),
        (.tightEnd, 2),
        (.leftTackle, 1),
        (.leftGuard, 1),
        (.center, 1),
        (.rightGuard, 1),
        (.rightTackle, 1),
        (.defensiveEnd, 2),
        (.defensiveTackle, 2),
        (.outsideLinebacker, 3),
        (.middleLinebacker, 2),
        (.cornerback, 4),
        (.freeSafety, 1),
        (.strongSafety, 2),
        (.kicker, 1),
        (.punter, 1),
    ]

    public static let openSlotCount = 11
    public static let irSlotCount = 2
    public static let totalSlots = 47

    /// Create a fresh set of 47 empty roster slots.
    public static func makeSlots() -> [RosterSlot] {
        var slots: [RosterSlot] = []
        for (position, count) in assignedSlots {
            for _ in 0..<count {
                slots.append(RosterSlot(slotType: .assigned(position)))
            }
        }
        for _ in 0..<openSlotCount {
            slots.append(RosterSlot(slotType: .open))
        }
        for _ in 0..<irSlotCount {
            slots.append(RosterSlot(slotType: .injuredReserve))
        }
        return slots
    }
}

// MARK: - Depth Chart

public struct DepthChart: Codable, Equatable { // Public
    public var positions: [Position: [UUID]] // Position -> Array of player IDs in order

    public init() {
        positions = [:]
        for position in Position.allCases {
            positions[position] = []
        }
    }

    public mutating func setStarter(_ playerId: UUID, at position: Position) {
        var list = positions[position] ?? []
        list.removeAll { $0 == playerId }
        list.insert(playerId, at: 0)
        positions[position] = list
    }

    public mutating func addPlayer(_ playerId: UUID, at position: Position) {
        var list = positions[position] ?? []
        if !list.contains(playerId) {
            list.append(playerId)
        }
        positions[position] = list
    }

    public mutating func removePlayer(_ playerId: UUID) {
        for (position, var list) in positions {
            list.removeAll { $0 == playerId }
            positions[position] = list
        }
    }

    public func starter(at position: Position) -> UUID? {
        positions[position]?.first
    }

    public func backups(at position: Position) -> [UUID] {
        guard let list = positions[position], list.count > 1 else { return [] }
        return Array(list.dropFirst())
    }

    public func depthPosition(for playerId: UUID, at position: Position) -> Int? {
        positions[position]?.firstIndex(of: playerId).map { $0 + 1 }
    }
}

// MARK: - Team Finances

public struct TeamFinances: Codable, Equatable { // Public
    public var salaryCap: Int // Total cap in thousands
    public var currentPayroll: Int // Active payroll in thousands
    public var deadMoney: Int // Dead cap from released players

    public var availableCap: Int {
        salaryCap - currentPayroll - deadMoney
    }

    public var capPercentageUsed: Double {
        Double(currentPayroll + deadMoney) / Double(salaryCap) * 100
    }

    public static var standard: TeamFinances {
        TeamFinances(salaryCap: 225000, currentPayroll: 0, deadMoney: 0)
    }

    public mutating func addContract(_ contract: Contract) {
        currentPayroll += contract.capHit
    }

    public mutating func removeContract(_ contract: Contract, cutMidSeason: Bool = false) {
        currentPayroll -= contract.capHit
        if cutMidSeason {
            deadMoney += contract.guaranteedMoney / contract.yearsRemaining
        }
    }
}

// MARK: - Team Record

public struct TeamRecord: Codable, Equatable { // Public
    public var wins: Int = 0
    public var losses: Int = 0
    public var ties: Int = 0

    public var divisionWins: Int = 0
    public var divisionLosses: Int = 0
    public var divisionTies: Int = 0

    public var conferenceWins: Int = 0
    public var conferenceLosses: Int = 0
    public var conferenceTies: Int = 0

    public var pointsFor: Int = 0
    public var pointsAgainst: Int = 0

    public var gamesPlayed: Int {
        wins + losses + ties
    }

    public var winPercentage: Double {
        guard gamesPlayed > 0 else { return 0 }
        return (Double(wins) + (Double(ties) * 0.5)) / Double(gamesPlayed)
    }

    public var pointDifferential: Int {
        pointsFor - pointsAgainst
    }

    public var displayRecord: String {
        if ties > 0 {
            return "\(wins)-\(losses)-\(ties)"
        }
        return "\(wins)-\(losses)"
    }

    public mutating func recordWin(points: Int, opponentPoints: Int, isDivision: Bool, isConference: Bool) {
        wins += 1
        pointsFor += points
        pointsAgainst += opponentPoints
        if isDivision {
            divisionWins += 1
        }
        if isConference {
            conferenceWins += 1
        }
    }

    public mutating func recordLoss(points: Int, opponentPoints: Int, isDivision: Bool, isConference: Bool) {
        losses += 1
        pointsFor += points
        pointsAgainst += opponentPoints
        if isDivision {
            divisionLosses += 1
        }
        if isConference {
            conferenceLosses += 1
        }
    }
}

// MARK: - Offensive/Defensive Scheme

public enum OffensiveScheme: String, Codable, CaseIterable { // Public
    case westCoast = "West Coast"
    case airRaid = "Air Raid"
    case spreadOption = "Spread Option"
    case proStyle = "Pro Style"
    case powerRun = "Power Run"

    public var description: String {
        switch self {
        case .westCoast: return "Short, quick passes to move the chains"
        case .airRaid: return "Aggressive vertical passing attack"
        case .spreadOption: return "RPO-heavy with QB running threat"
        case .proStyle: return "Balanced attack with play-action"
        case .powerRun: return "Physical ground game with heavy sets"
        }
    }
}

public enum DefensiveScheme: String, Codable, CaseIterable { // Public
    case base43 = "4-3 Base"
    case base34 = "3-4 Base"
    case nickel = "Nickel"
    case dime = "Dime"
    case tampa2 = "Tampa 2"

    public var description: String {
        switch self {
        case .base43: return "Four down linemen, three linebackers"
        case .base34: return "Three down linemen, four linebackers"
        case .nickel: return "Five defensive backs, pass-focused"
        case .dime: return "Six defensive backs, prevent defense"
        case .tampa2: return "Cover 2 zone with LB dropping deep"
        }
    }
}

// MARK: - Team

public struct Team: Identifiable, Codable, Equatable { // Public
    public let id: UUID
    public var name: String // e.g., "Eagles"
    public var city: String // e.g., "Philadelphia"
    public var abbreviation: String // e.g., "PHI"
    public var colors: TeamColors
    public var stadiumName: String
    public var coachName: String
    public var weatherZone: Int
    public var divisionId: UUID

    public var roster: [Player]
    public var rosterSlots: [RosterSlot]
    public var depthChart: DepthChart
    public var finances: TeamFinances
    public var record: TeamRecord

    public var offensiveScheme: OffensiveScheme
    public var defensiveScheme: DefensiveScheme

    public var isUserControlled: Bool

    public var fullName: String {
        "\(city) \(name)"
    }

    public var activeRoster: [Player] {
        roster.filter { $0.status.canPlay }
    }

    public var injuredPlayers: [Player] {
        roster.filter { $0.status.isInjured }
    }

    public var totalPayroll: Int {
        roster.reduce(0) { $0 + $1.contract.capHit }
    }

    public init(id: UUID = UUID(),
         name: String,
         city: String,
         abbreviation: String,
         colors: TeamColors,
         stadiumName: String,
         coachName: String = "",
         weatherZone: Int = 0,
         divisionId: UUID,
         offensiveScheme: OffensiveScheme = .proStyle,
         defensiveScheme: DefensiveScheme = .base43,
         isUserControlled: Bool = false) {
        self.id = id
        self.name = name
        self.city = city
        self.abbreviation = abbreviation
        self.colors = colors
        self.stadiumName = stadiumName
        self.coachName = coachName
        self.weatherZone = weatherZone
        self.divisionId = divisionId
        self.roster = []
        self.rosterSlots = RosterSlotTemplate.makeSlots()
        self.depthChart = DepthChart()
        self.finances = .standard
        self.record = TeamRecord()
        self.offensiveScheme = offensiveScheme
        self.defensiveScheme = defensiveScheme
        self.isUserControlled = isUserControlled
    }

    // MARK: - Codable (backward compatibility for saves without rosterSlots)

    private enum CodingKeys: String, CodingKey {
        case id, name, city, abbreviation, colors, stadiumName, coachName, weatherZone
        case divisionId, roster, rosterSlots, depthChart, finances, record
        case offensiveScheme, defensiveScheme, isUserControlled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        city = try container.decode(String.self, forKey: .city)
        abbreviation = try container.decode(String.self, forKey: .abbreviation)
        colors = try container.decode(TeamColors.self, forKey: .colors)
        stadiumName = try container.decode(String.self, forKey: .stadiumName)
        coachName = try container.decode(String.self, forKey: .coachName)
        weatherZone = try container.decode(Int.self, forKey: .weatherZone)
        divisionId = try container.decode(UUID.self, forKey: .divisionId)
        roster = try container.decode([Player].self, forKey: .roster)
        depthChart = try container.decode(DepthChart.self, forKey: .depthChart)
        finances = try container.decode(TeamFinances.self, forKey: .finances)
        record = try container.decode(TeamRecord.self, forKey: .record)
        offensiveScheme = try container.decode(OffensiveScheme.self, forKey: .offensiveScheme)
        defensiveScheme = try container.decode(DefensiveScheme.self, forKey: .defensiveScheme)
        isUserControlled = try container.decode(Bool.self, forKey: .isUserControlled)

        // Backward compatibility: old saves won't have rosterSlots
        if let slots = try? container.decode([RosterSlot].self, forKey: .rosterSlots) {
            rosterSlots = slots
        } else {
            rosterSlots = RosterSlotTemplate.makeSlots()
            // Rebuild from existing roster
            for player in roster {
                if player.status.injuryType == .seasonEnding {
                    // Try assigned slot first, then IR
                    if let idx = rosterSlots.firstIndex(where: {
                        if case .assigned(let p) = $0.slotType { return p == player.position && $0.isEmpty }
                        return false
                    }) {
                        rosterSlots[idx].playerId = player.id
                    } else if let idx = rosterSlots.firstIndex(where: {
                        if case .injuredReserve = $0.slotType { return $0.isEmpty }
                        return false
                    }) {
                        rosterSlots[idx].playerId = player.id
                    }
                } else {
                    // Assign to position slot first, then open
                    if let idx = rosterSlots.firstIndex(where: {
                        if case .assigned(let p) = $0.slotType { return p == player.position && $0.isEmpty }
                        return false
                    }) {
                        rosterSlots[idx].playerId = player.id
                    } else if let idx = rosterSlots.firstIndex(where: {
                        if case .open = $0.slotType { return $0.isEmpty }
                        return false
                    }) {
                        rosterSlots[idx].playerId = player.id
                    }
                }
            }
        }
    }

    // MARK: - Roster Slot Queries

    /// Assigned slots for a given position.
    public func assignedSlots(for position: Position) -> [RosterSlot] {
        rosterSlots.filter {
            if case .assigned(let p) = $0.slotType { return p == position }
            return false
        }
    }

    /// All open (flex) slots.
    public var openSlots: [RosterSlot] {
        rosterSlots.filter {
            if case .open = $0.slotType { return true }
            return false
        }
    }

    /// All IR slots.
    public var irSlots: [RosterSlot] {
        rosterSlots.filter {
            if case .injuredReserve = $0.slotType { return true }
            return false
        }
    }

    /// Number of empty open slots available.
    public var availableOpenSlots: Int {
        openSlots.filter { $0.isEmpty }.count
    }

    /// Number of empty IR slots available.
    public var availableIRSlots: Int {
        irSlots.filter { $0.isEmpty }.count
    }

    /// Whether the roster has room for a new player (either assigned or open slot).
    public func hasRoomFor(position: Position) -> Bool {
        // Check assigned slots first
        if assignedSlots(for: position).contains(where: { $0.isEmpty }) { return true }
        // Fall back to open slots
        return availableOpenSlots > 0
    }

    /// Players currently on IR.
    public var irPlayers: [Player] {
        let irPlayerIds = irSlots.compactMap { $0.playerId }
        return roster.filter { irPlayerIds.contains($0.id) }
    }

    /// Whether a player is on injured reserve.
    public func isOnIR(_ playerId: UUID) -> Bool {
        irSlots.contains { $0.playerId == playerId }
    }

    // MARK: - Roster Management

    public mutating func addPlayer(_ player: Player) {
        roster.append(player)
        assignPlayerToSlot(player)
        depthChart.addPlayer(player.id, at: player.position)
        finances.addContract(player.contract)
    }

    /// Assign a player to the best available slot: assigned position slot first, then open slot.
    private mutating func assignPlayerToSlot(_ player: Player) {
        // Try assigned slot for this position
        if let idx = rosterSlots.firstIndex(where: {
            if case .assigned(let p) = $0.slotType { return p == player.position && $0.isEmpty }
            return false
        }) {
            rosterSlots[idx].playerId = player.id
            return
        }
        // Fall back to open slot
        if let idx = rosterSlots.firstIndex(where: {
            if case .open = $0.slotType { return $0.isEmpty }
            return false
        }) {
            rosterSlots[idx].playerId = player.id
            return
        }
        // No slot available — player is still on roster but unslotted
    }

    public mutating func removePlayer(_ playerId: UUID, cutMidSeason: Bool = false) {
        guard let index = roster.firstIndex(where: { $0.id == playerId }) else { return }
        let player = roster[index]
        finances.removeContract(player.contract, cutMidSeason: cutMidSeason)
        roster.remove(at: index)
        clearPlayerFromSlots(playerId)
        depthChart.removePlayer(playerId)
    }

    /// Remove a player from whatever roster slot they occupy.
    private mutating func clearPlayerFromSlots(_ playerId: UUID) {
        for i in rosterSlots.indices {
            if rosterSlots[i].playerId == playerId {
                rosterSlots[i].playerId = nil
            }
        }
    }

    /// Move a player to injured reserve. Returns true if successful.
    @discardableResult
    public mutating func moveToIR(_ playerId: UUID) -> Bool {
        guard let irIdx = rosterSlots.firstIndex(where: {
            if case .injuredReserve = $0.slotType { return $0.isEmpty }
            return false
        }) else { return false }

        clearPlayerFromSlots(playerId)
        rosterSlots[irIdx].playerId = playerId
        return true
    }

    /// Move a player off IR back to an active slot.
    @discardableResult
    public mutating func activateFromIR(_ playerId: UUID) -> Bool {
        guard let player = self.player(withId: playerId) else { return false }
        clearPlayerFromSlots(playerId)
        assignPlayerToSlot(player)
        return true
    }

    /// Rebuild roster slots from current roster (for migration from old saves).
    public mutating func rebuildRosterSlots() {
        rosterSlots = RosterSlotTemplate.makeSlots()
        for player in roster {
            if player.status.injuryType == .seasonEnding && availableIRSlots > 0 {
                assignPlayerToSlot(player)
                moveToIR(player.id)
            } else {
                assignPlayerToSlot(player)
            }
        }
    }

    public func player(withId id: UUID) -> Player? {
        roster.first { $0.id == id }
    }

    public func players(at position: Position) -> [Player] {
        roster.filter { $0.position == position }
    }

    public func starter(at position: Position) -> Player? {
        guard let starterId = depthChart.starter(at: position) else { return nil }
        return player(withId: starterId)
    }

    public mutating func setStarter(_ playerId: UUID, at position: Position) {
        depthChart.setStarter(playerId, at: position)
    }

    // MARK: - Team Ratings

    public var offensiveRating: Int {
        let offensivePlayers = roster.filter { $0.position.isOffense }
        guard !offensivePlayers.isEmpty else { return 50 }
        return offensivePlayers.reduce(0) { $0 + $1.overall } / offensivePlayers.count
    }

    public var defensiveRating: Int {
        let defensivePlayers = roster.filter { $0.position.isDefense }
        guard !defensivePlayers.isEmpty else { return 50 }
        return defensivePlayers.reduce(0) { $0 + $1.overall } / defensivePlayers.count
    }

    public var specialTeamsRating: Int {
        let stPlayers = roster.filter { $0.position.isSpecialTeams }
        guard !stPlayers.isEmpty else { return 50 }
        return stPlayers.reduce(0) { $0 + $1.overall } / stPlayers.count
    }

    public var overallRating: Int {
        (offensiveRating + defensiveRating + specialTeamsRating) / 3
    }

    // MARK: - Season Advancement

    /// Archives all player season stats to career stats
    public mutating func archiveAllPlayerStats() {
        for index in roster.indices {
            roster[index].archiveSeasonStats()
        }
    }

    /// Advances all players to next season (age, contract years)
    public mutating func advanceAllPlayersToNextSeason() {
        for index in roster.indices {
            roster[index].advanceToNextSeason()
        }
    }

    /// Returns players whose contracts have expired
    public func playersWithExpiredContracts() -> [Player] {
        roster.filter { $0.isContractExpired }
    }

    /// Removes players with expired contracts, returns them for free agency
    public mutating func releaseExpiredContracts() -> [Player] {
        let expiredPlayers = playersWithExpiredContracts()
        for player in expiredPlayers {
            removePlayer(player.id, cutMidSeason: false)
        }
        return expiredPlayers
    }

    /// Resets team record for new season
    public mutating func resetRecord() {
        record = TeamRecord()
    }
}

// MARK: - Team Generation

public struct TeamGenerator { // Public
    public static let teamData: [(name: String, city: String, abbr: String, primary: String, secondary: String, stadium: String)] = [
        ("Thunder", "Austin", "AUS", "1A237E", "FF6F00", "Lone Star Stadium"),
        ("Wolves", "Portland", "POR", "1B5E20", "FFFFFF", "Pacific Northwest Arena"),
        ("Titans", "Nashville", "NSH", "0D47A1", "F44336", "Music City Stadium"),
        ("Storm", "Seattle", "SEA", "006064", "B2FF59", "Emerald Field"),
        ("Blazers", "Phoenix", "PHX", "E65100", "000000", "Desert Dome"),
        ("Knights", "Las Vegas", "LVK", "212121", "CFD8DC", "Silver State Stadium"),
        ("Hurricanes", "Miami", "MIA", "00838F", "FF8A65", "Tropical Bowl"),
        ("Pioneers", "Denver", "DEN", "4A148C", "FFC107", "Mile High Field")
    ]

    public static func generateTeam(index: Int, divisionId: UUID) -> Team {
        let data = teamData[index % teamData.count]
        var team = Team(
            name: data.name,
            city: data.city,
            abbreviation: data.abbr,
            colors: TeamColors(primary: data.primary, secondary: data.secondary, accent: "FFFFFF"),
            stadiumName: data.stadium,
            divisionId: divisionId,
            offensiveScheme: OffensiveScheme.allCases.randomElement()!,
            defensiveScheme: DefensiveScheme.allCases.randomElement()!
        )

        // Generate roster
        let rosterTemplate: [(Position, Int, [PlayerTier])] = [
            // Offense
            (.quarterback, 2, [.starter, .backup]),
            (.runningBack, 3, [.starter, .backup, .reserve]),
            (.fullback, 1, [.backup]),
            (.wideReceiver, 5, [.starter, .starter, .starter, .backup, .reserve]),
            (.tightEnd, 2, [.starter, .backup]),
            (.leftTackle, 2, [.starter, .backup]),
            (.leftGuard, 2, [.starter, .backup]),
            (.center, 2, [.starter, .backup]),
            (.rightGuard, 2, [.starter, .backup]),
            (.rightTackle, 2, [.starter, .backup]),
            // Defense
            (.defensiveEnd, 4, [.starter, .starter, .backup, .backup]),
            (.defensiveTackle, 3, [.starter, .starter, .backup]),
            (.outsideLinebacker, 4, [.starter, .starter, .backup, .backup]),
            (.middleLinebacker, 2, [.starter, .backup]),
            (.cornerback, 4, [.starter, .starter, .backup, .backup]),
            (.freeSafety, 2, [.starter, .backup]),
            (.strongSafety, 2, [.starter, .backup]),
            // Special Teams
            (.kicker, 1, [.starter]),
            (.punter, 1, [.starter])
        ]

        // Add one elite player randomly
        let elitePosition = [Position.quarterback, .runningBack, .wideReceiver, .cornerback, .defensiveEnd].randomElement()!
        let elitePlayer = PlayerGenerator.generate(position: elitePosition, tier: .elite)
        team.addPlayer(elitePlayer)

        for (position, count, tiers) in rosterTemplate {
            for i in 0..<count {
                if position == elitePosition && i == 0 { continue } // Skip if we added elite
                let tier = tiers[i]
                let player = PlayerGenerator.generate(position: position, tier: tier)
                team.addPlayer(player)
            }
        }

        // Set depth chart
        for position in Position.allCases {
            let positionPlayers = team.players(at: position).sorted { $0.overall > $1.overall }
            for (index, player) in positionPlayers.enumerated() {
                if index == 0 {
                    team.setStarter(player.id, at: position)
                }
            }
        }

        return team
    }
}