//
//  FieldView3D.swift
//  footballPro
//
//  3D Football Field visualization using SceneKit
//

import SwiftUI
import SceneKit

// MARK: - 3D Field View

struct FieldView3D: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var scene: FootballFieldScene?

    var body: some View {
        ZStack {
            if let scene = scene {
                SceneView(
                    scene: scene,
                    pointOfView: scene.cameraNode,
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
            } else {
                Color.black
                ProgressView("Loading field...")
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            setupScene()
        }
        .onChange(of: viewModel.lastPlayResult) { _, result in
            if let result = result, let scene = scene {
                scene.animatePlay(playType: result.playType, yardsGained: result.yardsGained) {
                    // Animation complete
                }
            }
        }
    }

    private func setupScene() {
        let newScene = FootballFieldScene()

        if let homeTeam = viewModel.homeTeam,
           let awayTeam = viewModel.awayTeam,
           let game = viewModel.game {
            let offenseTeam = game.isHomeTeamPossession ? homeTeam : awayTeam
            let defenseTeam = game.isHomeTeamPossession ? awayTeam : homeTeam
            newScene.setupTeams(
                offense: offenseTeam,
                defense: defenseTeam,
                lineOfScrimmage: CGFloat(game.fieldPosition.yardLine)
            )
        }

        scene = newScene
    }
}

// MARK: - SceneKit View Representable

struct SceneKitView: NSViewRepresentable {
    let scene: SCNScene
    let cameraNode: SCNNode?

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.pointOfView = cameraNode
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = NSColor.black
        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        nsView.scene = scene
        nsView.pointOfView = cameraNode
    }
}

#Preview {
    FieldView3D(viewModel: GameViewModel())
        .frame(width: 800, height: 600)
}
