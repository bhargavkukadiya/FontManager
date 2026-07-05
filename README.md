# FontManager.swift

**Production-Ready iOS & iPadOS Font Management System**

| | |
|---|---|
| **Platform** | iOS 14.0+ · iPadOS 14.0+ (builds clean on iOS 26 SDK / Xcode 26+) |
| **Language** | Swift 5.7+ · Swift 6 language mode audited |
| **Xcode** | 14.0+ (verified against Xcode 26) |
| **Type** | Singleton — `final class`, `@unchecked Sendable` |
| **Fonts** | System (SF Pro) + custom TTF/OTF |
| **Accessibility** | Full Dynamic Type support |
| **SwiftUI** | Native `Font` + ViewModifier included |
| **3rd Party** | None — zero dependencies |

---

## Overview

FontManager is a zero-dependency, thread-safe singleton that centralises every font decision in your iOS or iPadOS application. Instead of scattering point sizes and weights across view controllers, you reference a single semantic token — `.title1`, `.body`, `.buttonPrimary` — and FontManager resolves the correct `UIFont` or SwiftUI `Font` for the current device class.

**Key capabilities:**

- Separate iPhone and iPad scale tables with tuned point sizes and letter-spacing
- Automatic Dynamic Type scaling via `UIFontMetrics` — respects the user's Accessibility text-size preference
- System font (SF Pro / SF Compact) by default; drop-in custom font support (TTF/OTF) with automatic fallback
- Thread-safe `NSLock` cache — fonts are built once and reused
- Cache automatically invalidates on `UIContentSizeCategory` change
- One-call UIKit helpers: `apply(_:to:)` for `UILabel`, `UITextField`, `UITextView`, `UIButton`, `UINavigationBar`, `UITabBar`
- SwiftUI `Font` and `.appFont()` ViewModifier included
- `NSAttributedString` helper with correct letter-spacing (`kern`) baked in
- Custom font registration utility — load TTF/OTF from any `Bundle`
- Debug printer: lists all resolved fonts in one call
- Swift 6 strict concurrency clean: explicit `Sendable` conformance, `@MainActor` on UIKit-mutating calls

---

## Quick Start

### 1. Drop in the file

Add `FontManager.swift` to your Xcode project. No podfile, no SPM manifest, no bridging header needed.

### 2. (Optional) Configure at launch

In `AppDelegate` or your `App` struct, set up before the first `UIWindow` renders:

```swift
// AppDelegate.swift
func application(_ application: UIApplication,
    didFinishLaunchingWithOptions ...) -> Bool {

    // Register custom fonts (skip for system SF Pro)
    FontManager.shared.registerFont(named: "Poppins-Regular")
    FontManager.shared.registerFont(named: "Poppins-SemiBold")
    FontManager.shared.registerFont(named: "Poppins-Bold")

    // Switch source to your family
    FontManager.shared.fontSource = .custom(familyName: "Poppins")

    // Disable Dynamic Type if your design requires fixed sizes
    // FontManager.shared.respectsDynamicType = false

    return true
}
```

### 3. Apply fonts

UIKit — convenience extension on each view type (main thread, since these mutate live views):

```swift
titleLabel.appFont(.largeTitle)
subtitleLabel.appFont(.title2)
bodyLabel.appFont(.body)
captionLabel.appFont(.caption1)
emailField.appFont(.textFieldText)
primaryButton.appFont(.buttonPrimary)
```

UIKit — explicit manager call:

```swift
label.font = FontManager.shared.uiFont(for: .headline)
label.adjustsFontForContentSizeCategory = true
```

SwiftUI — ViewModifier:

```swift
Text("Welcome")
    .appFont(.largeTitle)
    .foregroundColor(.primary)
```

SwiftUI — direct `Font`:

```swift
Text("Supporting copy")
    .font(FontManager.shared.swiftUIFont(for: .body))
```

---

## Style Token Reference

All 21 semantic tokens, their resolved sizes on iPhone and iPad, and their typographic metadata. Sizes shown are the base (Dynamic Type "Large" category). Scalable tokens grow with the user's preferred content size; non-scalable tokens remain fixed (navigation bars, tab labels, badges).

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

