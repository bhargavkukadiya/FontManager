# FontManager.swift

**Production-Ready iOS & iPadOS Font Management System**

| | |
|---|---|
| **Platform** | iOS 14.0+ · iPadOS 14.0+ (builds clean on iOS 26 SDK / Xcode 16+ / Xcode 26+) |
| **Language** | Swift 5.7+ · Swift 6 strict concurrency mode audited |
| **Xcode** | 14.0+ (verified against Xcode 26) |
| **Type** | Singleton — `final class`, `@unchecked Sendable` |
| **Fonts** | System (SF Pro) + custom TTF/OTF |
| **Accessibility** | Full Dynamic Type support |
| **SwiftUI** | Native `Font` + ViewModifier with letter-spacing tracking |
| **3rd Party** | None — zero dependencies |

---

## Overview

FontManager is a zero-dependency, thread-safe singleton that centralises every font decision in your iOS or iPadOS application. Instead of scattering point sizes and weights across view controllers, you reference a single semantic token — `.title1`, `.body`, `.buttonPrimary` — and FontManager resolves the correct `UIFont` or SwiftUI `Font` for the current device class.

**Key capabilities:**

- **Dedicated iPhone & iPad Scale Tables** with tuned point sizes and letter-spacing (`tracking`)
- **Static Scale Storage** — Zero unnecessary dictionary allocations on lookup
- **Dynamic Type scaling** via `UIFontMetrics` — respecting the user's Accessibility text-size preference
- **System Font & Custom Font Support** (TTF/OTF) with automatic fallback and duplicate-registration tolerance
- **Thread-safe `NSLock` cache** — fonts are built once and reused across threads
- **Modern UIKit Support**:
  - `UIButton.Configuration` (iOS 15+) and legacy `titleLabel`
  - `UINavigationBarAppearance` and `UITabBarAppearance`
  - `UILabel`, `UITextField`, `UITextView`
- **SwiftUI ViewModifier** (`.appFont(.title1)`) with native letter-spacing tracking
- **Swift Value-Type `AttributedString` (iOS 15+)** and Foundation `NSAttributedString` helpers
- **Swift 6 Strict Concurrency Clean**: explicit `Sendable` conformance and `@MainActor` isolation on view mutations

---

## Installation

### Option 1: Swift Package Manager (Recommended)

Add FontManager to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/bhargavkukadiya/FontManager.git", branch: "main")
]
```

*(Or specify a release tag like `from: "1.0.0"` once tagged).*

Or in Xcode: **File › Add Package Dependencies...** and enter the repository URL.

### Option 2: Drop-in File

Drag and drop `FontManager.swift` directly into your Xcode project.

---

## Quick Start

### 1. (Optional) Configure at Launch

In `AppDelegate` or your SwiftUI `App` struct, configure your typography before windows render:

```swift
// AppDelegate.swift
func application(_ application: UIApplication,
    didFinishLaunchingWithOptions ...) -> Bool {

    // Register custom fonts (skip if using system SF Pro)
    FontManager.shared.registerFont(named: "Poppins-Regular")
    FontManager.shared.registerFont(named: "Poppins-SemiBold")
    FontManager.shared.registerFont(named: "Poppins-Bold")

    // Switch source to your custom family
    FontManager.shared.fontSource = .custom(familyName: "Poppins")

    // Optional: Disable Dynamic Type if fixed sizes are required by design
    // FontManager.shared.respectsDynamicType = false

    return true
}
```

### 2. Apply Fonts

**UIKit — View Extensions:**

```swift
titleLabel.appFont(.largeTitle)
subtitleLabel.appFont(.title2)
bodyLabel.appFont(.body)
captionLabel.appFont(.caption1)
emailField.appFont(.textFieldText)
primaryButton.appFont(.buttonPrimary)
```

**UIKit — Direct Manager Queries:**

```swift
label.font = FontManager.shared.uiFont(for: .headline)
label.adjustsFontForContentSizeCategory = true
```

**SwiftUI — Native Text & View Extensions:**

```swift
// Direct Text modifier: sets both font and tracking (iOS 14+)
Text("Welcome")
    .appFont(.largeTitle)
    .foregroundColor(.primary)

// General View modifier: sets font (and tracking on iOS 16+)
VStack {
    Text("Title")
    Text("Subtitle")
}
.appFont(.body)
```

**SwiftUI — Direct `Font`:**

```swift
Text("Supporting copy")
    .font(FontManager.shared.swiftUIFont(for: .body))
