//
//  GaltonBoardView.swift
//  Galton board: random balls that always pile up into the same bell curve. SwiftUI Canvas, iOS 17+
//
//  Copyright (c) 2026 Arturs (https://github.com/artdome)
//  SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//  Free for non-commercial use. Commercial use is not allowed. See LICENSE.md.
//
//  • Tap to drop 150 balls from the funnel. Each ball hits 12 rows of pegs and goes
//    left or right at random, 50/50, then lands in one of 13 bins.
//  • Every single path is random, but together they always build the same shape:
//    the normal distribution. A dashed line shows the curve the maths predicts.
//  • When the bins are about to overflow, the next tap starts over.
//
//  How to run:
//  • Make it the root view in your App file:
//        WindowGroup { GaltonBoardView() }
//    then Cmd+R and tap.
//  • Xcode preview: switch the preview to LIVE mode (▶︎), not "Selectable".
//

import SwiftUI

struct GaltonBoardView: View {
    /// Show a ring where the finger touched (handy for screen recordings).
    var showTouches = true

    private static let rows = 12
    private static let perDrop = 150
    private static let dropRate = 45.0               // balls per second leaving the funnel
    private static let stepTime = 0.075              // seconds from one peg row to the next
    private static let firstFall = 0.25              // funnel to first peg
    private static let gravity = 2200.0              // pt/s² for the fall into the bins
    private static let maxPerBin = 105               // start over before the bins overflow

    private struct Ball {
        let spawn: Date
        let path: [Bool]                             // true = bounced right at that row
        let bin: Int
        let slot: Int                                // position in the bin's pile
    }

