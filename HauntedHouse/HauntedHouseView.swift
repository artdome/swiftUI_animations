//
//  HauntedHouseView.swift
//  Haunted apartment block on a stormy night. Tap and a random window opens with a monster inside.
//  SwiftUI Canvas, iOS 17+
//
//  Copyright (c) 2026 Arturs (https://github.com/artdome)
//  SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//  Free for non-commercial use. Commercial use is not allowed. See LICENSE.md.
//
//  • Night sky, full moon behind drifting clouds, bats, silent heat lightning, fog, a dead tree.
//  • 24 windows with closed shutters. Some leak a flickering light through the gap.
//  • Tap: a random window lights up red, the shutters fly open and one of 6 monsters
//    rises from below (ghost, pumpkin, skull, horned shadow, zombie, black cat),
//    blinks, hides again and the shutters close. Sometimes lightning strikes too.
//  • All monsters are drawn with code, no images.
//
//  How to run:
//  • Make it the root view in your App file:
//        WindowGroup { HauntedHouseView() }
//    then Cmd+R and tap.
//  • Xcode preview: switch the preview to LIVE mode (▶︎), not "Selectable".
//

import SwiftUI

struct HauntedHouseView: View {
    /// Show a ring where the finger touched (handy for screen recordings).
    var showTouches = true

    private static let cols = 4, rows = 6
    private static let openDuration = 3.4
    private static let monsterCount = 6

    private struct Opening {
        let window: Int
        let monster: Int
        let start: Date
    }

