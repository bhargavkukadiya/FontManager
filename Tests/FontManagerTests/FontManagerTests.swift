import XCTest
import UIKit
import SwiftUI
@testable import FontManager

@MainActor
final class FontManagerTests: XCTestCase {

    private let manager = FontManager.shared

    override func setUp() {
        super.setUp()
        resetManager()
    }

    override func tearDown() {
        resetManager()
        super.tearDown()
    }

    // XCTestCase's setUp/tearDown are nonisolated; FontManager's state is lock-protected and Sendable.
    nonisolated private func resetManager() {
        let manager = FontManager.shared
        manager.fontSource = .system
        manager.respectsDynamicType = true
        manager.isIPadOverride = nil
        manager.invalidateCache()
    }

    // MARK: - Style Enumeration & Scale Tables

    func testAllStylesResolveValidUIFont() {
        for style in AppTextStyle.allCases {
            let font = manager.uiFont(for: style)
            XCTAssertGreaterThan(font.pointSize, 0, "Style \(style.rawValue) should have pointSize > 0")
        }
    }

    func testScaleTablesCoverEveryStyle() {
        for style in AppTextStyle.allCases {
            XCTAssertNotNil(FontManager.iPhoneScaleTable[style], "iPhone table is missing \(style.rawValue)")
            XCTAssertNotNil(FontManager.iPadScaleTable[style], "iPad table is missing \(style.rawValue)")
        }
    }

    func testScaleSpecsPhoneVsPad() {
        for style in AppTextStyle.allCases {
            let phoneSpec = manager.scaleSpec(for: style, isIPad: false)
            let padSpec = manager.scaleSpec(for: style, isIPad: true)

            XCTAssertGreaterThan(phoneSpec.size, 0)
            XCTAssertGreaterThan(padSpec.size, 0)
            XCTAssertGreaterThanOrEqual(padSpec.size, phoneSpec.size, "Pad size should be >= Phone size for \(style)")
        }
    }

    func testAppFontWeightMapping() {
        XCTAssertEqual(AppFontWeight.ultraLight.uiFontWeight, .ultraLight)
        XCTAssertEqual(AppFontWeight.thin.uiFontWeight, .thin)
        XCTAssertEqual(AppFontWeight.light.uiFontWeight, .light)
        XCTAssertEqual(AppFontWeight.regular.uiFontWeight, .regular)
        XCTAssertEqual(AppFontWeight.medium.uiFontWeight, .medium)
        XCTAssertEqual(AppFontWeight.semibold.uiFontWeight, .semibold)
        XCTAssertEqual(AppFontWeight.bold.uiFontWeight, .bold)
        XCTAssertEqual(AppFontWeight.heavy.uiFontWeight, .heavy)
        XCTAssertEqual(AppFontWeight.black.uiFontWeight, .black)
    }

    // MARK: - Dynamic Type

    func testScalableStylesFollowContentSizeCategory() {
        let small = manager.uiFont(for: .body, contentSizeCategory: .extraSmall)
        let large = manager.uiFont(for: .body, contentSizeCategory: .large)
        let huge = manager.uiFont(for: .body, contentSizeCategory: .accessibilityExtraExtraExtraLarge)

        XCTAssertEqual(large.pointSize, manager.scaleSpec(for: .body).size, accuracy: 0.01)
        XCTAssertLessThan(small.pointSize, large.pointSize)
        XCTAssertGreaterThan(huge.pointSize, large.pointSize)
    }

    func testNonScalableStylesIgnoreContentSizeCategory() {
        let expected = manager.scaleSpec(for: .tabBarItem).size
        for category in [UIContentSizeCategory.extraSmall, .large, .accessibilityExtraExtraExtraLarge] {
            XCTAssertEqual(manager.uiFont(for: .tabBarItem, contentSizeCategory: category).pointSize, expected, accuracy: 0.01)
        }
    }

