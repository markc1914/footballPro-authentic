//
//  PhysicsEngine.swift
//  footballPro
//
//  3D Physics engine using SceneKit for realistic football visualization
//

import Foundation
import SceneKit
import SwiftUI

// MARK: - Physics Configuration

struct PhysicsConfig {
    static let fieldLength: Float = 100.0  // yards
    static let fieldWidth: Float = 53.33   // yards (160 feet / 3)
    static let playerRadius: Float = 0.5
    static let ballRadius: Float = 0.3
    static let gravity: Float = -9.8
    static let playerMass: Float = 1.0
    static let ballMass: Float = 0.1
    static let tackleForce: Float = 5.0
    static let runSpeed: Float = 8.0       // yards per second (fast player)
    static let passSpeed: Float = 25.0     // yards per second
}

// MARK: - Player Physics Body

class PlayerPhysicsBody {
    let node: SCNNode
    let playerId: UUID
    let playerPosition: String
    var velocity: SCNVector3 = SCNVector3(0, 0, 0)
    var isCarryingBall: Bool = false
    var isTackled: Bool = false

    init(playerId: UUID, playerPosition: String, teamColor: NSColor, startPosition: SCNVector3) {
        self.playerId = playerId
        self.playerPosition = playerPosition

        let capsule = SCNCapsule(capRadius: CGFloat(PhysicsConfig.playerRadius),
                                  height: CGFloat(PhysicsConfig.playerRadius * 4))
        capsule.firstMaterial?.diffuse.contents = teamColor

        node = SCNNode(geometry: capsule)
        node.position = startPosition
        node.eulerAngles.x = .pi / 2

        let physicsShape = SCNPhysicsShape(geometry: capsule, options: nil)
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: physicsShape)
        node.physicsBody?.mass = CGFloat(PhysicsConfig.playerMass)
        node.physicsBody?.friction = 0.8
        node.physicsBody?.restitution = 0.2
        node.physicsBody?.angularDamping = 0.9
        node.physicsBody?.categoryBitMask = PhysicsCategory.player
        node.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.ball
    }

    func moveTo(target: SCNVector3, speed: Float) {
        let dx = Float(target.x - node.position.x)
        let dz = Float(target.z - node.position.z)
        let length = sqrtf(dx * dx + dz * dz)
        if length > 0.1 {
            let vx = dx / length * speed
            let vz = dz / length * speed
            node.physicsBody?.velocity = SCNVector3(vx, 0, vz)
        }
    }

    func tackle() {
        isTackled = true
        node.physicsBody?.velocity = SCNVector3(0, 0, 0)
        node.physicsBody?.angularVelocity = SCNVector4(0, 0, 0, 0)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        node.eulerAngles.z = .pi / 2
        SCNTransaction.commit()
    }

    func reset(to position: SCNVector3) {
        isTackled = false
        node.position = position
        node.eulerAngles = SCNVector3(x: .pi / 2, y: 0, z: 0)
        node.physicsBody?.velocity = SCNVector3(0, 0, 0)
    }
}

// MARK: - Football Physics Body

class FootballPhysicsBody {
    let node: SCNNode
    var isInFlight: Bool = false
    var carrier: PlayerPhysicsBody?

    init() {
        let football = SCNSphere(radius: CGFloat(PhysicsConfig.ballRadius))
        football.firstMaterial?.diffuse.contents = NSColor.brown

        node = SCNNode(geometry: football)
        node.scale = SCNVector3(1.0, 0.6, 0.6)

        let physicsShape = SCNPhysicsShape(geometry: football, options: nil)
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: physicsShape)
        node.physicsBody?.mass = CGFloat(PhysicsConfig.ballMass)
        node.physicsBody?.friction = 0.6
        node.physicsBody?.restitution = 0.4
        node.physicsBody?.categoryBitMask = PhysicsCategory.ball
        node.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.ground
    }

    func throwTo(target: SCNVector3, from start: SCNVector3) {
        isInFlight = true
        carrier = nil
        node.position = start

        let dx = Float(target.x - start.x)
        let dy = Float(target.y - start.y) + 5
        let dz = Float(target.z - start.z)

        let distance = sqrtf(dx * dx + dz * dz)
        let flightTime = distance / PhysicsConfig.passSpeed

        let vx = dx / flightTime
        let vy = dy / flightTime + PhysicsConfig.gravity * flightTime / 2
        let vz = dz / flightTime

        node.physicsBody?.velocity = SCNVector3(vx, vy, vz)
        node.physicsBody?.angularVelocity = SCNVector4(1, 0, 0, 10)
    }

    func attachTo(player: PlayerPhysicsBody) {
        isInFlight = false
        carrier = player
        player.isCarryingBall = true
    }

    func update() {
        if let carrier = carrier {
            node.position = SCNVector3(
                carrier.node.position.x,
                carrier.node.position.y + 1,
                carrier.node.position.z
            )
        }
    }
}

