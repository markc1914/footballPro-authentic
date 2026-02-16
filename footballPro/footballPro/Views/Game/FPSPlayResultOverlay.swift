//
//  FPSPlayResultOverlay.swift
//  footballPro
//
//  FPS '93 play result — flat dark charcoal rectangle overlaid on field
//  Continuous prose with colored team names, buttons below the text box
//  Matched from actual gameplay video frames
//

import SwiftUI

struct FPSPlayResultOverlay: View {
    @ObservedObject var viewModel: GameViewModel

    /// Whether this result is from a FG/PAT (shows on black background instead of field)
    private var isSpecialResult: Bool {
        guard let result = viewModel.lastPlayResult else { return false }
        let desc = result.description.uppercased()
        return desc.contains("FIELD GOAL") || desc.contains("EXTRA POINT") || desc.contains("PAT")
    }

    var body: some View {
        ZStack {
            // FG/PAT results show on black background
            if isSpecialResult {
                Color.black.ignoresSafeArea()
            }

            // Center the overlay on the field
            GeometryReader { geo in
                VStack(spacing: 8) {
                    // Dark text box (flat rectangle, no rounded corners — FPS '93 style)
                    textBox

                    // Buttons BELOW the text box (not inside it)
                    buttonBar
                }
                .frame(maxWidth: 500)
                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
            }
        }
    }

    // MARK: - Text Box (flat dark rectangle with continuous prose)

    private var textBox: some View {
        VStack(spacing: 0) {
            if viewModel.lastPlayResult != nil {
                Text(attributedProseResult())
                    .font(RetroFont.body())
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            } else {
                Text("Play complete.")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.lightGray)
                    .padding(12)
            }
        }
        .frame(maxWidth: 500)
        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
        .border(Color(red: 0.4, green: 0.4, blue: 0.45), width: 1)
    }

    // MARK: - Button Bar (outside the text box)

    private var buttonBar: some View {
        HStack(spacing: 16) {
            FPSButton("Instant Replay") {
                viewModel.enterReplay()
            }
            FPSButton("Continue") {
                viewModel.continueAfterResult()
            }
        }
    }

    // MARK: - Continuous Prose (FPS '93 authentic style)

    private func attributedProseResult() -> AttributedString {
        let prose = viewModel.generateProseResult()
        var result = AttributedString(prose)
        result.foregroundColor = VGA.white
        result.font = RetroFont.body()

        // Color ALL occurrences of each team's city name
        let possTeam = viewModel.game?.isHomeTeamPossession == true ? viewModel.homeTeam : viewModel.awayTeam
        let oppTeam = viewModel.game?.isHomeTeamPossession == true ? viewModel.awayTeam : viewModel.homeTeam

        if let team = possTeam {
            for name in [team.city, team.name, team.fullName] {
                colorAllOccurrences(of: name, in: &result, color: VGA.teamCyan)
            }
        }

        if let team = oppTeam {
            for name in [team.city, team.name, team.fullName] {
                colorAllOccurrences(of: name, in: &result, color: VGA.teamRed)
            }
        }

        return result
    }

    private func colorAllOccurrences(of text: String, in attributed: inout AttributedString, color: Color) {
        var searchStart = attributed.startIndex
        while searchStart < attributed.endIndex {
            let remaining = attributed[searchStart...]
            if let range = remaining.range(of: text, options: .caseInsensitive) {
                attributed[range].foregroundColor = color
                searchStart = range.upperBound
            } else {
                break
            }
        }
    }
}
