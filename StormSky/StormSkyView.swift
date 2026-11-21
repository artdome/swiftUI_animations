//
//  StormSkyView.swift
//  Grey thunderstorm sky. Tap anywhere and lightning strikes. SwiftUI Canvas, iOS 17+
//
//  Copyright (c) 2026 Arturs (https://github.com/artdome)
//  SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//  Free for non-commercial use. Commercial use is not allowed. See LICENSE.md.
//
//  • Layered clouds drift at different speeds, rain falls, dark hills at the bottom.
//  • Every tap fires 1 to 3 bolts of random size with small random delays.
//    The first one strikes near your finger, the others somewhere random.
//  • Each bolt is generated fresh (fractal zig-zag with branches), so no two are the same.
//  • The flash lights up the clouds around the bolt and the whole sky. Heavy haptic on tap.
//
//  How to run:
//  • Make it the root view in your App file:
//        WindowGroup { StormSkyView() }
//    then Cmd+R and tap the sky.
//  • Xcode preview: switch the preview to LIVE mode (▶︎), not "Selectable".
//

import SwiftUI

struct StormSkyView: View {
    /// Show a ring where the finger touched (handy for screen recordings).
    var showTouches = true

    @State private var bolts: [StormBolt] = []
    @State private var strikes = 0
    @State private var touch: (point: CGPoint, start: Date)?

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    draw(context, size: size, now: timeline.date)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                strike(at: location, size: geo.size)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: strikes)
    }

    // MARK: - Tap

    private func strike(at point: CGPoint, size: CGSize) {
        let now = Date()
        touch = (point, now)
        bolts.removeAll { now.timeIntervalSince($0.start) > 1.5 }

        let count = Int.random(in: 1...3)
        var delay = 0.0
        for i in 0..<count {
            bolts.append(StormBolt.make(in: size, near: i == 0 ? point : nil, start: now.addingTimeInterval(delay)))
            delay += Double.random(in: 0.06...0.35)
        }
        strikes += 1
    }

    // MARK: - Drawing

    private func draw(_ context: GraphicsContext, size: CGSize, now: Date) {
        let w = Double(size.width), h = Double(size.height)
        let t = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000)

        // How bright each bolt is right now
        let lit = bolts.map { (bolt: $0, light: $0.brightness(at: now)) }.filter { $0.light > 0.001 }
        let flash = min(1, lit.reduce(0) { $0 + $1.light * $1.bolt.power })

        // 1. Sky
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(white: 0.13 + 0.25 * flash),
                    Color(red: 0.27 + 0.3 * flash, green: 0.28 + 0.3 * flash, blue: 0.32 + 0.32 * flash),
                    Color(white: 0.18 + 0.2 * flash),
                ]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

        // 2. Clouds, lit from inside near each bolt
        context.drawLayer { clouds in
            clouds.addFilter(.blur(radius: 22))
            for blob in Self.clouds {
                let speed = [4.0, 9.0, 16.0][blob.layer]                         // far clouds move slower
                let span = w * 1.8
                let x = (blob.x * span + t * speed).truncatingRemainder(dividingBy: span) - w * 0.4
                let y = blob.y * h
                let bw = blob.w * w, bh = blob.h * h

                var glow = 0.0
                for l in lit {
                    let dx = (x - Double(l.bolt.top.x)) / (w * 0.45)
                    let dy = (y - Double(l.bolt.top.y)) / (h * 0.25)
                    glow += l.light * l.bolt.power * exp(-(dx * dx + dy * dy))
                }
                let g = min(1, glow)
                let shade = blob.shade + 0.45 * g
                clouds.fill(
                    Path(ellipseIn: CGRect(x: x - bw / 2, y: y - bh / 2, width: bw, height: bh)),
                    with: .color(Color(red: shade, green: shade * 1.01, blue: min(1, shade * 1.08))))
            }
        }

        // 3. Lightning: blue glow, then a white-hot core
        if !lit.isEmpty {
            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 9))
                glow.blendMode = .plusLighter
                for l in lit {
                    for s in l.bolt.segments {
                        glow.stroke(s.path, with: .color(Color(red: 0.55, green: 0.65, blue: 1).opacity(0.8 * l.light)),
                                    style: StrokeStyle(lineWidth: s.width * 5, lineCap: .round))
                    }
                }
            }
            var core = context
            core.blendMode = .plusLighter
            for l in lit {
                for s in l.bolt.segments {
                    core.stroke(s.path, with: .color(Color(red: 0.9, green: 0.94, blue: 1).opacity(l.light)),
                                style: StrokeStyle(lineWidth: s.width, lineCap: .round, lineJoin: .round))
                }
            }
        }

        // 4. Rain
        var rain = Path()
        for d in Self.rain {
            let y = (d.y * h + t * d.speed).truncatingRemainder(dividingBy: h + 60) - 30
            let x = (d.x * (w + 80) - y * 0.12).truncatingRemainder(dividingBy: w + 80) - 40
            rain.move(to: CGPoint(x: x, y: y))
            rain.addLine(to: CGPoint(x: x - d.length * 0.12, y: y + d.length))
        }
        context.stroke(rain, with: .color(.white.opacity(0.09 + 0.3 * flash)), lineWidth: 0.7)

        // 5. Hills
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: h))
        for i in 0...80 {
            let x = w * Double(i) / 80
            let y = h * (0.86 + 0.022 * sin(Double(i) * 0.12) + 0.010 * sin(Double(i) * 0.37 + 1))
            hills.addLine(to: CGPoint(x: x, y: y))
        }
        hills.addLine(to: CGPoint(x: w, y: h))
        hills.closeSubpath()
        context.fill(hills, with: .color(Color(white: 0.05 + 0.12 * flash)))

        // 6. Whole-screen flash
        if flash > 0.01 {
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(red: 0.85, green: 0.9, blue: 1).opacity(0.22 * flash)))
        }

        // 7. Touch ring
        if showTouches, let touch {
            let age = now.timeIntervalSince(touch.start)
            if age >= 0 && age < 0.55 {
                let p = age / 0.55, a = 1 - p
                let r = 26 + 46 * (1 - pow(1 - p, 3))
                let c = touch.point
                context.fill(Path(ellipseIn: CGRect(x: c.x - 24, y: c.y - 24, width: 48, height: 48)),
                             with: .color(.white.opacity(0.25 * a)))
                context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                               with: .color(.white.opacity(0.8 * a)), lineWidth: 3)
            }
        }
    }

    // MARK: - Scenery (fixed, generated once)

    private struct CloudBlob { let x, y, w, h, shade: Double; let layer: Int }
    private struct RainDrop { let x, y, speed, length: Double }

    private static let clouds: [CloudBlob] = {
        var rng = StormRNG(seed: 11)
        return (0..<54).map { i in
            let layer = i % 3
            return CloudBlob(
                x: .random(in: 0..<1, using: &rng),
                y: .random(in: -0.02...0.36, using: &rng) + Double(layer) * 0.03,
                w: .random(in: 0.35...0.85, using: &rng),
                h: .random(in: 0.07...0.15, using: &rng),
                shade: .random(in: 0.25...0.40, using: &rng) + Double(layer) * 0.03,
                layer: layer)
        }
    }()

    private static let rain: [RainDrop] = {
        var rng = StormRNG(seed: 5)
        return (0..<180).map { _ in
            RainDrop(x: .random(in: 0..<1, using: &rng), y: .random(in: 0..<1, using: &rng),
                     speed: .random(in: 800...1200, using: &rng), length: .random(in: 14...28, using: &rng))
        }
    }()
}