    @State private var balls: [Ball] = []
    @State private var binCounts = Array(repeating: 0, count: GaltonBoardView.rows + 1)
    @State private var drops = 0
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
            drop(at: location)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: drops)
    }

    // MARK: - Tap

    private func drop(at point: CGPoint) {
        let now = Date()
        touch = (point, now)

        // Expected extra balls in the middle bin is about perDrop × 0.23
        if (binCounts.max() ?? 0) + Int(Double(Self.perDrop) * 0.25) > Self.maxPerBin {
            balls.removeAll()
            binCounts = Array(repeating: 0, count: Self.rows + 1)
        }

        // If balls are still queued in the funnel, the new ones line up after them
        let queueEnd = balls.last.map { max(0, $0.spawn.timeIntervalSince(now) + 1 / Self.dropRate) } ?? 0
        for i in 0..<Self.perDrop {
            var path: [Bool] = []
            var bin = 0
            for _ in 0..<Self.rows {
                let right = Bool.random()
                path.append(right)
                if right { bin += 1 }
            }
            balls.append(Ball(spawn: now.addingTimeInterval(queueEnd + Double(i) / Self.dropRate),
                              path: path, bin: bin, slot: binCounts[bin]))
            binCounts[bin] += 1
        }
        drops += 1
    }

    // MARK: - Layout

    private struct Layout {
        let w, h, cx, spacing, r, pegR, funnelTop, funnelY, pegTop, rowH, binTop, binBottom: Double

        init(_ size: CGSize) {
            let w = Double(size.width), h = Double(size.height)
            let spacing = min(w * 0.068, h * 0.031)
            let pegTop = h * 0.26, rowH = h * 0.027
            self.w = w; self.h = h
            self.cx = w / 2
            self.spacing = spacing
            self.r = spacing * 0.16
            self.pegR = spacing * 0.09
            self.funnelTop = h * 0.165
            self.funnelY = h * 0.225
            self.pegTop = pegTop
            self.rowH = rowH
            self.binTop = pegTop + Double(GaltonBoardView.rows) * rowH + rowH * 0.3
            self.binBottom = h * 0.93
        }

        func binX(_ k: Int) -> Double { cx + (Double(k) - Double(GaltonBoardView.rows) / 2) * spacing }

        func slotPoint(bin: Int, slot: Int) -> CGPoint {
            let layer = slot / 3, col = slot % 3
            return CGPoint(x: binX(bin) + Double(col - 1) * r * 2.04,
                           y: binBottom - r - Double(layer) * r * 1.84)
        }
    }

    /// Where a ball is right now, or nil if it has not left the funnel yet. Also says if it has landed.
    private func position(of ball: Ball, now: Date, _ L: Layout) -> (point: CGPoint, landed: Bool)? {
        let a = now.timeIntervalSince(ball.spawn)
        guard a >= 0 else { return nil }
        let rows = Self.rows
        let topRest = L.pegTop - L.pegR - L.r

        if a < Self.firstFall {
            let p = a / Self.firstFall
            return (CGPoint(x: L.cx, y: L.funnelY + (topRest - L.funnelY) * p * p), false)
        }

        let a2 = a - Self.firstFall
        let step = Int(a2 / Self.stepTime)
        if step < rows {
            var k = 0
            for i in 0..<step where ball.path[i] { k += 1 }
            let p = (a2 - Double(step) * Self.stepTime) / Self.stepTime
            let x0 = L.cx + (Double(k) - Double(step) / 2) * L.spacing
            let x1 = x0 + (ball.path[step] ? 0.5 : -0.5) * L.spacing
            let y0 = topRest + Double(step) * L.rowH
            let y1 = y0 + L.rowH
            return (CGPoint(x: x0 + (x1 - x0) * p,
                            y: y0 + (y1 - y0) * p * p - L.rowH * 0.35 * sin(.pi * p)), false)   // little hop off the peg
        }

        // Fall into the bin and onto the pile
        let a3 = a2 - Double(rows) * Self.stepTime
        let start = CGPoint(x: L.binX(ball.bin), y: topRest + Double(rows) * L.rowH)
        let end = L.slotPoint(bin: ball.bin, slot: ball.slot)
        let d = max(1, Double(end.y - start.y))
        let fall = (2 * d / Self.gravity).squareRoot()
        if a3 < fall {
            let p = a3 / fall
            return (CGPoint(x: start.x + (end.x - start.x) * p, y: start.y + d * p * p), false)
        }
        return (end, true)
    }

    // MARK: - Drawing

    private func draw(_ context: GraphicsContext, size: CGSize, now: Date) {
        let L = Layout(size)
        let w = L.w, h = L.h

        // Background
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.12),
                                                            Color(red: 0.10, green: 0.11, blue: 0.20)]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

        // Funnel
        var funnel = Path()
        funnel.move(to: CGPoint(x: L.cx - w * 0.2, y: L.funnelTop))
        funnel.addLine(to: CGPoint(x: L.cx - L.r * 2.2, y: L.funnelY))
        funnel.move(to: CGPoint(x: L.cx + w * 0.2, y: L.funnelTop))
        funnel.addLine(to: CGPoint(x: L.cx + L.r * 2.2, y: L.funnelY))
        context.stroke(funnel, with: .color(Color(white: 0.75)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        // Balls still waiting in the funnel
        let waiting = balls.filter { $0.spawn > now }.count
        if waiting > 0 {
            var heap = Path()
            let shown = min(waiting, 36)
            for i in 0..<shown {
                let row = Int((Double(i) * 2).squareRoot())          // a rough triangle heap
                let inRow = i - row * row / 2
                let x = L.cx + (Double(inRow) - Double(row) / 2) * L.r * 2.1
                let y = L.funnelY - L.r - Double(row) * L.r * 1.9
                heap.addEllipse(in: CGRect(x: x - L.r, y: y - L.r, width: L.r * 2, height: L.r * 2))
            }
            context.fill(heap, with: .color(Color(red: 1, green: 0.6, blue: 0.15)))
        }

        // Pegs
        var pegs = Path()
        for i in 0..<Self.rows {
            for j in 0...i {
                let x = L.cx + (Double(j) - Double(i) / 2) * L.spacing
                let y = L.pegTop + Double(i) * L.rowH
                pegs.addEllipse(in: CGRect(x: x - L.pegR, y: y - L.pegR, width: L.pegR * 2, height: L.pegR * 2))
            }
        }
        context.fill(pegs, with: .color(Color(white: 0.82)))

        // Bins
        var bins = Path()
        for k in 0...(Self.rows + 1) {
            let x = L.binX(k) - L.spacing / 2
            bins.move(to: CGPoint(x: x, y: L.binTop))
            bins.addLine(to: CGPoint(x: x, y: L.binBottom))
        }
        bins.move(to: CGPoint(x: L.binX(0) - L.spacing / 2, y: L.binBottom))
        bins.addLine(to: CGPoint(x: L.binX(Self.rows) + L.spacing / 2, y: L.binBottom))
        context.stroke(bins, with: .color(Color(white: 0.55)), lineWidth: 1.5)

        // Balls: one path for the bodies, one for the highlights
        var bodies = Path(), shines = Path()
        var landed = 0
        for ball in balls {
            guard let pos = position(of: ball, now: now, L) else { continue }
            if pos.landed { landed += 1 }
            let c = pos.point
            bodies.addEllipse(in: CGRect(x: c.x - L.r, y: c.y - L.r, width: L.r * 2, height: L.r * 2))
            shines.addEllipse(in: CGRect(x: c.x - L.r * 0.55, y: c.y - L.r * 0.6, width: L.r * 0.7, height: L.r * 0.7))
        }
        context.fill(bodies, with: .color(Color(red: 1, green: 0.6, blue: 0.15)))       // Randomaker orange
        context.fill(shines, with: .color(.white.opacity(0.6)))

        // The curve the maths predicts for this many balls
        if landed > 30 {
            let n = Double(Self.rows)
            let mean = n / 2, sigma = (n / 4).squareRoot()
            let perBall = L.r * 1.84 / 3                               // pile height added by one ball
            var curve = Path()
            for i in 0...80 {
                let k = -0.5 + (n + 1) * Double(i) / 80
                let density = exp(-(k - mean) * (k - mean) / (2 * sigma * sigma)) / (sigma * (2 * .pi).squareRoot())
                let y = L.binBottom - Double(landed) * density * perBall
                let p = CGPoint(x: L.cx + (k - mean) * L.spacing, y: y)
                if i == 0 { curve.move(to: p) } else { curve.addLine(to: p) }
            }
            let alpha = min(1, Double(landed - 30) / 40)
            context.stroke(curve, with: .color(.white.opacity(0.85 * alpha)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 5]))
        }

        // Counter
        context.draw(Text("\(landed) balls")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(white: 0.7)),
                     at: CGPoint(x: w / 2, y: L.binBottom + 18))

        // Touch ring
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
}

#Preview {
    GaltonBoardView()
}
