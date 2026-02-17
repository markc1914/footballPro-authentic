//
//  CoinTossView.swift
//  footballPro
//
//  Coin toss ceremony before the opening kickoff (FPS '93 DOS style)
//

import SwiftUI

struct CoinTossView: View {
    @ObservedObject var viewModel: GameViewModel

    // Coin toss state machine
    @State private var phase: CoinTossPhase = .calling
    @State private var calledHeads: Bool = true
    @State private var flipResult: Bool = true  // true = heads
    @State private var userWon: Bool = false
    @State private var resultText: String = ""
    @State private var coinAngle: Double = 0
    @State private var isFlipping: Bool = false

    enum CoinTossPhase {
        case calling       // User picks heads or tails
        case flipping      // Coin is in the air
        case result        // Show who won
        case choosing      // Winner picks kick or receive
        case summary       // Brief display of final choice
    }

    private var userTeamName: String {
        if let game = viewModel.game {
            let userIsHome = viewModel.homeTeam?.id == game.homeTeamId
            // User team is whichever team matches userTeamId
            // For coin toss, visiting team calls it
            return viewModel.awayTeam?.name ?? "Visitors"
        }
        return "Visitors"
    }

    private var opponentTeamName: String {
        return viewModel.homeTeam?.name ?? "Home"
    }

    var body: some View {
        ZStack {
            VGA.screenBg.ignoresSafeArea()

            FPSDialog("COIN TOSS") {
                VStack(spacing: 16) {
                    Spacer().frame(height: 12)

                    switch phase {
                    case .calling:
                        callingPhaseView

                    case .flipping:
                        flippingPhaseView

                    case .result:
                        resultPhaseView

                    case .choosing:
                        choosingPhaseView

                    case .summary:
                        summaryPhaseView
                    }

                    Spacer().frame(height: 12)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Phase Views

    private var callingPhaseView: some View {
        VStack(spacing: 16) {
            Text("The visiting captain calls the toss.")
                .font(RetroFont.body())
                .foregroundColor(VGA.white)
                .multilineTextAlignment(.center)

            coinDisplay

            Text("CALL IT:")
                .font(RetroFont.header())
                .foregroundColor(VGA.digitalAmber)

            HStack(spacing: 24) {
                FPSButton("HEADS", width: 120) {
                    calledHeads = true
                    executeCoinFlip()
                }
                FPSButton("TAILS", width: 120) {
                    calledHeads = false
                    executeCoinFlip()
                }
            }
        }
    }

    private var flippingPhaseView: some View {
        VStack(spacing: 16) {
            Text(calledHeads ? "The call is HEADS..." : "The call is TAILS...")
                .font(RetroFont.body())
                .foregroundColor(VGA.white)

            coinDisplay

            Text("FLIPPING...")
                .font(RetroFont.header())
                .foregroundColor(VGA.digitalAmber)
        }
    }

    private var resultPhaseView: some View {
        VStack(spacing: 16) {
            Text(flipResult ? "The coin lands HEADS!" : "The coin lands TAILS!")
                .font(RetroFont.header())
                .foregroundColor(VGA.digitalAmber)

            coinDisplay

            Text(resultText)
                .font(RetroFont.body())
                .foregroundColor(userWon ? VGA.green : VGA.brightRed)
                .multilineTextAlignment(.center)
        }
    }

    private var choosingPhaseView: some View {
        VStack(spacing: 16) {
            if userWon {
                Text("You won the toss!")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.green)

                Text("ELECT TO:")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.white)

                HStack(spacing: 24) {
                    FPSButton("RECEIVE", width: 120) {
                        finishCoinToss(userElectsToReceive: true)
                    }
                    FPSButton("KICK", width: 120) {
                        finishCoinToss(userElectsToReceive: false)
                    }
                }
            } else {
                // AI won -- auto-choose (AI almost always elects to receive)
                let aiReceives = Bool.random() ? true : (Double.random(in: 0...1) < 0.85)
                Text(aiReceives
                     ? "\(opponentTeamName) wins the toss and elects to RECEIVE."
                     : "\(opponentTeamName) wins the toss and elects to KICK.")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.white)
                    .multilineTextAlignment(.center)
                    .onAppear {
                        // AI chose, auto-advance after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            // If AI receives, user kicks. If AI kicks, user receives.
                            viewModel.startKickoffAfterCoinToss(userElectsToReceive: !aiReceives)
                        }
                    }
            }
        }
    }

    private var summaryPhaseView: some View {
        VStack(spacing: 16) {
            Text(resultText)
                .font(RetroFont.body())
                .foregroundColor(VGA.digitalAmber)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Coin Display

    private var coinDisplay: some View {
        ZStack {
            Circle()
                .fill(VGA.digitalAmber.opacity(0.8))
                .frame(width: 64, height: 64)
                .modifier(DOSPanelBorder(.raised, width: 2))

            Text(displayedCoinFace)
                .font(RetroFont.large())
                .foregroundColor(VGA.panelVeryDark)
                .scaleEffect(x: 1.0, y: isFlipping ? abs(cos(coinAngle * .pi / 180)) : 1.0)
        }
        .scaleEffect(y: isFlipping ? abs(cos(coinAngle * .pi / 180)) : 1.0)
    }

    private var displayedCoinFace: String {
        if isFlipping {
            // During flip, alternate rapidly
            return Int(coinAngle / 180) % 2 == 0 ? "H" : "T"
        }
        if phase == .calling {
            return "?"
        }
        return flipResult ? "H" : "T"
    }

    // MARK: - Logic

    private func executeCoinFlip() {
        phase = .flipping
        isFlipping = true
        flipResult = Bool.random()
        userWon = (calledHeads == flipResult)

        // Animate coin flip
        withAnimation(.linear(duration: 1.5)) {
            coinAngle = 1080 + (flipResult ? 0 : 180)  // Multiple rotations + land on correct side
        }

        // After flip animation, show result
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            isFlipping = false
            let winnerName = userWon ? userTeamName : opponentTeamName
            resultText = "\(winnerName) wins the toss!"
            phase = .result

            // Auto-advance to choosing phase
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                phase = .choosing
            }
        }
    }

    private func finishCoinToss(userElectsToReceive: Bool) {
        let choiceText = userElectsToReceive ? "receive" : "kick"
        resultText = "\(userTeamName) wins the toss and elects to \(choiceText)."
        phase = .summary

        // Store coin toss result
        viewModel.coinTossResult = CoinTossResult(
            calledHeads: calledHeads,
            wasHeads: flipResult,
            winnerTeamName: userWon ? userTeamName : opponentTeamName,
            loserTeamName: userWon ? opponentTeamName : userTeamName,
            winnerElectsToReceive: userElectsToReceive
        )

        // Auto-advance to kickoff after brief display
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            viewModel.startKickoffAfterCoinToss(userElectsToReceive: userElectsToReceive)
        }
    }
}