// MARK: - Physics Categories

struct PhysicsCategory {
    static let none: Int = 0
    static let player: Int = 1 << 0
    static let ball: Int = 1 << 1
    static let ground: Int = 1 << 2
    static let boundary: Int = 1 << 3
}

// MARK: - Football Field Scene

class FootballFieldScene: SCNScene {
    var offensivePlayers: [PlayerPhysicsBody] = []
    var defensivePlayers: [PlayerPhysicsBody] = []
    var football: FootballPhysicsBody!
    var lineOfScrimmage: Float = 25.0
    var cameraNode: SCNNode!

    override init() {
        super.init()
        setupField()
        setupLighting()
        setupCamera()
        setupFootball()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupField() {
        let field = SCNBox(width: CGFloat(PhysicsConfig.fieldWidth),
                          height: 0.1,
                          length: CGFloat(PhysicsConfig.fieldLength + 20),
                          chamferRadius: 0)
        field.firstMaterial?.diffuse.contents = NSColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 1.0)

        let fieldNode = SCNNode(geometry: field)
        fieldNode.position = SCNVector3(0, -0.05, PhysicsConfig.fieldLength / 2)
        fieldNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        fieldNode.physicsBody?.categoryBitMask = PhysicsCategory.ground
        rootNode.addChildNode(fieldNode)

        // Yard lines
        for yard in stride(from: 0, through: Int(PhysicsConfig.fieldLength), by: 10) {
            let line = SCNBox(width: CGFloat(PhysicsConfig.fieldWidth), height: 0.02, length: 0.2, chamferRadius: 0)
            line.firstMaterial?.diffuse.contents = NSColor.white

            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(0, 0.01, Float(yard))
            rootNode.addChildNode(lineNode)

            if yard > 0 && yard < 100 && yard % 10 == 0 {
                let displayYard = yard <= 50 ? yard : 100 - yard
                let text = SCNText(string: "\(displayYard)", extrusionDepth: 0.1)
                text.font = NSFont.systemFont(ofSize: 3)
                text.firstMaterial?.diffuse.contents = NSColor.white

                let textNode = SCNNode(geometry: text)
                textNode.position = SCNVector3(-12, 0.1, Float(yard) - 1)
                textNode.eulerAngles.x = -.pi / 2
                rootNode.addChildNode(textNode)
            }
        }

        // End zones
        let endZoneColors: [NSColor] = [.blue, .orange]
        let endZonePositions: [Float] = [-5, PhysicsConfig.fieldLength + 5]
        for (index, zPosition) in endZonePositions.enumerated() {
            let endZone = SCNBox(width: CGFloat(PhysicsConfig.fieldWidth),
                                height: 0.12,
                                length: 10,
                                chamferRadius: 0)
            endZone.firstMaterial?.diffuse.contents = endZoneColors[index]

            let endZoneNode = SCNNode(geometry: endZone)
            endZoneNode.position = SCNVector3(0, 0, zPosition)
            rootNode.addChildNode(endZoneNode)
        }

        // Goal posts
        let goalPostPositions: [Float] = [-10, PhysicsConfig.fieldLength + 10]
        for zPosition in goalPostPositions {
            addGoalPost(at: SCNVector3(0, 0, zPosition))
        }
    }

