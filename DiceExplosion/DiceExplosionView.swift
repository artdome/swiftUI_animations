//
//  DiceExplosionView.swift
//  50 tumbling 3D dice explode, bounce, settle and add up — SwiftUI, iOS 17+
//
//  How to run:
//  • Simulator / iPhone: make it the root view in your App file:
//        WindowGroup { DiceExplosionView() }
//    then Cmd+R. The first explosion starts by itself; tap anywhere for more.
//  • Xcode preview: switch the preview to LIVE mode (▶︎), not "Selectable".
//

import SwiftUI

struct DiceExplosionView: View {
    /// Re-explode automatically a few seconds after the total is shown (handy for recording).
    var autoReplay = true
    /// Hook text at the top of the screen. Set to nil to hide it.
    var title: String? = "50 dice. 1 tap."

    @State private var sim = DiceSimulation()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                sim.step(to: timeline.date, size: size, autoReplay: autoReplay)
                sim.draw(in: context, size: size, title: title)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { location in
            sim.explode(at: location)
        }
        .statusBarHidden()
    }
}

// MARK: - Simulation

final class DiceSimulation {

    // Tunables
    let diceCount = 50
    let gravity = 2600.0             // pt/s²
    let bounce = 0.42                // how much speed is kept after hitting the table
    let cameraPitch = -0.95          // look down at the table from above

    private struct Die {
        var x, y, vx, vy: Double
        var floorY: Double           // where on the table this die lands
        var depth: Double            // 0 = far (small) … 1 = near (big)
        var ax, ay, az: Double       // orientation
        var wx, wy, wz: Double       // spin speed
        var bounces = 0
        var settleStart: Double? = nil
        var from = (0.0, 0.0, 0.0)
        var target = (0.0, 0.0, 0.0)
        var value = 1
        var settled = false
    }

    private struct Spark {
        var x, y, vx, vy, hue, size: Double
    }

    private var dice: [Die] = []
    private var sparks: [Spark] = []
    private var time = 0.0
    private var lastDate: Date?
    private var pendingOrigin: CGPoint?
    private var explodeTime = -100.0
    private var origin = CGPoint.zero
    private var settledTime: Double?
    private var total = 0

    // MARK: Input

    func explode(at point: CGPoint) {
        pendingOrigin = point
    }

    // MARK: Physics

    func step(to date: Date, size: CGSize, autoReplay: Bool) {
        let dt = lastDate.map { min(1.0 / 30, max(0, date.timeIntervalSince($0))) } ?? 0
        lastDate = date
        time += dt

        let defaultOrigin = CGPoint(x: size.width / 2, y: size.height * 0.80)

        if let o = pendingOrigin {
            pendingOrigin = nil
            launch(from: o, size: size)
        } else if dice.isEmpty && time > 0.6 {
            launch(from: defaultOrigin, size: size)               // first, automatic explosion
        } else if autoReplay, let s = settledTime, time - s > 3.2 {
            launch(from: defaultOrigin, size: size)
        }

        let w = Double(size.width)
        for i in dice.indices {
            var d = dice[i]
            if d.settled { continue }

            if let start = d.settleStart {
                // Roll into place: ease the orientation to the nearest flat face
                let p = min(1, (time - start) / 0.35)
                let e = 1 - pow(1 - p, 3)
                d.ax = d.from.0 + (d.target.0 - d.from.0) * e
                d.ay = d.from.1 + (d.target.1 - d.from.1) * e
                d.az = d.from.2 + (d.target.2 - d.from.2) * e
                d.x += d.vx * dt
                d.vx *= pow(0.02, dt)                              // table friction
                if p >= 1 { d.settled = true }
            } else {
                d.vy += gravity * dt
                d.x += d.vx * dt
                d.y += d.vy * dt
                d.ax += d.wx * dt
                d.ay += d.wy * dt
                d.az += d.wz * dt

                // side walls
                let margin = 24.0
                if d.x < margin { d.x = margin; d.vx = abs(d.vx) * 0.6 }
                if d.x > w - margin { d.x = w - margin; d.vx = -abs(d.vx) * 0.6 }

                // table
                if d.vy > 0 && d.y >= d.floorY {
                    d.y = d.floorY
                    d.bounces += 1
                    d.vy = -d.vy * bounce
                    d.vx *= 0.7
                    d.wx *= 0.6; d.wy *= 0.6; d.wz *= 0.6
                    if abs(d.vy) < 160 || d.bounces >= 4 {
                        d.vy = 0
                        d.settleStart = time
                        d.from = (d.ax, d.ay, d.az)
                        d.target = (snap(d.ax), snap(d.ay), snap(d.az))
                        d.value = topValue(ax: d.target.0, ay: d.target.1, az: d.target.2)
                    }
                }
            }
            dice[i] = d
        }

        for i in sparks.indices {
            sparks[i].vx *= pow(0.08, dt)
            sparks[i].vy *= pow(0.08, dt)
            sparks[i].vy += 500 * dt
            sparks[i].x += sparks[i].vx * dt
            sparks[i].y += sparks[i].vy * dt
        }

        if settledTime == nil, !dice.isEmpty, dice.allSatisfy(\.settled) {
            settledTime = time
            total = dice.reduce(0) { $0 + $1.value }
        }
    }