When `true` (default), scalable tokens are wrapped with `UIFontMetrics` and grow or shrink with `UIContentSizeCategory`. Both this and `fontSource` are lock-protected computed properties, so reading and writing them concurrently from different threads is safe.

### `uiFont(for:)`

Returns a `UIFont` for the given `AppTextStyle`. Thread-safe; cached per device class + accessibility size. Safe to call from a background thread — it deliberately avoids `UIApplication.shared` in favor of the thread-local `UITraitCollection.current`.

```swift
let font: UIFont = FontManager.shared.uiFont(for: .title1)
```

### `swiftUIFont(for:)`

Returns a SwiftUI `Font` wrapping the resolved `UIFont`.

```swift
let font: Font = FontManager.shared.swiftUIFont(for: .body)
```

### `attributedString(_:style:additionalAttributes:)`

Builds an `NSAttributedString` with the correct `.font` and `.kern` (letter-spacing) attributes. Pass extra attributes (e.g. foreground colour) via `additionalAttributes`.

```swift
let attr = FontManager.shared.attributedString(
    "Hello, World",
    style: .title1,
    additionalAttributes: [.foregroundColor: UIColor.label]
)
```

### `apply(_:to:)` — `@MainActor`

Applies a font directly to `UILabel`, `UITextField`, `UITextView`, or `UIButton`. Also sets `adjustsFontForContentSizeCategory` automatically. Marked `@MainActor` because these view types are main-actor isolated in current SDKs.

```swift
FontManager.shared.apply(.body, to: myLabel)
FontManager.shared.apply(.textFieldText, to: searchField)
```

### `apply(largeTitleStyle:inlineTitleStyle:to:)` — `@MainActor`

Configures both `largeTitleTextAttributes` and `titleTextAttributes` on a `UINavigationBar` simultaneously.

```swift
FontManager.shared.apply(to: navigationController.navigationBar)
```

### `applyTabBarFont(to:)` — `@MainActor`

Sets `UITabBarItem` appearance-level attributes for `.normal` and `.selected` states.

```swift
FontManager.shared.applyTabBarFont(to: tabBarController.tabBar)
```

### `registerFont(named:extension:bundle:)`

Programmatically registers a custom font from any bundle using CoreText. Returns `true` on success. Call before setting `fontSource = .custom`.

```swift
FontManager.shared.registerFont(named: "Inter-Bold", extension: "otf")
```

### `debugPrintAllFonts()`

Prints a formatted table of every resolved font for the current device class and accessibility size. Strip from Release builds via a `DEBUG` preprocessor guard.

```swift
#if DEBUG
FontManager.shared.debugPrintAllFonts()
#endif
```

---

## Using Custom Fonts

**Step 1** — Add font files to your Xcode project. Ensure each file is added to the correct Target Membership.

**Step 2** — Declare them in `Info.plist` under `UIAppFonts` (Fonts provided by application):

```xml
<key>UIAppFonts</key>
<array>
    <string>Inter-Regular.ttf</string>
    <string>Inter-Medium.ttf</string>
    <string>Inter-SemiBold.ttf</string>
    <string>Inter-Bold.ttf</string>
</array>
```

**Step 3** — Register and activate at launch:

```swift
FontManager.shared.registerFont(named: "Inter-Regular")
FontManager.shared.registerFont(named: "Inter-Medium")
FontManager.shared.registerFont(named: "Inter-SemiBold")
FontManager.shared.registerFont(named: "Inter-Bold")
FontManager.shared.fontSource = .custom(familyName: "Inter")
```

If a custom font family is not found at runtime, FontManager logs an `assertionFailure` in Debug builds and silently falls back to the system font in Release builds. Your UI will never crash due to a missing font.

---

## Dynamic Type & Accessibility

All 21 tokens with `scalable: true` are wrapped with `UIFontMetrics` before being returned. This means they automatically adjust when the user changes their preferred text size in Settings › Accessibility › Larger Text.