    func testUnspecifiedCategoryFollowsCurrentTraits() {
        var atLarge: UIFont?
        var atHuge: UIFont?
        UITraitCollection(preferredContentSizeCategory: .large).performAsCurrent {
            atLarge = manager.uiFont(for: .body, contentSizeCategory: .unspecified)
        }
        UITraitCollection(preferredContentSizeCategory: .accessibilityExtraLarge).performAsCurrent {
            atHuge = manager.uiFont(for: .body, contentSizeCategory: .unspecified)
        }

        XCTAssertEqual(atLarge?.pointSize, manager.uiFont(for: .body, contentSizeCategory: .large).pointSize)
        XCTAssertEqual(atHuge?.pointSize, manager.uiFont(for: .body, contentSizeCategory: .accessibilityExtraLarge).pointSize)
        XCTAssertGreaterThan(atHuge?.pointSize ?? 0, atLarge?.pointSize ?? .greatestFiniteMagnitude)
    }

    func testDisablingDynamicTypeUsesBaseSizes() {
        manager.respectsDynamicType = false
        for style in AppTextStyle.allCases {
            let font = manager.uiFont(for: style, contentSizeCategory: .accessibilityExtraExtraExtraLarge)
            XCTAssertEqual(font.pointSize, manager.scaleSpec(for: style).size, accuracy: 0.01, "\(style.rawValue)")
        }
    }

    // MARK: - Device Detection

    func testPadIdiomDetection() {
        // Universal app
        XCTAssertTrue(FontManager.isPadIdiom(machineIdentifier: "iPad16,3", supportedDeviceFamilies: [1, 2]))
        XCTAssertFalse(FontManager.isPadIdiom(machineIdentifier: "iPhone17,1", supportedDeviceFamilies: [1, 2]))
        XCTAssertFalse(FontManager.isPadIdiom(machineIdentifier: "iPod9,1", supportedDeviceFamilies: [1, 2]))
        // iPhone-only app in compatibility mode on iPad
        XCTAssertFalse(FontManager.isPadIdiom(machineIdentifier: "iPad16,3", supportedDeviceFamilies: [1]))
        // iPad-capable app on an Apple silicon Mac or Apple Vision Pro
        XCTAssertTrue(FontManager.isPadIdiom(machineIdentifier: "MacBookPro18,3", supportedDeviceFamilies: [1, 2]))
        XCTAssertTrue(FontManager.isPadIdiom(machineIdentifier: "RealityDevice14,1", supportedDeviceFamilies: [2]))
        // iPhone-only app on an Apple silicon Mac
        XCTAssertFalse(FontManager.isPadIdiom(machineIdentifier: "MacBookPro18,3", supportedDeviceFamilies: [1]))
        // Missing UIDeviceFamily falls back to the hardware
        XCTAssertTrue(FontManager.isPadIdiom(machineIdentifier: "iPad16,3", supportedDeviceFamilies: nil))
    }

    func testDetectedIdiomMatchesUIDevice() {
        XCTAssertEqual(manager.isIPad, UIDevice.current.userInterfaceIdiom == .pad)
    }

    func testIsIPadOverrideSelectsScaleTable() {
        manager.respectsDynamicType = false

        manager.isIPadOverride = true
        XCTAssertTrue(manager.isIPad)
        XCTAssertEqual(manager.uiFont(for: .body).pointSize, FontManager.iPadScaleTable[.body]?.size)

        manager.isIPadOverride = false
        XCTAssertFalse(manager.isIPad)
        XCTAssertEqual(manager.uiFont(for: .body).pointSize, FontManager.iPhoneScaleTable[.body]?.size)
    }

    // MARK: - Caching