    private func launch(from o: CGPoint, size: CGSize) {
        origin = o
        explodeTime = time
        settledTime = nil
        let h = Double(size.height)
        dice = (0..<diceCount).map { _ in
            let angle = Double.random(in: (-Double.pi * 0.9)...(-Double.pi * 0.1))   // upward fan
            let speed = Double.random(in: 900...1700)
            let depth = Double.random(in: 0...1)
            return Die(
                x: o.x, y: o.y,
                vx: cos(angle) * speed, vy: sin(angle) * speed,
                floorY: h * (0.60 + 0.24 * depth),
                depth: depth,
                ax: .random(in: 0..<(2 * .pi)), ay: .random(in: 0..<(2 * .pi)), az: .random(in: 0..<(2 * .pi)),
                wx: .random(in: -16...16), wy: .random(in: -16...16), wz: .random(in: -10...10)
            )
        }
        sparks = (0..<80).map { _ in
            let a = Double.random(in: 0..<(2 * .pi))
            let s = Double.random(in: 300...1300)
            return Spark(x: o.x, y: o.y, vx: cos(a) * s, vy: sin(a) * s,
                         hue: .random(in: 0..<1), size: .random(in: 2...6))
        }
    }

    private func snap(_ a: Double) -> Double {
        (a / (.pi / 2)).rounded() * (.pi / 2)
    }

    /// The face that ends up on top — that's the number the die rolled.
    private func topValue(ax: Double, ay: Double, az: Double) -> Int {
        var best = (up: -2.0, pips: 1)
        for f in Self.cubeFaces {
            let n = rotate(f.n, ax: ax, ay: ay, az: az)
            if -n.y > best.up { best = (-n.y, f.pips) }        // screen y points down, so "up" is -y
        }
        return best.pips
    }

    // MARK: Drawing

