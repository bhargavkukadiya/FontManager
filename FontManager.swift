// FontManager.swift
// Production-ready font management singleton for iOS/iPadOS
// Supports custom fonts, dynamic type, and all standard UI elements
// Minimum deployment target: iOS 14.0+
// Swift 6 language mode compatible (strict concurrency checking, Xcode 26+ / iOS 26 SDK)

import UIKit
import SwiftUI

// MARK: - Font Style Definitions

/// Semantic text roles used throughout the app.
/// Maps to distinct visual hierarchies on both iPhone and iPad.
public enum AppTextStyle: String, CaseIterable, Sendable {
    // Navigation & Page Structure
    case largeTitle      // e.g. "Welcome"
    case navigationTitle // UINavigationBar title
    case pageHeader      // Section-level headings

    // Content Hierarchy
    case title1          // Primary card/screen title
    case title2          // Secondary title
    case title3          // Tertiary title

    // Body Content
    case headline        // Bold callout / emphasized body
    case body            // Default reading text
    case callout         // Slightly smaller emphasis
    case subheadline     // Supporting label below headlines

    // Supporting Text
    case footnote        // Legal, disclaimers
    case caption1        // Image captions, table labels
    case caption2        // Smallest readable label

    // Input Elements
    case textFieldText   // Text inside a UITextField / UITextView
    case textFieldPlaceholder
    case buttonPrimary
    case buttonSecondary
    case buttonDestructive
    case tabBarItem
    case badgeLabel
    case tooltip
}

// MARK: - Font Weight Token

public enum AppFontWeight: Sendable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

    var uiFontWeight: UIFont.Weight {
        switch self {
        case .ultraLight:  return .ultraLight
        case .thin:        return .thin
        case .light:       return .light
        case .regular:     return .regular
        case .medium:      return .medium
        case .semibold:    return .semibold
        case .bold:        return .bold
        case .heavy:       return .heavy
        case .black:       return .black
        }
    }
}

// MARK: - Font Source

/// Determines whether to use the system font (SF Pro / SF Compact)
/// or a registered custom font family.
public enum FontSource: Sendable {
    case system
    case custom(familyName: String)
}

// MARK: - Font Scale Spec

/// The full specification for a single text style on a given device class.
public struct FontScaleSpec: Sendable {
    /// Point size for this style/device combination.
    public let size: CGFloat
    /// Font weight.
    public let weight: AppFontWeight
    /// When true, the font tracks UIContentSizeCategory changes.
    public let scalable: Bool
    /// Letter-spacing adjustment (0 = default).
    public let tracking: CGFloat

    public init(
        size: CGFloat,
        weight: AppFontWeight = .regular,
        scalable: Bool = true,
        tracking: CGFloat = 0
    ) {
        self.size = size
        self.weight = weight
        self.scalable = scalable
        self.tracking = tracking
    }
}

// MARK: - FontManager

/// Thread-safe singleton that vends `UIFont` and `Font` (SwiftUI) values
/// for every semantic role, adapting sizes for iPhone vs iPad.
///
/// Usage:
/// ```swift
/// label.font = FontManager.shared.uiFont(for: .title1)
/// label.attributedText = FontManager.shared.attributedString("Hello", style: .title1)
/// textView.font = FontManager.shared.uiFont(for: .body)
/// ```
///
/// Concurrency: `FontManager` is `@unchecked Sendable`. All mutable state (the font
/// cache, `fontSource`, and `respectsDynamicType`) is guarded by an internal `NSLock`,
/// so the compiler's automatic Sendable checking is bypassed deliberately, not skipped
/// out of convenience. `uiFont(for:)` and friends are safe to call from any thread.
///
/// UIKit-mutating helpers (`apply(_:to:)` and friends) are `@MainActor`-isolated
/// because the view types they touch (`UILabel`, `UITextField`, etc.) are themselves
/// `@MainActor`-isolated in modern SDKs — call those from the main actor only.
public final class FontManager: @unchecked Sendable {