    @State private var openings: [Opening] = []
    @State private var bolt: HauntBolt?
    @State private var scares = 0
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
                scare(at: location, size: geo.size)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: scares)
    }

    // MARK: - Tap

    private func scare(at point: CGPoint, size: CGSize) {
        let now = Date()
        touch = (point, now)
        openings.removeAll { now.timeIntervalSince($0.start) > Self.openDuration }

        let busy = Set(openings.map(\.window))
        let free = (0..<(Self.cols * Self.rows)).filter { !busy.contains($0) }
        guard let window = free.randomElement() else { return }

        var monster = Int.random(in: 0..<Self.monsterCount)
        if monster == openings.last?.monster { monster = (monster + 1) % Self.monsterCount }   // no repeats in a row
        openings.append(Opening(window: window, monster: monster, start: now))

        if Double.random(in: 0...1) < 0.4 {
            bolt = HauntBolt.make(in: size, start: now.addingTimeInterval(0.25))
        }
        scares += 1
    }

    // MARK: - Layout

    private static func buildingRect(w: Double, h: Double) -> CGRect {
        let bw = w * 0.88
        return CGRect(x: (w - bw) / 2, y: h * 0.27, width: bw, height: h * 0.61)
    }

    private static func windowRect(_ i: Int, w: Double, h: Double) -> CGRect {
        let b = buildingRect(w: w, h: h)
        let top = Double(b.minY) + h * 0.03, bottom = h * 0.80
        let cellW = Double(b.width) / Double(cols), cellH = (bottom - top) / Double(rows)
        let ww = cellW * 0.6, wh = min(cellH * 0.76, ww * 1.4)
        let col = i % cols, row = i / cols
        return CGRect(x: Double(b.minX) + cellW * (Double(col) + 0.5) - ww / 2,
                      y: top + cellH * (Double(row) + 0.5) - wh / 2,
                      width: ww, height: wh)
    }

    // MARK: - Drawing

    private func draw(_ context: GraphicsContext, size: CGSize, now: Date) {
        let w = Double(size.width), h = Double(size.height)
        let t = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000)

        // Light from lightning: a real bolt, or silent heat lightning every few seconds
        let boltLight = bolt?.brightness(at: now) ?? 0
        let phase = (t / 8.3).truncatingRemainder(dividingBy: 1)
        let heat = phase < 0.05 ? 0.25 * (0.5 + 0.5 * sin(phase * 400)) : 0
        let flash = min(1, max(boltLight, heat))

        // 1. Sky
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(
                        Gradient(colors: [Color(red: 0.04 + 0.3 * flash, green: 0.03 + 0.28 * flash, blue: 0.09 + 0.35 * flash),
                                          Color(red: 0.17 + 0.3 * flash, green: 0.10 + 0.28 * flash, blue: 0.22 + 0.35 * flash)]),
                        startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.9)))

        // 2. Moon
        let moon = CGPoint(x: w * 0.76, y: h * 0.13), mr = w * 0.09
        context.fill(Path(ellipseIn: CGRect(x: moon.x - mr * 3, y: moon.y - mr * 3, width: mr * 6, height: mr * 6)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.95, blue: 0.75).opacity(0.28), .clear]),
                                           center: moon, startRadius: mr * 0.8, endRadius: mr * 3))
        context.fill(Path(ellipseIn: CGRect(x: moon.x - mr, y: moon.y - mr, width: mr * 2, height: mr * 2)),
                     with: .color(Color(red: 0.96, green: 0.93, blue: 0.78)))
        for (dx, dy, r) in [(-0.35, -0.2, 0.22), (0.3, 0.25, 0.16), (0.05, 0.45, 0.12), (0.4, -0.35, 0.1)] {
            context.fill(Path(ellipseIn: CGRect(x: moon.x + dx * mr - r * mr, y: moon.y + dy * mr - r * mr,
                                                width: 2 * r * mr, height: 2 * r * mr)),
                         with: .color(Color(red: 0.86, green: 0.82, blue: 0.68)))
        }

        // 3. Clouds drifting over the moon
        context.drawLayer { clouds in
            clouds.addFilter(.blur(radius: 18))
            for c in Self.clouds {
                let speed = [6.0, 12.0, 20.0][c.layer]
                let span = w * 1.8
                let x = (c.x * span + t * speed).truncatingRemainder(dividingBy: span) - w * 0.4
                let y = c.y * h, cw = c.w * w, ch = c.h * h
                let dx = (x - moon.x) / (w * 0.3), dy = (y - moon.y) / (h * 0.12)
                let moonLit = 0.12 * exp(-(dx * dx + dy * dy))
                let s = c.shade + moonLit + 0.35 * flash
                clouds.fill(Path(ellipseIn: CGRect(x: x - cw / 2, y: y - ch / 2, width: cw, height: ch)),
                            with: .color(Color(red: s * 0.95, green: s * 0.88, blue: s * 1.15).opacity(0.92)))
            }
        }

        // 4. Lightning behind the building
        if let bolt, boltLight > 0.001 {
            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 9))
                glow.blendMode = .plusLighter
                for s in bolt.segments {
                    glow.stroke(s.path, with: .color(Color(red: 0.7, green: 0.6, blue: 1).opacity(0.8 * boltLight)),
                                style: StrokeStyle(lineWidth: s.width * 5, lineCap: .round))
                }
            }
            var core = context
            core.blendMode = .plusLighter
            for s in bolt.segments {
                core.stroke(s.path, with: .color(Color(red: 0.95, green: 0.93, blue: 1).opacity(boltLight)),
                            style: StrokeStyle(lineWidth: s.width, lineCap: .round, lineJoin: .round))
            }
        }

        // 5. Bats
        for (i, bat) in Self.bats.enumerated() {
            let u = ((t + bat.offset) / bat.period).truncatingRemainder(dividingBy: 1)
            let x = i % 2 == 0 ? -0.1 * w + u * 1.2 * w : 1.1 * w - u * 1.2 * w
            let y = bat.y * h + sin(u * .pi * 4) * h * 0.03
            drawBat(context, at: CGPoint(x: x, y: y), size: bat.size, flap: sin(t * 14 + bat.offset), flip: i % 2 == 1)
        }

        // 6. Building
        let b = Self.buildingRect(w: w, h: h)
        let wall = Color(red: 0.11 + 0.22 * flash, green: 0.09 + 0.2 * flash, blue: 0.13 + 0.25 * flash)
        // roof details: water tank and a crooked antenna
        let tank = CGRect(x: b.minX + b.width * 0.15, y: b.minY - h * 0.05, width: b.width * 0.18, height: h * 0.05)
        context.fill(Path(tank), with: .color(wall))
        var cone = Path()
        cone.move(to: CGPoint(x: tank.minX - 4, y: tank.minY))
        cone.addLine(to: CGPoint(x: tank.midX, y: tank.minY - h * 0.025))
        cone.addLine(to: CGPoint(x: tank.maxX + 4, y: tank.minY))
        cone.closeSubpath()
        context.fill(cone, with: .color(wall))
        var antenna = Path()
        antenna.move(to: CGPoint(x: b.maxX - b.width * 0.2, y: b.minY))
        antenna.addLine(to: CGPoint(x: b.maxX - b.width * 0.17, y: b.minY - h * 0.09))
        antenna.move(to: CGPoint(x: b.maxX - b.width * 0.24, y: b.minY - h * 0.06))
        antenna.addLine(to: CGPoint(x: b.maxX - b.width * 0.12, y: b.minY - h * 0.075))
        antenna.move(to: CGPoint(x: b.maxX - b.width * 0.225, y: b.minY - h * 0.035))
        antenna.addLine(to: CGPoint(x: b.maxX - b.width * 0.14, y: b.minY - h * 0.045))
        context.stroke(antenna, with: .color(wall), lineWidth: 2.5)
        // body + parapet + rim light from the moon
        context.fill(Path(b), with: .color(wall))
        context.fill(Path(CGRect(x: b.minX - 6, y: b.minY - 6, width: b.width + 12, height: 10)), with: .color(wall))
        context.fill(Path(CGRect(x: b.maxX - 3, y: b.minY, width: 3, height: b.height)),
                     with: .color(Color(red: 0.5, green: 0.45, blue: 0.6).opacity(0.35 + 0.4 * flash)))
        // floor lines
        for r in 1..<Self.rows {
            let y = Double(Self.windowRect(r * Self.cols, w: w, h: h).minY) - h * 0.012
            context.fill(Path(CGRect(x: b.minX, y: y, width: b.width, height: 1.5)), with: .color(.black.opacity(0.35)))
        }

        // 7. Windows
        for i in 0..<(Self.cols * Self.rows) {
            let opening = openings.last { $0.window == i && now.timeIntervalSince($0.start) < Self.openDuration }
            drawWindow(context, rect: Self.windowRect(i, w: w, h: h), index: i, opening: opening, now: now, t: t, flash: flash)
        }

        // 8. Door
        let door = CGRect(x: b.midX - b.width * 0.07, y: h * 0.815, width: b.width * 0.14, height: Double(b.maxY) - h * 0.815)
        context.fill(Path(roundedRect: door, cornerRadius: 4), with: .color(Color(red: 0.12, green: 0.07, blue: 0.05)))
        context.fill(Path(ellipseIn: CGRect(x: door.maxX - 9, y: door.midY, width: 4, height: 4)),
                     with: .color(Color(red: 0.6, green: 0.5, blue: 0.3)))

        // 9. Dead tree
        for s in Self.tree {
            context.stroke(Path { p in
                p.move(to: CGPoint(x: s.x1 * w, y: s.y1 * h))
                p.addLine(to: CGPoint(x: s.x2 * w, y: s.y2 * h))
            }, with: .color(Color(white: 0.02 + 0.1 * flash)), style: StrokeStyle(lineWidth: s.width, lineCap: .round))
        }

        // 10. Ground + fog
        context.fill(Path(CGRect(x: 0, y: h * 0.875, width: w, height: h * 0.125)),
                     with: .color(Color(red: 0.03 + 0.1 * flash, green: 0.03 + 0.1 * flash, blue: 0.05 + 0.12 * flash)))
        context.drawLayer { fog in
            fog.addFilter(.blur(radius: 20))
            for (i, f) in Self.fog.enumerated() {
                let x = (f.x * w * 1.6 + t * (8 + Double(i % 3) * 5)).truncatingRemainder(dividingBy: w * 1.6) - w * 0.3
                fog.fill(Path(ellipseIn: CGRect(x: x - w * 0.45, y: f.y * h, width: w * 0.9, height: h * 0.06)),
                         with: .color(Color(red: 0.75, green: 0.7, blue: 0.85).opacity(0.08)))
            }
        }

        // 11. Flash over everything
        if flash > 0.01 {
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(red: 0.85, green: 0.8, blue: 1).opacity(0.18 * flash)))
        }

        // 12. Touch ring
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

    // MARK: - Window

    private func drawWindow(_ context: GraphicsContext, rect: CGRect, index: Int, opening: Opening?,
                            now: Date, t: Double, flash: Double) {
        // Frame
        context.fill(Path(rect.insetBy(dx: -4, dy: -4)), with: .color(Color(red: 0.03, green: 0.02, blue: 0.04)))

        var openAmount = 0.0, light = 0.0, rise = 0.0, age = 0.0
        if let opening {
            age = now.timeIntervalSince(opening.start)
            light = smooth(age / 0.15) * (1 - smooth((age - 2.9) / 0.4))
            openAmount = overshoot((age - 0.05) / 0.35) * (1 - smooth((age - 2.85) / 0.35))
            rise = overshoot((age - 0.3) / 0.45) * (1 - smooth((age - 2.5) / 0.4))
        }

        // Room behind the glass: dark, or glowing red when something is home
        context.fill(Path(rect), with: .color(Color(red: 0.03, green: 0.03, blue: 0.06)))
        if light > 0 {
            context.fill(Path(rect), with: .radialGradient(
                Gradient(colors: [Color(red: 1, green: 0.35, blue: 0.1).opacity(light),
                                  Color(red: 0.45, green: 0.05, blue: 0.05).opacity(light)]),
                center: CGPoint(x: rect.midX, y: rect.maxY), startRadius: 0, endRadius: rect.height * 1.1))
        }

        // Monster
        if let opening, rise > 0.001 {
            var inside = context
            inside.clip(to: Path(rect))
            let blink = (age > 1.5 && age < 1.62) || (age > 2.2 && age < 2.3)
            drawMonster(inside, type: opening.monster, rect: rect, rise: rise, blink: blink,
                        bob: sin(age * 3) * Double(rect.width) * 0.02)
        }

        // Shutters (hinged at the sides)
        let half = Double(rect.width) / 2
        let shutterW = half * (1 - 0.88 * openAmount)
        let wood = Color(red: 0.2 - 0.08 * openAmount + 0.15 * flash, green: 0.12 - 0.05 * openAmount + 0.12 * flash,
                         blue: 0.08 - 0.03 * openAmount + 0.12 * flash)
        for side in 0..<2 {
            let x = side == 0 ? Double(rect.minX) : Double(rect.maxX) - shutterW
            let r = CGRect(x: x, y: rect.minY, width: shutterW, height: rect.height)
            context.fill(Path(r), with: .color(wood))
            var slats = Path()
            var y = Double(rect.minY) + 5
            while y < Double(rect.maxY) - 2 {
                slats.addRect(CGRect(x: x + 2, y: y, width: max(0, shutterW - 4), height: 1.2))
                y += 5
            }
            context.fill(slats, with: .color(.black.opacity(0.35)))
        }

        // A thin flickering light leaking between closed shutters in some windows
        if Self.leaky.contains(index) && openAmount < 0.05 {
            let f = 0.55 + 0.45 * sin(t * 9 + Double(index)) * sin(t * 2.3 + Double(index) * 0.7)
            context.fill(Path(CGRect(x: rect.midX - 1, y: rect.minY + 2, width: 2, height: rect.height - 4)),
                         with: .color(Color(red: 1, green: 0.75, blue: 0.35).opacity(0.85 * max(0, f))))
            context.fill(Path(ellipseIn: rect.insetBy(dx: -6, dy: -6)),
                         with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.7, blue: 0.3).opacity(0.18 * max(0, f)), .clear]),
                                               center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0,
                                               endRadius: rect.height * 0.7))
        }

        // Sill
        context.fill(Path(CGRect(x: rect.minX - 6, y: rect.maxY + 3, width: rect.width + 12, height: 4)),
                     with: .color(Color(red: 0.13 + 0.15 * flash, green: 0.11 + 0.13 * flash, blue: 0.14 + 0.15 * flash)))
    }

    // MARK: - Monsters

    private func drawMonster(_ ctx: GraphicsContext, type: Int, rect: CGRect, rise: Double, blink: Bool, bob: Double) {
        let s = Double(rect.width)
        let cx = Double(rect.midX)
        let base = Double(rect.maxY) + (1 - rise) * Double(rect.height) * 1.1
        let cy = base - s * 0.62 + bob                  // head centre
        let eyeH = blink ? 0.12 : 1.0

        func ellipse(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double) -> Path {
            Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: 2 * rx, height: 2 * ry))
        }
        func glowEyes(_ points: [(Double, Double)], _ r: Double, _ color: Color) {
            ctx.drawLayer { g in
                g.addFilter(.blur(radius: r * 1.6))
                for (x, y) in points { g.fill(ellipse(x, y, r * 2, r * 2 * eyeH), with: .color(color.opacity(0.9))) }
            }
            for (x, y) in points { ctx.fill(ellipse(x, y, r, r * eyeH), with: .color(color)) }
        }

        switch type {
        case 0: // Ghost
            let r = s * 0.36
            ctx.fill(Path(roundedRect: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: base - cy + r + 20), cornerRadius: r),
                     with: .color(Color(red: 0.95, green: 0.95, blue: 1).opacity(0.95)))
            ctx.fill(ellipse(cx - s * 0.13, cy - s * 0.04, s * 0.07, s * 0.11 * eyeH), with: .color(.black))
            ctx.fill(ellipse(cx + s * 0.13, cy - s * 0.04, s * 0.07, s * 0.11 * eyeH), with: .color(.black))
            ctx.fill(ellipse(cx, cy + s * 0.17, s * 0.07, s * 0.1), with: .color(.black))

        case 1: // Pumpkin
            let pumpkin = Color(red: 0.95, green: 0.48, blue: 0.08)
            ctx.fill(Path(CGRect(x: cx - s * 0.04, y: cy - s * 0.4, width: s * 0.08, height: s * 0.12)),
                     with: .color(Color(red: 0.25, green: 0.4, blue: 0.12)))
            ctx.fill(ellipse(cx, cy, s * 0.42, s * 0.32), with: .color(pumpkin))
            for dx in [-0.18, 0.18] {
                ctx.stroke(ellipse(cx + dx * s, cy, s * 0.16, s * 0.31), with: .color(.black.opacity(0.25)), lineWidth: 1.5)
            }
            let fire = Color(red: 1, green: 0.85, blue: 0.3)
            let eye = { (x: Double) -> Path in
                var p = Path()
                p.move(to: CGPoint(x: x - s * 0.08, y: cy - s * 0.02))
                p.addLine(to: CGPoint(x: x, y: cy - s * 0.02 - s * 0.13 * eyeH))
                p.addLine(to: CGPoint(x: x + s * 0.08, y: cy - s * 0.02))
                p.closeSubpath()
                return p
            }
            ctx.fill(eye(cx - s * 0.15), with: .color(fire))
            ctx.fill(eye(cx + s * 0.15), with: .color(fire))
            var mouth = Path()
            let mw = s * 0.26, my = cy + s * 0.12
            mouth.move(to: CGPoint(x: cx - mw, y: my))
            for k in 0...6 {
                let x = cx - mw + Double(k) * mw / 3
                mouth.addLine(to: CGPoint(x: x, y: my + (k % 2 == 0 ? 0 : s * 0.05)))
            }
            mouth.addLine(to: CGPoint(x: cx + mw * 0.7, y: my + s * 0.1))
            mouth.addLine(to: CGPoint(x: cx - mw * 0.7, y: my + s * 0.1))
            mouth.closeSubpath()
            ctx.fill(mouth, with: .color(fire))

        case 2: // Skull
            let bone = Color(red: 0.92, green: 0.9, blue: 0.82)
            ctx.fill(ellipse(cx, cy - s * 0.03, s * 0.33, s * 0.31), with: .color(bone))
            ctx.fill(Path(roundedRect: CGRect(x: cx - s * 0.2, y: cy + s * 0.12, width: s * 0.4, height: s * 0.2),
                          cornerRadius: s * 0.05), with: .color(bone))
            ctx.fill(ellipse(cx - s * 0.12, cy, s * 0.09, s * 0.1), with: .color(.black))
            ctx.fill(ellipse(cx + s * 0.12, cy, s * 0.09, s * 0.1), with: .color(.black))
            if !blink { glowEyes([(cx - s * 0.12, cy), (cx + s * 0.12, cy)], s * 0.025, Color(red: 1, green: 0.15, blue: 0.1)) }
            var nose = Path()
            nose.move(to: CGPoint(x: cx - s * 0.04, y: cy + s * 0.08))
            nose.addLine(to: CGPoint(x: cx + s * 0.04, y: cy + s * 0.08))
            nose.addLine(to: CGPoint(x: cx, y: cy + s * 0.15))
            nose.closeSubpath()
            ctx.fill(nose, with: .color(.black))
            for k in -2...2 {
                let x = cx + Double(k) * s * 0.06
                ctx.fill(Path(CGRect(x: x - 0.75, y: cy + s * 0.2, width: 1.5, height: s * 0.1)), with: .color(.black.opacity(0.6)))
            }

        case 3: // Horned shadow with a grin
            let dark = Color(red: 0.02, green: 0.01, blue: 0.03)
            for side in [-1.0, 1.0] {
                var horn = Path()
                horn.move(to: CGPoint(x: cx + side * s * 0.12, y: cy - s * 0.25))
                horn.addLine(to: CGPoint(x: cx + side * s * 0.36, y: cy - s * 0.52))
                horn.addLine(to: CGPoint(x: cx + side * s * 0.27, y: cy - s * 0.15))
                horn.closeSubpath()
                ctx.fill(horn, with: .color(dark))
            }
            ctx.fill(Path(roundedRect: CGRect(x: cx - s * 0.34, y: cy - s * 0.32, width: s * 0.68, height: base - cy + s * 0.4),
                          cornerRadius: s * 0.3), with: .color(dark))
            glowEyes([(cx - s * 0.13, cy - s * 0.04), (cx + s * 0.13, cy - s * 0.04)], s * 0.045, Color(red: 1, green: 0.1, blue: 0.05))
            var teeth = Path()
            let tw = s * 0.2, ty = cy + s * 0.14
            teeth.move(to: CGPoint(x: cx - tw, y: ty))
            for k in 0...8 {
                let x = cx - tw + Double(k) * tw / 4
                teeth.addLine(to: CGPoint(x: x, y: ty + (k % 2 == 0 ? 0 : s * 0.06)))
            }
            teeth.addLine(to: CGPoint(x: cx + tw, y: ty + s * 0.02))
            teeth.addQuadCurve(to: CGPoint(x: cx - tw, y: ty + s * 0.02), control: CGPoint(x: cx, y: ty + s * 0.14))
            teeth.closeSubpath()
            ctx.fill(teeth, with: .color(Color(white: 0.92)))

        case 4: // Zombie
            let skin = Color(red: 0.45, green: 0.58, blue: 0.42)
            ctx.fill(Path(roundedRect: CGRect(x: cx - s * 0.3, y: cy - s * 0.32, width: s * 0.6, height: base - cy + s * 0.4),
                          cornerRadius: s * 0.18), with: .color(skin))
            var hair = Path()
            hair.move(to: CGPoint(x: cx - s * 0.32, y: cy - s * 0.12))
            for k in 0...8 {
                let x = cx - s * 0.32 + Double(k) * s * 0.08
                hair.addLine(to: CGPoint(x: x, y: cy - s * (k % 2 == 0 ? 0.36 : 0.26)))
            }
            hair.addLine(to: CGPoint(x: cx + s * 0.32, y: cy - s * 0.12))
            hair.closeSubpath()
            ctx.fill(hair, with: .color(Color(red: 0.1, green: 0.08, blue: 0.06)))
            ctx.fill(ellipse(cx - s * 0.12, cy - s * 0.02, s * 0.08, s * 0.08 * eyeH), with: .color(Color(red: 0.95, green: 0.95, blue: 0.7)))
            ctx.fill(ellipse(cx + s * 0.13, cy + s * 0.01, s * 0.055, s * 0.05 * eyeH), with: .color(Color(red: 0.95, green: 0.95, blue: 0.7)))
            if !blink {
                ctx.fill(ellipse(cx - s * 0.11, cy - s * 0.01, s * 0.025, s * 0.025), with: .color(.black))
                ctx.fill(ellipse(cx + s * 0.14, cy + s * 0.02, s * 0.018, s * 0.018), with: .color(.black))
            }
            var mouth = Path()
            mouth.move(to: CGPoint(x: cx - s * 0.15, y: cy + s * 0.17))
            mouth.addLine(to: CGPoint(x: cx + s * 0.15, y: cy + s * 0.15))
            for k in -2...2 {
                let x = cx + Double(k) * s * 0.06
                mouth.move(to: CGPoint(x: x, y: cy + s * 0.12))
                mouth.addLine(to: CGPoint(x: x, y: cy + s * 0.2))
            }
            mouth.move(to: CGPoint(x: cx + s * 0.05, y: cy - s * 0.22))
            mouth.addLine(to: CGPoint(x: cx + s * 0.2, y: cy - s * 0.12))
            ctx.stroke(mouth, with: .color(Color(red: 0.3, green: 0.08, blue: 0.08)), lineWidth: 1.6)

        default: // Black cat
            let fur = Color(red: 0.02, green: 0.02, blue: 0.03)
            for side in [-1.0, 1.0] {
                var ear = Path()
                ear.move(to: CGPoint(x: cx + side * s * 0.08, y: cy - s * 0.15))
                ear.addLine(to: CGPoint(x: cx + side * s * 0.28, y: cy - s * 0.36))
                ear.addLine(to: CGPoint(x: cx + side * s * 0.3, y: cy - s * 0.05))
                ear.closeSubpath()
                ctx.fill(ear, with: .color(fur))
            }
            ctx.fill(ellipse(cx, cy + s * 0.04, s * 0.32, s * 0.27), with: .color(fur))
            ctx.fill(Path(CGRect(x: cx - s * 0.25, y: cy + s * 0.1, width: s * 0.5, height: base - cy)), with: .color(fur))
            glowEyes([(cx - s * 0.12, cy), (cx + s * 0.12, cy)], s * 0.055, Color(red: 0.75, green: 0.95, blue: 0.2))
            if !blink {
                ctx.fill(ellipse(cx - s * 0.12, cy, s * 0.012, s * 0.045), with: .color(.black))
                ctx.fill(ellipse(cx + s * 0.12, cy, s * 0.012, s * 0.045), with: .color(.black))
            }
        }
    }

    private func drawBat(_ context: GraphicsContext, at p: CGPoint, size: Double, flap: Double, flip: Bool) {
        var bat = Path()
        let f = 0.2 + 0.8 * (flap + 1) / 2              // wing angle
        for side in [-1.0, 1.0] {
            bat.move(to: CGPoint(x: 0, y: 0))
            bat.addLine(to: CGPoint(x: side * 0.4, y: -0.5 * f))
            bat.addLine(to: CGPoint(x: side * 1.0, y: -0.35 * f))
            bat.addLine(to: CGPoint(x: side * 0.8, y: 0.1))
            bat.addLine(to: CGPoint(x: side * 0.55, y: 0.0))
            bat.addLine(to: CGPoint(x: side * 0.35, y: 0.2))
            bat.closeSubpath()
        }
        bat.addEllipse(in: CGRect(x: -0.15, y: -0.2, width: 0.3, height: 0.45))
        let scale = CGAffineTransform(scaleX: flip ? -size : size, y: size)
            .concatenating(CGAffineTransform(translationX: p.x, y: p.y))
        context.fill(bat.applying(scale), with: .color(Color(red: 0.02, green: 0.01, blue: 0.03)))
    }

    // MARK: - Easing

    private func smooth(_ x: Double) -> Double {
        let p = min(1, max(0, x)); return p * p * (3 - 2 * p)
    }
    private func overshoot(_ x: Double) -> Double {
        let q = min(1, max(0, x)) - 1, s = 1.6
        return 1 + (s + 1) * q * q * q + s * q * q
    }

    // MARK: - Scenery (fixed, generated once)

    private struct Cloud { let x, y, w, h, shade: Double; let layer: Int }
    private struct Bat { let y, period, offset, size: Double }
    private struct Fog { let x, y: Double }
    private struct Branch { let x1, y1, x2, y2, width: Double }

    private static let clouds: [Cloud] = {
        var rng = HauntRNG(seed: 21)
        return (0..<34).map { i in
            Cloud(x: .random(in: 0..<1, using: &rng), y: .random(in: -0.02...0.26, using: &rng),
                  w: .random(in: 0.35...0.8, using: &rng), h: .random(in: 0.05...0.11, using: &rng),
                  shade: .random(in: 0.09...0.17, using: &rng), layer: i % 3)
        }
    }()

    private static let bats: [Bat] = {
        var rng = HauntRNG(seed: 3)
        return (0..<5).map { _ in
            Bat(y: .random(in: 0.08...0.26, using: &rng), period: .random(in: 7...12, using: &rng),
                offset: .random(in: 0...12, using: &rng), size: .random(in: 9...15, using: &rng))
        }
    }()

    private static let fog: [Fog] = {
        var rng = HauntRNG(seed: 8)
        return (0..<7).map { _ in Fog(x: .random(in: 0..<1, using: &rng), y: .random(in: 0.84...0.94, using: &rng)) }
    }()

    /// Windows that leak light between the shutters.
    private static let leaky: Set<Int> = {
        var rng = HauntRNG(seed: 13)
        return Set((0..<(HauntedHouseView.cols * HauntedHouseView.rows)).filter { _ in Double.random(in: 0...1, using: &rng) < 0.2 })
    }()

    /// A crooked dead tree on the left, built as a small recursive branch tree.
    private static let tree: [Branch] = {
        var rng = HauntRNG(seed: 4)
        var out: [Branch] = []
        func grow(_ x: Double, _ y: Double, _ angle: Double, _ length: Double, _ width: Double, _ depth: Int) {
            let x2 = x + cos(angle) * length * 0.55              // x is in width units, y in height units
            let y2 = y + sin(angle) * length
            out.append(Branch(x1: x, y1: y, x2: x2, y2: y2, width: width))
            guard depth > 0 else { return }
            for _ in 0..<2 {
                grow(x2, y2, angle + Double.random(in: -0.7...0.7, using: &rng),
                     length * Double.random(in: 0.6...0.78, using: &rng), width * 0.62, depth - 1)
            }
        }
        grow(0.04, 0.9, -Double.pi / 2 + 0.12, 0.13, 7, 5)
        return out
    }()
}

