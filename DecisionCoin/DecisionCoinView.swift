//
//  DecisionCoinView.swift
//  A 3D coin that settles arguments. Tap to flip. SwiftUI Canvas, iOS 17+
//
//  Copyright (c) 2026 Arturs (https://github.com/artdome)
//  SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//  Free for non-commercial use. Commercial use is not allowed. See LICENSE.md.
//
//  • Put your two options on the coin: DecisionCoinView(sideA: "PIZZA", sideB: "SUSHI").
//  • Tap: the coin jumps, spins in 3D, lands, does a tiny bounce and settles flat.
//    The side facing up is the answer, and it pops up above the coin.
//  • The coin is drawn as a real disc: two faces, a rim and a shadow that shrinks as it rises.
//  • Background in Randomaker style: black sky, waves, orange table with a faint dice pattern.
//
//  How to run:
//  • Make it the root view in your App file:
//        WindowGroup { DecisionCoinView(sideA: "ME", sideB: "YOU") }
//    then Cmd+R and tap.
//  • Xcode preview: switch the preview to LIVE mode (▶︎), not "Selectable".
//

import SwiftUI

struct DecisionCoinView: View {
    var sideA = "YES"
    var sideB = "NO"

    private static let gravity = 2600.0             // pt/s²
    private static let cameraPitch = -0.95          // looking down at the table

    private struct Flip {
        let start: Date
        let fromAngle: Double
        let toAngle: Double
        let sideAUp: Bool
        let v0: Double                              // launch speed, pt/s
        var air: Double { 2 * v0 / DecisionCoinView.gravity }
        var bounce: Double { 2 * v0 * 0.18 / DecisionCoinView.gravity }
        var total: Double { air + bounce + 0.25 }
    }

