//
//  RetroDisplaysView.swift
//  Three monochrome retro displays drawn with SwiftUI Canvas, driven by taps. iOS 17+
//
//  Copyright (c) 2026 Arturs (https://github.com/artdome)
//  SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//  Free for non-commercial use. Commercial use is not allowed. See LICENSE.md.
//
//  • RetroLCDView    : green pixel LCD. Tap to roll a pixel die.
//  • LEDBoardView    : amber dot-matrix LED board. Tap to pick a random number 1-100.
//  • CRTTerminalView : green phosphor terminal. Each tap runs the next Randomaker command.
//
//  Every tap shows a ring where the finger touched (handy for screen recordings,
//  where the finger itself is not visible) and gives a light haptic.
//  Set showTouches: false to hide the ring.
//
//  How to run:
//  • Make one of them (or the swipeable gallery) the root view in your App file:
//        WindowGroup { RetroDisplaysGallery() }
//    then Cmd+R.
//  • Xcode preview: switch the preview to LIVE mode (▶︎), not "Selectable".
//

import SwiftUI

// MARK: - Gallery (swipe between the three displays)

struct RetroDisplaysGallery: View {
    var showTouches = true

    var body: some View {
        TabView {
            RetroLCDView(showTouches: showTouches)
            LEDBoardView(showTouches: showTouches)
            CRTTerminalView(showTouches: showTouches)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
    }
}

// MARK: - 1. Green pixel LCD

struct RetroLCDView: View {
    var showTouches = true

    private static let cols = 84, rows = 48          // classic small-phone LCD resolution
    private static let rollTime = 2.2                // seconds the die tumbles

    // LCD palette
    private let glassLight = Color(red: 0.66, green: 0.75, blue: 0.20)
    private let glassDark  = Color(red: 0.54, green: 0.63, blue: 0.11)
    private let pixelOff   = Color(red: 0.50, green: 0.59, blue: 0.10)
    private let pixelOn    = Color(red: 0.09, green: 0.19, blue: 0.07)

