//
//  SkyBeamView.swift
//  Snowy forest at night, seen from above. Touch and a beam of light hits from the sky,
//  drag and it follows your finger. SwiftUI Canvas, iOS 17+
//
//  Copyright (c) 2026 Arturs (https://github.com/artdome)
//  SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//  Free for non-commercial use. Commercial use is not allowed. See LICENSE.md.
//
//  • A dark, almost monochrome snowy forest with a small cabin, drawn top-down.
//  • Touch: a bright beam strikes from the sky with a flash and a ring of light.
//  • Drag: the beam glides after your finger with a bit of weight. The trees around it
//    light up and their shadows swing away from the light in real time.
//  • Snow drifting through the beam sparkles. Let go and the beam fades out.
//  • No 3D engine and no images: every tree, shadow and ray is a Canvas path.
//
//  How to run:
//  • Make it the root view in your App file:
//        WindowGroup { SkyBeamView() }
//    then Cmd+R, touch and drag.
//  • Xcode preview: switch the preview to LIVE mode (▶︎), not "Selectable".
//

import SwiftUI

struct SkyBeamView: View {
    @State private var beam = BeamModel()
    @State private var finger: CGPoint?
    @State private var strikes = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                beam.update(finger: finger, now: timeline.date)
                draw(context, size: size, now: timeline.date)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if finger == nil {
                        beam.strike(at: value.location, now: Date())
                        strikes += 1
                    }
                    finger = value.location
                }
                .onEnded { _ in finger = nil }
        )
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: strikes)
    }

    // MARK: - Drawing

    private func draw(_ context: GraphicsContext, size: CGSize, now: Date) {
        let w = Double(size.width), h = Double(size.height)
        let t = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000)
        let spot = beam.position
        let power = beam.intensity
        let sigma = min(w, h) * 0.26                             // size of the lit area
        let ambient = 0.3                                        // faint moonlight

        func light(at x: Double, _ y: Double) -> Double {
            let dx = x - Double(spot.x), dy = y - Double(spot.y)
            return power * exp(-(dx * dx + dy * dy) / (2 * sigma * sigma))
        }
        func gray(_ base: Double, _ lit: Double) -> Color {
            let v = min(1, base * (ambient + 1.1 * lit))
            return Color(red: v * 0.94, green: v * 0.97, blue: v * 1.04)          // a touch of cold blue
        }

        // 1. Snowy ground
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(gray(0.42, 0)))
        if power > 0.01 {
            var pool = context
            pool.blendMode = .plusLighter
            pool.fill(Path(ellipseIn: CGRect(x: spot.x - sigma * 2.4, y: spot.y - sigma * 2.4, width: sigma * 4.8, height: sigma * 4.8)),
                      with: .radialGradient(Gradient(colors: [Color(white: 0.55 * power), Color(white: 0.18 * power), .clear]),
                                            center: spot, startRadius: 0, endRadius: sigma * 2.4))
        }

        // 2. Shadows, pointing away from the beam (all in one blurred layer)
        context.drawLayer { shadows in
            shadows.addFilter(.blur(radius: 4))
            for tree in Self.trees {
                let x = tree.x * w, y = tree.y * h, r = tree.r
                let lit = light(at: x, y)
                guard lit > 0.02 else { continue }
                var dx = x - Double(spot.x), dy = y - Double(spot.y)
                let d = max(1, (dx * dx + dy * dy).squareRoot())
                dx /= d; dy /= d
                let length = r * (1.2 + min(2.5, d / 90))
                var shadow = Path()
                shadow.move(to: CGPoint(x: x - dy * r * 0.8, y: y + dx * r * 0.8))
                shadow.addLine(to: CGPoint(x: x + dx * length - dy * r * 1.1, y: y + dy * length + dx * r * 1.1))
                shadow.addLine(to: CGPoint(x: x + dx * length + dy * r * 1.1, y: y + dy * length - dx * r * 1.1))
                shadow.addLine(to: CGPoint(x: x + dy * r * 0.8, y: y - dx * r * 0.8))
                shadow.closeSubpath()
                shadows.fill(shadow, with: .color(.black.opacity(0.55 * min(1, lit * 1.5))))
            }
        }

        // 3. Cabin
        drawCabin(context, w: w, h: h, light: light, gray: gray)

        // 4. Trees seen from above: four jagged layers, brighter on the side facing the light
        for tree in Self.trees {
            let x = tree.x * w, y = tree.y * h
            let lit = light(at: x, y)
            var dx = Double(spot.x) - x, dy = Double(spot.y) - y
            let d = max(1, (dx * dx + dy * dy).squareRoot())
            dx /= d; dy /= d
            for layer in 0..<4 {
                let r = tree.r * (1 - Double(layer) * 0.22)
                let points = 11 + layer * 2
                var star = Path()
                for i in 0..<(points * 2) {
                    let a = tree.angle + Double(layer) * 0.3 + Double(i) * .pi / Double(points)
                    let noise = sin(Double(i) * 12.9898 + tree.angle * 78.233 + Double(layer)) * 43758.5453
                    let jitter = 0.86 + 0.24 * (noise - noise.rounded(.down))      // uneven branch tips
                    let rr = (i % 2 == 0 ? r : r * 0.62) * jitter
                    let p = CGPoint(x: x + cos(a) * rr, y: y + sin(a) * rr)
                    if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
                }
                star.closeSubpath()
                let base = 0.5 + Double(layer) * 0.1
                context.fill(star, with: .linearGradient(
                    Gradient(colors: [gray(base + 0.15, lit), gray(base - 0.1, lit * 0.6)]),
                    startPoint: CGPoint(x: x + dx * r, y: y + dy * r), endPoint: CGPoint(x: x - dx * r, y: y - dy * r)))
            }
        }

        // 5. Snow drifting through the air, sparkling inside the beam
        var flakes = Path(), sparkles = Path()
        for f in Self.snow {
            let x = (f.x * w + t * f.vx).truncatingRemainder(dividingBy: w + 20) - 10
            let y = (f.y * h + t * f.vy).truncatingRemainder(dividingBy: h + 20) - 10
            let rect = CGRect(x: x - f.size, y: y - f.size, width: 2 * f.size, height: 2 * f.size)
            if light(at: x, y) > 0.35 { sparkles.addEllipse(in: rect.insetBy(dx: -0.6, dy: -0.6)) } else { flakes.addEllipse(in: rect) }
        }
        context.fill(flakes, with: .color(.white.opacity(0.35)))
        context.fill(sparkles, with: .color(.white.opacity(0.95)))

        // 6. The beam: a soft cone and a hot core, leaning towards the sky
        if power > 0.01 {
            let sky = CGPoint(x: Double(spot.x) * 0.55 + w * 0.22, y: -h * 0.35)
            var cone = Path()
            cone.move(to: CGPoint(x: spot.x - 6, y: spot.y))
            cone.addLine(to: CGPoint(x: sky.x - 70, y: sky.y))
            cone.addLine(to: CGPoint(x: sky.x + 70, y: sky.y))
            cone.addLine(to: CGPoint(x: spot.x + 6, y: spot.y))
            cone.closeSubpath()
            var core = Path()
            core.move(to: spot)
            core.addLine(to: sky)

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 18))
                glow.blendMode = .plusLighter
                glow.fill(cone, with: .linearGradient(Gradient(colors: [Color(white: 0.6 * power), Color(white: 0.15 * power)]),
                                                      startPoint: spot, endPoint: sky))
                glow.stroke(core, with: .color(.white.opacity(0.8 * power)), lineWidth: 14)
            }
            var hot = context
            hot.blendMode = .plusLighter
            hot.stroke(core, with: .color(.white.opacity(power)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            hot.fill(Path(ellipseIn: CGRect(x: spot.x - 40, y: spot.y - 40, width: 80, height: 80)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(power), .white.opacity(0.3 * power), .clear]),
                                           center: spot, startRadius: 0, endRadius: 40))
        }

        // 7. Strike: a ring of light and a quick flash
        let since = now.timeIntervalSince(beam.strikeTime)
        if since >= 0 && since < 0.6 {
            let p = since / 0.6
            let r = 20 + 200 * (1 - (1 - p) * (1 - p))
            let c = beam.strikePoint
            context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                           with: .color(.white.opacity(0.7 * (1 - p))), lineWidth: 3)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.15 * max(0, 1 - since / 0.15))))
        }
    }

    private func drawCabin(_ context: GraphicsContext, w: Double, h: Double,
                           light: (Double, Double) -> Double, gray: (Double, Double) -> Color) {
        let cx = w * 0.6, cy = h * 0.64
        let lit = light(cx, cy)
        var c = context
        c.translateBy(x: cx, y: cy)
        c.rotate(by: .degrees(28))
        let cw = 78.0, ch = 54.0
        c.fill(Path(CGRect(x: -cw / 2 + 6, y: -ch / 2 + 6, width: cw, height: ch)), with: .color(.black.opacity(0.4)))   // shadow
        c.fill(Path(CGRect(x: -cw / 2, y: -ch / 2, width: cw, height: ch / 2)), with: .color(gray(0.8, lit)))       // roof, light side
        c.fill(Path(CGRect(x: -cw / 2, y: 0, width: cw, height: ch / 2)), with: .color(gray(0.55, lit)))            // roof, dark side
        c.fill(Path(CGRect(x: -cw / 2, y: -1, width: cw, height: 2)), with: .color(gray(0.95, lit)))                // ridge
        c.fill(Path(CGRect(x: cw * 0.22, y: -ch * 0.38, width: 10, height: 10)), with: .color(gray(0.35, lit)))     // chimney
        var steps = Path()
        for i in 0..<5 { steps.addRect(CGRect(x: -cw / 2 - 16 + Double(i) * 3, y: ch * 0.1 + Double(i) * 3, width: 14, height: 1.5)) }
        c.fill(steps, with: .color(gray(0.4, lit)))
    }

    // MARK: - Scenery (fixed, generated once)

    private struct Tree { let x, y, r, angle: Double }
    private struct Snow { let x, y, vx, vy, size: Double }

    private static let trees: [Tree] = {
        var rng = BeamRNG(seed: 17)
        var out: [Tree] = []
        while out.count < 32 {
            let x = Double.random(in: -0.05...1.05, using: &rng), y = Double.random(in: -0.03...1.03, using: &rng)
            if abs(x - 0.6) < 0.25 && abs(y - 0.64) < 0.1 { continue }            // keep the cabin clear
            if out.contains(where: { abs($0.x - x) < 0.12 && abs($0.y - y) < 0.06 }) { continue }
            out.append(Tree(x: x, y: y, r: .random(in: 28...60, using: &rng), angle: .random(in: 0...6, using: &rng)))
        }
        return out
    }()

    private static let snow: [Snow] = {
        var rng = BeamRNG(seed: 8)
        return (0..<160).map { _ in
            Snow(x: .random(in: 0..<1, using: &rng), y: .random(in: 0..<1, using: &rng),
                 vx: .random(in: 8...25, using: &rng), vy: .random(in: 20...45, using: &rng), size: .random(in: 0.8...2, using: &rng))
        }
    }()
}

// MARK: - Beam position and brightness, smoothed every frame

final class BeamModel {
    private(set) var position = CGPoint(x: 200, y: 400)
    private(set) var intensity = 0.0
    private(set) var strikeTime = Date.distantPast
    private(set) var strikePoint = CGPoint.zero
    private var last: Date?

    func strike(at point: CGPoint, now: Date) {
        position = point
        strikePoint = point
        strikeTime = now
    }

    func update(finger: CGPoint?, now: Date) {
        let dt = last.map { min(0.1, max(0, now.timeIntervalSince($0))) } ?? 0
        last = now
        if let finger {
            let k = 1 - exp(-dt / 0.09)                         // glides after the finger
            position.x += (finger.x - position.x) * k
            position.y += (finger.y - position.y) * k
            intensity += (1 - intensity) * (1 - exp(-dt / 0.05))
        } else {
            intensity += (0 - intensity) * (1 - exp(-dt / 0.25))
        }
    }
}

// MARK: - Deterministic random generator (same forest every launch)

private struct BeamRNG: RandomNumberGenerator {
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
    SkyBeamView()
}
