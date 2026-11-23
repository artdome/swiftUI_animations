//
//  SlotMachineView.swift
//  Retro slot machine. Tap to pull the lever, the reels stop one by one. SwiftUI Canvas, iOS 17+
//
//  Copyright (c) 2026 Arturs (https://github.com/artdome)
//  SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//  Free for non-commercial use. Commercial use is not allowed. See LICENSE.md.
//
//  • Red cabinet, "RANDOMAKER" sign with chasing bulbs, three reels and a lever.
//  • Tap anywhere: the lever goes down, the reels spin with motion blur and stop
//    one after another with a small bounce.
//  • Jackpot: all bulbs flash and coins fly out of the tray.
//    Near miss: the matching symbol stops right above the line, and the last reel
//    takes longer to stop, just to tease you.
//  • All symbols are drawn with code: seven, die, star, cherries, diamond, heart, coin.
//  • jackpotChance is set high on purpose so the demo is fun. Lower it for realism.
//
//  How to run:
//  • Make it the root view in your App file:
//        WindowGroup { SlotMachineView() }
//    then Cmd+R and tap.
//  • Xcode preview: switch the preview to LIVE mode (▶︎), not "Selectable".
//

import SwiftUI

struct SlotMachineView: View {
    /// Show a ring where the finger touched (handy for screen recordings).
    var showTouches = true
    var jackpotChance = 0.25
    var nearMissChance = 0.35

    /// The symbols on every reel, top to bottom. Seven and diamond appear once, so they are rarer.
    private static let strip = [0, 1, 2, 3, 4, 5, 6, 1, 2, 3, 5, 6]

    private enum Outcome { case jackpot, close, lose }

    private struct Spin {
        let start: Date
        let from: [Double]
        let targets: [Int]
        let laps: [Int]
        let stops: [Double]          // seconds after start when each reel stops
        let outcome: Outcome
        let coinSeed: UInt64
        var end: Double { stops.max() ?? 0 }
    }