    @State private var flip: Flip?
    @State private var flips = 0
    @State private var landings = 0

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
        .onTapGesture { toss() }
        .sensoryFeedback(.impact(weight: .light), trigger: flips)
        .sensoryFeedback(.impact(weight: .medium), trigger: landings)
    }

    // MARK: - Tap

    private func toss() {
        let now = Date()
        if let flip, now.timeIntervalSince(flip.start) < flip.total { return }    // still in the air

        let from = flip?.toAngle ?? .pi / 2                                      // lying flat, side A up
        let sideAUp = Bool.random()
        let v0 = Double.random(in: 1450...1700)
        let air = 2 * v0 / Self.gravity

        // Angle π/2 + k·π lies flat. Even k = side A up, odd k = side B up.
        let halfTurns = Int((air * 14).rounded())
        var k = Int(((from + Double(halfTurns) * .pi - .pi / 2) / .pi).rounded())
        if (k % 2 == 0) != sideAUp { k += 1 }
        let to = .pi / 2 + Double(k) * .pi

        flip = Flip(start: now, fromAngle: from, toAngle: to, sideAUp: sideAUp, v0: v0)
        flips += 1
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(air))
            landings += 1
        }
    }

    /// Height above the table and spin angle at this moment.
    private func coinState(now: Date) -> (height: Double, angle: Double) {
        guard let flip else { return (0, .pi / 2) }
        let a = now.timeIntervalSince(flip.start)
        let g = Self.gravity
        let approach = flip.toAngle - 0.6
        if a < flip.air {
            return (flip.v0 * a - 0.5 * g * a * a,
                    flip.fromAngle + (approach - flip.fromAngle) * (a / flip.air))
        }
        let b = a - flip.air
        let settle = flip.bounce + 0.25
        let q = min(1, b / settle)
        let angle = approach + 0.6 * (1 - (1 - q) * (1 - q))
        let v1 = flip.v0 * 0.18
        let height = b < flip.bounce ? v1 * b - 0.5 * g * b * b : 0
        return (height, angle)
    }

    // MARK: - Drawing

    private func draw(_ context: GraphicsContext, size: CGSize, now: Date) {
        let w = Double(size.width), h = Double(size.height)
        let t = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000)
        drawBackground(context, w: w, h: h, t: t)

        let tableY = h * 0.72
        let radius = min(w * 0.2, 80)
        let state = coinState(now: now)
        let cosP = cos(Self.cameraPitch)

        // Shadow on the table: smaller and lighter as the coin goes up
        let k = max(0.25, 1 - state.height / 500)
        context.fill(Path(ellipseIn: CGRect(x: w / 2 - radius * 1.1 * k, y: tableY + radius * 0.35 - radius * 0.35 * k,
                                            width: radius * 2.2 * k, height: radius * 0.7 * k)),
                     with: .color(.black.opacity(0.4 * k)))

        drawCoin(context, center: CGPoint(x: w / 2, y: tableY - state.height * cosP), radius: radius, angle: state.angle)

        // Answer above the coin, or a hint before the first flip
        if let flip {
            let a = now.timeIntervalSince(flip.start)
            if a >= flip.total {
                let p = min(1, (a - flip.total) / 0.3)
                let pop = 1 + 0.3 * sin(.pi * p)
                var c = context
                c.opacity = p
                c.translateBy(x: w / 2, y: h * 0.38)
                c.scaleBy(x: pop, y: pop)
                c.draw(Text(flip.sideAUp ? sideA : sideB)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 1, green: 0.62, blue: 0.18)), at: .zero)
            }
        } else if Int(t * 1.5) % 2 == 0 {
            context.draw(Text("TAP TO FLIP").font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8)), at: CGPoint(x: w / 2, y: h * 0.38))
        }
    }

    private struct Vec3 { var x, y, z: Double }

    /// Rotate around X by the spin angle, then tilt for the camera.
    private func project(_ v: Vec3, angle: Double) -> Vec3 {
        let y1 = v.y * cos(angle) - v.z * sin(angle)
        let z1 = v.y * sin(angle) + v.z * cos(angle)
        let p = Self.cameraPitch
        return Vec3(x: v.x, y: y1 * cos(p) - z1 * sin(p), z: y1 * sin(p) + z1 * cos(p))
    }

    private func drawCoin(_ context: GraphicsContext, center: CGPoint, radius r: Double, angle: Double) {
        let n = project(Vec3(x: 0, y: 0, z: 1), angle: angle)
        let u = project(Vec3(x: 1, y: 0, z: 0), angle: angle)
        let v = project(Vec3(x: 0, y: 1, z: 0), angle: angle)
        let thickness = r * 0.13
        let aFacesUs = n.z >= 0

        func faceTransform(offset: Double, mirror: Bool) -> CGAffineTransform {
            let s = r / 100                                   // faces are drawn in a 100-unit circle
            // The back face is seen from behind: flip it vertically so its label reads upright when it lands
            let vx = mirror ? -v.x : v.x, vy = mirror ? -v.y : v.y
            return CGAffineTransform(a: u.x * s, b: u.y * s, c: vx * s, d: vy * s,
                                     tx: Double(center.x) + n.x * offset, ty: Double(center.y) + n.y * offset)
        }

        // Back face, rim, front face
        let backOffset = aFacesUs ? -thickness / 2 : thickness / 2
        let unit = Path(ellipseIn: CGRect(x: -100, y: -100, width: 200, height: 200))
        context.fill(unit.applying(faceTransform(offset: backOffset, mirror: false)), with: .color(Color(red: 0.45, green: 0.3, blue: 0.08)))
        for i in 0...10 {
            let off = backOffset + (-backOffset * 2) * Double(i) / 10
            context.fill(unit.applying(faceTransform(offset: off, mirror: false)),
                         with: .color(Color(red: 0.62, green: 0.45, blue: 0.14)))
        }

        var face = context
        face.concatenate(faceTransform(offset: -backOffset, mirror: !aFacesUs))
        drawFace(face, isA: aFacesUs)
        let shade = (1 - abs(n.z)) * 0.45                    // edge-on faces are darker
        face.fill(unit, with: .color(.black.opacity(shade)))
    }

    /// One face in a 100-unit circle: gold for side A, silver for side B.
    private func drawFace(_ ctx: GraphicsContext, isA: Bool) {
        let light = isA ? Color(red: 1, green: 0.86, blue: 0.4) : Color(red: 0.92, green: 0.93, blue: 0.96)
        let dark = isA ? Color(red: 0.85, green: 0.55, blue: 0.1) : Color(red: 0.6, green: 0.62, blue: 0.68)
        let ink = isA ? Color(red: 0.45, green: 0.27, blue: 0.03) : Color(red: 0.3, green: 0.32, blue: 0.38)
        ctx.fill(Path(ellipseIn: CGRect(x: -100, y: -100, width: 200, height: 200)),
                 with: .radialGradient(Gradient(colors: [light, dark]), center: CGPoint(x: -30, y: -30), startRadius: 0, endRadius: 150))
        ctx.stroke(Path(ellipseIn: CGRect(x: -80, y: -80, width: 160, height: 160)), with: .color(ink.opacity(0.6)), lineWidth: 5)
        for i in 0..<16 {
            let a = Double(i) / 16 * 2 * .pi
            ctx.fill(Path(ellipseIn: CGRect(x: cos(a) * 90 - 3, y: sin(a) * 90 - 3, width: 6, height: 6)), with: .color(ink.opacity(0.5)))
        }
        let label = isA ? sideA : sideB
        let fontSize = label.count > 4 ? 30.0 : 44.0
        ctx.draw(Text(label).font(.system(size: fontSize, weight: .black, design: .rounded)).foregroundColor(ink), at: .zero)
    }

    // MARK: - Background (Randomaker style)

    private func drawBackground(_ context: GraphicsContext, w: Double, h: Double, t: Double) {
        context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(.black))
        context.fill(wave(baseline: h * 0.47, amp: h * 0.030, freq: 1.6, phase: t * 0.6, w: w, h: h),
                     with: .color(Color(red: 0.17, green: 0.25, blue: 0.52)))
        context.fill(wave(baseline: h * 0.495, amp: h * 0.035, freq: 1.2, phase: 2.0 - t * 0.45, w: w, h: h),
                     with: .color(Color(red: 0.42, green: 0.13, blue: 0.16)))
        let table = wave(baseline: h * 0.535, amp: h * 0.028, freq: 0.9, phase: 4.0 + t * 0.35, w: w, h: h)
        context.fill(table, with: .linearGradient(
            Gradient(colors: [Color(red: 0.84, green: 0.50, blue: 0.21), Color(red: 0.70, green: 0.40, blue: 0.17)]),
            startPoint: CGPoint(x: 0, y: h * 0.5), endPoint: CGPoint(x: 0, y: h)))
        var pattern = context
        pattern.clip(to: table)
        let ink = Color(red: 0.45, green: 0.22, blue: 0.08).opacity(0.16)
        var row = 0
        var y = h * 0.47
        while y < h + 78 {
            var x = row % 2 == 0 ? 78 * 0.25 : 78 * 0.75
            while x < w + 78 {
                var c = pattern
                c.translateBy(x: x, y: y)
                c.rotate(by: .degrees(Double((row * 7 + Int(x)) % 40) - 20))
                c.stroke(Path(roundedRect: CGRect(x: -15, y: -15, width: 30, height: 30), cornerRadius: 5), with: .color(ink), lineWidth: 2)
                x += 78
            }
            y += 78 * 0.8
            row += 1
        }
        context.fill(Path(ellipseIn: CGRect(x: -w * 0.1, y: h * 0.55, width: w * 1.2, height: h * 0.38)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.78, blue: 0.5).opacity(0.22), .clear]),
                                           center: CGPoint(x: w / 2, y: h * 0.72), startRadius: 0, endRadius: w * 0.7))
    }

    private func wave(baseline: Double, amp: Double, freq: Double, phase: Double, w: Double, h: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h))
        for i in 0...48 {
            let x = w * Double(i) / 48
            p.addLine(to: CGPoint(x: x, y: baseline + amp * sin(x / w * freq * 2 * .pi + phase)))
        }
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}

#Preview {
    DecisionCoinView(sideA: "ME", sideB: "YOU")
}
