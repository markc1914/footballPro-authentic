//
//  TrainingCampView.swift
//  footballPro
//
//  Training Camp — July off-season screen
//  Allocate training points across 8 ratings per position group.
//  DOS/VGA aesthetic matching FPS Football Pro '93
//

import SwiftUI

// MARK: - Training Camp Position Group

enum TrainingGroup: String, CaseIterable, Identifiable {
    case qb = "QB"
    case rb = "RB"
    case wrte = "WR/TE"
    case ol = "OL"
    case dl = "DL"
    case lb = "LB"
    case db = "DB"
    case kp = "K/P"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qb: return "QUARTERBACKS"
        case .rb: return "RUNNING BACKS"
        case .wrte: return "RECEIVERS / TIGHT ENDS"
        case .ol: return "OFFENSIVE LINE"
        case .dl: return "DEFENSIVE LINE"
        case .lb: return "LINEBACKERS"
        case .db: return "DEFENSIVE BACKS"
        case .kp: return "KICKERS / PUNTERS"
        }
    }

    var positions: [Position] {
        switch self {
        case .qb: return [.quarterback]
        case .rb: return [.runningBack, .fullback]
        case .wrte: return [.wideReceiver, .tightEnd]
        case .ol: return [.leftTackle, .leftGuard, .center, .rightGuard, .rightTackle]
        case .dl: return [.defensiveEnd, .defensiveTackle]
        case .lb: return [.outsideLinebacker, .middleLinebacker]
        case .db: return [.cornerback, .freeSafety, .strongSafety]
        case .kp: return [.kicker, .punter]
        }
    }
}

// MARK: - Training Rating (the 8 FPS '93 categories)

enum TrainingRating: String, CaseIterable, Identifiable {
    case sp = "SP"
    case ac = "AC"
    case ag = "AG"
    case st = "ST"
    case ha = "HA"
    case en = "EN"
    case intelligence = "IN"
    case di = "DI"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .sp: return "SPEED"
        case .ac: return "ACCELERATION"
        case .ag: return "AGILITY"
        case .st: return "STRENGTH"
        case .ha: return "HANDS"
        case .en: return "ENDURANCE"
        case .intelligence: return "INTELLIGENCE"
        case .di: return "DISCIPLINE"
        }
    }

    /// Maps to the primary PlayerRatings keypath
    var keyPath: WritableKeyPath<PlayerRatings, Int> {
        switch self {
        case .sp: return \.speed
        case .ac: return \.agility
        case .ag: return \.elusiveness
        case .st: return \.strength
        case .ha: return \.catching
        case .en: return \.stamina
        case .intelligence: return \.awareness
        case .di: return \.toughness
        }
    }

    /// Secondary keypaths that also improve (position-relevant skills)
    var secondaryKeyPaths: [WritableKeyPath<PlayerRatings, Int>] {
        switch self {
        case .sp: return [\.pursuit]
        case .ac: return [\.breakTackle, \.elusiveness]
        case .ag: return [\.routeRunning, \.manCoverage]
        case .st: return [\.runBlock, \.passBlock, \.blockShedding]
        case .ha: return [\.catchInTraffic, \.spectacularCatch]
        case .en: return [\.carrying]
        case .intelligence: return [\.playRecognition, \.zoneCoverage]
        case .di: return [\.tackle, \.hitPower]
        }
    }
}

// MARK: - Training Camp View

struct TrainingCampView: View {
    @EnvironmentObject var gameState: GameState
    let onDismiss: () -> Void

    static let maxPointsPerGroup = 100
    static let maxPointsPerRating = 20

    @State private var allocations: [TrainingGroup: [TrainingRating: Int]] = {
        var alloc: [TrainingGroup: [TrainingRating: Int]] = [:]
        for group in TrainingGroup.allCases {
            var ratings: [TrainingRating: Int] = [:]
            for rating in TrainingRating.allCases {
                ratings[rating] = 0
            }
            alloc[group] = ratings
        }
        return alloc
    }()

    @State private var selectedGroup: TrainingGroup = .qb
    @State private var trainingApplied = false
    @State private var showResults = false
    @State private var resultMessages: [String] = []

    private var seasonYear: Int {
        gameState.currentSeason?.year ?? 1993
    }

    private var team: Team? {
        gameState.userTeam
    }

    private func pointsUsed(for group: TrainingGroup) -> Int {
        let groupAlloc = allocations[group] ?? [:]
        return groupAlloc.values.reduce(0, +)
    }

    private func pointsRemaining(for group: TrainingGroup) -> Int {
        Self.maxPointsPerGroup - pointsUsed(for: group)
    }