    @State private var lcd = PixelPersistence()
    @State private var rollStart: Date?
    @State private var result = 6
    @State private var rolls = 0
    @State private var ripple: TapRipple?

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let elapsed = rollStart.map { now.timeIntervalSince($0) }
                let frame = Self.frame(elapsed: elapsed, result: result, clock: now.timeIntervalSinceReferenceDate)
                lcd.update(with: frame, date: now, response: 0.07)   // slow LCD pixels = motion blur
                draw(context, size: size)
                if showTouches, let ripple { drawRipple(ripple, in: context, now: now, color: .white) }
            }
        }
        .background(Color(white: 0.08))
        .ignoresSafeArea()
        .statusBarHidden()
        .contentShape(Rectangle())
        .onTapGesture { location in
            ripple = TapRipple(location: location, start: Date())
            if let s = rollStart, Date().timeIntervalSince(s) < Self.rollTime { return }   // still rolling
            result = Int.random(in: 1...6)
            rollStart = Date()
            rolls += 1
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: rolls)
    }

    /// What the LCD shows. elapsed = seconds since the last tap, nil before the first one.
    private static func frame(elapsed: Double?, result: Int, clock: Double) -> PixelBuffer {
        var b = PixelBuffer(width: cols, height: rows)
        b.centeredText("RANDOMAKER", y: 1)
        for x in 0..<cols where x % 2 == 0 { b.set(x, 10) }

        // Roll: faces change fast, then slower and slower (14 → 2 faces/s), ending on the result
        var face = result
        var lift = 0
        if let e = elapsed, e < rollTime {
            let p = e / rollTime
            let flips = Int(14 * e - 6 * e * p)
            let totalFlips = Int(8 * rollTime)
            face = (result - 1 + (totalFlips - flips)) % 6 + 1
            lift = Int((abs(sin(e * .pi * 3)) * 6 * (1 - p)).rounded())
        }
        drawDie(&b, face: face, cx: cols / 2, cy: 25 - lift)

        if let e = elapsed, e < rollTime {
            let dots = String(repeating: ".", count: Int(e * 4) % 4)
            b.text("ROLLING" + dots, x: (cols - PixelBuffer.textWidth("ROLLING...")) / 2, y: 40)
        } else if let e = elapsed, e < rollTime + 3.5 {
            let blinking = e < rollTime + 0.9 && Int((e - rollTime) * 6) % 2 == 1
            if !blinking { b.centeredText("YOU ROLLED \(result)", y: 40) }
        } else if Int(clock * 1.6) % 2 == 0 {
            b.centeredText("TAP TO ROLL", y: 40)
        }
        return b
    }

    private static func drawDie(_ b: inout PixelBuffer, face: Int, cx: Int, cy: Int) {
        let h = 10
        for i in (-h + 1)...(h - 1) {               // outline with rounded corners
            b.set(cx + i, cy - h); b.set(cx + i, cy + h)
            b.set(cx - h, cy + i); b.set(cx + h, cy + i)
        }
        for i in (-h + 2)...(h + 1) {               // 1-px drop shadow = a bit of depth
            b.set(cx + h + 1, cy + i); b.set(cx + i, cy + h + 1)
        }
        for (px, py) in pipLayout(face) {
            b.fillRect(x: cx + px * 5 - 1, y: cy + py * 5 - 1, w: 3, h: 3)
        }
    }

    private func draw(_ context: GraphicsContext, size: CGSize) {
        let cols = Self.cols, rows = Self.rows
        let w = Double(size.width), h = Double(size.height)
        let screenW = w * 0.86
        let p = screenW / Double(cols)
        let screenH = p * Double(rows)
        let sx = (w - screenW) / 2, sy = (h - screenH) / 2 - h * 0.03

        // Plastic body
        let shell = CGRect(x: sx - 24, y: sy - 40, width: screenW + 48, height: screenH + 100)
        context.fill(Path(roundedRect: shell, cornerRadius: 28),
                     with: .linearGradient(Gradient(colors: [Color(white: 0.34), Color(white: 0.19)]),
                                           startPoint: CGPoint(x: shell.minX, y: shell.minY),
                                           endPoint: CGPoint(x: shell.maxX, y: shell.maxY)))
        // LCD glass
        let glass = CGRect(x: sx - 8, y: sy - 8, width: screenW + 16, height: screenH + 16)
        context.fill(Path(roundedRect: glass, cornerRadius: 6),
                     with: .linearGradient(Gradient(colors: [glassLight, glassDark]),
                                           startPoint: CGPoint(x: glass.minX, y: glass.minY),
                                           endPoint: CGPoint(x: glass.maxX, y: glass.maxY)))

        // "Ghost" grid of all pixels
        let gap = p * 0.12
        var grid = Path()
        for y in 0..<rows {
            for x in 0..<cols {
                grid.addRect(CGRect(x: sx + Double(x) * p + gap / 2, y: sy + Double(y) * p + gap / 2,
                                    width: p - gap, height: p - gap))
            }
        }
        context.fill(grid, with: .color(pixelOff.opacity(0.55)))

        // Pixel shadows (LCD pixels float above the reflector), then the pixels themselves
        for pass in 0..<2 {
            for i in lcd.level.indices {
                let level = lcd.level[i]
                guard level > 0.02 else { continue }
                let x = Double(i % cols), y = Double(i / cols)
                let off = pass == 0 ? p * 0.22 : 0
                let rect = CGRect(x: sx + x * p + gap / 2 + off, y: sy + y * p + gap / 2 + off,
                                  width: p - gap, height: p - gap)
                context.fill(Path(rect),
                             with: .color(pixelOn.opacity(pass == 0 ? 0.22 * level : level)))
            }
        }

        context.draw(Text("RANDOMAKER  ·  MONOCHROME LCD")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(white: 0.62)),
                     at: CGPoint(x: w / 2, y: glass.maxY + 30))
    }
}

// MARK: - 2. Amber LED dot-matrix board

struct LEDBoardView: View {
    var showTouches = true

    private static let cols = 64, rows = 27
    private static let rollTime = 2.6
    private static let marquee = "RANDOMAKER * TAP FOR A RANDOM NUMBER * "

    private let ledOn  = Color(red: 1.00, green: 0.60, blue: 0.14)     // Randomaker orange
    private let ledHot = Color(red: 1.00, green: 0.85, blue: 0.55)
    private let ledOff = Color(red: 0.20, green: 0.09, blue: 0.03)