    @State private var spin: Spin?
    @State private var pulls = 0
    @State private var wins = 0
    @State private var touch: (point: CGPoint, start: Date)?

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
            pull(at: location)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: pulls)
        .sensoryFeedback(.success, trigger: wins)
    }

    // MARK: - Tap

    private func pull(at point: CGPoint) {
        let now = Date()
        touch = (point, now)
        if let spin, now.timeIntervalSince(spin.start) < spin.end + 0.3 { return }      // still spinning

        let from = spin.map { $0.targets.map(Double.init) } ?? [0, 4, 8]
        let roll = Double.random(in: 0..<1)
        var targets: [Int]
        var stops = [1.0, 1.45, 1.9]
        var outcome: Outcome

        func index(of symbol: Int) -> Int {
            Self.strip.indices.filter { Self.strip[$0] == symbol }.randomElement() ?? 0
        }

        if roll < jackpotChance {
            let s = Int.random(in: 0..<7)
            targets = [index(of: s), index(of: s), index(of: s)]
            stops[2] = 2.4                                          // a bit of suspense
            outcome = .jackpot
        } else if roll < jackpotChance + nearMissChance {
            let s = Int.random(in: 0..<7)
            // third reel stops one step early: the match sits just above the line
            let early = (index(of: s) - 1 + Self.strip.count) % Self.strip.count
            targets = [index(of: s), index(of: s), early]
            stops[2] = 2.6
            outcome = .close
        } else {
            repeat {
                targets = (0..<3).map { _ in Int.random(in: 0..<Self.strip.count) }
            } while Self.strip[targets[0]] == Self.strip[targets[1]] && Self.strip[targets[1]] == Self.strip[targets[2]]
            outcome = Self.strip[targets[0]] == Self.strip[targets[1]] ? .close : .lose
        }

        spin = Spin(start: now, from: from, targets: targets, laps: [2, 3, outcome == .lose ? 4 : 5],
                    stops: stops, outcome: outcome, coinSeed: UInt64.random(in: 0...UInt64.max))
        pulls += 1
        if outcome == .jackpot {
            let delay = stops[2]
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                wins += 1
            }
        }
    }

    // MARK: - Reel motion

    /// Reel position in symbols. Fast start, slows down, small overshoot, settles on the target.
    private func reelPosition(_ r: Int, at a: Double) -> Double {
        guard let spin else { return [0.0, 4, 8][r] }
        let n = Double(Self.strip.count)
        let from = spin.from[r], target = Double(spin.targets[r])
        let T = spin.stops[r]
        if a <= 0 { return from }
        if a >= T { return target }
        let distance = Double(spin.laps[r]) * n + ((target - from).truncatingRemainder(dividingBy: n) + n)
            .truncatingRemainder(dividingBy: n)
        let x = a / T, s = 0.7, q = x - 1
        return from + distance * (1 + (s + 1) * q * q * q + s * q * q)
    }

    // MARK: - Drawing

    private func draw(_ context: GraphicsContext, size: CGSize, now: Date) {
        let w = Double(size.width), h = Double(size.height)
        let t = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000)
        let age = spin.map { now.timeIntervalSince($0.start) } ?? -1
        let finished = spin != nil && age >= (spin?.end ?? 0)
        let jackpotOn = finished && spin?.outcome == .jackpot && age < (spin?.end ?? 0) + 3.5
        let spinning = spin != nil && !finished

        // Background with a soft spotlight
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(Gradient(colors: [Color(red: 0.22, green: 0.08, blue: 0.16), Color(red: 0.04, green: 0.02, blue: 0.05)]),
                                           center: CGPoint(x: w / 2, y: h * 0.45), startRadius: 0, endRadius: h * 0.7))

        // Cabinet
        let cab = CGRect(x: w * 0.07, y: h * 0.2, width: w * 0.76, height: h * 0.62)
        context.fill(Path(roundedRect: cab.insetBy(dx: -5, dy: -5), cornerRadius: 30),
                     with: .linearGradient(Gradient(colors: [Color(white: 0.92), Color(white: 0.55), Color(white: 0.85)]),
                                           startPoint: CGPoint(x: cab.minX, y: cab.minY), endPoint: CGPoint(x: cab.maxX, y: cab.maxY)))
        context.fill(Path(roundedRect: cab, cornerRadius: 26),
                     with: .linearGradient(Gradient(colors: [Color(red: 0.82, green: 0.12, blue: 0.14), Color(red: 0.45, green: 0.03, blue: 0.07)]),
                                           startPoint: CGPoint(x: cab.minX, y: cab.minY), endPoint: CGPoint(x: cab.minX, y: cab.maxY)))

        // Sign with chasing bulbs
        let sign = CGRect(x: cab.minX + 16, y: cab.minY + 18, width: cab.width - 32, height: h * 0.085)
        context.fill(Path(roundedRect: sign, cornerRadius: 12), with: .color(Color(red: 0.1, green: 0.03, blue: 0.05)))
        context.draw(Text("RANDOMAKER").font(.system(size: sign.height * 0.42, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 1, green: 0.8, blue: 0.25)),
                     at: CGPoint(x: sign.midX, y: sign.midY))
        let ring = sign.insetBy(dx: -8, dy: -8)
        let bulbs = 26
        let perimeter = 2 * Double(ring.width + ring.height)
        for i in 0..<bulbs {
            var d = perimeter * Double(i) / Double(bulbs)
            var p: CGPoint
            if d < Double(ring.width) { p = CGPoint(x: ring.minX + d, y: ring.minY) }
            else if (d - Double(ring.width)) < Double(ring.height) { d -= Double(ring.width); p = CGPoint(x: ring.maxX, y: ring.minY + d) }
            else if (d - Double(ring.width + ring.height)) < Double(ring.width) { d -= Double(ring.width + ring.height); p = CGPoint(x: ring.maxX - d, y: ring.maxY) }
            else { d -= Double(2 * ring.width + ring.height); p = CGPoint(x: ring.minX, y: ring.maxY - d) }
            let lit: Bool
            if jackpotOn { lit = Int(t * 8) % 2 == 0 }
            else { lit = (i + Int(t * (spinning ? 14 : 5))) % 3 == 0 }
            let c = lit ? Color(red: 1, green: 0.9, blue: 0.55) : Color(red: 0.45, green: 0.3, blue: 0.15)
            if lit {
                context.fill(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)),
                             with: .radialGradient(Gradient(colors: [c.opacity(0.7), .clear]), center: p, startRadius: 0, endRadius: 8))
            }
            context.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)), with: .color(c))
        }

        // Reel window
        let window = CGRect(x: cab.minX + 18, y: sign.maxY + h * 0.035, width: cab.width - 36, height: h * 0.24)
        context.fill(Path(roundedRect: window.insetBy(dx: -6, dy: -6), cornerRadius: 12), with: .color(Color(red: 0.12, green: 0.03, blue: 0.05)))
        let gap = 6.0
        let reelW = (Double(window.width) - 2 * gap) / 3
        let symH = Double(window.height) / 3
        for r in 0..<3 {
            let rect = CGRect(x: Double(window.minX) + Double(r) * (reelW + gap), y: window.minY, width: reelW, height: window.height)
            var reel = context
            reel.clip(to: Path(rect))
            reel.fill(Path(rect), with: .color(Color(red: 0.98, green: 0.96, blue: 0.9)))

            let a = max(0, age)
            let pos = reelPosition(r, at: a)
            let speed = abs(reelPosition(r, at: a + 0.016) - pos) / 0.016          // symbols per second
            let blur = speed > 3 ? min(7, speed * 0.18) : 0
            reel.drawLayer { layer in
                if blur > 0 { layer.addFilter(.blur(radius: blur)) }
                let base = Int(pos.rounded(.down))
                for j in (base - 2)...(base + 2) {
                    let n = Self.strip.count
                    let symbol = Self.strip[((j % n) + n) % n]
                    let y = Double(rect.midY) + (pos - Double(j)) * symH            // reels roll downwards
                    drawSymbol(layer, symbol, at: CGPoint(x: rect.midX, y: y), size: min(reelW, symH) * 0.82)
                }
            }
            // Cylinder shading
            reel.fill(Path(rect), with: .linearGradient(
                Gradient(stops: [.init(color: .black.opacity(0.55), location: 0), .init(color: .clear, location: 0.3),
                                 .init(color: .clear, location: 0.7), .init(color: .black.opacity(0.55), location: 1)]),
                startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)))
        }
        // Pay line
        context.fill(Path(CGRect(x: window.minX - 4, y: window.midY - 1, width: window.width + 8, height: 2)),
                     with: .color(Color(red: 1, green: 0.25, blue: 0.2).opacity(0.8)))

        // Message panel
        let panel = CGRect(x: window.minX, y: window.maxY + h * 0.03, width: window.width, height: h * 0.06)
        context.fill(Path(roundedRect: panel, cornerRadius: 10), with: .color(Color(red: 0.08, green: 0.02, blue: 0.03)))
        var message = "TAP TO SPIN"
        if spinning { message = "GOOD LUCK" }
        else if finished, let spin {
            switch spin.outcome {
            case .jackpot: message = age < spin.end + 3.5 && Int(t * 6) % 2 == 1 ? "" : "JACKPOT!"
            case .close:   message = "SO CLOSE"
            case .lose:    message = "TRY AGAIN"
            }
        }
        context.draw(Text(message).font(.system(size: panel.height * 0.5, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(red: 1, green: 0.6, blue: 0.15)),
                     at: CGPoint(x: panel.midX, y: panel.midY))

        // Coin tray
        let tray = CGRect(x: cab.minX + cab.width * 0.2, y: panel.maxY + h * 0.035, width: cab.width * 0.6, height: h * 0.05)
        context.fill(Path(roundedRect: tray, cornerRadius: 10), with: .color(Color(red: 0.12, green: 0.03, blue: 0.05)))
        context.fill(Path(roundedRect: tray.insetBy(dx: 6, dy: 6), cornerRadius: 6), with: .color(.black))

        // Lever
        let pivot = CGPoint(x: cab.maxX + w * 0.05, y: window.midY + h * 0.02)
        context.fill(Path(roundedRect: CGRect(x: cab.maxX - 4, y: pivot.y - 18, width: w * 0.06, height: 36), cornerRadius: 8),
                     with: .color(Color(white: 0.6)))
        var pullAmount = 0.0
        if age >= 0 {
            pullAmount = age < 0.18 ? age / 0.18 : max(0, 1 - (age - 0.25) / 0.35)
        }
        let theta = pullAmount * .pi * 0.85
        let length = h * 0.15
        let knob = CGPoint(x: pivot.x, y: pivot.y - length * cos(theta))
        var stick = Path()
        stick.move(to: pivot)
        stick.addLine(to: knob)
        context.stroke(stick, with: .color(Color(white: 0.8)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        let kr = w * 0.04 * (1 + 0.3 * sin(theta))
        context.fill(Path(ellipseIn: CGRect(x: knob.x - kr, y: knob.y - kr, width: 2 * kr, height: 2 * kr)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.5, blue: 0.5), Color(red: 0.75, green: 0.05, blue: 0.08)]),
                                           center: CGPoint(x: knob.x - kr * 0.3, y: knob.y - kr * 0.3), startRadius: 0, endRadius: kr))

        // Jackpot coins
        if let spin, spin.outcome == .jackpot {
            var rng = SlotRNG(seed: spin.coinSeed)
            let origin = CGPoint(x: tray.midX, y: tray.minY)
            for i in 0..<44 {
                let vx = Double.random(in: -230...230, using: &rng)
                let vy = Double.random(in: (-720)...(-380), using: &rng)
                let spinRate = Double.random(in: 6...14, using: &rng)
                let ca = age - spin.end - 0.05 - Double(i) * 0.03
                guard ca > 0, ca < 2.6 else { continue }
                let x = Double(origin.x) + vx * ca
                let y = Double(origin.y) + vy * ca + 0.5 * 1500 * ca * ca
                let r = w * 0.028
                let squash = max(0.15, abs(cos(ca * spinRate)))
                let coin = CGRect(x: x - r * squash, y: y - r, width: 2 * r * squash, height: 2 * r)
                context.fill(Path(ellipseIn: coin), with: .color(Color(red: 1, green: 0.78, blue: 0.2)))
                context.stroke(Path(ellipseIn: coin.insetBy(dx: r * 0.2 * squash, dy: r * 0.2)),
                               with: .color(Color(red: 0.8, green: 0.5, blue: 0.05)), lineWidth: 1.5)
            }
            if jackpotOn {
                let glow = 0.12 * (0.5 + 0.5 * sin(t * 25))
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 1, green: 0.85, blue: 0.4).opacity(glow)))
            }
        }

        // Touch ring
        if showTouches, let touch {
            let ta = now.timeIntervalSince(touch.start)
            if ta >= 0 && ta < 0.55 {
                let p = ta / 0.55, a = 1 - p
                let r = 26 + 46 * (1 - pow(1 - p, 3))
                let c = touch.point
                context.fill(Path(ellipseIn: CGRect(x: c.x - 24, y: c.y - 24, width: 48, height: 48)),
                             with: .color(.white.opacity(0.25 * a)))
                context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                               with: .color(.white.opacity(0.8 * a)), lineWidth: 3)
            }
        }
    }

    // MARK: - Symbols

    private func drawSymbol(_ ctx: GraphicsContext, _ kind: Int, at c: CGPoint, size s: Double) {
        let x = Double(c.x), y = Double(c.y)
        func pt(_ dx: Double, _ dy: Double) -> CGPoint { CGPoint(x: x + dx * s, y: y + dy * s) }
        func circle(_ dx: Double, _ dy: Double, _ r: Double) -> Path {
            Path(ellipseIn: CGRect(x: x + (dx - r) * s, y: y + (dy - r) * s, width: 2 * r * s, height: 2 * r * s))
        }
        func polygon(_ points: [(Double, Double)]) -> Path {
            var p = Path()
            p.addLines(points.map { pt($0.0, $0.1) })
            p.closeSubpath()
            return p
        }

        switch kind {
        case 0: // Seven
            let font = Font.system(size: s * 0.85, weight: .black, design: .rounded)
            ctx.draw(Text("7").font(font).foregroundColor(Color(red: 0.45, green: 0.02, blue: 0.05)), at: pt(0.03, 0.03))
            ctx.draw(Text("7").font(font).foregroundColor(Color(red: 0.92, green: 0.1, blue: 0.12)), at: c)
        case 1: // Die
            let box = Path(roundedRect: CGRect(x: x - s * 0.34, y: y - s * 0.34, width: s * 0.68, height: s * 0.68), cornerRadius: s * 0.12)
            ctx.fill(box, with: .color(.white))
            ctx.stroke(box, with: .color(Color(white: 0.55)), lineWidth: 2)
            for (dx, dy) in [(-0.17, -0.17), (0.17, -0.17), (0.0, 0.0), (-0.17, 0.17), (0.17, 0.17)] {
                ctx.fill(circle(dx, dy, 0.065), with: .color(Color(red: 0.15, green: 0.1, blue: 0.25)))
            }
        case 2: // Star
            var pts: [(Double, Double)] = []
            for k in 0..<10 {
                let a = -Double.pi / 2 + Double(k) * .pi / 5
                let r = k % 2 == 0 ? 0.4 : 0.17
                pts.append((cos(a) * r, sin(a) * r + 0.03))
            }
            let star = polygon(pts)
            ctx.fill(star, with: .color(Color(red: 1, green: 0.82, blue: 0.1)))
            ctx.stroke(star, with: .color(Color(red: 0.9, green: 0.5, blue: 0.05)), lineWidth: 2)
        case 3: // Cherries
            var stems = Path()
            stems.move(to: pt(0.05, -0.33))
            stems.addQuadCurve(to: pt(-0.16, 0.1), control: pt(-0.12, -0.2))
            stems.move(to: pt(0.05, -0.33))
            stems.addQuadCurve(to: pt(0.17, 0.14), control: pt(0.14, -0.15))
            ctx.stroke(stems, with: .color(Color(red: 0.2, green: 0.55, blue: 0.15)), lineWidth: 3)
            ctx.fill(Path(ellipseIn: CGRect(x: x + 0.05 * s, y: y - 0.38 * s, width: 0.2 * s, height: 0.1 * s)),
                     with: .color(Color(red: 0.25, green: 0.65, blue: 0.2)))
            for (dx, dy) in [(-0.16, 0.14), (0.17, 0.18)] {
                ctx.fill(circle(dx, dy, 0.15), with: .color(Color(red: 0.85, green: 0.05, blue: 0.12)))
                ctx.fill(circle(dx - 0.05, dy - 0.05, 0.04), with: .color(.white.opacity(0.7)))
            }
        case 4: // Diamond
            let gem = polygon([(-0.32, -0.1), (-0.16, -0.3), (0.16, -0.3), (0.32, -0.1), (0, 0.36)])
            ctx.fill(gem, with: .color(Color(red: 0.35, green: 0.8, blue: 1)))
            var facets = Path()
            facets.move(to: pt(-0.32, -0.1)); facets.addLine(to: pt(0.32, -0.1))
            facets.move(to: pt(-0.16, -0.3)); facets.addLine(to: pt(-0.08, -0.1)); facets.addLine(to: pt(0, 0.36))
            facets.move(to: pt(0.16, -0.3)); facets.addLine(to: pt(0.08, -0.1)); facets.addLine(to: pt(0, 0.36))
            ctx.stroke(facets, with: .color(.white.opacity(0.6)), lineWidth: 1.5)
            ctx.stroke(gem, with: .color(Color(red: 0.1, green: 0.45, blue: 0.7)), lineWidth: 2)
        case 5: // Heart
            let pink = Color(red: 0.95, green: 0.2, blue: 0.4)
            ctx.fill(circle(-0.13, -0.08, 0.17), with: .color(pink))
            ctx.fill(circle(0.13, -0.08, 0.17), with: .color(pink))
            ctx.fill(polygon([(-0.285, -0.02), (0.285, -0.02), (0, 0.33)]), with: .color(pink))
            ctx.fill(circle(-0.17, -0.13, 0.05), with: .color(.white.opacity(0.6)))
        default: // Coin with an R
            ctx.fill(circle(0, 0, 0.33), with: .color(Color(red: 1, green: 0.76, blue: 0.15)))
            ctx.stroke(circle(0, 0, 0.26), with: .color(Color(red: 0.8, green: 0.5, blue: 0.05)), lineWidth: 2)
            ctx.draw(Text("R").font(.system(size: s * 0.36, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.75, green: 0.45, blue: 0.05)), at: c)
        }
    }
}

// MARK: - Deterministic random generator (same coin burst for the same spin)

private struct SlotRNG: RandomNumberGenerator {
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
    SlotMachineView()
}