// MARK: - Lightning bolt

private struct StormBolt {
    struct Segment {
        let path: Path
        let width: Double
    }

    let segments: [Segment]
    let start: Date
    let top: CGPoint
    let power: Double          // 0.35 = small distant bolt … 1 = huge one
    let seed: Double

    /// 0 = dark, 1 = full flash. Quick rise, a few flickers, then fades out.
    func brightness(at now: Date) -> Double {
        let age = now.timeIntervalSince(start)
        guard age >= 0, age < 0.9 else { return 0 }
        let rise = min(1, age / 0.03)
        let decay = exp(-age * 4.5)
        let flicker = age < 0.35 ? 0.6 + 0.4 * cos(age * 55 + seed) : 1
        return rise * decay * flicker
    }

    static func make(in size: CGSize, near point: CGPoint?, start: Date) -> StormBolt {
        let w = Double(size.width), h = Double(size.height)
        let power = Double.random(in: 0.35...1)
        let length = h * (0.25 + 0.5 * power)

        let x0 = point.map { Double($0.x) + .random(in: -80...80) } ?? .random(in: (w * 0.1)...(w * 0.9))
        let top = CGPoint(x: min(max(x0, 20), w - 20), y: h * .random(in: 0.12...0.24))
        let end = CGPoint(x: Double(top.x) + .random(in: -0.3...0.3) * length,
                          y: min(h * 0.9, Double(top.y) + length))

        var raw: [(CGPoint, CGPoint, Double)] = []
        subdivide(top, end, displace: length * 0.18, depth: 7, width: 1.4 + 2.4 * power,
                  branchChance: 0.35, into: &raw)

        let segments = raw.map { item -> Segment in
            var p = Path()
            p.move(to: item.0)
            p.addLine(to: item.1)
            return Segment(path: p, width: item.2)
        }
        return StormBolt(segments: segments, start: start, top: top, power: power,
                         seed: .random(in: 0...0.8))
    }

    /// Midpoint displacement: split the line, push the middle sideways, repeat. Sometimes fork.
    private static func subdivide(_ a: CGPoint, _ b: CGPoint, displace: Double, depth: Int, width: Double,
                                  branchChance: Double, into out: inout [(CGPoint, CGPoint, Double)]) {
        if depth == 0 {
            out.append((a, b, width))
            return
        }
        let ax = Double(a.x), ay = Double(a.y), bx = Double(b.x), by = Double(b.y)
        let dx = bx - ax, dy = by - ay
        let len = max(1, (dx * dx + dy * dy).squareRoot())
        let off = Double.random(in: -displace...displace)
        let mid = CGPoint(x: (ax + bx) / 2 - dy / len * off, y: (ay + by) / 2 + dx / len * off)

        subdivide(a, mid, displace: displace / 2, depth: depth - 1, width: width,
                  branchChance: branchChance, into: &out)
        subdivide(mid, b, displace: displace / 2, depth: depth - 1, width: width,
                  branchChance: branchChance, into: &out)

        if depth >= 3, depth <= 6, Double.random(in: 0...1) < branchChance {
            let angle = atan2(Double(mid.y) - ay, Double(mid.x) - ax)
                + Double.random(in: 0.35...0.8) * (Bool.random() ? 1 : -1)
            let branchLength = len * Double.random(in: 0.5...0.9)
            let branchEnd = CGPoint(x: Double(mid.x) + cos(angle) * branchLength,
                                    y: Double(mid.y) + sin(angle) * branchLength)
            subdivide(mid, branchEnd, displace: displace / 2, depth: depth - 1, width: width * 0.5,
                      branchChance: branchChance * 0.6, into: &out)
        }
    }
}

// MARK: - Deterministic random generator (same clouds every launch)

private struct StormRNG: RandomNumberGenerator {
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
    StormSkyView()
}