    @State private var leds = PixelPersistence()
    @State private var rollStart: Date?
    @State private var rollID = 0
    @State private var salt = UInt64.random(in: 0...UInt64.max)      // new numbers every launch
    @State private var ripple: TapRipple?

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let elapsed = rollStart.map { now.timeIntervalSince($0) }
                leds.update(with: Self.frame(clock: now.timeIntervalSinceReferenceDate, elapsed: elapsed,
                                             rollID: rollID, salt: salt),
                            date: now, response: 0.03)
                draw(context, size: size)
                if showTouches, let ripple { drawRipple(ripple, in: context, now: now, color: ledHot) }
            }
        }
        .background(Color(white: 0.03))
        .ignoresSafeArea()
        .statusBarHidden()
        .contentShape(Rectangle())
        .onTapGesture { location in
            ripple = TapRipple(location: location, start: Date())
            if let s = rollStart, Date().timeIntervalSince(s) < Self.rollTime { return }   // still rolling
            rollID += 1
            rollStart = Date()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: rollID)
    }

    private static func number(roll: Int, step: Int, salt: UInt64) -> Int {
        var rng = SeededRNG(seed: salt ^ (UInt64(roll) &* 0x9E3779B97F4A7C15 &+ UInt64(step) &* 0xBF58476D1CE4E5B9))
        return Int.random(in: 1...100, using: &rng)
    }

    private static func frame(clock: Double, elapsed: Double?, rollID: Int, salt: UInt64) -> PixelBuffer {
        var b = PixelBuffer(width: cols, height: rows)

        // Marquee on the top line
        let unit = PixelBuffer.textWidth(marquee) + 1
        let offset = Int(clock * 22) % unit
        var x = -offset
        while x < cols {
            b.text(marquee, x: x, y: 1)
            x += unit
        }
        for x in 0..<cols where x % 2 == 0 { b.set(x, 10) }

        guard let e = elapsed else {
            if Int(clock * 1.6) % 2 == 0 { b.centeredText("TAP", y: 12, scale: 2) }
            return b
        }

        // Rolling number: fast at first, slowing down (25 → 3 changes/s), then blinks on the result
        let steps = { (s: Double) in Int(25 * s - 11 * s * s / rollTime) }
        let value = number(roll: rollID, step: steps(min(e, rollTime)), salt: salt)
        let blinking = e > rollTime && e < rollTime + 1.2 && Int((e - rollTime) * 5) % 2 == 1
        if !blinking {
            b.centeredText("\(value)", y: 12, scale: 2)
        }
        return b
    }

    private func draw(_ context: GraphicsContext, size: CGSize) {
        let cols = Self.cols, rows = Self.rows
        let w = Double(size.width), h = Double(size.height)
        let pitch = w * 0.92 / Double(cols)
        let bw = pitch * Double(cols), bh = pitch * Double(rows)
        let bx = (w - bw) / 2, by = (h - bh) / 2
        let r = pitch * 0.36

        // Panel housing
        let housing = CGRect(x: bx - 14, y: by - 14, width: bw + 28, height: bh + 28)
        context.fill(Path(roundedRect: housing, cornerRadius: 12), with: .color(Color(white: 0.11)))
        context.stroke(Path(roundedRect: housing, cornerRadius: 12), with: .color(Color(white: 0.25)), lineWidth: 2)
        for (cx, cy) in [(housing.minX + 7, housing.minY + 7), (housing.maxX - 7, housing.minY + 7),
                         (housing.minX + 7, housing.maxY - 7), (housing.maxX - 7, housing.maxY - 7)] {
            context.fill(Path(ellipseIn: CGRect(x: cx - 2.5, y: cy - 2.5, width: 5, height: 5)),
                         with: .color(Color(white: 0.35)))                              // screws
        }

        func center(_ i: Int) -> CGPoint {
            CGPoint(x: bx + (Double(i % cols) + 0.5) * pitch, y: by + (Double(i / cols) + 0.5) * pitch)
        }

        // All LEDs, switched off
        var offPath = Path()
        for i in 0..<(cols * rows) {
            let c = center(i)
            offPath.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        }
        context.fill(offPath, with: .color(ledOff))

        // Glow behind lit LEDs
        context.drawLayer { glow in
            glow.addFilter(.blur(radius: pitch * 0.9))
            glow.blendMode = .plusLighter
            for i in leds.level.indices where leds.level[i] > 0.02 {
                let c = center(i), g = r * 1.8
                glow.fill(Path(ellipseIn: CGRect(x: c.x - g, y: c.y - g, width: 2 * g, height: 2 * g)),
                          with: .color(ledOn.opacity(0.55 * leds.level[i])))
            }
        }
        // Lit LEDs with a hot centre
        for i in leds.level.indices where leds.level[i] > 0.02 {
            let c = center(i), level = leds.level[i]
            context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(ledOn.opacity(level)))
            let hr = r * 0.5
            context.fill(Path(ellipseIn: CGRect(x: c.x - hr, y: c.y - hr, width: 2 * hr, height: 2 * hr)),
                         with: .color(ledHot.opacity(0.8 * level)))
        }
    }
}