    // MARK: Shared Instance

    public static let shared = FontManager()

    // MARK: Configuration

    private var _fontSource: FontSource = .system
    private var _respectsDynamicType: Bool = true

    /// Override before first use (e.g. in `application(_:didFinishLaunchingWithOptions:)`).
    /// Backed by `lock` so it is safe to read/write from any thread.
    public var fontSource: FontSource {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _fontSource
        }
        set {
            lock.lock()
            _fontSource = newValue
            lock.unlock()
            invalidateCache()
        }
    }

    /// When true, fonts respond to the user's preferred text size setting.
    /// Backed by `lock` so it is safe to read/write from any thread.
    public var respectsDynamicType: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _respectsDynamicType
        }
        set {
            lock.lock()
            _respectsDynamicType = newValue
            lock.unlock()
            invalidateCache()
        }
    }

    // MARK: Private State

    private var cache: [String: UIFont] = [:]
    private let lock = NSLock()

    // MARK: Init

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Scale Tables

    /// iPhone scale table — all sizes in points at the "large" accessibility base.
    private var iPhoneScaleTable: [AppTextStyle: FontScaleSpec] {
        [
            .largeTitle:            FontScaleSpec(size: 34, weight: .bold,      scalable: true,  tracking: 0.37),
            .navigationTitle:       FontScaleSpec(size: 17, weight: .semibold,  scalable: false, tracking: -0.41),
            .pageHeader:            FontScaleSpec(size: 28, weight: .bold,      scalable: true,  tracking: 0.36),

            .title1:                FontScaleSpec(size: 28, weight: .bold,      scalable: true,  tracking: 0.36),
            .title2:                FontScaleSpec(size: 22, weight: .bold,      scalable: true,  tracking: 0.35),
            .title3:                FontScaleSpec(size: 20, weight: .semibold,  scalable: true,  tracking: 0.38),

            .headline:              FontScaleSpec(size: 17, weight: .semibold,  scalable: true,  tracking: -0.41),
            .body:                  FontScaleSpec(size: 17, weight: .regular,   scalable: true,  tracking: -0.41),
            .callout:               FontScaleSpec(size: 16, weight: .regular,   scalable: true,  tracking: -0.32),
            .subheadline:           FontScaleSpec(size: 15, weight: .regular,   scalable: true,  tracking: -0.24),

            .footnote:              FontScaleSpec(size: 13, weight: .regular,   scalable: true,  tracking: -0.08),
            .caption1:              FontScaleSpec(size: 12, weight: .regular,   scalable: true,  tracking: 0),
            .caption2:              FontScaleSpec(size: 11, weight: .regular,   scalable: true,  tracking: 0.07),

            .textFieldText:         FontScaleSpec(size: 17, weight: .regular,   scalable: true,  tracking: -0.41),
            .textFieldPlaceholder:  FontScaleSpec(size: 17, weight: .regular,   scalable: true,  tracking: -0.41),
            .buttonPrimary:         FontScaleSpec(size: 17, weight: .semibold,  scalable: true,  tracking: -0.41),
            .buttonSecondary:       FontScaleSpec(size: 17, weight: .regular,   scalable: true,  tracking: -0.41),
            .buttonDestructive:     FontScaleSpec(size: 17, weight: .regular,   scalable: true,  tracking: -0.41),
            .tabBarItem:            FontScaleSpec(size: 10, weight: .medium,    scalable: false, tracking: 0.12),
            .badgeLabel:            FontScaleSpec(size: 12, weight: .bold,      scalable: false, tracking: 0),
            .tooltip:               FontScaleSpec(size: 13, weight: .regular,   scalable: false, tracking: -0.08),
        ]
    }

    /// iPad scale table — larger base sizes to suit the bigger canvas.
    private var iPadScaleTable: [AppTextStyle: FontScaleSpec] {
        [
            .largeTitle:            FontScaleSpec(size: 40, weight: .bold,      scalable: true,  tracking: 0.37),
            .navigationTitle:       FontScaleSpec(size: 18, weight: .semibold,  scalable: false, tracking: -0.41),
            .pageHeader:            FontScaleSpec(size: 34, weight: .bold,      scalable: true,  tracking: 0.36),

            .title1:                FontScaleSpec(size: 34, weight: .bold,      scalable: true,  tracking: 0.36),
            .title2:                FontScaleSpec(size: 28, weight: .bold,      scalable: true,  tracking: 0.35),
            .title3:                FontScaleSpec(size: 24, weight: .semibold,  scalable: true,  tracking: 0.38),

            .headline:              FontScaleSpec(size: 18, weight: .semibold,  scalable: true,  tracking: -0.41),
            .body:                  FontScaleSpec(size: 18, weight: .regular,   scalable: true,  tracking: -0.41),
            .callout:               FontScaleSpec(size: 17, weight: .regular,   scalable: true,  tracking: -0.32),
            .subheadline:           FontScaleSpec(size: 16, weight: .regular,   scalable: true,  tracking: -0.24),

            .footnote:              FontScaleSpec(size: 14, weight: .regular,   scalable: true,  tracking: -0.08),
            .caption1:              FontScaleSpec(size: 13, weight: .regular,   scalable: true,  tracking: 0),
            .caption2:              FontScaleSpec(size: 12, weight: .regular,   scalable: true,  tracking: 0.07),

            .textFieldText:         FontScaleSpec(size: 18, weight: .regular,   scalable: true,  tracking: -0.41),
            .textFieldPlaceholder:  FontScaleSpec(size: 18, weight: .regular,   scalable: true,  tracking: -0.41),
            .buttonPrimary:         FontScaleSpec(size: 18, weight: .semibold,  scalable: true,  tracking: -0.41),
            .buttonSecondary:       FontScaleSpec(size: 18, weight: .regular,   scalable: true,  tracking: -0.41),
            .buttonDestructive:     FontScaleSpec(size: 18, weight: .regular,   scalable: true,  tracking: -0.41),
            .tabBarItem:            FontScaleSpec(size: 11, weight: .medium,    scalable: false, tracking: 0.12),
            .badgeLabel:            FontScaleSpec(size: 13, weight: .bold,      scalable: false, tracking: 0),
            .tooltip:               FontScaleSpec(size: 14, weight: .regular,   scalable: false, tracking: -0.08),
        ]
    }

    // MARK: - Device Detection

    private var isIPad: Bool {
        UITraitCollection.current.userInterfaceIdiom == .pad
    }

    private func spec(for style: AppTextStyle) -> FontScaleSpec {
        let table = isIPad ? iPadScaleTable : iPhoneScaleTable
        return table[style] ?? FontScaleSpec(size: 17, weight: .regular)
    }

    // MARK: - Core Font Resolution

    /// Returns a `UIFont` for the given semantic style.
    ///
    /// - Parameter style: The semantic role (e.g. `.title1`, `.body`).
    /// - Returns: A `UIFont` appropriately sized and weighted.
    public func uiFont(for style: AppTextStyle) -> UIFont {
        // NOTE: UIApplication.shared is @MainActor-isolated in modern SDKs, which would
        // force this whole method onto the main actor. UITraitCollection.current is
        // stored as a thread-local by UIKit, so it is safe to read from any thread and
        // also correctly reflects per-scene/per-window overrides (UIApplication.shared's
        // value does not).
        let sizeCategory = UITraitCollection.current.preferredContentSizeCategory
        let cacheKey = "\(style.rawValue)-\(isIPad)-\(respectsDynamicType)-\(sizeCategory.rawValue)"

        lock.lock()
        if let cached = cache[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let resolved = makeFont(for: style)

        lock.lock()
        cache[cacheKey] = resolved
        lock.unlock()

        return resolved
    }

    /// Returns a SwiftUI `Font` for the given semantic style.
    public func swiftUIFont(for style: AppTextStyle) -> Font {
        Font(uiFont(for: style))
    }

    // MARK: - Private Font Construction

    private func makeFont(for style: AppTextStyle) -> UIFont {
        let s = spec(for: style)
        let baseFont = buildBaseFont(size: s.size, weight: s.weight)

        guard respectsDynamicType, s.scalable else {
            return baseFont
        }

        let metrics = UIFontMetrics(forTextStyle: closestTextStyle(for: style))
        return metrics.scaledFont(for: baseFont)
    }

    private func buildBaseFont(size: CGFloat, weight: AppFontWeight) -> UIFont {
        switch fontSource {
        case .system:
            return UIFont.systemFont(ofSize: size, weight: weight.uiFontWeight)

        case .custom(let familyName):
            let descriptor = UIFontDescriptor(fontAttributes: [
                .family: familyName,
                .traits: [UIFontDescriptor.TraitKey.weight: weight.uiFontWeight.rawValue]
            ])
            let custom = UIFont(descriptor: descriptor, size: size)
            // Fall back to system font if the family isn't registered
            if custom.familyName.lowercased() == familyName.lowercased() {
                return custom
            }
            assertionFailure("FontManager: Custom font '\(familyName)' not found. Falling back to system font.")
            return UIFont.systemFont(ofSize: size, weight: weight.uiFontWeight)
        }
    }

    /// Maps semantic styles to UIFontTextStyle for Dynamic Type metrics.
    private func closestTextStyle(for style: AppTextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle:                        return .largeTitle
        case .navigationTitle, .pageHeader:      return .title1
        case .title1:                            return .title1
        case .title2:                            return .title2
        case .title3:                            return .title3
        case .headline:                          return .headline
        case .body, .textFieldText,
             .textFieldPlaceholder:              return .body
        case .callout:                           return .callout
        case .subheadline:                       return .subheadline
        case .footnote, .tooltip:               return .footnote
        case .caption1:                          return .caption1
        case .caption2:                          return .caption2
        case .buttonPrimary, .buttonSecondary,
             .buttonDestructive:                 return .headline
        case .tabBarItem, .badgeLabel:           return .caption2
        }
    }

    // MARK: - Attributed String Helpers

    /// Returns an `NSAttributedString` with the correct font AND letter-spacing.
    ///
    /// - Parameters:
    ///   - text: The display string.
    ///   - style: Semantic style.
    ///   - additionalAttributes: Any extra attributes (e.g. foreground color).
    public func attributedString(
        _ text: String,
        style: AppTextStyle,
        additionalAttributes: [NSAttributedString.Key: Any] = [:]
    ) -> NSAttributedString {
        let s = spec(for: style)
        var attributes: [NSAttributedString.Key: Any] = [
            .font: uiFont(for: style),
            .kern: s.tracking,
        ]
        attributes.merge(additionalAttributes) { _, new in new }
        return NSAttributedString(string: text, attributes: attributes)
    }

    // MARK: - UIKit Apply Helpers
    // These are @MainActor because the view types they mutate (UILabel, UITextField,
    // UITextView, UIButton, UINavigationBar, UITabBar) are themselves @MainActor-isolated.

    /// Applies the correct font to a `UILabel`.
    @MainActor
    public func apply(_ style: AppTextStyle, to label: UILabel) {
        label.font = uiFont(for: style)
        label.adjustsFontForContentSizeCategory = respectsDynamicType
    }

    /// Applies the correct font to a `UITextField`.
    @MainActor
    public func apply(_ style: AppTextStyle, to textField: UITextField) {
        textField.font = uiFont(for: style)
        textField.adjustsFontForContentSizeCategory = respectsDynamicType
    }

    /// Applies the correct font to a `UITextView`.
    @MainActor
    public func apply(_ style: AppTextStyle, to textView: UITextView) {
        textView.font = uiFont(for: style)
        textView.adjustsFontForContentSizeCategory = respectsDynamicType
    }

    /// Applies the correct font to a `UIButton`.
    @MainActor
    public func apply(_ style: AppTextStyle, to button: UIButton) {
        button.titleLabel?.font = uiFont(for: style)
        button.titleLabel?.adjustsFontForContentSizeCategory = respectsDynamicType
    }

    /// Applies the correct font to a `UINavigationBar` (large and inline titles).
    @MainActor
    public func apply(largeTitleStyle: AppTextStyle = .largeTitle,
                      inlineTitleStyle: AppTextStyle = .navigationTitle,
                      to bar: UINavigationBar) {
        bar.largeTitleTextAttributes = [
            .font: uiFont(for: largeTitleStyle)
        ]
        bar.titleTextAttributes = [
            .font: uiFont(for: inlineTitleStyle)
        ]
    }

    /// Applies the correct font to a `UITabBarItem` label.
    @MainActor
    public func applyTabBarFont(to tabBar: UITabBar) {
        let font = uiFont(for: .tabBarItem)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        UITabBarItem.appearance().setTitleTextAttributes(attrs, for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(attrs, for: .selected)
    }

    // MARK: - Custom Font Registration

    /// Registers a custom font from a bundle.
    ///
    /// Call once at app launch (before `fontSource` is set to `.custom`).
    ///
    /// - Parameters:
    ///   - name: Font file name without extension (e.g. "Poppins-Regular").
    ///   - extension: File extension (e.g. "ttf", "otf").
    ///   - bundle: The bundle containing the font file (default: `.main`).
    /// - Returns: `true` if registration succeeded.
    @discardableResult
    public func registerFont(
        named name: String,
        extension ext: String = "ttf",
        bundle: Bundle = .main
    ) -> Bool {
        guard let url = bundle.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let font = CGFont(provider) else {
            assertionFailure("FontManager: Could not load font file '\(name).\(ext)' from bundle.")
            return false
        }

        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterGraphicsFont(font, &error)

        if !registered {
            let reason = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            assertionFailure("FontManager: Failed to register '\(name)': \(reason)")
        }

        return registered
    }

    // MARK: - Debugging

    /// Prints all resolved fonts for the current device class. Useful during development.
    public func debugPrintAllFonts() {
        let device = isIPad ? "iPad" : "iPhone"
        print("──── FontManager Debug [\(device)] ────")
        for style in AppTextStyle.allCases {
            let font = uiFont(for: style)
            let name = style.rawValue.padding(toLength: 26, withPad: " ", startingAt: 0)
            let size = String(format: "%.1f", font.pointSize)
            print("  \(name) → \(font.fontName) \(size)pt")
        }
        print("────────────────────────────────────")
    }

    // MARK: - Cache Invalidation

    @objc private func contentSizeCategoryDidChange() {
        invalidateCache()
    }

    private func invalidateCache() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}

// MARK: - SwiftUI ViewModifier

/// Apply in SwiftUI with `.appFont(.title1)`.
public struct AppFontModifier: ViewModifier {
    let style: AppTextStyle

    public func body(content: Content) -> some View {
        content.font(FontManager.shared.swiftUIFont(for: style))
    }
}

public extension View {
    /// Applies a semantic `AppTextStyle` font to this view.
    func appFont(_ style: AppTextStyle) -> some View {
        modifier(AppFontModifier(style: style))
    }
}

// MARK: - UILabel / UITextField Convenience

public extension UILabel {
    /// Shorthand: `label.appFont(.headline)`
    @MainActor
    func appFont(_ style: AppTextStyle) {
        FontManager.shared.apply(style, to: self)
    }
}

public extension UITextField {
    @MainActor
    func appFont(_ style: AppTextStyle) {
        FontManager.shared.apply(style, to: self)
    }
}

public extension UITextView {
    @MainActor
    func appFont(_ style: AppTextStyle) {
        FontManager.shared.apply(style, to: self)
    }
}

public extension UIButton {
    @MainActor
    func appFont(_ style: AppTextStyle) {
        FontManager.shared.apply(style, to: self)
    }
}