    func draw(in context: GraphicsContext, size: CGSize, title: String?) {
        let w = Double(size.width), h = Double(size.height)

        // Background in Randomaker style: black sky, blue + burgundy waves, orange table
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
        context.fill(
            wave(baseline: h * 0.47, amp: h * 0.030, freq: 1.6, phase: time * 0.6, w: w, h: h),
            with: .color(Color(red: 0.17, green: 0.25, blue: 0.52)))
        context.fill(
            wave(baseline: h * 0.495, amp: h * 0.035, freq: 1.2, phase: 2.0 - time * 0.45, w: w, h: h),
            with: .color(Color(red: 0.42, green: 0.13, blue: 0.16)))
        let table = wave(baseline: h * 0.535, amp: h * 0.028, freq: 0.9, phase: 4.0 + time * 0.35, w: w, h: h)
        context.fill(
            table,
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.84, green: 0.50, blue: 0.21), Color(red: 0.70, green: 0.40, blue: 0.17)]),
                startPoint: CGPoint(x: 0, y: h * 0.5), endPoint: CGPoint(x: 0, y: h)))

        // Faint dice pattern on the table, like in the app
        var pattern = context
        pattern.clip(to: table)
        drawDicePattern(pattern, w: w, h: h)

        // Warm light in the middle of the table
        context.fill(
            Path(ellipseIn: CGRect(x: -w * 0.1, y: h * 0.55, width: w * 1.2, height: h * 0.38)),
            with: .radialGradient(
                Gradient(colors: [Color(red: 1, green: 0.78, blue: 0.5).opacity(0.22), .clear]),
                center: CGPoint(x: w / 2, y: h * 0.72), startRadius: 0, endRadius: w * 0.7))

        // Explosion flash + sparks
        let age = time - explodeTime
        if age < 0.35 {
            let a = 1 - age / 0.35
            let r = 60 + age * 900
            context.fill(
                Path(ellipseIn: CGRect(x: origin.x - r, y: origin.y - r, width: 2 * r, height: 2 * r)),
                with: .radialGradient(Gradient(colors: [Color.white.opacity(0.9 * a), Color.orange.opacity(0.4 * a), .clear]),
                                      center: origin, startRadius: 0, endRadius: r))
        }
        if age < 1.0 {
            var glow = context
            glow.blendMode = .plusLighter
            let a = 1 - age / 1.0
            for s in sparks {
                let r = s.size * (0.6 + a)
                glow.fill(Path(ellipseIn: CGRect(x: s.x - r, y: s.y - r, width: 2 * r, height: 2 * r)),
                          with: .color(Color.white.opacity(a)))
            }
        }

        // Far dice first, near dice last
        let order = dice.indices.sorted { dice[$0].depth < dice[$1].depth }

        // Shadows on the table
        for i in order {
            let d = dice[i]
            let half = dieHalf(d)
            let lift = max(0, d.floorY - d.y)
            let k = max(0, 1 - lift / 450)
            let sw = half * 2.6 * (0.5 + 0.5 * k), sh = half * 0.7 * (0.5 + 0.5 * k)
            context.fill(
                Path(ellipseIn: CGRect(x: d.x - sw / 2, y: d.floorY + half * 1.0 - sh / 2, width: sw, height: sh)),
                with: .color(.black.opacity(0.45 * k)))
        }
        for i in order {
            let d = dice[i]
            drawDie3D(context, at: CGPoint(x: d.x, y: d.y), half: dieHalf(d), ax: d.ax, ay: d.ay, az: d.az)
        }

        // Hook text
        if let title {
            context.draw(
                Text(title).font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundColor(.white),
                at: CGPoint(x: w / 2, y: h * 0.13))
        }

        // Total, counting up with a pop
        if let s = settledTime {
            let p = min(1, (time - s) / 0.9)
            let shown = Int((Double(total) * (1 - pow(1 - p, 3))).rounded())
            let popP = min(1, (time - s) / 0.35)
            let pop = 1 + 0.25 * sin(.pi * popP)

            var c = context
            c.opacity = min(1, (time - s) / 0.15)
            c.translateBy(x: w / 2, y: h * 0.30)
            c.scaleBy(x: pop, y: pop)
            c.draw(Text("TOTAL").font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7)), at: CGPoint(x: 0, y: -62))
            c.draw(Text("\(shown)").font(.system(size: 104, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 1, green: 0.62, blue: 0.18)), at: .zero)
        }
    }

    /// Filled area under a gentle sine wave (used for the layered background).
    private func wave(baseline: Double, amp: Double, freq: Double, phase: Double, w: Double, h: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h))
        let steps = 48
        for i in 0...steps {
            let x = w * Double(i) / Double(steps)
            p.addLine(to: CGPoint(x: x, y: baseline + amp * sin(x / w * freq * 2 * .pi + phase)))
        }
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }

    private func drawDicePattern(_ context: GraphicsContext, w: Double, h: Double) {
        let ink = Color(red: 0.45, green: 0.22, blue: 0.08).opacity(0.16)
        let step = 78.0, s = 15.0
        var row = 0
        var y = h * 0.47
        while y < h + step {
            var x = (row % 2 == 0) ? step * 0.25 : step * 0.75
            while x < w + step {
                var c = context
                c.translateBy(x: x, y: y)
                c.rotate(by: .degrees(Double((row * 7 + Int(x)) % 40) - 20))
                let box = Path(roundedRect: CGRect(x: -s, y: -s, width: 2 * s, height: 2 * s), cornerRadius: 5)
                c.stroke(box, with: .color(ink), lineWidth: 2)
                for (px, py) in [(-0.5, -0.5), (0.5, -0.5), (0.0, 0.0), (-0.5, 0.5), (0.5, 0.5)] {
                    c.fill(Path(ellipseIn: CGRect(x: px * s - 2.5, y: py * s - 2.5, width: 5, height: 5)), with: .color(ink))
                }
                x += step
            }
            y += step * 0.8
            row += 1
        }
    }

    private func dieHalf(_ d: Die) -> Double {
        15 * (0.62 + 0.55 * d.depth)          // nearer dice are bigger
    }

    // MARK: 3D die

    private struct Vec3 { var x, y, z: Double }
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

    /// Camera looks down at the table, so the top faces (the results) face the viewer.
    private func camera(_ v: Vec3) -> Vec3 {
        let p = cameraPitch
        return Vec3(x: v.x, y: v.y * cos(p) - v.z * sin(p), z: v.y * sin(p) + v.z * cos(p))
    }

    private func drawDie3D(_ context: GraphicsContext, at center: CGPoint, half: Double,
                           ax: Double, ay: Double, az: Double) {
        var visible: [(n: Vec3, u: Vec3, v: Vec3, pips: Int)] = []
        for face in Self.cubeFaces {
            let n = camera(rotate(face.n, ax: ax, ay: ay, az: az))
            guard n.z > 0.02 else { continue }
            visible.append((n: n,
                            u: camera(rotate(face.u, ax: ax, ay: ay, az: az)),
                            v: camera(rotate(face.v, ax: ax, ay: ay, az: az)),
                            pips: face.pips))
        }
        visible.sort { $0.n.z < $1.n.z }

        let unit = CGRect(x: -1, y: -1, width: 2, height: 2)
        for f in visible {
            let transform = CGAffineTransform(
                a: f.u.x * half, b: f.u.y * half,
                c: f.v.x * half, d: f.v.y * half,
                tx: center.x + f.n.x * half, ty: center.y + f.n.y * half)
            let light = 0.5 + 0.5 * f.n.z
            let facePath = Path(roundedRect: unit, cornerRadius: 0.18).applying(transform)
            context.fill(facePath, with: .color(Color(white: light)))
            context.stroke(facePath, with: .color(.black.opacity(0.25)), lineWidth: 0.8)
            for pip in Self.pipOffsets(f.pips) {
                let r = 0.19
                let pipPath = Path(ellipseIn: CGRect(x: pip.x - r, y: pip.y - r, width: 2 * r, height: 2 * r))
                    .applying(transform)
                context.fill(pipPath, with: .color(Color(red: 0.12, green: 0.08, blue: 0.22)))
            }
        }
    }
}

#Preview {
    DiceExplosionView()
}
