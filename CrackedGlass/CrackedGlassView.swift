//
//  CrackedGlassView.swift
//  Tap the screen and the glass cracks. Tap too many times and it shatters. SwiftUI Canvas, iOS 17+
//
//  Copyright (c) 2026 Arturs (https://github.com/artdome)
//  SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//  Free for non-commercial use. Commercial use is not allowed. See LICENSE.md.
//
//  • A soft animated wallpaper sits behind the "glass".
//  • Every tap makes a new spider-web crack where you touched: jagged rays that
//    grow outwards, some branching, rings joining them, and crushed glass in the middle.
//  • On tap number `tapsToShatter` the glass breaks into pieces that fall off the screen,
//    then a fresh, clean screen fades back in.
//  • Nothing is an image. Every crack is generated on the spot, so no two are the same.
//
//  How to run:
//  • Make it the root view in your App file:
//        WindowGroup { CrackedGlassView() }
//    then Cmd+R and tap (if you dare).
//  • Xcode preview: switch the preview to LIVE mode (▶︎), not "Selectable".
//

import SwiftUI

struct CrackedGlassView: View {
    var tapsToShatter = 6

    @State private var cracks: [GlassCrack] = []
    @State private var shatter: GlassShatter?
    @State private var hits = 0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    draw(context, size: size, now: timeline.date)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                tap(at: location, size: geo.size)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: hits)
    }

    // MARK: - Tap

    private func tap(at point: CGPoint, size: CGSize) {
        let now = Date()
        if let shatter, now.timeIntervalSince(shatter.start) < GlassShatter.duration { return }   // still falling
        shatter = nil

        if cracks.count + 1 >= tapsToShatter {
            shatter = GlassShatter.make(size: size, impact: point, start: now, cracks: cracks)
            cracks.removeAll()
        } else {
            cracks.append(GlassCrack.make(at: point, size: size, start: now))
        }
        hits += 1
    }

    // MARK: - Drawing

    private func draw(_ context: GraphicsContext, size: CGSize, now: Date) {
        let t = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000)

        if let shatter {
            drawShatter(shatter, in: context, size: size, now: now, t: t)
            return
        }

        drawWallpaper(context, size: size, t: t)
        drawGlassSheen(context, size: size)
        for crack in cracks {
            drawCrack(crack, in: context, now: now, fade: 1)
        }
    }

    /// Soft coloured blobs drifting slowly, in Randomaker colours.
    private func drawWallpaper(_ context: GraphicsContext, size: CGSize, t: Double) {
        let w = Double(size.width), h = Double(size.height)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.06, green: 0.05, blue: 0.12)))
        let blobs: [(Color, Double, Double, Double)] = [
            (Color(red: 1, green: 0.55, blue: 0.15), 0.30, 0.25, 0.0),
            (Color(red: 0.55, green: 0.25, blue: 0.95), 0.75, 0.40, 1.7),
            (Color(red: 0.2, green: 0.5, blue: 1), 0.35, 0.75, 3.1),
            (Color(red: 1, green: 0.3, blue: 0.55), 0.70, 0.85, 4.4),
        ]
        for (color, bx, by, phase) in blobs {
            let c = CGPoint(x: (bx + 0.12 * sin(t * 0.21 + phase)) * w, y: (by + 0.08 * cos(t * 0.17 + phase)) * h)
            let r = w * 0.75
            context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                         with: .radialGradient(Gradient(colors: [color.opacity(0.8), color.opacity(0)]),
                                               center: c, startRadius: 0, endRadius: r))
        }
    }

    /// A faint diagonal reflection, so it reads as glass.
    private func drawGlassSheen(_ context: GraphicsContext, size: CGSize) {
        var band = Path()
        let w = Double(size.width), h = Double(size.height)
        band.move(to: CGPoint(x: w * 0.15, y: 0))
        band.addLine(to: CGPoint(x: w * 0.45, y: 0))
        band.addLine(to: CGPoint(x: w * 0.05, y: h * 0.45))
        band.addLine(to: CGPoint(x: -w * 0.25, y: h * 0.45))
        band.closeSubpath()
        context.fill(band, with: .color(.white.opacity(0.05)))
    }

    private func drawCrack(_ crack: GlassCrack, in context: GraphicsContext, now: Date, fade: Double) {
        let p = min(1, max(0, now.timeIntervalSince(crack.start) / GlassCrack.growTime))
        guard p > 0, fade > 0 else { return }

        // Rays grow outwards; branches start once their parent ray reaches them
        var lines = Path()
        for ray in crack.rays {
            guard p > ray.delay else { continue }
            let v = min(1, (p - ray.delay) / max(0.01, 1 - ray.delay))
            let count = max(2, Int(Double(ray.points.count - 1) * v) + 1)
            lines.addLines(Array(ray.points.prefix(count)))
        }
        // Rings join neighbouring rays once the rays are long enough
        let ringAlpha = min(1, max(0, (p - 0.55) / 0.45))
        var rings = Path()
        for ring in crack.rings {
            rings.move(to: ring.from)
            rings.addQuadCurve(to: ring.to, control: ring.control)
        }

        // Glow, dark edge, bright edge: looks like a crack inside the glass
        context.drawLayer { glow in
            glow.addFilter(.blur(radius: 2))
            glow.stroke(lines, with: .color(.white.opacity(0.35 * fade)), lineWidth: 3)
            glow.stroke(rings, with: .color(.white.opacity(0.3 * ringAlpha * fade)), lineWidth: 3)
        }
        var shadow = context
        shadow.translateBy(x: 1.2, y: 1.2)
        shadow.stroke(lines, with: .color(.black.opacity(0.4 * fade)), lineWidth: 2.2)
        shadow.stroke(rings, with: .color(.black.opacity(0.35 * ringAlpha * fade)), lineWidth: 2)
        context.stroke(lines, with: .color(.white.opacity(0.9 * fade)), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
        context.stroke(rings, with: .color(.white.opacity(0.75 * ringAlpha * fade)), lineWidth: 1)

        // Crushed glass at the point of impact
        let c = crack.center
        context.fill(Path(ellipseIn: CGRect(x: c.x - 32, y: c.y - 32, width: 64, height: 64)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(0.35 * fade), .clear]), center: c, startRadius: 0, endRadius: 32))
        for shard in crack.shards {
            var s = Path()
            s.addLines(shard)
            s.closeSubpath()
            context.fill(s, with: .color(.white.opacity(0.7 * fade)))
        }
        context.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(.white.opacity(0.95 * fade)))
    }

    private func drawShatter(_ shatter: GlassShatter, in context: GraphicsContext, size: CGSize, now: Date, t: Double) {
        let a = now.timeIntervalSince(shatter.start)
        let h = Double(size.height)

        // Clean screen fades back in at the end
        if a >= GlassShatter.duration {
            drawWallpaper(context, size: size, t: t)
            drawGlassSheen(context, size: size)
            let fadeIn = min(1, (a - GlassShatter.duration) / 0.5)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(1 - fadeIn)))
            return
        }

        // Pieces fall away from the impact, each spinning a little
        for piece in shatter.pieces {
            let dt = max(0, a - piece.delay)
            let dx = piece.vx * dt
            let dy = piece.vy * dt + 0.5 * 2400 * dt * dt
            if Double(piece.centroid.y) + dy > h + 150 { continue }

            var c = context
            c.translateBy(x: piece.centroid.x + dx, y: piece.centroid.y + dy)
            c.rotate(by: .radians(piece.spin * dt))
            c.translateBy(x: -piece.centroid.x, y: -piece.centroid.y)
            var shape = Path()
            shape.addLines(piece.corners)
            shape.closeSubpath()

            var inside = c
            inside.clip(to: shape)
            drawWallpaper(inside, size: size, t: t)
            inside.fill(shape, with: .color(.white.opacity(0.06)))
            c.stroke(shape, with: .color(.white.opacity(0.55 * min(1, dt * 4))), lineWidth: 1)   // edges show once it moves
        }

        // Old cracks and a white flash vanish in the first moment
        let flash = max(0, 1 - a / 0.25)
        for crack in shatter.oldCracks { drawCrack(crack, in: context, now: now, fade: flash) }
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.35 * flash)))
    }
}

