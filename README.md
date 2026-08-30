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

Managing typography in large iOS applications often leads to fragmented point sizes, inconsistent line heights, broken iPad layouts, and ignored Accessibility text settings.

**FontManager** is a lightweight, zero-dependency, thread-safe typography engine that unifies every font decision across **UIKit**, **SwiftUI**, and **AttributedStrings** behind a single semantic token system (`.title1`, `.body`, `.buttonPrimary`).

```swift
// UIKit
titleLabel.appFont(.largeTitle)
actionButton.appFont(.buttonPrimary)

// SwiftUI (includes native letter-spacing tracking on iOS 14+)
Text("Welcome Back")
    .appFont(.largeTitle)
```

---

## ✨ Features

- 📱 **Universal Device Adaptation**: Tailored scale tables for iPhone and iPad canvas sizes.
- ♿ **Dynamic Type by Default**: Automatic `UIFontMetrics` scaling honoring user accessibility preferences.
- ⚡ **Swift 6 Concurrency Certified**: Deadlock-free singleton (`@unchecked Sendable`) backed by an `NSLock` cache and `@MainActor`-isolated UI mutators.
- 🔤 **Custom & System Fonts**: Seamless switching between SF Pro and custom `.ttf`/`.otf` font families with graceful fallback and duplicate registration handling.
- 🎨 **Unified UIKit & SwiftUI**: Direct view extensions for `UILabel`, `UITextField`, `UITextView`, `UIButton` (including iOS 15+ `UIButton.Configuration`), `UINavigationBarAppearance`, and `UITabBarAppearance`.
- 🔠 **Letter-Spacing (Tracking) Support**: Native tracking applied to UIKit, SwiftUI `Text`, and `AttributedString`.
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
    .package(url: "https://github.com/bhargavkukadiya/FontManager.git", branch: "main")
]
```

*(Or specify a release tag like `from: "1.0.0"` once tagged).*

### Manual Drop-in

Drag and drop `FontManager.swift` directly into your Xcode project.

---

## 🚀 Quick Start

### 1. (Optional) Configure at Launch

Configure your custom font family or global preferences in your `AppDelegate` or SwiftUI `App`:

```swift
// AppDelegate.swift or @main App
func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) -> Bool {

    // Register custom fonts (skip if using system SF Pro)
    FontManager.shared.registerFont(named: "Poppins-Regular")
    FontManager.shared.registerFont(named: "Poppins-SemiBold")
    FontManager.shared.registerFont(named: "Poppins-Bold")

    // Set active font source
    FontManager.shared.fontSource = .custom(familyName: "Poppins")

    // Optional: Disable Dynamic Type if fixed point sizes are required
    // FontManager.shared.respectsDynamicType = false

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

// Buttons (Supports modern UIButton.Configuration & legacy titleLabel)
submitButton.appFont(.buttonPrimary)

// Navigation & Tab Bars
FontManager.shared.apply(to: navigationController.navigationBar)
FontManager.shared.applyTabBarFont(to: tabBarController.tabBar)
```

#### SwiftUI — Text & View Modifiers

```swift
// Text modifier: Applies both font and letter-spacing tracking (iOS 14+)
Text("Welcome")
    .appFont(.largeTitle)

// General View modifier: Sets font environment (and tracking on iOS 16+)
VStack(alignment: .leading, spacing: 8) {
    Text("Header")
    Text("Supporting description copy")
}
.appFont(.body)

// Direct SwiftUI Font
Text("Direct query")
    .font(FontManager.shared.swiftUIFont(for: .headline))
```

#### AttributedString & Modern Swift Attributed Text

```swift
// Modern Swift AttributedString (iOS 15+)
let modernAttr = FontManager.shared.attributedString("Styled Copy", style: .title1)

// Foundation NSAttributedString
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
2. **Update Info.plist**: Add font filenames under the `Fonts provided by application` (`UIAppFonts`) key.
3. **Register & Activate**:
   ```swift
   FontManager.shared.registerFont(named: "Inter-Regular")
   FontManager.shared.registerFont(named: "Inter-SemiBold")
   FontManager.shared.registerFont(named: "Inter-Bold")

   FontManager.shared.fontSource = .custom(familyName: "Inter")
   ```

*If a custom font family is not registered or cannot be resolved, FontManager logs a non-fatal debug warning and gracefully falls back to the system font without crashing.*

---

## 🧵 Thread Safety & Concurrency

- **Lock-Protected Storage**: `FontManager` is an `@unchecked Sendable` singleton. State mutations (`cache`, `fontSource`, `respectsDynamicType`) are synchronised via `NSLock`.
- **Zero Deadlocks**: Device classification operates on non-blocking POSIX `utsname` and `ProcessInfo` inspection without dispatching synchronously to the main thread.
- **Atomic Cache Invalidation**: Changing configuration atomically clears the cache under lock, and font resolution verifies snapshot consistency before insertion.
- **MainActor Isolation**: All view mutators (`apply(_:to:)`, `UILabel.appFont`, etc.) are isolated to `@MainActor`.

---

## 🧪 Running Tests

The test suite validates concurrency safety, Dynamic Type scaling, custom font fallbacks, and UIKit/SwiftUI integrations:

```bash
swift test
```

Or open in Xcode and press `Cmd+U`.

---

## 📄 License

FontManager is released under the **MIT License**. See [LICENSE](LICENSE) for details.

Copyright © 2026 [Bhargav Kukadia](https://github.com/bhargavkukadiya).
