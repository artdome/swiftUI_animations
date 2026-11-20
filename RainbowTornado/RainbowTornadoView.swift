//
//  RainbowTornadoView.swift
//  Rainbow particle tornado with tumbling 3D dice — SwiftUI, iOS 17+
//
//  Copyright (c) 2026 Arturs (https://github.com/artdome)
//  SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//  Free for non-commercial use. Commercial use is not allowed. See LICENSE.md.
//
//  How to run:
//  • Simulator / iPhone: make it the root view in your App file:
//        WindowGroup { RainbowTornadoView() }
//    then Cmd+R.
//  • Xcode preview: make sure the preview is in LIVE mode (▶︎ button under
//    the preview), not "Selectable" — a static preview does not animate.
//

import SwiftUI

struct RainbowTornadoView: View {

    // MARK: - Tunables
    private let riseSpeed = 0.07          // how fast particles climb the funnel
    private let spinSpeed = 4.2           // rotation speed at the bottom
    private let colorFlow = 0.12          // how fast the rainbow flows

    // MARK: - Model (created once, no onAppear needed)
    private struct Particle {
        let phase, h0, speed, size, jitter: Double
        let isDust: Bool                  // swirling ground cloud
    }

    private struct Debris {
        let phase, h0, scale: Double
        let ax, ay, az: Double            // starting orientation (radians)
        let wx, wy, wz: Double            // tumbling speed around X / Y / Z (rad/s)
    }

    private static let particles: [Particle] = {
        var rng = SeededRNG(seed: 42)
        return (0..<1800).map { _ in
            Particle(
                phase: .random(in: 0..<(2 * .pi), using: &rng),
                h0: .random(in: 0..<1, using: &rng),
                speed: .random(in: 0.75...1.35, using: &rng),
                size: .random(in: 1.6...4.6, using: &rng),
                jitter: .random(in: -1...1, using: &rng),
                isDust: Double.random(in: 0...1, using: &rng) < 0.16
            )
        }
    }()

    private static let debris: [Debris] = {
        var rng = SeededRNG(seed: 7)
        return (0..<9).map { _ in
            Debris(
                phase: .random(in: 0..<(2 * .pi), using: &rng),
                h0: .random(in: 0..<1, using: &rng),
                scale: .random(in: 0.9...1.5, using: &rng),
                ax: .random(in: 0..<(2 * .pi), using: &rng),
                ay: .random(in: 0..<(2 * .pi), using: &rng),
                az: .random(in: 0..<(2 * .pi), using: &rng),
                wx: .random(in: -3...3, using: &rng),
                wy: .random(in: -3...3, using: &rng),
                wz: .random(in: -2...2, using: &rng)
            )
        }
    }()

    @State private var startDate = Date()