// MARK: - One crack

private struct GlassCrack {
    struct Ray {
        let points: [CGPoint]
        let delay: Double                  // 0…1 of the growth time before this ray starts
    }
    struct Ring {
        let from, to, control: CGPoint
    }

    static let growTime = 0.28

    let start: Date
    let center: CGPoint
    let rays: [Ray]
    let rings: [Ring]
    let shards: [[CGPoint]]

    static func make(at c: CGPoint, size: CGSize, start: Date) -> GlassCrack {
        let cx = Double(c.x), cy = Double(c.y)
        let diagonal = (Double(size.width * size.width + size.height * size.height)).squareRoot()
        let n = Int.random(in: 9...14)
        var mains: [[CGPoint]] = []
        var rays: [Ray] = []

        func walk(from x0: Double, _ y0: Double, angle a0: Double, length: Double) -> [CGPoint] {
            var pts = [CGPoint(x: x0, y: y0)]
            var x = x0, y = y0, angle = a0, travelled = 0.0
            while travelled < length {
                let step = Double.random(in: 10...22)
                angle += Double.random(in: -0.22...0.22)
                x += cos(angle) * step
                y += sin(angle) * step
                travelled += step
                pts.append(CGPoint(x: x, y: y))
            }
            return pts
        }

        for i in 0..<n {
            let angle = 2 * Double.pi * Double(i) / Double(n) + Double.random(in: -0.25...0.25)
            let pts = walk(from: cx, cy, angle: angle, length: Double.random(in: 90...max(140, diagonal * 0.55)))
            mains.append(pts)
            rays.append(Ray(points: pts, delay: 0))

            // Branches split off along the way
            for _ in 0..<Int.random(in: 0...2) where pts.count > 5 {
                let k = Int.random(in: 3..<(pts.count - 1))
                let prev = pts[k - 1], here = pts[k]
                let dir = atan2(Double(here.y - prev.y), Double(here.x - prev.x)) + Double.random(in: 0.4...0.9) * (Bool.random() ? 1 : -1)
                let branch = walk(from: Double(here.x), Double(here.y), angle: dir, length: Double.random(in: 25...90))
                rays.append(Ray(points: branch, delay: Double(k) / Double(pts.count)))
            }
        }

        // Spider-web rings between neighbouring rays, sagging towards the centre
        var rings: [Ring] = []
        for level in 1...3 {
            let index = level * 2 + Int.random(in: 0...1)
            for i in 0..<n {
                let a = mains[i], b = mains[(i + 1) % n]
                guard a.count > index, b.count > index, Double.random(in: 0...1) < 0.7 else { continue }
                let p1 = a[index], p2 = b[index]
                let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                let control = CGPoint(x: mid.x + (c.x - mid.x) * 0.18, y: mid.y + (c.y - mid.y) * 0.18)
                rings.append(Ring(from: p1, to: p2, control: control))
            }
        }

        // Little shards of crushed glass around the impact
        let shards: [[CGPoint]] = (0..<Int.random(in: 8...12)).map { _ in
            let ang = Double.random(in: 0..<(2 * .pi)), dist = Double.random(in: 3...14), s = Double.random(in: 2.5...6)
            let sx = cx + cos(ang) * dist, sy = cy + sin(ang) * dist
            return (0..<3).map { j in
                let aj = ang + Double(j) * 2.1 + Double.random(in: -0.4...0.4)
                return CGPoint(x: sx + cos(aj) * s, y: sy + sin(aj) * s)
            }
        }

        return GlassCrack(start: start, center: c, rays: rays, rings: rings, shards: shards)
    }
}

