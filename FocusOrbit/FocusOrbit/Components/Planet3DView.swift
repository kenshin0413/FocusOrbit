import SceneKit
import SwiftUI
import UIKit

struct Planet3DView: UIViewRepresentable {
    let destination: Destination
    var earth = false

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.scene = buildScene()
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling2X
        view.allowsCameraControl = false
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        let root = SCNNode()
        scene.rootNode.addChildNode(root)

        if destination == .station && !earth {
            root.addChildNode(stationNode())
        } else {
            let sphere = SCNSphere(radius: 1)
            sphere.segmentCount = 144
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = PlanetTextureFactory.texture(for: destination, earth: earth)
            material.roughness.contents = earth ? 0.54 : 0.78
            material.metalness.contents = 0.02
            material.normal.intensity = 0.4
            sphere.firstMaterial = material
            let planet = SCNNode(geometry: sphere)
            planet.runAction(.repeatForever(.rotateBy(x: 0.03, y: .pi * 2, z: 0, duration: earth ? 55 : 70)))
            root.addChildNode(planet)
            if destination == .saturn && !earth { root.addChildNode(ringsNode()) }
        }

        root.eulerAngles.x = earth ? -0.12 : 0.13
        root.eulerAngles.z = earth ? -0.28 : 0.08

        let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera?.fieldOfView = 36; camera.position = SCNVector3(0, 0, 4.15)
        scene.rootNode.addChildNode(camera)
        let key = SCNNode(); key.light = SCNLight(); key.light?.type = .directional; key.light?.intensity = 1_650; key.light?.temperature = 5_900; key.eulerAngles = SCNVector3(-0.65, -0.72, 0)
        scene.rootNode.addChildNode(key)
        let rim = SCNNode(); rim.light = SCNLight(); rim.light?.type = .omni; rim.light?.intensity = 520; rim.light?.color = UIColor(destination.accent); rim.position = SCNVector3(2.8, -1.3, 2.4)
        scene.rootNode.addChildNode(rim)
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 105; ambient.light?.color = UIColor(white: 0.35, alpha: 1)
        scene.rootNode.addChildNode(ambient)
        return scene
    }

    private func ringsNode() -> SCNNode {
        let torus = SCNTorus(ringRadius: 1.38, pipeRadius: 0.12)
        torus.ringSegmentCount = 160; torus.pipeSegmentCount = 18
        let material = SCNMaterial(); material.diffuse.contents = UIColor(red: 0.72, green: 0.61, blue: 0.42, alpha: 0.72); material.roughness.contents = 0.9
        torus.firstMaterial = material
        let node = SCNNode(geometry: torus); node.scale = SCNVector3(1, 0.18, 1); node.eulerAngles.x = 0.32
        return node
    }

    private func stationNode() -> SCNNode {
        let root = SCNNode()
        let core = SCNCylinder(radius: 0.22, height: 1.7); core.firstMaterial?.diffuse.contents = UIColor(white: 0.68, alpha: 1)
        let coreNode = SCNNode(geometry: core); coreNode.eulerAngles.z = .pi / 2; root.addChildNode(coreNode)
        for side in [-1.0, 1.0] {
            let panel = SCNBox(width: 1.05, height: 0.04, length: 0.44, chamferRadius: 0.02)
            panel.firstMaterial?.diffuse.contents = UIColor(red: 0.08, green: 0.19, blue: 0.38, alpha: 1)
            let node = SCNNode(geometry: panel); node.position.x = Float(side * 0.92); root.addChildNode(node)
        }
        root.runAction(.repeatForever(.rotateBy(x: 0.1, y: .pi * 2, z: 0.15, duration: 80)))
        return root
    }
}

@MainActor
private enum PlanetTextureFactory {
    private static var cache: [String: UIImage] = [:]