The closest `UIFont.TextStyle` is chosen per token — for example `.title1` maps to `.title1` metrics, `.caption2` maps to `.caption2` metrics — so the scaling ratio matches Apple's Human Interface Guidelines.

Non-scalable tokens (`navigationTitle`, `tabBarItem`, `badgeLabel`, `tooltip`) are intentionally fixed. Navigation bars, tab bars, and compact UI elements break layout when they scale beyond their containers.

The font cache invalidates automatically when `UIContentSizeCategory.didChangeNotification` fires, so fonts are regenerated at the new size on the next access.

---

## Thread Safety & Concurrency

FontManager uses `NSLock` to guard all reads and writes to the internal cache dictionary, as well as the `fontSource` and `respectsDynamicType` properties. `uiFont(for:)`, `swiftUIFont(for:)`, and `attributedString(_:style:)` are safe to call from any thread.

The UIKit-mutating helpers (`apply(_:to:)`, `applyTabBarFont`, `apply(to: UINavigationBar)`, and the `UILabel`/`UITextField`/`UITextView`/`UIButton` `appFont(_:)` extensions) are explicitly marked `@MainActor`, matching the actor isolation of the view classes they touch under Swift 6.

---

## Architecture

**Scale Tables** — Two private computed properties, `iPhoneScaleTable` and `iPadScaleTable`, return `[AppTextStyle: FontScaleSpec]` dictionaries. A `FontScaleSpec` carries `size`, `weight`, `scalable`, and `tracking`. The correct table is selected at runtime via `UIDevice.current.userInterfaceIdiom`.