// MARK: - 3. Green phosphor CRT terminal

struct CRTTerminalView: View {
    var showTouches = true

    private let phosphor = Color(red: 0.35, green: 1.0, blue: 0.45)
    private static let typeSpeed = 16.0              // characters per second
    private static let thinkTime = 0.35              // pause before the answer appears

    private struct Entry {
        let command: String
        let output: String
        let start: Date
    }

    @State private var entries: [Entry] = []
    @State private var nextCommand = 0
    @State private var ripple: TapRipple?

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                draw(context, size: size, now: timeline.date)
                if showTouches, let ripple { drawRipple(ripple, in: context, now: timeline.date, color: phosphor) }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .contentShape(Rectangle())
        .onTapGesture { location in
            ripple = TapRipple(location: location, start: Date())
            if let last = entries.last, Date().timeIntervalSince(last.start) < Self.busyTime(last) { return }
            entries.append(Self.makeEntry(nextCommand))
            nextCommand += 1
            if entries.count > 40 { entries.removeFirst(entries.count - 40) }
        }
        .sensoryFeedback(.selection, trigger: nextCommand)
    }

    private static func busyTime(_ e: Entry) -> Double {
        Double(e.command.count) / typeSpeed + thinkTime
    }

    /// The commands run in turn: dice, coin, number, password, and again with new values.
    private static func makeEntry(_ index: Int) -> Entry {
        switch index % 4 {
        case 0:
            let dice = (0..<3).map { _ in Int.random(in: 1...6) }
            return Entry(command: "> roll 3 dice",
                         output: "  " + dice.map { "[\($0)]" }.joined(separator: " ") + "  TOTAL \(dice.reduce(0, +))",
                         start: Date())
        case 1:
            return Entry(command: "> flip coin", output: "  " + (Bool.random() ? "HEADS" : "TAILS"), start: Date())
        case 2:
            return Entry(command: "> random 1-100", output: "  \(Int.random(in: 1...100))", start: Date())
        default:
            let chars = Array("abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789#$%&!?")
            return Entry(command: "> password 12", output: "  " + String((0..<12).map { _ in chars.randomElement()! }),
                         start: Date())
        }
    }

    /// Everything on screen right now, oldest line first.
    private func lines(now: Date) -> [String] {
        var out = ["RANDOMAKER OS v1.0", "READY.", "TAP TO RUN A COMMAND"]
        for e in entries {
            let elapsed = now.timeIntervalSince(e.start)
            let typing = Double(e.command.count) / Self.typeSpeed
            if elapsed < typing {
                out.append(String(e.command.prefix(Int(elapsed * Self.typeSpeed))))
                return out
            }
            out.append(e.command)
            if elapsed < typing + Self.thinkTime { return out }
            out.append(e.output)
        }
        out.append("> ")
        return out
    }

    private func draw(_ context: GraphicsContext, size: CGSize, now: Date) {
        let w = Double(size.width), h = Double(size.height)
        let t = now.timeIntervalSinceReferenceDate

        // Monitor body + screen
        let screen = CGRect(x: w * 0.06, y: h * 0.2, width: w * 0.88, height: h * 0.52)
        let shell = screen.insetBy(dx: -18, dy: -22)
        context.fill(Path(roundedRect: shell, cornerRadius: 30),
                     with: .linearGradient(Gradient(colors: [Color(red: 0.80, green: 0.77, blue: 0.69),
                                                            Color(red: 0.62, green: 0.59, blue: 0.52)]),
                                           startPoint: CGPoint(x: shell.minX, y: shell.minY),
                                           endPoint: CGPoint(x: shell.maxX, y: shell.maxY)))
        let screenPath = Path(roundedRect: screen, cornerRadius: 26)
        context.fill(screenPath, with: .radialGradient(
            Gradient(colors: [Color(red: 0.04, green: 0.12, blue: 0.06), Color(red: 0.01, green: 0.04, blue: 0.02)]),
            center: CGPoint(x: screen.midX, y: screen.midY), startRadius: 0, endRadius: screen.width * 0.7))

        var crt = context
        crt.clip(to: screenPath)

        let fontSize = screen.width / (26 * 0.62)
        let font = Font.system(size: fontSize, weight: .semibold, design: .monospaced)
        let charW = crt.resolve(Text("M").font(font)).measure(in: CGSize(width: 1000, height: 1000)).width
        let lineH = fontSize * 1.32
        let x0 = screen.minX + 18, y0 = screen.minY + 22

        // Keep only the lines that fit, like a real terminal scrolling up
        let maxLines = max(1, Int((screen.height - 40) / lineH))
        let visible = Array(lines(now: now).suffix(maxLines))

        let cursorOn = Int(t * 2.2) % 2 == 0
        func drawText(_ ctx: GraphicsContext, color: Color) {
            for (i, line) in visible.enumerated() {
                ctx.draw(Text(line).font(font).foregroundColor(color),
                         at: CGPoint(x: x0, y: y0 + Double(i) * lineH), anchor: .topLeading)
            }
            if cursorOn, let last = visible.last {
                let cx = x0 + Double(last.count) * charW
                let cy = y0 + Double(visible.count - 1) * lineH
                ctx.fill(Path(CGRect(x: cx, y: cy + lineH * 0.1, width: charW, height: lineH * 0.75)),
                         with: .color(color))
            }
        }

        // Phosphor glow, then sharp text
        crt.drawLayer { glow in
            glow.addFilter(.blur(radius: fontSize * 0.35))
            glow.blendMode = .plusLighter
            drawText(glow, color: phosphor.opacity(0.9))
        }
        drawText(crt, color: phosphor)

        // Scanlines
        var scan = Path()
        var y = screen.minY
        while y < screen.maxY {
            scan.addRect(CGRect(x: screen.minX, y: y, width: screen.width, height: 1.2))
            y += 3
        }
        crt.fill(scan, with: .color(.black.opacity(0.28)))

        // Slow rolling bright band
        let bandH = 140.0
        let bandY = screen.minY + (t * 70).truncatingRemainder(dividingBy: screen.height + bandH) - bandH
        crt.fill(Path(CGRect(x: screen.minX, y: bandY, width: screen.width, height: bandH)),
                 with: .linearGradient(Gradient(colors: [.clear, phosphor.opacity(0.06), .clear]),
                                       startPoint: CGPoint(x: 0, y: bandY), endPoint: CGPoint(x: 0, y: bandY + bandH)))

        // Flicker + vignette
        let flicker = 0.03 + 0.03 * sin(t * 57) * sin(t * 13)
        crt.fill(screenPath, with: .color(.black.opacity(max(0, flicker))))
        crt.fill(screenPath, with: .radialGradient(
            Gradient(colors: [.clear, .black.opacity(0.65)]),
            center: CGPoint(x: screen.midX, y: screen.midY),
            startRadius: screen.width * 0.35, endRadius: screen.width * 0.85))

        // Glass reflection
        crt.fill(Path(roundedRect: CGRect(x: screen.minX + 20, y: screen.minY + 12,
                                          width: screen.width * 0.55, height: screen.height * 0.18),
                      cornerRadius: 40),
                 with: .linearGradient(Gradient(colors: [.white.opacity(0.07), .clear]),
                                       startPoint: CGPoint(x: screen.minX, y: screen.minY),
                                       endPoint: CGPoint(x: screen.minX, y: screen.minY + screen.height * 0.18)))

        context.draw(Text("RANDOMAKER TERMINAL")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(red: 0.36, green: 0.34, blue: 0.30)),
                     at: CGPoint(x: w / 2, y: shell.maxY - 10))
    }
}