    private func averageRating(for group: TrainingGroup, rating: TrainingRating) -> Int {
        guard let team = team else { return 0 }
        let players = team.roster.filter { group.positions.contains($0.position) }
        guard !players.isEmpty else { return 0 }
        let total = players.reduce(0) { $0 + $1.ratings[keyPath: rating.keyPath] }
        return total / players.count
    }

    private func playerCount(for group: TrainingGroup) -> Int {
        guard let team = team else { return 0 }
        return team.roster.filter { group.positions.contains($0.position) }.count
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
            DOSSeparator()

            if trainingApplied && showResults {
                resultsView
            } else {
                mainContent
            }
        }
        .background(VGA.screenBg)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            FPSButton("< BACK") {
                onDismiss()
            }

            Spacer()

            Text("TRAINING CAMP \u{2014} JULY \(String(seasonYear))")
                .font(RetroFont.title())
                .foregroundColor(VGA.digitalAmber)

            Spacer()

            if let team = team {
                Text(team.fullName.uppercased())
                    .font(RetroFont.body())
                    .foregroundColor(VGA.lightGray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelDark)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        HStack(spacing: 0) {
            // Left: Position group list
            groupListPanel
                .frame(width: 180)

            DOSVerticalSeparator()

            // Right: Selected group allocator
            VStack(spacing: 0) {
                groupHeader
                DOSSeparator()
                allocationPanel
                DOSSeparator()
                bottomBar
            }
        }
    }

    // MARK: - Group List Panel