    static func texture(for destination: Destination, earth: Bool) -> UIImage {
        let key = earth ? "earth" : destination.rawValue
        if let cached = cache[key] { return cached }
        let size = CGSize(width: 1024, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            let colors = palette(destination: destination, earth: earth)
            context.setFillColor(colors.base.cgColor); context.fill(CGRect(origin: .zero, size: size))
            var random = SeededRandom(seed: UInt64(key.utf8.reduce(0) { $0 + Int($1) }) + 91)

            if destination == .jupiter && !earth {
                for band in 0..<22 {
                    context.setFillColor(colors.secondary.withAlphaComponent(CGFloat.random(in: 0.09...0.33, using: &random)).cgColor)
                    context.fill(CGRect(x: 0, y: CGFloat(band) * 24 + CGFloat.random(in: -5...5, using: &random), width: size.width, height: CGFloat.random(in: 7...22, using: &random)))
                }
                context.setFillColor(UIColor(red: 0.60, green: 0.25, blue: 0.16, alpha: 0.65).cgColor)
                context.fillEllipse(in: CGRect(x: 670, y: 285, width: 125, height: 54))
            } else {
                for _ in 0..<180 {
                    let width = CGFloat.random(in: 10...130, using: &random)
                    let height = earth ? CGFloat.random(in: 5...46, using: &random) : CGFloat.random(in: 4...28, using: &random)
                    let rect = CGRect(x: CGFloat.random(in: -30...size.width, using: &random), y: CGFloat.random(in: 0...size.height, using: &random), width: width, height: height)
                    context.setFillColor(colors.secondary.withAlphaComponent(CGFloat.random(in: 0.06...0.38, using: &random)).cgColor)
                    context.fillEllipse(in: rect)
                }
            }
            if earth {
                context.setFillColor(UIColor.white.withAlphaComponent(0.22).cgColor)
                for _ in 0..<35 {
                    context.fillEllipse(in: CGRect(x: CGFloat.random(in: 0...size.width, using: &random), y: CGFloat.random(in: 0...size.height, using: &random), width: CGFloat.random(in: 35...160, using: &random), height: CGFloat.random(in: 3...13, using: &random)))
                }
            }
        }
        cache[key] = image
        return image
    }

    private static func palette(destination: Destination, earth: Bool) -> (base: UIColor, secondary: UIColor) {
        if earth { return (UIColor(red: 0.02, green: 0.16, blue: 0.34, alpha: 1), UIColor(red: 0.25, green: 0.48, blue: 0.25, alpha: 1)) }
        switch destination {
        case .moon: return (UIColor(white: 0.48, alpha: 1), UIColor(white: 0.82, alpha: 1))
        case .station: return (.darkGray, .lightGray)
        case .mercury: return (UIColor(white: 0.34, alpha: 1), UIColor(white: 0.72, alpha: 1))
        case .venus: return (UIColor(red: 0.68, green: 0.52, blue: 0.30, alpha: 1), UIColor(red: 0.95, green: 0.82, blue: 0.60, alpha: 1))
        case .mars: return (UIColor(red: 0.34, green: 0.08, blue: 0.035, alpha: 1), UIColor(red: 0.83, green: 0.31, blue: 0.13, alpha: 1))
        case .jupiter: return (UIColor(red: 0.60, green: 0.43, blue: 0.29, alpha: 1), UIColor(red: 0.94, green: 0.77, blue: 0.58, alpha: 1))
        case .saturn: return (UIColor(red: 0.56, green: 0.43, blue: 0.25, alpha: 1), UIColor(red: 0.92, green: 0.78, blue: 0.52, alpha: 1))
        case .uranus: return (UIColor(red: 0.35, green: 0.70, blue: 0.76, alpha: 1), UIColor(red: 0.72, green: 0.94, blue: 0.96, alpha: 1))
        case .neptune: return (UIColor(red: 0.10, green: 0.22, blue: 0.62, alpha: 1), UIColor(red: 0.32, green: 0.54, blue: 0.96, alpha: 1))
        case .pluto: return (UIColor(red: 0.37, green: 0.27, blue: 0.21, alpha: 1), UIColor(red: 0.82, green: 0.70, blue: 0.58, alpha: 1))
        }
    }
}

private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = 2_862_933_555_777_941_757 &* state &+ 3_037_000_493
        return state
    }
}
