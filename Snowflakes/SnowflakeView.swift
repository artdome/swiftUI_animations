//
//  SnowflakeView.swift
//  Tap the winter sky and a brand new snowflake grows, then drifts down. SwiftUI Canvas, iOS 17+
//
//  Copyright (c) 2026 Arturs (https://github.com/artdome)
//  SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//  Free for non-commercial use. Commercial use is not allowed. See LICENSE.md.
//
//  • Night sky with stars, light snowfall, snowy hills and pine trees.
//  • Every tap grows a snowflake right under your finger. Like a real ice crystal it has
//    6 identical arms, but each flake gets its own random arm: side branches, little twigs,
//    plates at the tips. No two are the same.
//  • The flake grows from the centre out, glows for a moment, then slowly falls, spinning
//    and swaying, and melts into the snow on the ground.
//
//  How to run:
//  • Make it the root view in your App file:
//        WindowGroup { SnowflakeView() }
//    then Cmd+R and tap the sky.
//  • Xcode preview: switch the preview to LIVE mode (▶︎), not "Selectable".
//

import SwiftUI

struct SnowflakeView: View {
    @State private var flakes: [Snowflake] = []
    @State private var taps = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                draw(context, size: size, now: timeline.date)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .contentShape(Rectangle())
        .onTapGesture { location in
            let now = Date()
            flakes.removeAll { now.timeIntervalSince($0.start) > 40 }
            flakes.append(Snowflake.make(at: location, start: now))
            taps += 1
        }
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }

    // MARK: - Drawing

    private func draw(_ context: GraphicsContext, size: CGSize, now: Date) {
        let w = Double(size.width), h = Double(size.height)
        let t = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000)
        let ground = h * 0.86

        // Sky
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Color(red: 0.02, green: 0.04, blue: 0.12),
                                                            Color(red: 0.10, green: 0.16, blue: 0.32)]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: ground)))
        // Stars
        for s in Self.stars {
            let twinkle = 0.5 + 0.5 * sin(t * s.speed + s.phase)
            let r = s.size
            context.fill(Path(ellipseIn: CGRect(x: s.x * w - r, y: s.y * h - r, width: 2 * r, height: 2 * r)),
                         with: .color(.white.opacity(0.25 + 0.6 * twinkle)))
        }

        // Snowflakes (behind the hills, so they melt into the snow)
        for flake in flakes {
            drawFlake(flake, in: context, now: now, ground: ground)
        }

        // Hills, trees and snow on the ground
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: h))
        for i in 0...60 {
            let x = w * Double(i) / 60
            hills.addLine(to: CGPoint(x: x, y: ground - h * 0.02 * sin(Double(i) * 0.16 + 0.8) - h * 0.012 * sin(Double(i) * 0.41)))
        }
        hills.addLine(to: CGPoint(x: w, y: h))
        hills.closeSubpath()
        for tree in Self.trees {
            let x = tree.x * w, baseY = ground - h * 0.02 * sin(tree.x * 60 * 0.16 + 0.8)
            let th = tree.height * h, tw = th * 0.42
            var pine = Path()
            for layer in 0..<3 {
                let top = baseY - th + Double(layer) * th * 0.25
                let wide = tw * (0.55 + 0.25 * Double(layer))
                pine.move(to: CGPoint(x: x, y: top))
                pine.addLine(to: CGPoint(x: x - wide / 2, y: top + th * 0.45))
                pine.addLine(to: CGPoint(x: x + wide / 2, y: top + th * 0.45))
                pine.closeSubpath()
            }
            context.fill(pine, with: .color(Color(red: 0.04, green: 0.08, blue: 0.16)))
        }
        context.fill(hills, with: .linearGradient(Gradient(colors: [Color(red: 0.86, green: 0.91, blue: 1),
                                                                    Color(red: 0.62, green: 0.72, blue: 0.9)]),
                                                  startPoint: CGPoint(x: 0, y: ground - h * 0.04), endPoint: CGPoint(x: 0, y: h)))

        // Light snowfall in front of everything
        var snow = Path()
        for d in Self.snowfall {
            let y = (d.y * (h + 20) + t * d.speed).truncatingRemainder(dividingBy: h + 20) - 10
            let x = d.x * w + sin(t * 0.8 + d.phase) * 14
            snow.addEllipse(in: CGRect(x: x - d.size, y: y - d.size, width: 2 * d.size, height: 2 * d.size))
        }
        context.fill(snow, with: .color(.white.opacity(0.75)))
    }

    private func drawFlake(_ flake: Snowflake, in context: GraphicsContext, now: Date, ground: Double) {
        let age = now.timeIntervalSince(flake.start)
        guard age >= 0 else { return }

        // Grow, hold, fall
        let g = min(1, age / Snowflake.growTime)
        let grown = 1 - (1 - g) * (1 - g) * (1 - g)
        let fallT = max(0, age - Snowflake.growTime - Snowflake.holdTime)
        let x = Double(flake.center.x) + flake.sway * sin(fallT * 1.1 + flake.phase) * min(1, fallT)
        let y = Double(flake.center.y) + flake.fallSpeed * fallT + 6 * fallT * fallT
        let melt = min(1, max(0, (ground + 25 - y) / 50))
        guard melt > 0 else { return }
        let angle = flake.rotation + age * flake.spin

        // Only the part of the arm that has grown so far
        let reach = grown * flake.radius
        var paths = [Path(), Path(), Path()]                 // main arm, branches, twigs
        for s in flake.arm {
            guard s.d0 < reach else { continue }
            let k = s.d1 <= reach ? 1 : (reach - s.d0) / max(0.001, s.d1 - s.d0)
            let end = CGPoint(x: Double(s.a.x) + (Double(s.b.x) - Double(s.a.x)) * k,
                              y: Double(s.a.y) + (Double(s.b.y) - Double(s.a.y)) * k)
            paths[s.level].move(to: s.a)
            paths[s.level].addLine(to: end)
        }

        // Six identical arms, 60° apart
        var full = [Path(), Path(), Path()]
        for arm in 0..<6 {
            let transform = CGAffineTransform(rotationAngle: angle + Double(arm) * .pi / 3)
                .concatenating(CGAffineTransform(translationX: x, y: y))
            for level in 0..<3 { full[level].addPath(paths[level].applying(transform)) }
        }

        let widths = [2.6, 1.8, 1.2]
        let flash = age < Snowflake.growTime + 0.4 ? 1 - max(0, age - Snowflake.growTime) / 0.4 : 0
        context.drawLayer { glow in
            glow.addFilter(.blur(radius: 5))
            glow.blendMode = .plusLighter
            for level in 0..<3 {
                glow.stroke(full[level], with: .color(Color(red: 0.6, green: 0.8, blue: 1).opacity((0.5 + 0.4 * flash) * melt)),
                            style: StrokeStyle(lineWidth: widths[level] * 3, lineCap: .round))
            }
        }
        for level in 0..<3 {
            context.stroke(full[level], with: .color(.white.opacity(0.95 * melt)),
                           style: StrokeStyle(lineWidth: widths[level], lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Scenery (fixed, generated once)

    private struct Star { let x, y, size, speed, phase: Double }
    private struct Tree { let x, height: Double }
    private struct Flake { let x, y, size, speed, phase: Double }

    private static let stars: [Star] = {
        var rng = SnowRNG(seed: 9)
        return (0..<45).map { _ in
            Star(x: .random(in: 0..<1, using: &rng), y: .random(in: 0..<0.6, using: &rng),
                 size: .random(in: 0.6...1.6, using: &rng), speed: .random(in: 1...3, using: &rng),
                 phase: .random(in: 0...6, using: &rng))
        }
    }()

    private static let trees: [Tree] = {
        var rng = SnowRNG(seed: 2)
        return (0..<9).map { _ in Tree(x: .random(in: 0..<1, using: &rng), height: .random(in: 0.05...0.09, using: &rng)) }
    }()

    private static let snowfall: [Flake] = {
        var rng = SnowRNG(seed: 4)
        return (0..<140).map { _ in
            Flake(x: .random(in: 0..<1, using: &rng), y: .random(in: 0..<1, using: &rng),
                  size: .random(in: 0.8...2.3, using: &rng), speed: .random(in: 18...55, using: &rng),
                  phase: .random(in: 0...6, using: &rng))
        }
    }()
}

// MARK: - One snowflake

private struct Snowflake {
    struct Segment {
        let a, b: CGPoint            // in arm space: the arm points along +x
        let level: Int               // 0 main arm, 1 branch, 2 twig
        let d0, d1: Double           // distance from the centre where it starts and ends (for growing)
    }

    static let growTime = 1.2
    static let holdTime = 0.6

    let arm: [Segment]
    let center: CGPoint
    let start: Date
    let radius, rotation, spin, sway, phase, fallSpeed: Double

    static func make(at point: CGPoint, start: Date) -> Snowflake {
        let L = Double.random(in: 55...100)
        let angle = Double.random(in: 50...65) * .pi / 180          // branch angle, the same across the flake
        var arm: [Segment] = []

        func add(_ a: CGPoint, _ b: CGPoint, _ level: Int) {
            let d0 = (Double(a.x * a.x + a.y * a.y)).squareRoot()
            let d1 = (Double(b.x * b.x + b.y * b.y)).squareRoot()
            arm.append(Segment(a: a, b: b, level: level, d0: min(d0, d1), d1: max(d0, d1)))
        }

        // Main arm
        add(.zero, CGPoint(x: L, y: 0), 0)

        // Side branches, mirrored, getting shorter towards the tip
        let count = Int.random(in: 2...5)
        let spots = (0..<count).map { _ in Double.random(in: 0.22...0.85) }.sorted()
        for s in spots {
            let x = L * s
            let length = L * Double.random(in: 0.18...0.42) * (1 - s * 0.55)
            let twig = Double.random(in: 0...1) < 0.5
            for side in [-1.0, 1.0] {
                let end = CGPoint(x: x + cos(angle) * length, y: side * sin(angle) * length)
                add(CGPoint(x: x, y: 0), end, 1)
                if twig {
                    // A little twig off the branch, parallel to the main arm
                    let mx = x + cos(angle) * length * 0.5, my = side * sin(angle) * length * 0.5
                    add(CGPoint(x: mx, y: my), CGPoint(x: mx + length * 0.35, y: my), 2)
                }
            }
        }

        // Tip: a small hexagon plate, a fork, or nothing
        switch Int.random(in: 0...2) {
        case 0:
            let r = L * 0.09
            for k in 0..<6 {
                let a0 = Double(k) * .pi / 3, a1 = Double(k + 1) * .pi / 3
                add(CGPoint(x: L + cos(a0) * r, y: sin(a0) * r), CGPoint(x: L + cos(a1) * r, y: sin(a1) * r), 2)
            }
        case 1:
            for side in [-1.0, 1.0] {
                add(CGPoint(x: L, y: 0), CGPoint(x: L + cos(angle) * L * 0.12, y: side * sin(angle) * L * 0.12), 2)
            }
        default:
            break
        }

        // One edge of the centre hexagon (six arms make the whole hexagon)
        let rc = L * Double.random(in: 0.1...0.16)
        add(CGPoint(x: rc * cos(-Double.pi / 6), y: rc * sin(-Double.pi / 6)),
            CGPoint(x: rc * cos(Double.pi / 6), y: rc * sin(Double.pi / 6)), 1)

        return Snowflake(arm: arm, center: point, start: start, radius: L * 1.12,
                         rotation: .random(in: 0..<(Double.pi / 3)),
                         spin: Double.random(in: 0.08...0.3) * (Bool.random() ? 1 : -1),
                         sway: .random(in: 15...35), phase: .random(in: 0...6),
                         fallSpeed: .random(in: 35...60))
    }
}

// MARK: - Deterministic random generator (same scenery every launch)

private struct SnowRNG: RandomNumberGenerator {
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
    SnowflakeView()
}