    private var groupListPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("POSITION GROUPS")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.lightGray)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VGA.titleBarBg)

            // Group buttons
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(TrainingGroup.allCases) { group in
                        groupButton(group)
                    }
                }
                .padding(6)
            }
            .background(VGA.panelBg)
        }
        .modifier(DOSPanelBorder(.raised, width: 2))
    }

    private func groupButton(_ group: TrainingGroup) -> some View {
        let isSelected = selectedGroup == group
        let used = pointsUsed(for: group)
        let count = playerCount(for: group)

        return Button(action: { selectedGroup = group }) {
            HStack(spacing: 6) {
                Text(group.rawValue)
                    .font(RetroFont.bodyBold())
                    .foregroundColor(isSelected ? .black : VGA.digitalAmber)
                    .frame(width: 40, alignment: .leading)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(count) PLAYERS")
                        .font(RetroFont.tiny())
                        .foregroundColor(isSelected ? VGA.panelDark : VGA.darkGray)
                    Text("\(used)/\(Self.maxPointsPerGroup) PTS")
                        .font(RetroFont.tiny())
                        .foregroundColor(isSelected ? VGA.panelDark : (used > 0 ? VGA.green : VGA.darkGray))
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? VGA.digitalAmber : VGA.panelVeryDark)
            .modifier(DOSPanelBorder(isSelected ? .sunken : .raised, width: 1))
        }
        .buttonStyle(.plain)
        .disabled(trainingApplied)
    }

    // MARK: - Group Header

    private var groupHeader: some View {
        HStack {
            Text(selectedGroup.displayName)
                .font(RetroFont.header())
                .foregroundColor(VGA.white)

            Spacer()

            // Points remaining
            let remaining = pointsRemaining(for: selectedGroup)
            HStack(spacing: 4) {
                Text("REMAINING:")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.lightGray)
                Text("\(remaining)")
                    .font(RetroFont.header())
                    .foregroundColor(remaining > 0 ? VGA.green : VGA.brightRed)
                Text("/ \(Self.maxPointsPerGroup)")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.darkGray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelDark)
    }

    // MARK: - Allocation Panel

    private var allocationPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Column headers
                HStack(spacing: 0) {
                    Text("RATING")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.lightGray)
                        .frame(width: 36, alignment: .leading)
                    Text("")
                        .frame(width: 110, alignment: .leading)
                    Text("AVG")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.lightGray)
                        .frame(width: 34, alignment: .trailing)
                    Spacer()
                        .frame(width: 8)
                    Text("CURRENT LEVEL")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.lightGray)
                        .frame(minWidth: 100)
                    Spacer()
                    Text("PTS")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.lightGray)
                        .frame(width: 36, alignment: .center)
                    Text("")
                        .frame(width: 80)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(VGA.panelDark)

                // Rating rows
                ForEach(TrainingRating.allCases) { rating in
                    allocationRow(rating)
                }
            }
            .padding(8)
        }
        .background(VGA.panelBg)
    }

    private func allocationRow(_ rating: TrainingRating) -> some View {
        let avg = averageRating(for: selectedGroup, rating: rating)
        let points = allocations[selectedGroup]?[rating] ?? 0
        let remaining = pointsRemaining(for: selectedGroup)

        return HStack(spacing: 0) {
            // Abbreviation
            Text(rating.rawValue)
                .font(RetroFont.bodyBold())
                .foregroundColor(VGA.digitalAmber)
                .frame(width: 36, alignment: .leading)

            // Full name
            Text(rating.fullName)
                .font(RetroFont.body())
                .foregroundColor(VGA.white)
                .frame(width: 110, alignment: .leading)

            // Average rating value
            Text(String(format: "%02d", avg))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(ratingColor(avg))
                .frame(width: 34, alignment: .trailing)

            Spacer()
                .frame(width: 8)

            // Rating bar
            ratingBar(current: avg)

            Spacer()
                .frame(width: 8)

            // Points allocated display
            Text(String(format: "%2d", points))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(points > 0 ? VGA.green : VGA.darkGray)
                .frame(width: 28, alignment: .trailing)

            Spacer()
                .frame(width: 8)

            // +/- buttons
            FPSButton("-", width: 28) {
                adjustAllocation(selectedGroup, rating, by: -1)
            }
            .disabled(points <= 0 || trainingApplied)

            Spacer()
                .frame(width: 4)

            FPSButton("+", width: 28) {
                adjustAllocation(selectedGroup, rating, by: 1)
            }
            .disabled(points >= Self.maxPointsPerRating || remaining <= 0 || trainingApplied)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func ratingBar(current: Int) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(VGA.screenBg)
                Rectangle()
                    .fill(VGA.playSlotGreen)
                    .frame(width: w * CGFloat(current) / 99.0)
            }
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
        .frame(height: 14)
        .frame(minWidth: 100)
    }

    private func ratingColor(_ value: Int) -> Color {
        if value >= 90 { return VGA.green }
        if value >= 80 { return VGA.cyan }
        if value >= 70 { return VGA.white }
        if value >= 60 { return VGA.orange }
        return VGA.brightRed
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            FPSButton("AUTO ALLOCATE", width: 140) {
                autoAllocate()
            }
            .disabled(trainingApplied)

            FPSButton("RESET ALL", width: 100) {
                resetAllocations()
            }
            .disabled(trainingApplied)

            Spacer()

            FPSButton("APPLY TRAINING", width: 160) {
                applyTraining()
            }
            .disabled(trainingApplied)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(VGA.panelDark)
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Results header
            HStack {
                Text("TRAINING CAMP RESULTS")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.digitalAmber)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VGA.panelDark)

            DOSSeparator()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(resultMessages.enumerated()), id: \.offset) { _, message in
                        Text(message)
                            .font(RetroFont.body())
                            .foregroundColor(VGA.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(VGA.panelBg)

            DOSSeparator()

            HStack {
                Spacer()
                FPSButton("CONTINUE", width: 120) {
                    onDismiss()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(VGA.panelDark)
        }
    }

    // MARK: - Actions

    private func adjustAllocation(_ group: TrainingGroup, _ rating: TrainingRating, by amount: Int) {
        guard !trainingApplied else { return }
        let current = allocations[group]?[rating] ?? 0
        let newValue = current + amount

        guard newValue >= 0, newValue <= Self.maxPointsPerRating else { return }

        if amount > 0 {
            guard pointsRemaining(for: group) > 0 else { return }
        }

        allocations[group]?[rating] = newValue
    }

    private func autoAllocate() {
        guard !trainingApplied, let team = team else { return }

        for group in TrainingGroup.allCases {
            // Find the weakest ratings for this group
            var ratingAverages: [(TrainingRating, Int)] = []
            let players = team.roster.filter { group.positions.contains($0.position) }
            guard !players.isEmpty else { continue }

            for rating in TrainingRating.allCases {
                let avg = players.reduce(0) { $0 + $1.ratings[keyPath: rating.keyPath] } / players.count
                ratingAverages.append((rating, avg))
            }

            // Sort by weakest first
            ratingAverages.sort { $0.1 < $1.1 }

            // Distribute points: more to weaker ratings
            var remaining = Self.maxPointsPerGroup
            var groupAlloc: [TrainingRating: Int] = [:]
            for rating in TrainingRating.allCases {
                groupAlloc[rating] = 0
            }

            // Give weakest ratings more points (inverse weighting)
            let totalInverse = ratingAverages.reduce(0.0) { $0 + (100.0 - Double($1.1)) }
            guard totalInverse > 0 else { continue }

            for (rating, avg) in ratingAverages {
                let weight = (100.0 - Double(avg)) / totalInverse
                var points = Int(Double(Self.maxPointsPerGroup) * weight)
                points = min(points, Self.maxPointsPerRating)
                points = min(points, remaining)
                groupAlloc[rating] = points
                remaining -= points
            }

            // Distribute any leftover points to weakest
            for (rating, _) in ratingAverages {
                if remaining <= 0 { break }
                let current = groupAlloc[rating] ?? 0
                let canAdd = min(Self.maxPointsPerRating - current, remaining)
                if canAdd > 0 {
                    groupAlloc[rating] = current + canAdd
                    remaining -= canAdd
                }
            }

            allocations[group] = groupAlloc
        }
    }

    private func resetAllocations() {
        guard !trainingApplied else { return }
        for group in TrainingGroup.allCases {
            for rating in TrainingRating.allCases {
                allocations[group]?[rating] = 0
            }
        }
    }

    private func applyTraining() {
        guard !trainingApplied,
              var league = gameState.currentLeague,
              let userTeamId = gameState.userTeam?.id,
              let teamIndex = league.teams.firstIndex(where: { $0.id == userTeamId })
        else { return }

        var messages: [String] = []
        messages.append("=== TRAINING CAMP REPORT ===")
        messages.append("")

        for group in TrainingGroup.allCases {
            let groupAlloc = allocations[group] ?? [:]
            let totalPoints = groupAlloc.values.reduce(0, +)
            guard totalPoints > 0 else { continue }

            messages.append("\(group.displayName):")

            let positions = group.positions
            var improvedCount = 0

            for rosterIndex in league.teams[teamIndex].roster.indices {
                let player = league.teams[teamIndex].roster[rosterIndex]
                guard positions.contains(player.position) else { continue }

                var anyImprovement = false

                for (rating, points) in groupAlloc {
                    guard points > 0 else { continue }

                    let current = player.ratings[keyPath: rating.keyPath]
                    let potential = min(99, current + 10) // Potential cap: current + 10

                    let improvement = TrainingCampView.calculateImprovement(
                        current: current,
                        potential: potential,
                        points: points,
                        age: player.age
                    )

                    if improvement > 0 {
                        let newValue = min(current + improvement, potential)
                        league.teams[teamIndex].roster[rosterIndex].ratings[keyPath: rating.keyPath] = newValue

                        // Apply smaller improvement to secondary keypaths
                        let secondaryImprovement = max(1, improvement / 2)
                        for secondaryKP in rating.secondaryKeyPaths {
                            let secCurrent = league.teams[teamIndex].roster[rosterIndex].ratings[keyPath: secondaryKP]
                            let secNew = min(99, secCurrent + secondaryImprovement)
                            league.teams[teamIndex].roster[rosterIndex].ratings[keyPath: secondaryKP] = secNew
                        }

                        anyImprovement = true
                    }
                }

                if anyImprovement {
                    improvedCount += 1
                }
            }

            messages.append("  \(improvedCount) players improved (\(totalPoints) training points)")
        }

        messages.append("")
        messages.append("Training camp complete. Players are ready for the season.")

        // Update game state
        gameState.currentLeague = league
        if let updatedTeam = league.teams.first(where: { $0.id == userTeamId }) {
            gameState.userTeam = updatedTeam
        }

        resultMessages = messages
        trainingApplied = true
        showResults = true
    }

    /// Calculate improvement for a single rating.
    /// base = points * 0.3, adjusted by age and gap to potential.
    static func calculateImprovement(current: Int, potential: Int, points: Int, age: Int) -> Int {
        guard points > 0, current < potential else { return 0 }

        let base = Double(points) * 0.3

        // Age multiplier
        let ageMult: Double
        switch age {
        case ...24: ageMult = 1.5   // Young players improve fast
        case 25...28: ageMult = 1.0 // Prime years
        case 29...31: ageMult = 0.7 // Starting to slow
        case 32...: ageMult = 0.5   // Veterans improve slowly
        default: ageMult = 1.0
        }

        // Gap multiplier: bigger gap to potential = faster improvement
        let gap = Double(potential - current)
        let gapMult = min(2.0, max(0.5, gap / 10.0))

        let rawImprovement = base * ageMult * gapMult
        let improvement = max(0, min(Int(rawImprovement.rounded()), potential - current))

        return improvement
    }
}

// MARK: - DOS Vertical Separator

struct DOSVerticalSeparator: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(VGA.shadowInner).frame(width: 1)
            Rectangle().fill(VGA.highlightOuter).frame(width: 1)
        }
    }
}