    // MARK: - View
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)

            Canvas { context, size in
                drawBackground(context, size: size, t: t)

                // 1) Soft glow layer (blurred, bigger particles)
                context.drawLayer { glow in
                    glow.addFilter(.blur(radius: 12))
                    drawFunnel(glow, size: size, t: t, sizeScale: 3.2, alpha: 0.4)
                }

                // 2) Sharp particles on top, additive "neon" blending
                var sharp = context
                sharp.blendMode = .plusLighter
                drawFunnel(sharp, size: size, t: t, sizeScale: 1, alpha: 1)

                // 3) Dice flying around the funnel
                drawDebris(context, size: size, t: t)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
    }

    // MARK: - Geometry shared by particles and dice

    /// Screen point + depth (-1 = behind, 1 = in front) for a point on the funnel.
    private func funnelPoint(h: Double, angle: Double, radiusOffset: Double,
                             size: CGSize, t: Double) -> (CGPoint, Double) {
        let w = size.width
        let baseY = size.height * 0.86
        let topY = size.height * 0.10

        // Funnel widens towards the top
        let radius = 12 + pow(h, 1.7) * w * 0.42 + radiusOffset
        // The whole column sways like a real twister (more at the top)
        let sway = sin(t * 0.9 + h * 3.2) * 34 * h + sin(t * 0.55) * 20

        let depth = sin(angle)
        let x = w / 2 + sway + cos(angle) * radius
        let y = baseY - h * (baseY - topY) + depth * radius * 0.22   // tilt = 3D ellipse
        return (CGPoint(x: x, y: y), depth)
    }

    // MARK: - Drawing

    private func drawBackground(_ context: GraphicsContext, size: CGSize, t: Double) {
        let rect = CGRect(origin: .zero, size: size)
        let pulse = 0.5 + 0.5 * sin(t * 0.8)
        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(hue: 0.75, saturation: 0.8, brightness: 0.22 + 0.06 * pulse),
                    Color(hue: 0.68, saturation: 0.9, brightness: 0.07),
                    .black
                ]),
                center: CGPoint(x: size.width / 2, y: size.height * 0.55),
                startRadius: 0,
                endRadius: size.height * 0.75
            )
        )
    }

    private func drawFunnel(_ context: GraphicsContext, size: CGSize, t: Double,
                            sizeScale: Double, alpha: Double) {
        for p in Self.particles {
            var h = (p.h0 + t * riseSpeed * p.speed).truncatingRemainder(dividingBy: 1)
            var radiusOffset = p.jitter * 7
            var angle = p.phase + t * p.speed * (spinSpeed - 2.8 * h)   // faster at the bottom

            if p.isDust {
                // wide, flat cloud at the base
                h *= 0.06
                radiusOffset = size.width * (0.18 + 0.14 * (p.jitter + 1))
                angle = p.phase + t * p.speed * 1.6
            }

            let (pt, depth) = funnelPoint(h: h, angle: angle, radiusOffset: radiusOffset, size: size, t: t)

            // fade in at the bottom, fade out at the top
            let fade = p.isDust ? 0.55 : min(1, h * 10) * min(1, (1 - h) * 5)
            let front = (depth + 1) / 2                     // 0 back ... 1 front
            let opacity = fade * (0.3 + 0.7 * front) * alpha
            let hue = (h * 0.9 + t * colorFlow + p.phase * 0.02).truncatingRemainder(dividingBy: 1)
            let s = p.size * (0.65 + 0.6 * front) * sizeScale

            let rect = CGRect(x: pt.x - s / 2, y: pt.y - s / 2, width: s, height: s)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color(hue: hue, saturation: 0.85, brightness: 1).opacity(opacity))
            )
        }
    }

    private func drawDebris(_ context: GraphicsContext, size: CGSize, t: Double) {
        for d in Self.debris {
            let h = (d.h0 + t * 0.05).truncatingRemainder(dividingBy: 1)
            let angle = d.phase + t * (2.6 - 1.4 * h)
            let (pt, depth) = funnelPoint(h: h, angle: angle, radiusOffset: 40, size: size, t: t)
            let front = (depth + 1) / 2
            let fade = min(1, h * 6) * min(1, (1 - h) * 4)

            drawDie3D(
                context,
                at: pt,
                half: 11 * d.scale * (0.7 + 0.6 * front),      // half of the cube edge, in points
                ax: d.ax + t * d.wx,
                ay: d.ay + t * d.wy,
                az: d.az + t * d.wz,
                opacity: fade * (0.45 + 0.55 * front)
            )
        }
    }

    // MARK: - 3D tumbling die

    private struct Vec3 { var x, y, z: Double }

    /// One cube face: outward normal, two in-plane axes, number of pips.
    private struct CubeFace { let n, u, v: Vec3; let pips: Int }

    // Opposite faces add up to 7, like a real die.
    private static let cubeFaces: [CubeFace] = [
        CubeFace(n: Vec3(x: 0, y: 0, z: 1),  u: Vec3(x: 1, y: 0, z: 0),  v: Vec3(x: 0, y: 1, z: 0),  pips: 1),
        CubeFace(n: Vec3(x: 0, y: 0, z: -1), u: Vec3(x: -1, y: 0, z: 0), v: Vec3(x: 0, y: 1, z: 0),  pips: 6),
        CubeFace(n: Vec3(x: 1, y: 0, z: 0),  u: Vec3(x: 0, y: 0, z: -1), v: Vec3(x: 0, y: 1, z: 0),  pips: 2),
        CubeFace(n: Vec3(x: -1, y: 0, z: 0), u: Vec3(x: 0, y: 0, z: 1),  v: Vec3(x: 0, y: 1, z: 0),  pips: 5),
        CubeFace(n: Vec3(x: 0, y: -1, z: 0), u: Vec3(x: 1, y: 0, z: 0),  v: Vec3(x: 0, y: 0, z: 1),  pips: 3),
        CubeFace(n: Vec3(x: 0, y: 1, z: 0),  u: Vec3(x: 1, y: 0, z: 0),  v: Vec3(x: 0, y: 0, z: -1), pips: 4),
    ]

    /// Pip positions in face-local coordinates (face spans -1...1).
    private static func pipOffsets(_ count: Int) -> [CGPoint] {
        let o = 0.5
        switch count {
        case 1: return [.zero]
        case 2: return [CGPoint(x: -o, y: -o), CGPoint(x: o, y: o)]
        case 3: return [CGPoint(x: -o, y: -o), .zero, CGPoint(x: o, y: o)]
        case 4: return [CGPoint(x: -o, y: -o), CGPoint(x: o, y: -o), CGPoint(x: -o, y: o), CGPoint(x: o, y: o)]
        case 5: return [CGPoint(x: -o, y: -o), CGPoint(x: o, y: -o), .zero, CGPoint(x: -o, y: o), CGPoint(x: o, y: o)]
        default: return [CGPoint(x: -o, y: -o), CGPoint(x: o, y: -o), CGPoint(x: -o, y: 0),
                         CGPoint(x: o, y: 0), CGPoint(x: -o, y: o), CGPoint(x: o, y: o)]
        }
    }

    /// Rotate around X, then Y, then Z.
    private func rotate(_ p: Vec3, ax: Double, ay: Double, az: Double) -> Vec3 {
        let y1 = p.y * cos(ax) - p.z * sin(ax)
        let z1 = p.y * sin(ax) + p.z * cos(ax)
        let x2 = p.x * cos(ay) + z1 * sin(ay)
        let z2 = -p.x * sin(ay) + z1 * cos(ay)
        let x3 = x2 * cos(az) - y1 * sin(az)
        let y3 = x2 * sin(az) + y1 * cos(az)
        return Vec3(x: x3, y: y3, z: z2)
    }

    private func drawDie3D(_ context: GraphicsContext, at center: CGPoint, half: Double,
                           ax: Double, ay: Double, az: Double, opacity: Double) {
        // Rotate every face and keep only those turned towards the viewer (z > 0)
        var visible: [(n: Vec3, u: Vec3, v: Vec3, pips: Int)] = []
        for face in Self.cubeFaces {
            let n = rotate(face.n, ax: ax, ay: ay, az: az)
            guard n.z > 0.02 else { continue }
            visible.append((n: n,
                            u: rotate(face.u, ax: ax, ay: ay, az: az),
                            v: rotate(face.v, ax: ax, ay: ay, az: az),
                            pips: face.pips))
        }
        visible.sort { $0.n.z < $1.n.z }

        var c = context
        c.opacity = opacity
        let unit = CGRect(x: -1, y: -1, width: 2, height: 2)

        for f in visible {
            // Maps the flat face square (-1...1) onto its rotated position on screen
            let transform = CGAffineTransform(
                a: f.u.x * half, b: f.u.y * half,
                c: f.v.x * half, d: f.v.y * half,
                tx: center.x + f.n.x * half, ty: center.y + f.n.y * half
            )
            let light = 0.45 + 0.55 * f.n.z                      // faces turned away are darker
            let facePath = Path(roundedRect: unit, cornerRadius: 0.18).applying(transform)
            c.fill(facePath, with: .color(Color(white: light)))
            c.stroke(facePath, with: .color(.black.opacity(0.25)), lineWidth: 0.8)

            for pip in Self.pipOffsets(f.pips) {
                let r = 0.18
                let pipPath = Path(ellipseIn: CGRect(x: pip.x - r, y: pip.y - r, width: 2 * r, height: 2 * r))
                    .applying(transform)
                c.fill(pipPath, with: .color(Color(red: 0.12, green: 0.08, blue: 0.22)))
            }
        }
    }
}

// MARK: - Deterministic random generator (same tornado every launch)

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

#Preview {
    RainbowTornadoView()
}