    private func addGoalPost(at position: SCNVector3) {
        let postMaterial = SCNMaterial()
        postMaterial.diffuse.contents = NSColor.yellow

        let verticalPost = SCNCylinder(radius: 0.15, height: 10)
        verticalPost.firstMaterial = postMaterial
        let verticalNode = SCNNode(geometry: verticalPost)
        verticalNode.position = SCNVector3(position.x, 5, position.z)
        rootNode.addChildNode(verticalNode)

        let crossbar = SCNCylinder(radius: 0.1, height: 18.5)
        crossbar.firstMaterial = postMaterial
        let crossbarNode = SCNNode(geometry: crossbar)
        crossbarNode.position = SCNVector3(position.x, 10, position.z)
        crossbarNode.eulerAngles.z = .pi / 2
        rootNode.addChildNode(crossbarNode)

        let offsets: [Float] = [-9.25, 9.25]
        for xOffset in offsets {
            let upright = SCNCylinder(radius: 0.08, height: 15)
            upright.firstMaterial = postMaterial
            let uprightNode = SCNNode(geometry: upright)
            uprightNode.position = SCNVector3(Float(position.x) + xOffset, 17.5, Float(position.z))
            rootNode.addChildNode(uprightNode)
        }
    }

    private func setupLighting() {
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 500
        ambientLight.color = NSColor.white

        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        rootNode.addChildNode(ambientNode)

        let lightPositions: [SCNVector3] = [
            SCNVector3(-40, 30, 25),
            SCNVector3(40, 30, 25),
            SCNVector3(-40, 30, 75),
            SCNVector3(40, 30, 75)
        ]
        for pos in lightPositions {
            let spotLight = SCNLight()
            spotLight.type = .spot
            spotLight.intensity = 2000
            spotLight.spotInnerAngle = 30
            spotLight.spotOuterAngle = 60
            spotLight.castsShadow = true

            let lightNode = SCNNode()
            lightNode.light = spotLight
            lightNode.position = pos
            lightNode.look(at: SCNVector3(0, 0, 50))
            rootNode.addChildNode(lightNode)
        }
    }

    private func setupCamera() {
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        cameraNode.position = SCNVector3(0, 30, -10)
        cameraNode.look(at: SCNVector3(0, 0, lineOfScrimmage))
        rootNode.addChildNode(cameraNode)
    }

    private func setupFootball() {
        football = FootballPhysicsBody()
        rootNode.addChildNode(football.node)
        football.node.position = SCNVector3(0, 1, lineOfScrimmage)
    }

    // MARK: - Team Setup

    func setupTeams(offense: Team, defense: Team, lineOfScrimmage los: CGFloat) {
        self.lineOfScrimmage = Float(los)

        offensivePlayers.forEach { $0.node.removeFromParentNode() }
        defensivePlayers.forEach { $0.node.removeFromParentNode() }
        offensivePlayers.removeAll()
        defensivePlayers.removeAll()

        let offensivePositions = getOffensiveFormationPositions(at: self.lineOfScrimmage)
        let offenseColor = NSColor(offense.colors.primaryColor)

        for (index, pos) in offensivePositions.enumerated() {
            let player = PlayerPhysicsBody(
                playerId: UUID(),
                playerPosition: "QB",
                teamColor: offenseColor,
                startPosition: pos
            )
            offensivePlayers.append(player)
            rootNode.addChildNode(player.node)

            if index == 0 {
                football.attachTo(player: player)
            }
        }

        let defensivePositions = getDefensiveFormationPositions(at: self.lineOfScrimmage)
        let defenseColor = NSColor(defense.colors.primaryColor)

        for pos in defensivePositions {
            let player = PlayerPhysicsBody(
                playerId: UUID(),
                playerPosition: "LB",
                teamColor: defenseColor,
                startPosition: pos
            )
            defensivePlayers.append(player)
            rootNode.addChildNode(player.node)
        }

        cameraNode.position = SCNVector3(0, 25, self.lineOfScrimmage - 20)
        cameraNode.look(at: SCNVector3(0, 0, self.lineOfScrimmage + 10))
    }