    func testFontsAreCachedAndConfigurationChangesClearCache() {
        let first = manager.uiFont(for: .headline)
        XCTAssertTrue(first === manager.uiFont(for: .headline))
        XCTAssertGreaterThan(manager.cachedFontCount, 0)

        manager.fontSource = .custom(familyName: "Avenir Next")
        XCTAssertEqual(manager.cachedFontCount, 0)
        _ = manager.uiFont(for: .headline)

        manager.respectsDynamicType = false
        XCTAssertEqual(manager.cachedFontCount, 0)
        _ = manager.uiFont(for: .headline)

        manager.isIPadOverride = true
        XCTAssertEqual(manager.cachedFontCount, 0)
    }

    // MARK: - Thread Safety & Concurrency

    func testConcurrentFontResolution() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<200 {
                group.addTask {
                    let style = AppTextStyle.allCases[i % AppTextStyle.allCases.count]
                    let font = FontManager.shared.uiFont(for: style)
                    XCTAssertGreaterThan(font.pointSize, 0)
                }
            }
        }
    }

    func testConcurrentPropertyMutationAndRead() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    switch i % 4 {
                    case 0: FontManager.shared.respectsDynamicType = (i % 8 == 0)
                    case 1: FontManager.shared.isIPadOverride = (i % 8 == 1) ? nil : true
                    default: _ = FontManager.shared.uiFont(for: .body)
                    }
                }
            }
        }
    }

    // MARK: - AttributedString Helpers

    func testAttributedStringGeneration() {
        let sample = "Hello FontManager"
        let attr = manager.attributedString(sample, style: .largeTitle)

        XCTAssertEqual(attr.string, sample)
        XCTAssertEqual(attr.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, manager.uiFont(for: .largeTitle))
        XCTAssertEqual(attr.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat, manager.scaleSpec(for: .largeTitle).tracking)
    }

    func testAttributedStringMergesAdditionalAttributes() {
        let attr = manager.attributedString("Hi", style: .body, additionalAttributes: [.foregroundColor: UIColor.red, .kern: 2.0])
        XCTAssertEqual(attr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
        XCTAssertEqual(attr.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat, 2.0)
    }

    @available(iOS 15.0, *)
    func testSwiftAttributedStringGeneration() {
        let sample = "Swift AttributedString"
        let attr = manager.swiftAttributedString(sample, style: .headline)
        let tracking = manager.scaleSpec(for: .headline).tracking

        XCTAssertEqual(String(attr.characters), sample)
        XCTAssertNotNil(attr.swiftUI.font)
        XCTAssertEqual(attr.swiftUI.tracking, tracking)
        XCTAssertEqual(attr.uiKit.font, manager.uiFont(for: .headline))
        XCTAssertEqual(attr.uiKit.kern, tracking)

        let bridged = NSAttributedString(attr)
        XCTAssertEqual(bridged.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, manager.uiFont(for: .headline))
    }

    // MARK: - Custom Fonts

    func testUnregisteredCustomFontFallsBackToSystemFont() {
        manager.fontSource = .custom(familyName: "NonExistentFontFamilyXYZ")
        let font = manager.uiFont(for: .title1)
        let system = UIFont.systemFont(ofSize: 17, weight: .bold)
        XCTAssertEqual(font.familyName, system.familyName)
    }

    func testCustomFamilyResolvesRequestedWeights() {
        manager.fontSource = .custom(familyName: "Avenir Next")
        XCTAssertEqual(manager.uiFont(for: .body).fontName, "AvenirNext-Regular")
        XCTAssertEqual(manager.uiFont(for: .headline).fontName, "AvenirNext-DemiBold")
        XCTAssertEqual(manager.uiFont(for: .title1).fontName, "AvenirNext-Bold")
        XCTAssertEqual(manager.uiFont(for: .tabBarItem).fontName, "AvenirNext-Medium")
    }

    func testRegisterMissingFontFileFails() {
        XCTAssertFalse(manager.registerFont(named: "DefinitelyMissingFont-Regular", bundle: Bundle(for: Self.self)))
    }

    // MARK: - UIKit Apply Helpers

    func testLabelApply() {
        let label = UILabel()
        label.appFont(.headline)
        XCTAssertEqual(label.font, manager.uiFont(for: .headline))
        XCTAssertTrue(label.adjustsFontForContentSizeCategory)

        let nonScalableLabel = UILabel()
        nonScalableLabel.appFont(.navigationTitle)
        XCTAssertFalse(nonScalableLabel.adjustsFontForContentSizeCategory)

        manager.respectsDynamicType = false
        let fixedLabel = UILabel()
        fixedLabel.appFont(.headline)
        XCTAssertFalse(fixedLabel.adjustsFontForContentSizeCategory)
    }

    func testTextInputApply() {
        let textField = UITextField()
        textField.appFont(.textFieldText)
        XCTAssertEqual(textField.font, manager.uiFont(for: .textFieldText))
        XCTAssertTrue(textField.adjustsFontForContentSizeCategory)

        let textView = UITextView()
        textView.appFont(.body)
        XCTAssertEqual(textView.font, manager.uiFont(for: .body))
        XCTAssertTrue(textView.adjustsFontForContentSizeCategory)
    }

    func testPlaceholderApplyKeepsExistingAttributes() {
        let textField = UITextField()
        textField.attributedPlaceholder = NSAttributedString(string: "Email", attributes: [.foregroundColor: UIColor.gray])
        textField.appPlaceholderFont()

        let placeholder = textField.attributedPlaceholder
        XCTAssertEqual(placeholder?.string, "Email")
        XCTAssertEqual(placeholder?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, manager.uiFont(for: .textFieldPlaceholder))
        XCTAssertEqual(placeholder?.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat, manager.scaleSpec(for: .textFieldPlaceholder).tracking)
        XCTAssertEqual(placeholder?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .gray)

        let empty = UITextField()
        empty.appPlaceholderFont()
        XCTAssertNil(empty.attributedPlaceholder)
    }

    func testButtonApply() {
        let button = UIButton(type: .system)
        button.appFont(.buttonPrimary)
        XCTAssertEqual(button.titleLabel?.font, manager.uiFont(for: .buttonPrimary))

        if #available(iOS 15.0, *) {
            let modernButton = UIButton(configuration: .filled())
            modernButton.appFont(.buttonPrimary)
            XCTAssertTrue(modernButton.titleLabel?.adjustsFontForContentSizeCategory == true)

            let transformer = modernButton.configuration?.titleTextAttributesTransformer
            XCTAssertNotNil(transformer)
            let transformed = transformer?.transform(AttributeContainer())
            XCTAssertEqual(transformed?[AttributeScopes.UIKitAttributes.FontAttribute.self], manager.uiFont(for: .buttonPrimary))
        }
    }

    // MARK: - Navigation & Tab Bars

    func testNavigationBarApplyKeepsExistingAppearance() {
        let bar = UINavigationBar()
        let standard = UINavigationBarAppearance()
        standard.configureWithOpaqueBackground()
        standard.titleTextAttributes = [.foregroundColor: UIColor.red]
        bar.standardAppearance = standard

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        bar.scrollEdgeAppearance = scrollEdge

        manager.apply(to: bar)

        let titleFont = manager.uiFont(for: .navigationTitle)
        let largeTitleFont = manager.uiFont(for: .largeTitle)
        XCTAssertEqual(bar.standardAppearance.titleTextAttributes[.font] as? UIFont, titleFont)
        XCTAssertEqual(bar.standardAppearance.largeTitleTextAttributes[.font] as? UIFont, largeTitleFont)
        XCTAssertEqual(bar.standardAppearance.titleTextAttributes[.foregroundColor] as? UIColor, .red)

        // Transparent scroll-edge appearance keeps its background and gains the fonts.
        XCTAssertNil(bar.scrollEdgeAppearance?.shadowColor)
        XCTAssertNil(bar.scrollEdgeAppearance?.backgroundEffect)
        XCTAssertEqual(bar.scrollEdgeAppearance?.titleTextAttributes[.font] as? UIFont, titleFont)

        // Unset appearances stay unset so UIKit keeps deriving them.
        XCTAssertNil(bar.compactAppearance)
        if #available(iOS 15.0, *) {
            XCTAssertNil(bar.compactScrollEdgeAppearance)
        }

        XCTAssertEqual(bar.titleTextAttributes?[.font] as? UIFont, titleFont)
        XCTAssertEqual(bar.largeTitleTextAttributes?[.font] as? UIFont, largeTitleFont)
    }

    func testTabBarApplyKeepsExistingAppearanceAndProxy() {
        let tabBar = UITabBar()
        let appearance = UITabBarAppearance()
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.green]
        tabBar.standardAppearance = appearance
        let proxyFontBefore = UITabBarItem.appearance().titleTextAttributes(for: .normal)?[.font] as? UIFont

        manager.applyTabBarFont(to: tabBar)

        let font = manager.uiFont(for: .tabBarItem)
        let normal = tabBar.standardAppearance.stackedLayoutAppearance.normal.titleTextAttributes
        XCTAssertEqual(normal[.font] as? UIFont, font)
        XCTAssertEqual(normal[.foregroundColor] as? UIColor, .green)
        XCTAssertEqual(tabBar.standardAppearance.stackedLayoutAppearance.selected.titleTextAttributes[.font] as? UIFont, font)
        XCTAssertEqual(tabBar.standardAppearance.inlineLayoutAppearance.normal.titleTextAttributes[.font] as? UIFont, font)
        XCTAssertEqual(tabBar.standardAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes[.font] as? UIFont, font)
        if #available(iOS 15.0, *) {
            XCTAssertNil(tabBar.scrollEdgeAppearance)
        }
        XCTAssertEqual(UITabBarItem.appearance().titleTextAttributes(for: .normal)?[.font] as? UIFont, proxyFontBefore)
    }

    func testTabBarApplyWithoutBarUpdatesProxy() {
        let proxy = UITabBarItem.appearance()
        proxy.setTitleTextAttributes([.foregroundColor: UIColor.blue], for: .normal)
        defer {
            proxy.setTitleTextAttributes(nil, for: .normal)
            proxy.setTitleTextAttributes(nil, for: .selected)
        }

        manager.applyTabBarFont()

        let font = manager.uiFont(for: .tabBarItem)
        XCTAssertEqual(proxy.titleTextAttributes(for: .normal)?[.font] as? UIFont, font)
        XCTAssertEqual(proxy.titleTextAttributes(for: .normal)?[.foregroundColor] as? UIColor, .blue)
        XCTAssertEqual(proxy.titleTextAttributes(for: .selected)?[.font] as? UIFont, font)
    }

    // MARK: - SwiftUI

    private func fittingHeight<V: View>(_ view: V, sizeCategory: ContentSizeCategory) -> CGFloat {
        let host = UIHostingController(rootView: view.environment(\.sizeCategory, sizeCategory))
        return host.sizeThatFits(in: CGSize(width: 2000, height: 2000)).height
    }

    func testTextAppFontFollowsEnvironmentSizeCategory() {
        let text = Text("Welcome").appFont(.body)
        XCTAssertGreaterThan(
            fittingHeight(text, sizeCategory: .accessibilityExtraExtraExtraLarge),
            fittingHeight(text, sizeCategory: .large)
        )
    }

    func testViewAppFontFollowsEnvironmentSizeCategory() {
        let stack = VStack { Text("Header"); Text("Body") }.appFont(.body)
        XCTAssertGreaterThan(
            fittingHeight(stack, sizeCategory: .accessibilityExtraExtraExtraLarge),
            fittingHeight(stack, sizeCategory: .large)
        )
    }

    func testTextAppFontWithSizeCategoryKeepsTextType() {
        let combined: Text = Text("A").appFont(.headline, sizeCategory: .large) + Text("B")
        XCTAssertGreaterThan(fittingHeight(combined, sizeCategory: .large), 0)
    }
}
