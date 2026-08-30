import XCTest
import UIKit
import SwiftUI
@testable import FontManager

@MainActor
final class FontManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        FontManager.shared.fontSource = .system
        FontManager.shared.respectsDynamicType = true
        FontManager.shared.invalidateCache()
    }

    // MARK: - Style Enumeration & Scale Tables

    func testAllStylesResolveValidUIFont() {
        for style in AppTextStyle.allCases {
            let font = FontManager.shared.uiFont(for: style)
            XCTAssertGreaterThan(font.pointSize, 0, "Style \(style.rawValue) should have pointSize > 0")
        }
    }

    func testAllStylesResolveValidSwiftUIFont() {
        for style in AppTextStyle.allCases {
            let _ = FontManager.shared.swiftUIFont(for: style)
        }
    }

    func testScaleSpecsPhoneVsPad() {
        for style in AppTextStyle.allCases {
            let phoneSpec = FontManager.shared.scaleSpec(for: style, isIPad: false)
            let padSpec = FontManager.shared.scaleSpec(for: style, isIPad: true)

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
                    if i % 2 == 0 {
                        FontManager.shared.respectsDynamicType = (i % 4 == 0)
                    } else {
                        let _ = FontManager.shared.uiFont(for: .body)
                    }
                }
            }
        }
    }

    // MARK: - AttributedString Helpers

    func testAttributedStringGeneration() {
        let sample = "Hello FontManager"
        let attr = FontManager.shared.attributedString(sample, style: .largeTitle)

        XCTAssertEqual(attr.string, sample)
        let fontAttr = attr.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(fontAttr)
        let kernAttr = attr.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat
        XCTAssertNotNil(kernAttr)
        XCTAssertEqual(kernAttr, FontManager.shared.scaleSpec(for: .largeTitle).tracking)
    }

    @available(iOS 15.0, *)
    func testModernAttributedStringGeneration() {
        let sample = "Swift AttributedString"
        let attr = FontManager.shared.attributedString(sample, style: .headline)
        XCTAssertEqual(String(attr.characters), sample)
    }

    // MARK: - Custom Font Fallback

    func testUnregisteredCustomFontFallsBackGracefully() {
        // Setting an unregistered custom font family should fall back to system font
        FontManager.shared.fontSource = .custom(familyName: "NonExistentFontFamilyXYZ")
        let font = FontManager.shared.uiFont(for: .title1)
        XCTAssertNotNil(font)
        XCTAssertGreaterThan(font.pointSize, 0)
    }

    // MARK: - UIKit Apply Helpers

    func testUIKitApplyHelpers() {
        let label = UILabel()
        label.appFont(.headline)
        XCTAssertNotNil(label.font)
        XCTAssertTrue(label.adjustsFontForContentSizeCategory)

        let nonScalableLabel = UILabel()
        nonScalableLabel.appFont(.navigationTitle)
        XCTAssertFalse(nonScalableLabel.adjustsFontForContentSizeCategory)

        let textField = UITextField()
        textField.appFont(.textFieldText)
        XCTAssertNotNil(textField.font)

        let textView = UITextView()
        textView.appFont(.body)
        XCTAssertNotNil(textView.font)

        let button = UIButton()
        button.appFont(.buttonPrimary)
        XCTAssertNotNil(button.titleLabel?.font)

        if #available(iOS 15.0, *) {
            let config = UIButton.Configuration.filled()
            let modernButton = UIButton(configuration: config)
            modernButton.appFont(.buttonPrimary)
            XCTAssertNotNil(modernButton.configuration?.titleTextAttributesTransformer)
            XCTAssertTrue(modernButton.titleLabel?.adjustsFontForContentSizeCategory == true)

            if let transformer = modernButton.configuration?.titleTextAttributesTransformer {
                let container = AttributeContainer()
                let transformed = transformer.transform(container)
                let font = transformed[AttributeScopes.UIKitAttributes.FontAttribute.self]
                XCTAssertNotNil(font)
            }
        }

        let navBar = UINavigationBar()
        FontManager.shared.apply(to: navBar)
        XCTAssertNotNil(navBar.titleTextAttributes?[.font])
        XCTAssertNotNil(navBar.largeTitleTextAttributes?[.font])

        let tabBar = UITabBar()
        FontManager.shared.applyTabBarFont(to: tabBar)
        XCTAssertNotNil(tabBar.standardAppearance.stackedLayoutAppearance.normal.titleTextAttributes[.font])
    }
}