// MARK: - Lightning bolt

private struct HauntBolt {
    struct Segment {
        let path: Path
        let width: Double
    }

    let segments: [Segment]
    let start: Date

    func brightness(at now: Date) -> Double {
        let age = now.timeIntervalSince(start)
        guard age >= 0, age < 0.9 else { return 0 }
        return min(1, age / 0.03) * exp(-age * 4.5) * (age < 0.35 ? 0.6 + 0.4 * cos(age * 55) : 1)
    }

    static func make(in size: CGSize, start: Date) -> HauntBolt {
        let w = Double(size.width), h = Double(size.height)
        let top = CGPoint(x: Double.random(in: (w * 0.1)...(w * 0.9)), y: h * 0.02)
        let end = CGPoint(x: Double(top.x) + .random(in: -0.25...0.25) * w, y: h * .random(in: 0.3...0.42))
        var raw: [(CGPoint, CGPoint, Double)] = []
        subdivide(top, end, displace: h * 0.06, depth: 7, width: 3, branchChance: 0.35, into: &raw)
        let segments = raw.map { item -> Segment in
            var p = Path()
            p.move(to: item.0)
            p.addLine(to: item.1)
            return Segment(path: p, width: item.2)
        }
        return HauntBolt(segments: segments, start: start)
    }

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
        subdivide(a, mid, displace: displace / 2, depth: depth - 1, width: width, branchChance: branchChance, into: &out)
        subdivide(mid, b, displace: displace / 2, depth: depth - 1, width: width, branchChance: branchChance, into: &out)
        if depth >= 3, depth <= 6, Double.random(in: 0...1) < branchChance {
            let angle = atan2(Double(mid.y) - ay, Double(mid.x) - ax) + Double.random(in: 0.35...0.8) * (Bool.random() ? 1 : -1)
            let branchLength = len * Double.random(in: 0.5...0.9)
            let branchEnd = CGPoint(x: Double(mid.x) + cos(angle) * branchLength, y: Double(mid.y) + sin(angle) * branchLength)
            subdivide(mid, branchEnd, displace: displace / 2, depth: depth - 1, width: width * 0.5,
                      branchChance: branchChance * 0.6, into: &out)
        }
    }
}

// MARK: - Deterministic random generator (same scenery every launch)

private struct HauntRNG: RandomNumberGenerator {
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
    HauntedHouseView()
}