// MARK: - Tap ring (shows where the finger touched)

struct TapRipple {
    let location: CGPoint
    let start: Date
}

func drawRipple(_ ripple: TapRipple, in context: GraphicsContext, now: Date, color: Color) {
    let age = now.timeIntervalSince(ripple.start)
    guard age >= 0, age < 0.55 else { return }
    let p = age / 0.55
    let a = 1 - p
    let r = 26 + 46 * (1 - pow(1 - p, 3))
    let c = ripple.location
    context.fill(Path(ellipseIn: CGRect(x: c.x - 24, y: c.y - 24, width: 48, height: 48)),
                 with: .color(color.opacity(0.25 * a)))
    context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                   with: .color(color.opacity(0.8 * a)), lineWidth: 3)
}

// MARK: - Shared: pixel buffer, 5×7 font, LCD/LED persistence

/// A tiny monochrome framebuffer.
struct PixelBuffer {
    let width: Int, height: Int
    var on: [Bool]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        on = Array(repeating: false, count: width * height)
    }

    mutating func set(_ x: Int, _ y: Int, _ value: Bool = true) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        on[y * width + x] = value
    }

    mutating func fillRect(x: Int, y: Int, w: Int, h: Int) {
        guard w > 0, h > 0 else { return }
        for yy in y..<(y + h) { for xx in x..<(x + w) { set(xx, yy) } }
    }

    mutating func text(_ s: String, x: Int, y: Int, scale: Int = 1) {
        var cx = x
        for ch in s.uppercased() {
            if let bitmap = PixelFont.bitmap(ch) {
                for (ry, row) in bitmap.enumerated() {
                    for (rx, lit) in row.enumerated() where lit {
                        fillRect(x: cx + rx * scale, y: y + ry * scale, w: scale, h: scale)
                    }
                }
            }
            cx += (PixelFont.width + 1) * scale
        }
    }

    mutating func centeredText(_ s: String, y: Int, scale: Int = 1) {
        text(s, x: (width - Self.textWidth(s, scale: scale)) / 2, y: y, scale: scale)
    }

    static func textWidth(_ s: String, scale: Int = 1) -> Int {
        max(0, s.count * (PixelFont.width + 1) * scale - scale)
    }
}