```

---

## Style Token Reference

All 21 semantic tokens, their resolved sizes on iPhone and iPad, and their typographic metadata. Sizes shown are the base (Dynamic Type "Large" category). Scalable tokens grow with the user's preferred content size; non-scalable tokens remain fixed.

| Style Token | iPhone (pt) | iPad (pt) | Weight | Scalable | Tracking |
|---|---|---|---|---|---|
| `.largeTitle` | 34 | 40 | Bold | ✓ | +0.37 |
| `.navigationTitle` | 17 | 18 | Semibold | — | -0.41 |
| `.pageHeader` | 28 | 34 | Bold | ✓ | +0.36 |
| `.title1` | 28 | 34 | Bold | ✓ | +0.36 |
| `.title2` | 22 | 28 | Bold | ✓ | +0.35 |
| `.title3` | 20 | 24 | Semibold | ✓ | +0.38 |
| `.headline` | 17 | 18 | Semibold | ✓ | -0.41 |
| `.body` | 17 | 18 | Regular | ✓ | -0.41 |
| `.callout` | 16 | 17 | Regular | ✓ | -0.32 |
| `.subheadline` | 15 | 16 | Regular | ✓ | -0.24 |
| `.footnote` | 13 | 14 | Regular | ✓ | -0.08 |
| `.caption1` | 12 | 13 | Regular | ✓ | 0.00 |
| `.caption2` | 11 | 12 | Regular | ✓ | +0.07 |
| `.textFieldText` | 17 | 18 | Regular | ✓ | -0.41 |
| `.textFieldPlaceholder` | 17 | 18 | Regular | ✓ | -0.41 |
| `.buttonPrimary` | 17 | 18 | Semibold | ✓ | -0.41 |
| `.buttonSecondary` | 17 | 18 | Regular | ✓ | -0.41 |
| `.buttonDestructive` | 17 | 18 | Regular | ✓ | -0.41 |
| `.tabBarItem` | 10 | 11 | Medium | — | +0.12 |
| `.badgeLabel` | 12 | 13 | Bold | — | 0.00 |
| `.tooltip` | 13 | 14 | Regular | — | -0.08 |

---

## API Reference

### `FontSource`

Controls whether FontManager builds fonts from the system or a registered custom family.

```swift
FontManager.shared.fontSource = .system
FontManager.shared.fontSource = .custom(familyName: "Inter")
```

### `respectsDynamicType`

When `true` (default), scalable tokens are wrapped with `UIFontMetrics` and grow or shrink with `UIContentSizeCategory`. Both this and `fontSource` are lock-protected computed properties, safe to access concurrently across threads.

### `uiFont(for:)`

Returns a `UIFont` for the given `AppTextStyle`. Thread-safe; cached per device class and accessibility size.

```swift
let font: UIFont = FontManager.shared.uiFont(for: .title1)
```

### `swiftUIFont(for:)`

Returns a SwiftUI `Font` wrapping the resolved `UIFont`.

```swift
let font: Font = FontManager.shared.swiftUIFont(for: .body)
```

### `attributedString(_:style:)` (iOS 15+)

Builds a Swift value-type `AttributedString` with the correct font and tracking attributes.

```swift
let attr = FontManager.shared.attributedString("Hello, World", style: .title1)
```

### `attributedString(_:style:additionalAttributes:)`

Builds an `NSAttributedString` with the correct `.font` and `.kern` (letter-spacing) attributes.

```swift
let attr = FontManager.shared.attributedString(
    "Hello, World",
    style: .title1,
    additionalAttributes: [.foregroundColor: UIColor.label]
)
```

### `apply(_:to:)` — `@MainActor`

Applies a font directly to `UILabel`, `UITextField`, `UITextView`, or `UIButton`. For `UIButton`, seamlessly configures `UIButton.Configuration.titleTextAttributesTransformer` on iOS 15+ or `titleLabel` on legacy configurations.

```swift
FontManager.shared.apply(.body, to: myLabel)
FontManager.shared.apply(.buttonPrimary, to: myButton)
```

### `apply(largeTitleStyle:inlineTitleStyle:to:)` — `@MainActor`

Configures `standardAppearance`, `compactAppearance`, `scrollEdgeAppearance`, and direct attributes on a `UINavigationBar`.

```swift
FontManager.shared.apply(to: navigationController.navigationBar)
```

### `applyTabBarFont(to:)` — `@MainActor`

Configures `UITabBarAppearance` on the given `UITabBar` instance as well as global appearance proxies.

```swift
FontManager.shared.applyTabBarFont(to: tabBarController.tabBar)
```

### `registerFont(named:extension:bundle:)`

Programmatically registers a custom font from any bundle using CoreText. Handles duplicate registration gracefully (`kCTFontManagerErrorAlreadyRegistered`).

```swift
FontManager.shared.registerFont(named: "Inter-Bold", extension: "otf")
```

### `debugPrintAllFonts()`

Prints a formatted table of every resolved font for the current device class.

```swift
#if DEBUG
FontManager.shared.debugPrintAllFonts()
#endif
```

---

## Dynamic Type & Accessibility

All tokens with `scalable: true` are wrapped with `UIFontMetrics` before being returned, ensuring they scale in harmony with Apple's Human Interface Guidelines.

Non-scalable tokens (`navigationTitle`, `tabBarItem`, `badgeLabel`, `tooltip`) remain fixed to prevent compact navigation and chrome elements from clipping or breaking layout.

The font cache automatically invalidates when `UIContentSizeCategory.didChangeNotification` fires.

---

## Thread Safety & Concurrency

- `FontManager` is `@unchecked Sendable`. Reads and writes to `cache`, `fontSource`, and `respectsDynamicType` are guarded by an internal `NSLock`.
- Device idiom is resolved once and cached safely, preventing background threads from experiencing trait fallback issues.
- All view-mutating helpers are explicitly marked `@MainActor`.

---

## License

MIT License. Copyright © 2026 Bhargav Kukadia. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the Software), to deal in the Software without restriction.