    private func getOffensiveFormationPositions(at los: Float) -> [SCNVector3] {
        return [
            SCNVector3(0, 1, los - 3),
            SCNVector3(0, 1, los - 7),
            SCNVector3(0, 1, los - 9),
            SCNVector3(-2, 1, los),
            SCNVector3(-1, 1, los),
            SCNVector3(1, 1, los),
            SCNVector3(2, 1, los),
            SCNVector3(-3, 1, los),
            SCNVector3(-10, 1, los),
            SCNVector3(10, 1, los),
            SCNVector3(5, 1, los - 1),
        ]
    }

    private func getDefensiveFormationPositions(at los: Float) -> [SCNVector3] {
        return [
            SCNVector3(-4, 1, los + 1),
            SCNVector3(-1.5, 1, los + 1),
            SCNVector3(1.5, 1, los + 1),
            SCNVector3(4, 1, los + 1),
            SCNVector3(-3, 1, los + 4),
            SCNVector3(0, 1, los + 3),
            SCNVector3(3, 1, los + 4),
            SCNVector3(-10, 1, los + 5),
            SCNVector3(10, 1, los + 5),
            SCNVector3(-5, 1, los + 10),
            SCNVector3(5, 1, los + 10),
        ]
    }

    // MARK: - Play Animation

    func animatePlay(playType: PlayType, yardsGained: Int, completion: @escaping () -> Void) {
        guard offensivePlayers.first != nil else {
            completion()
            return
        }

        let targetZ = lineOfScrimmage + Float(yardsGained)

        if playType.isRun {
            animateRunPlay(targetZ: targetZ, completion: completion)
        } else if playType.isPass {
            animatePassPlay(targetZ: targetZ, yardsGained: yardsGained, completion: completion)
        } else {
            completion()
        }
    }

    private func animateRunPlay(targetZ: Float, completion: @escaping () -> Void) {
        guard offensivePlayers.count > 2,
              let hb = offensivePlayers.dropFirst(2).first else {
            completion()
            return
        }

        football.attachTo(player: hb)

        let runDuration = TimeInterval(abs(targetZ - lineOfScrimmage) / PhysicsConfig.runSpeed)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = runDuration
        SCNTransaction.completionBlock = {
            hb.tackle()
            Task { @MainActor in
                SoundManager.shared.play(.tackle)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion()
            }
        }

        hb.node.position.z = CGFloat(targetZ)

        for defender in defensivePlayers {
            let target = SCNVector3(Float(hb.node.position.x), 1, targetZ)
            defender.moveTo(target: target, speed: PhysicsConfig.runSpeed * 0.9)
        }

        SCNTransaction.commit()
    }

    private func animatePassPlay(targetZ: Float, yardsGained: Int, completion: @escaping () -> Void) {
        guard let qb = offensivePlayers.first,
              let receiver = offensivePlayers.last else {
            completion()
            return
        }

        let receiverTarget = SCNVector3(Float(receiver.node.position.x), 1, targetZ)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.5
        receiver.node.position = receiverTarget
        SCNTransaction.commit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.football.throwTo(target: receiverTarget, from: qb.node.position)
            Task { @MainActor in
                SoundManager.shared.play(.hike)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if yardsGained > 0 {
                self.football.attachTo(player: receiver)
                Task { @MainActor in
                    SoundManager.shared.play(.catch_sound)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    receiver.tackle()
                    Task { @MainActor in
                        SoundManager.shared.play(.tackle)
                    }
                    completion()
                }
            } else {
                Task { @MainActor in
                    SoundManager.shared.play(.incomplete)
                }
                completion()
            }
        }
    }

    func reset() {
        let offensivePositions = getOffensiveFormationPositions(at: lineOfScrimmage)
        for (index, player) in offensivePlayers.enumerated() {
            if index < offensivePositions.count {
                player.reset(to: offensivePositions[index])
            }
        }

        let defensivePositions = getDefensiveFormationPositions(at: lineOfScrimmage)
        for (index, player) in defensivePlayers.enumerated() {
            if index < defensivePositions.count {
                player.reset(to: defensivePositions[index])
            }
        }

        if let qb = offensivePlayers.first {
            football.attachTo(player: qb)
        }
    }
}
