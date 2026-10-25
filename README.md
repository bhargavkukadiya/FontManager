<div align="center">

# FontManager.swift

### Production-ready typography management singleton for iOS & iPadOS

[![Swift](https://img.shields.io/badge/Swift-5.7%20%7C%206.0-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2014.0%2B%20%7C%20iPadOS%2014.0%2B-000000?style=flat-square&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-Compatible-brightgreen?style=flat-square&logo=swift&logoColor=white)](https://swift.org/package-manager/)
[![Concurrency](https://img.shields.io/badge/Swift%206%20Concurrency-Clean-success?style=flat-square)](https://developer.apple.com/documentation/swift/concurrency)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)

</div>

---

## 📖 Overview

Managing typography in large iOS applications often leads to fragmented point sizes, inconsistent letter-spacing, broken iPad layouts, and ignored Accessibility text settings.

**FontManager** is a lightweight, zero-dependency, thread-safe typography engine that unifies every font decision across **UIKit**, **SwiftUI**, and **AttributedStrings** behind a single semantic token system (`.title1`, `.body`, `.buttonPrimary`).

```swift
// UIKit
titleLabel.appFont(.largeTitle)
actionButton.appFont(.buttonPrimary)

// SwiftUI (follows Dynamic Type, includes letter-spacing tracking on iOS 14+)
Text("Welcome Back")
    .appFont(.largeTitle)
```

---

## ✨ Features

- 📱 **Universal Device Adaptation**: Tailored scale tables for iPhone and iPad canvas sizes, chosen by the idiom the app actually runs with (with a manual override).
- ♿ **Dynamic Type by Default**: Automatic `UIFontMetrics` scaling honoring user accessibility preferences in UIKit and SwiftUI, including SwiftUI environment overrides.
- ⚡ **Swift 6 Language Mode**: Built in Swift 6 mode on Swift 6 toolchains (Swift 5 mode on 5.7–5.10). Deadlock-free singleton (`@unchecked Sendable`) backed by an `NSLock` cache and `@MainActor`-isolated UI mutators.
- 🔤 **Custom & System Fonts**: Seamless switching between SF Pro and custom `.ttf`/`.otf` font families with graceful fallback and duplicate registration handling.
- 🎨 **Unified UIKit & SwiftUI**: Direct view extensions for `UILabel`, `UITextField` (text and placeholder), `UITextView`, and `UIButton` (including iOS 15+ `UIButton.Configuration`), plus appearance helpers for `UINavigationBar` and `UITabBar`. Bar helpers only change fonts and keep your colors and backgrounds.
- 🔠 **Letter-Spacing (Tracking) Support**: Tracking applied by SwiftUI `Text.appFont` (iOS 14+), `View.appFont` (iOS 16+), placeholders, `NSAttributedString`, and `AttributedString`. UIKit view helpers set the font only; use `attributedString(_:style:)` for tracked UIKit text.
- 🪶 **Zero Dependencies**: Pure Swift built entirely on Foundation, UIKit, SwiftUI, and CoreText.

---

## 📦 Installation

### Swift Package Manager (Recommended)

In Xcode, select **File › Add Package Dependencies...** and enter:

```
https://github.com/bhargavkukadiya/FontManager.git
```

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/bhargavkukadiya/FontManager.git", from: "2.0.0")
]
```

*(`from: "2.0.0"` accepts later 2.x releases; use `exact: "2.0.0"` for a fixed version or `branch: "main"` to follow development. The examples in this README match 2.0.0. See [Migrating from 1.x](#-migrating-from-1x) when upgrading from 1.0.0.)*

### Manual Drop-in

Drag and drop [`Sources/FontManager/FontManager.swift`](Sources/FontManager/FontManager.swift) directly into your Xcode project.

---

## 🚀 Quick Start

### 1. (Optional) Configure at Launch

Configure your custom font family or global preferences in your `AppDelegate` or SwiftUI `App`:

```swift
// AppDelegate.swift or @main App
func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) -> Bool {

    // Register custom fonts not listed under UIAppFonts in Info.plist
    // (skip if using system SF Pro or if the fonts are in Info.plist)
    FontManager.shared.registerFont(named: "Poppins-Regular")
    FontManager.shared.registerFont(named: "Poppins-SemiBold")
    FontManager.shared.registerFont(named: "Poppins-Bold")

    // Set active font source
    FontManager.shared.fontSource = .custom(familyName: "Poppins")

    // Optional: Disable Dynamic Type if fixed point sizes are required
    // FontManager.shared.respectsDynamicType = false

    // Optional: Force the iPhone (false) or iPad (true) scale table instead of auto-detection
    // FontManager.shared.isIPadOverride = false

    return true
}
```

### 2. Apply Across UIKit & SwiftUI

#### UIKit — Direct Extensions

```swift
// Labels & Text Fields
titleLabel.appFont(.largeTitle)
subtitleLabel.appFont(.title2)
bodyTextView.appFont(.body)
emailTextField.appFont(.textFieldText)

// Placeholders (set the placeholder text first; keeps its color)
emailTextField.placeholder = "Email"
emailTextField.appPlaceholderFont()

// Buttons (Supports modern UIButton.Configuration & legacy titleLabel)
submitButton.appFont(.buttonPrimary)

// Navigation & Tab Bars (fonts only; existing colors and backgrounds are kept)
FontManager.shared.apply(to: navigationController.navigationBar)
FontManager.shared.applyTabBarFont(to: tabBarController.tabBar)

// Or set the tab bar item font globally via the UITabBarItem appearance proxy
FontManager.shared.applyTabBarFont()
```

#### SwiftUI — Text & View Modifiers

```swift
// Text modifier: Applies both font and letter-spacing tracking (iOS 14+)
// and follows the environment's Dynamic Type size
Text("Welcome")
    .appFont(.largeTitle)

// General View modifier: Sets font environment (and tracking on iOS 16+)
VStack(alignment: .leading, spacing: 8) {
    Text("Header")
    Text("Supporting description copy")
}
.appFont(.body)

```

When you need a `Text` value (e.g. concatenation with `+`) or a raw `Font`, read the size category from the environment and pass it in:

```swift
struct Greeting: View {
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        VStack {
            // Keeps the `Text` type
            Text("Bold ").appFont(.headline, sizeCategory: sizeCategory) + Text("plain")

            // Direct SwiftUI Font
            Text("Direct query")
                .font(FontManager.shared.swiftUIFont(for: .headline, sizeCategory: sizeCategory))
        }
    }
}
```

`swiftUIFont(for:)` without a size category returns a fixed-size snapshot for the current trait collection, so it won't update when the text size changes. Prefer `.appFont(_:)` in views.

`Text.appFont(_:)` is `@MainActor`; call it from a SwiftUI view's `body` or another main-actor context. The explicit `appFont(_:sizeCategory:)` overload keeps the `Text` type and can also be used from a nonisolated helper.

#### AttributedString & Modern Swift Attributed Text

```swift
// Modern Swift AttributedString (iOS 15+), with SwiftUI and UIKit attributes
let modernAttr = FontManager.shared.swiftAttributedString("Styled Copy", style: .title1)

// Foundation NSAttributedString
let plainAttr = FontManager.shared.attributedString("Body Copy", style: .body)
let legacyAttr = FontManager.shared.attributedString(
    "Highlighted Copy",
    style: .headline,
    additionalAttributes: [.foregroundColor: UIColor.systemBlue]
)
```

---

## 📐 Typographic Scale Reference

Sizes shown are base point sizes (Dynamic Type "Large" category). Scalable tokens automatically expand and contract with the user's preferred content size.

| Style Token | iPhone (pt) | iPad (pt) | Weight | Scalable | Tracking | Typical Role |
|---|:---:|:---:|:---:|:---:|:---:|---|
| `.largeTitle` | 34 | 40 | Bold | ✓ | +0.37 | Hero titles, splash headlines |
| `.navigationTitle` | 17 | 18 | Semibold | — | -0.41 | Navigation bar title |
| `.pageHeader` | 28 | 34 | Bold | ✓ | +0.36 | Section / page headers |
| `.title1` | 28 | 34 | Bold | ✓ | +0.36 | Screen / primary card titles |
| `.title2` | 22 | 28 | Bold | ✓ | +0.35 | Sub-section headers |
| `.title3` | 20 | 24 | Semibold | ✓ | +0.38 | Grouping headers |
| `.headline` | 17 | 18 | Semibold | ✓ | -0.41 | Emphasized content |
| `.body` | 17 | 18 | Regular | ✓ | -0.41 | Default reading copy |
| `.callout` | 16 | 17 | Regular | ✓ | -0.32 | Pull quotes, callouts |
| `.subheadline` | 15 | 16 | Regular | ✓ | -0.24 | Secondary supporting text |
| `.footnote` | 13 | 14 | Regular | ✓ | -0.08 | Legal copy, footnotes |
| `.caption1` | 12 | 13 | Regular | ✓ | 0.00 | Timestamps, image captions |
| `.caption2` | 11 | 12 | Regular | ✓ | +0.07 | Micro-badges, smallest label |
| `.textFieldText` | 17 | 18 | Regular | ✓ | -0.41 | Text field input content |
| `.textFieldPlaceholder` | 17 | 18 | Regular | ✓ | -0.41 | Text field placeholder |
| `.buttonPrimary` | 17 | 18 | Semibold | ✓ | -0.41 | Primary action buttons |
| `.buttonSecondary` | 17 | 18 | Regular | ✓ | -0.41 | Secondary action buttons |
| `.buttonDestructive` | 17 | 18 | Regular | ✓ | -0.41 | Destructive / alert buttons |
| `.tabBarItem` | 10 | 11 | Medium | — | +0.12 | Tab bar item labels |
| `.badgeLabel` | 12 | 13 | Bold | — | 0.00 | Notification counter badges |
| `.tooltip` | 13 | 14 | Regular | — | -0.08 | Floating tooltips |

---

## 🔤 Custom Fonts Guide

To use custom fonts in your application:

1. **Add Font Files**: Add your `.ttf` or `.otf` files to your Xcode target.
2. **Register the fonts**, using **one** of these:
   - **Info.plist**: list the font filenames under `Fonts provided by application` (`UIAppFonts`). iOS registers them at launch.
   - **At runtime**: call `registerFont`, e.g. for fonts in a Swift package (`bundle: .module`):
     ```swift
     FontManager.shared.registerFont(named: "Inter-Regular", bundle: .module)
     FontManager.shared.registerFont(named: "Inter-SemiBold", bundle: .module)
     FontManager.shared.registerFont(named: "Inter-Bold", bundle: .module)
     ```
     Use `.module` inside the Swift package target that declares the font resources. For fonts in your app target, omit `bundle:` to use `.main`.
3. **Activate** the family:
   ```swift
   FontManager.shared.fontSource = .custom(familyName: "Inter")
   ```

FontManager picks the face closest to each style's weight from the registered family.

*If a custom font family is not registered or cannot be resolved, FontManager logs a non-fatal debug warning and gracefully falls back to the system font without crashing.*

---

## 🧵 Thread Safety & Concurrency

- **Lock-Protected Storage**: `FontManager` is an `@unchecked Sendable` singleton. State mutations (`cache`, `fontSource`, `respectsDynamicType`, `isIPadOverride`) are synchronised via `NSLock`.
- **Zero Deadlocks**: Device classification combines the hardware model (POSIX `utsname`) with the app's `UIDeviceFamily`, without dispatching synchronously to the main thread. iPhone-only apps on iPad get iPhone sizes; iPad-capable apps on Apple silicon Macs and Apple Vision Pro get iPad sizes. Set `isIPadOverride` to choose explicitly.
- **Atomic Cache Invalidation**: Changing configuration atomically clears the cache under lock, and font resolution verifies snapshot consistency before insertion. Fonts are cached per content size category, so a Dynamic Type change never returns a stale font.
- **MainActor Isolation**: All view mutators (`apply(_:to:)`, `UILabel.appFont`, etc.) are isolated to `@MainActor`.

---

## 🧪 Running Tests

The test suite validates concurrency safety, Dynamic Type scaling, device detection, custom font resolution and fallbacks, and UIKit/SwiftUI integrations. FontManager depends on UIKit, so tests run on an iOS simulator (`swift test` on macOS can't build it):

```bash
xcodebuild test -scheme FontManager -destination 'platform=iOS Simulator,name=iPhone 17'
```

Replace the simulator name with one from `xcrun simctl list devices available`, or open the package in Xcode and press `Cmd+U`.

---

## 🔁 Migrating from 1.x

- **`AttributedString`**: the iOS 15+ `attributedString(_:style:) -> AttributedString` overload is now `swiftAttributedString(_:style:)`. `attributedString(_:style:)` always returns `NSAttributedString`, so the call is no longer ambiguous and works on iOS 14.
- **`Text.appFont(_:)`** now returns `some View` so it can follow the environment's Dynamic Type size, and is `@MainActor`. Call it from `body` or another main-actor context. Where you need a `Text` (e.g. concatenation with `+`) or a nonisolated helper, use `appFont(_:sizeCategory:)`.
- **Bar helpers** no longer overwrite `compactAppearance` / `scrollEdgeAppearance` with the standard appearance, and only set fonts. `applyTabBarFont(to:)` with a tab bar no longer changes the global `UITabBarItem` appearance proxy. `applyTabBarFont()` without one now keeps existing proxy attributes such as colors.
- **iPad detection** now follows the idiom the app runs with: iPhone-only apps on iPad use the iPhone table, and iPad-capable apps on Apple silicon Macs and Apple Vision Pro use the iPad table. Set `isIPadOverride` to keep a specific table.
- **Manual drop-in**: the root `FontManager.swift` copy was removed. Use [`Sources/FontManager/FontManager.swift`](Sources/FontManager/FontManager.swift).

---

## 📄 License

FontManager is released under the **MIT License**. See [LICENSE](LICENSE) for details.

Copyright © 2026 [Bhargav Kukadiya](https://github.com/bhargavkukadiya).
