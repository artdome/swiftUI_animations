# SwiftUI Animations 🎲🌪️

[![License: PolyForm Noncommercial 1.0.0](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-orange)](LICENSE.md) ![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue) ![SwiftUI](https://img.shields.io/badge/SwiftUI-Canvas-purple)

Satisfying animations made **100% in SwiftUI code**. No videos, no images, no 3D engine. Just `TimelineView`, `Canvas` and a bit of math.

Every animation here was shown in a TikTok video. Each one is a single Swift file: drop it into any iOS 17+ project and run it.

Made by the developer of **[Randomaker](https://apps.apple.com/lv/app/randomaker/id6811426551)**, 12 random generators in one iPhone app.

---

## Animations

| # | Animation | File | What it shows |
|---|-----------|------|---------------|
| 1 | 🌪️ **Rainbow Tornado** | [`RainbowTornado/RainbowTornadoView.swift`](RainbowTornado/RainbowTornadoView.swift) | 1,800 glowing particles in a swaying funnel, plus 3D dice tumbling around it |
| 2 | 🎲 **Dice Explosion** | [`DiceExplosion/DiceExplosionView.swift`](DiceExplosion/DiceExplosionView.swift) | 50 3D dice explode, bounce on a table, settle on a face and add up to a total |
| 3 | 📟 **Retro Displays** | [`RetroDisplays/RetroDisplaysView.swift`](RetroDisplays/RetroDisplaysView.swift) | Three monochrome screens that react to taps: a green pixel LCD that rolls a die, an amber LED board that picks a number, a green CRT terminal that runs a command on every tap. Swipe between them in `RetroDisplaysGallery` |
| 4 | ⛈️ **Storm Sky** | [`StormSky/StormSkyView.swift`](StormSky/StormSkyView.swift) | Grey thunderstorm with drifting clouds and rain. Tap anywhere and 1 to 3 random lightning bolts strike, light up the clouds and fade out |
| 5 | 🎃 **Haunted House** | [`HauntedHouse/HauntedHouseView.swift`](HauntedHouse/HauntedHouseView.swift) | Stormy night, full moon, bats and fog. Tap and a random window of the apartment block opens with one of 6 monsters inside (ghost, pumpkin, skull, horned shadow, zombie, black cat) |
| 6 | 📊 **Galton Board** | [`GaltonBoard/GaltonBoardView.swift`](GaltonBoard/GaltonBoardView.swift) | Tap to drop 150 balls through 12 rows of pegs. Every bounce is a random 50/50, yet the bins always fill into the same bell curve |

---

## How to run

1. Create a new iOS App project in Xcode (SwiftUI, iOS 17 or later).
2. Drag the `.swift` file into the project.
3. Make it the root view in your `App` file:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            DiceExplosionView()      // or RainbowTornadoView(), RetroDisplaysGallery(), StormSkyView(), HauntedHouseView(), GaltonBoardView()
        }
    }
}
```

4. Press **Cmd + R**.

> **Xcode preview:** switch the preview to **Live** mode (▶︎ under the canvas). In "Selectable" mode it shows a static frame.

---

## How it works

- **`TimelineView(.animation)`** redraws every frame (60–120 fps).
- **`Canvas`** draws thousands of shapes in one pass, which is much faster than one SwiftUI view per particle.
- **3D dice without a 3D engine:** each face is rotated in 3D, back faces are hidden, and the visible ones are mapped to the screen with a `CGAffineTransform`. Opposite faces add up to 7, like a real die.
- **Glow:** particles are drawn twice: once blurred and larger, once sharp, with `.plusLighter` blending.
- **Retro Displays:** a tiny framebuffer with a hand-made 5×7 pixel font; each pixel fades on and off with a short delay, like real LCD crystals and LEDs. The CRT adds scanlines, a rolling band, flicker and a vignette.
- **Lightning (Storm Sky):** each bolt is built with midpoint displacement: split the line, push the middle sideways, repeat, and sometimes fork. Every tap makes new bolts, so no two are the same.
- **Physics (Dice Explosion):** simple gravity, bounces with energy loss, table friction. Each die then rolls onto its nearest face, and the top face is the number it rolled.

Every file has its tunable numbers (speed, count, gravity, colors) at the top.

---

## Follow

- 📱 Randomaker on the App Store: https://apps.apple.com/lv/app/randomaker/id6811426551
- 🎬 TikTok: https://www.tiktok.com/@artdome.cc

New animations are added as new TikTok videos come out. ⭐ Star the repo to keep up!

## License

[PolyForm Noncommercial 1.0.0](LICENSE.md).

- ✅ Free for personal projects, learning, experiments and non-profit use. Fork it, change it, share it, but keep the license and the copyright notice.
- ❌ **Commercial use is not allowed**: no paid apps, client work or company products.

Want to use something from here in a commercial project? Contact me on GitHub ([@artdome](https://github.com/artdome)) and we can talk about a license.