// MARK: - The big break

private struct GlassShatter {
    struct Piece {
        let corners: [CGPoint]
        let centroid: CGPoint
        let delay, vx, vy, spin: Double
    }

    static let duration = 1.8

    let start: Date
    let pieces: [Piece]
    let oldCracks: [GlassCrack]

    static func make(size: CGSize, impact: CGPoint, start: Date, cracks: [GlassCrack]) -> GlassShatter {
        let w = Double(size.width), h = Double(size.height)
        let cols = 7, rows = 13
        let cw = w / Double(cols), ch = h / Double(rows)

        // A jittered grid of points, edges kept straight
        var grid: [[CGPoint]] = []
        for r in 0...rows {
            var line: [CGPoint] = []
            for c in 0...cols {
                let edgeX = c == 0 || c == cols, edgeY = r == 0 || r == rows
                let x = Double(c) * cw + (edgeX ? 0 : Double.random(in: -0.35...0.35) * cw)
                let y = Double(r) * ch + (edgeY ? 0 : Double.random(in: -0.35...0.35) * ch)
                line.append(CGPoint(x: x, y: y))
            }
            grid.append(line)
        }

        // Two triangles per cell, split along a random diagonal
        let ix = Double(impact.x), iy = Double(impact.y)
        let maxDistance = (w * w + h * h).squareRoot()
        var pieces: [Piece] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let p00 = grid[r][c], p10 = grid[r][c + 1], p01 = grid[r + 1][c], p11 = grid[r + 1][c + 1]
                let triangles = Bool.random() ? [[p00, p10, p11], [p00, p11, p01]] : [[p00, p10, p01], [p10, p11, p01]]
                for tri in triangles {
                    let gx = tri.reduce(0.0) { $0 + Double($1.x) } / 3
                    let gy = tri.reduce(0.0) { $0 + Double($1.y) } / 3
                    let dx = gx - ix, dy = gy - iy
                    let distance = (dx * dx + dy * dy).squareRoot()
                    pieces.append(Piece(
                        corners: tri,
                        centroid: CGPoint(x: gx, y: gy),
                        delay: distance / 1400 + Double.random(in: 0...0.08),
                        vx: dx * 1.2 + Double.random(in: -60...60),
                        vy: Double.random(in: (-260)...(-60)) * (1 - 0.5 * distance / maxDistance),
                        spin: Double.random(in: -5...5)))
                }
            }
        }
        return GlassShatter(start: start, pieces: pieces, oldCracks: cracks)
    }
}

#Preview {
    CrackedGlassView()
}