**Cache Key** — Each resolved font is keyed by `styleName + deviceClass + dynamicTypeEnabled + currentContentSizeCategory`, the last of which now comes from `UITraitCollection.current` rather than `UIApplication.shared` (see [Correctness Review](#correctness-review--swift-6--current-platform-notes)). The cache is automatically segmented across accessibility size changes and device idiom.

**Custom Font Matching** — When `fontSource = .custom`, FontManager builds a `UIFontDescriptor` with the family name and a `UIFontDescriptor.TraitKey.weight` value matching the `AppFontWeight`. UIKit internally selects the closest registered face. If no match is found — detected by comparing the resolved `familyName` — the system font is substituted and an `assertionFailure` fires in Debug.

---

## Customising the Scale Tables

The scale tables are private computed properties and are intentionally not stored — they are rebuilt from literal values on each access (the cache means this is free in practice). To change a size, open `FontManager.swift` and edit the corresponding `FontScaleSpec` in `iPhoneScaleTable` or `iPadScaleTable`.

To add a new style token:

1. Add a new case to `AppTextStyle`
2. Add a `FontScaleSpec` entry to both `iPhoneScaleTable` and `iPadScaleTable`
3. Add a `UIFont.TextStyle` mapping in `closestTextStyle(for:)`

---

## Correctness Review — Swift 6 & Current Platform Notes

This file was audited against Swift 6 strict concurrency checking and the current Apple SDK line (iOS 26 / Xcode 26+, with iOS 27 in beta following WWDC 2026, Swift 6.4). The items below were genuine issues, fixed directly in the shipped `FontManager.swift` — this isn't a list of hypothetical style nits.

**1. Singleton was not `Sendable`.**
Under Swift 6 language mode, a `static let shared` instance of a plain class triggers a compiler error that the type may have shared mutable state across concurrency domains. Fixed by declaring `final class FontManager: @unchecked Sendable` — justified because every mutable stored property is now guarded by the internal `NSLock`, which the compiler cannot verify on its own.

**2. `fontSource` / `respectsDynamicType` had a real data race.**
These were plain `public var` properties with a `didSet`, unprotected by any lock — a genuine race condition independent of Swift 6, not just a compiler nitpick. Toggling `respectsDynamicType` from a settings screen while a background render pass called `uiFont(for:)` was undefined behavior. Both are now computed properties backed by private storage, with get/set routed through the same `NSLock` used by the cache.

**3. `UIApplication.shared` is now `@MainActor`-isolated.**
Recent SDKs annotate all of `UIApplication` with `@MainActor`. The original cache-key logic read `UIApplication.shared.preferredContentSizeCategory` directly inside `uiFont(for:)`, a method documented as callable from any thread — under Swift 6 this would force the method onto the main actor or fail to compile. Fixed by switching to `UITraitCollection.current.preferredContentSizeCategory`, which UIKit stores as a thread-local value. This is also more correct on multi-scene iPadOS apps, since `UIApplication.shared`'s value is app-wide while `UITraitCollection.current` reflects the calling context.

**4. UIKit-mutating helpers needed explicit `@MainActor`.**
`apply(_:to:)` and its overloads mutate `UILabel`, `UITextField`, `UITextView`, `UIButton`, `UINavigationBar`, and `UITabBar`, all of which are `@MainActor`-isolated in current SDKs. Those methods — and the matching UIKit convenience extensions — are now marked `@MainActor` explicitly. `uiFont(for:)`, `swiftUIFont(for:)`, and `attributedString(_:style:)` remain `nonisolated` by design, since they return values rather than mutate views, and are safe to call from a background thread.

**5. `debugPrintAllFonts()` used an unsafe format specifier.**
The original code passed a Swift `String` to `%s` inside `String(format:)`. That specifier expects a C string pointer, not a Swift or Foundation string — passing a `String` there is undefined behavior and can print garbage or crash depending on the runtime. Replaced with plain string interpolation, keeping `%.1f` only for the numeric point size, which is the specifier it's actually valid for.

**6. Explicit `Sendable` on value types.**
`AppTextStyle`, `AppFontWeight`, `FontSource`, and `FontScaleSpec` already qualified for implicit `Sendable` synthesis, but explicit conformance was added so the public API documents its own concurrency contract, and so a future contributor adding a non-Sendable property gets a compiler error instead of a silent regression.

**7. Known SDK limitation worth knowing about.**
`UIFont` itself is not annotated `Sendable` by Apple, despite being documented as safe to use across threads since iOS 4. If you resolve a font on a background `Task` and hand it to `MainActor`-isolated UI code under complete strict concurrency checking, the compiler may warn about sending a non-Sendable `UIFont` across the actor boundary. This isn't a bug in FontManager — it's a gap in the SDK's own concurrency annotations — resolve fonts on the main actor if you hit that warning.

**8. Platform / toolchain context.**
Apple unified its OS versioning in 2025, so what would have been "iOS 19" became iOS 26; the SDK is currently at iOS 26.x with iOS 27 in beta. Since April 28, 2026, Apple requires App Store submissions to be built with the iOS 26 SDK or later — this affects which Xcode you build with, not your minimum deployment target, so this file's iOS 14.0+ deployment target is unaffected. No `UIFont`, `UIFontDescriptor`, `UIFontMetrics`, or Core Text API used in this file has been deprecated as of this SDK.

**9. `UIDevice.current.userInterfaceIdiom` had the same problem as `UIApplication.shared`.**
`isIPad` (used by `uiFont(for:)`, `spec(for:)`, and the cache key) originally read `UIDevice.current.userInterfaceIdiom`. Both `UIDevice.current` and `.userInterfaceIdiom` are `@MainActor`-isolated in current SDKs, which produces the same class of warning as the `UIApplication.shared` issue above (`main actor-isolated property 'userInterfaceIdiom' can not be referenced from a nonisolated context`). Fixed the same way: switched to `UITraitCollection.current.userInterfaceIdiom`, which is thread-local and carries the identical value.

A tempting alternative is marking the import `@preconcurrency import UIKit`, which silences these warnings by telling the compiler to treat the whole UIKit module under the old concurrency rules. That was deliberately **not** used here — it suppresses the diagnostic for every UIKit symbol in the file, including ones where the warning is catching a real problem, rather than fixing the underlying thread-safety question. Routing through `UITraitCollection.current` actually removes the main-actor dependency instead of just hiding it.

---

## License

MIT License. Copyright © 2026 Bhargav Kukadia. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the Software), to deal in the Software without restriction.
