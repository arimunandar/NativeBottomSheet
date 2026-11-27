import XCTest
@testable import NativeBottomSheet

@MainActor
final class HeightResolverTests: XCTestCase {
    private let resolver = BottomSheetHeightResolver()

    func testFixedHeightIsUsed() {
        XCTAssertEqual(resolver.detentHeight(for: .fixed(300), contentHeight: 0, maximum: 800), 300)
    }

    func testNoHeightReachesTheMaximum() {
        // At the exact maximum UIKit pushes the page behind the sheet back.
        XCTAssertEqual(resolver.detentHeight(for: .fixed(.infinity), contentHeight: 0, maximum: 800), 799)
        XCTAssertEqual(resolver.detentHeight(for: .fixed(900), contentHeight: 0, maximum: 800), 799)
        XCTAssertEqual(resolver.detentHeight(for: .large, contentHeight: 0, maximum: 800), 799)
        XCTAssertEqual(resolver.detentHeight(for: .dynamic(), contentHeight: 5000, maximum: 800), 799)
    }

    func testDynamicFollowsContent() {
        XCTAssertEqual(resolver.detentHeight(for: .dynamic(), contentHeight: 250, maximum: 800), 250)
    }

    func testDynamicRespectsMinimumAndMaximum() {
        let sizing = BottomSheetSizing.dynamic(minHeight: 200, maxHeight: 400)
        XCTAssertEqual(resolver.detentHeight(for: sizing, contentHeight: 50, maximum: 800), 200)
        XCTAssertEqual(resolver.detentHeight(for: sizing, contentHeight: 300, maximum: 800), 300)
        XCTAssertEqual(resolver.detentHeight(for: sizing, contentHeight: 900, maximum: 800), 400)
    }

    func testDynamicMinimumNeverExceedsMaximum() {
        let sizing = BottomSheetSizing.dynamic(minHeight: 500, maxHeight: 300)
        XCTAssertEqual(resolver.detentHeight(for: sizing, contentHeight: 100, maximum: 800), 300)
    }

    func testFractionalUsesTheMaximum() {
        XCTAssertEqual(resolver.detentHeight(for: .fractional(0.5), contentHeight: 0, maximum: 801), 400)
        XCTAssertEqual(resolver.detentHeight(for: .fractional(2), contentHeight: 0, maximum: 801), 800)
    }

    func testPlainViewIsMeasuredWithAutoLayout() {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 120).isActive = true
        XCTAssertEqual(resolver.contentHeight(of: .view(view), width: 320, topInset: 0), 120, accuracy: 0.5)
        XCTAssertEqual(resolver.contentHeight(of: .view(view), width: 320, topInset: 10), 130, accuracy: 0.5)
    }

    func testMultilineLabelDependsOnWidth() {
        let label = UILabel()
        label.numberOfLines = 0
        label.text = String(repeating: "Word ", count: 60)
        label.translatesAutoresizingMaskIntoConstraints = false
        let narrow = resolver.contentHeight(of: .view(label), width: 150, topInset: 0)
        let wide = resolver.contentHeight(of: .view(label), width: 600, topInset: 0)
        XCTAssertGreaterThan(narrow, wide)
    }

    func testPreferredContentSizeWinsForControllers() {
        let controller = UIViewController()
        controller.preferredContentSize = CGSize(width: 0, height: 333)
        XCTAssertEqual(resolver.contentHeight(of: .viewController(controller), width: 320, topInset: 0), 333)
    }

    func testTinyMaximumNeverGivesNegativeHeight() {
        XCTAssertEqual(resolver.detentHeight(for: .large, contentHeight: 0, maximum: 0.5), 0)
        XCTAssertEqual(resolver.detentHeight(for: .fixed(100), contentHeight: 0, maximum: 0), 0)
    }

    func testEmptyScrollViewReportsAtLeastOnePoint() {
        // A height of 0 would stop a collection view from laying out, and the sheet could never grow.
        XCTAssertEqual(resolver.contentHeight(of: .view(UIScrollView()), width: 320, topInset: 0), 1)
    }
}

final class SizingTests: XCTestCase {
    func testDetentsAreFlattened() {
        let sizing = BottomSheetSizing.detents([.fixed(100), .detents([.medium, .large])])
        XCTAssertEqual(sizing.detentList, [.fixed(100), .medium, .large])
    }

    func testEmptyDetentsFallBackToLarge() {
        XCTAssertEqual(BottomSheetSizing.detents([]).detentList, [.large])
    }

    func testFollowsContentOnlyForDynamic() {
        XCTAssertTrue(BottomSheetSizing.dynamic().followsContent)
        XCTAssertTrue(BottomSheetSizing.detents([.fixed(100), .dynamic()]).followsContent)
        XCTAssertFalse(BottomSheetSizing.fixed(100).followsContent)
        XCTAssertFalse(BottomSheetSizing.medium.followsContent)
    }

    func testNumbersAreSanitized() {
        XCTAssertEqual(BottomSheetSizing.fixed(.nan).sanitized, .fixed(0))
        XCTAssertEqual(BottomSheetSizing.fixed(-50).sanitized, .fixed(0))
        XCTAssertEqual(BottomSheetSizing.fixed(.infinity).sanitized, .fixed(.infinity))
        XCTAssertEqual(BottomSheetSizing.fractional(.nan).sanitized, .fractional(0))
        XCTAssertEqual(BottomSheetSizing.fractional(3).sanitized, .fractional(1))
        XCTAssertEqual(BottomSheetSizing.dynamic(minHeight: -5, maxHeight: .nan).sanitized, .dynamic(minHeight: 0, maxHeight: nil))
        XCTAssertEqual(BottomSheetSizing.dynamic(minHeight: 10, maxHeight: -1).sanitized, .dynamic(minHeight: 10, maxHeight: 0))
        XCTAssertEqual(BottomSheetSizing.detents([.fixed(.nan), .medium]).sanitized, .detents([.fixed(0), .medium]))
    }

    func testSanitizedSizingCanBeCompared() {
        // NaN is never equal to itself, so an unsanitized `.fixed(.nan)` would never match the last sizing.
        XCTAssertEqual(BottomSheetSizing.fixed(.nan).sanitized, BottomSheetSizing.fixed(.nan).sanitized)
    }

    func testConfigurationDefaults() {
        let configuration = BottomSheetConfiguration()
        XCTAssertNil(configuration.cornerRadius)
        XCTAssertFalse(configuration.showsGrabber)
        XCTAssertTrue(configuration.allowsInteractiveDismissal)
        XCTAssertTrue(configuration.prefersScrollingExpandsWhenScrolledToEdge)
        XCTAssertTrue(configuration.dimsBackground)
        XCTAssertNil(configuration.backgroundColor)
        XCTAssertNil(configuration.grabberColor)
    }
}