/// Pixels that switch on and off with a short delay, like real LCD crystals or LEDs.
final class PixelPersistence {
    private(set) var level: [Double] = []
    private var last: Date?

    func update(with buffer: PixelBuffer, date: Date, response: Double) {
        if level.count != buffer.on.count { level = buffer.on.map { $0 ? 1 : 0 } }
        let dt = last.map { min(0.1, max(0, date.timeIntervalSince($0))) } ?? 0
        last = date
        let k = response > 0 ? 1 - exp(-dt / response) : 1
        for i in level.indices {
            level[i] += ((buffer.on[i] ? 1 : 0) - level[i]) * k
        }
    }
}

/// Classic 5×7 dot-matrix font.
enum PixelFont {
    static let width = 5, height = 7

    static func bitmap(_ c: Character) -> [[Bool]]? { bitmaps[c] }

    private static let bitmaps: [Character: [[Bool]]] = glyphs.mapValues { rows in
        rows.map { row in row.map { $0 == "#" } }
    }

    private static let glyphs: [Character: [String]] = [
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["###..", "#..#.", "#...#", "#...#", "#...#", "#..#.", "###.."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
        "-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
        ".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
        ":": [".....", ".##..", ".##..", ".....", ".##..", ".##..", "....."],
        "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
        "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
        "*": [".....", ".....", ".###.", ".###.", ".###.", ".....", "....."],
    ]
}

/// Pip positions on a die face, in units of -1 / 0 / 1.
private func pipLayout(_ face: Int) -> [(Int, Int)] {
    switch face {
    case 1: return [(0, 0)]
    case 2: return [(-1, -1), (1, 1)]
    case 3: return [(-1, -1), (0, 0), (1, 1)]
    case 4: return [(-1, -1), (1, -1), (-1, 1), (1, 1)]
    case 5: return [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)]
    default: return [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)]
    }
}

/// Deterministic random numbers, so every cycle shows new values.
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

#Preview("Gallery") { RetroDisplaysGallery() }
#Preview("LCD") { RetroLCDView() }
#Preview("LED board") { LEDBoardView() }
#Preview("CRT terminal") { CRTTerminalView() }
