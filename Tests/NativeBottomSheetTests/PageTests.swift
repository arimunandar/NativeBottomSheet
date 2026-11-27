import XCTest
@testable import NativeBottomSheet

/// These tests do not present anything. Without a window, pushes and pops run at once, without animation.
@MainActor
final class PageTests: XCTestCase {
    private func makeView(height: CGFloat) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    private func makeController(content: UIView? = nil, header: UIView? = nil, footer: UIView? = nil) -> BottomSheetController {
        let controller = BottomSheetController(
            content: .view(content ?? makeView(height: 100)), header: header, footer: footer,
            sizing: .dynamic(), configuration: BottomSheetConfiguration()
        )
        controller.prepare(for: UIViewController())
        return controller
    }

    // MARK: Header and footer

    func testPageHeightIsHeaderPlusContentPlusFooter() {
        let controller = makeController(content: makeView(height: 100), header: makeView(height: 50), footer: makeView(height: 30))
        XCTAssertEqual(controller.diagnostics.measuredContentHeight, 180, accuracy: 0.5)
    }

    func testHeaderIsPinnedToTheTopAndFooterToTheBottom() {
        let header = makeView(height: 50)
        let footer = makeView(height: 30)
        let controller = makeController(content: makeView(height: 100), header: header, footer: footer)
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        controller.view.layoutIfNeeded()
        let page = controller.pages[0].view
        XCTAssertEqual(header.convert(header.bounds, to: page).minY, 0, accuracy: 0.5)
        XCTAssertEqual(footer.convert(footer.bounds, to: page).maxY, page.bounds.maxY, accuracy: 0.5)
        // The header and the footer never overlap. (Off-window, the page height is a guess, so the content area is not checked.)
        XCTAssertLessThanOrEqual(header.convert(header.bounds, to: page).maxY, footer.convert(footer.bounds, to: page).minY + 0.5)
    }

    func testHeaderAndFooterAreGivenBackOnRelease() {
        let header = makeView(height: 50)
        let footer = makeView(height: 30)
        header.translatesAutoresizingMaskIntoConstraints = true
        let controller = makeController(header: header, footer: footer)
        XCTAssertNotNil(header.superview)
        controller.releaseContent()
        XCTAssertNil(header.superview)
        XCTAssertNil(footer.superview)
        XCTAssertTrue(header.translatesAutoresizingMaskIntoConstraints)
    }

    // MARK: Push and pop

    func testPushAddsAPageAndTheSheetFollowsItsHeight() {
        let controller = makeController(content: makeView(height: 100))
        controller.push(content: .view(makeView(height: 250)), header: nil, footer: nil, animated: true, completion: nil)
        XCTAssertEqual(controller.pageCount, 2)
        XCTAssertEqual(controller.diagnostics.measuredContentHeight, 250, accuracy: 0.5)
    }

    func testPopReturnsToThePageBelowWithItsHeight() {
        let controller = makeController(content: makeView(height: 100))
        controller.push(content: .view(makeView(height: 250)), header: nil, footer: nil, animated: false, completion: nil)
        controller.pop(animated: false, completion: nil)
        XCTAssertEqual(controller.pageCount, 1)
        XCTAssertEqual(controller.diagnostics.measuredContentHeight, 100, accuracy: 0.5)
        XCTAssertFalse(controller.pages[0].view.isHidden)
    }

    func testPopOnTheFirstPageDoesNothingButRunsTheCompletion() {
        let controller = makeController()
        var completed = false
        controller.pop(animated: false) { completed = true }
        XCTAssertEqual(controller.pageCount, 1)
        XCTAssertTrue(completed)
    }

    func testPopToRootKeepsOnlyTheFirstPage() {
        let controller = makeController(content: makeView(height: 100))
        for height in [150, 200, 250] as [CGFloat] {
            controller.push(content: .view(makeView(height: height)), header: nil, footer: nil, animated: false, completion: nil)
        }
        XCTAssertEqual(controller.pageCount, 4)
        controller.popToRoot(animated: false, completion: nil)
        XCTAssertEqual(controller.pageCount, 1)
        XCTAssertEqual(controller.diagnostics.measuredContentHeight, 100, accuracy: 0.5)
    }

    func testPoppedContentIsGivenBack() {
        let controller = makeController()
        let pushed = makeView(height: 250)
        pushed.translatesAutoresizingMaskIntoConstraints = true
        controller.push(content: .view(pushed), header: nil, footer: nil, animated: false, completion: nil)
        XCTAssertNotNil(pushed.superview)
        controller.pop(animated: false, completion: nil)
        XCTAssertNil(pushed.superview)
        XCTAssertTrue(pushed.translatesAutoresizingMaskIntoConstraints)
    }

    func testPoppedControllerCanBePushedAgain() {
        let controller = makeController()
        let child = UIViewController()
        controller.push(content: .viewController(child), header: nil, footer: nil, animated: false, completion: nil)
        XCTAssertTrue(child.parent === controller)
        controller.pop(animated: false, completion: nil)
        XCTAssertNil(child.parent)
        controller.push(content: .viewController(child), header: nil, footer: nil, animated: false, completion: nil)
        XCTAssertTrue(child.parent === controller)
        XCTAssertEqual(controller.pageCount, 2)
    }

    func testSeveralPushesInARowAllHappen() {
        let controller = makeController()
        for _ in 0..<5 {
            controller.push(content: .view(makeView(height: 120)), header: nil, footer: nil, animated: true, completion: nil)
        }
        XCTAssertEqual(controller.pageCount, 6)
    }

    // MARK: Refused pages

    func testPushingContentThatAPageAlreadyUsesIsRefused() {
        let shared = makeView(height: 100)
        let controller = makeController(content: shared)
        var completed = false
        controller.push(content: .view(shared), header: nil, footer: nil, animated: false) { completed = true }
        let done = expectation(description: "completion")
        DispatchQueue.main.async { done.fulfill() }
        wait(for: [done], timeout: 2)
        XCTAssertEqual(controller.pageCount, 1)
        XCTAssertTrue(completed)
    }

    func testHeaderThatIsAlsoTheContentIsRefused() {
        let controller = makeController()
        let same = makeView(height: 60)
        controller.push(content: .view(same), header: same, footer: nil, animated: false, completion: nil)
        XCTAssertEqual(controller.pageCount, 1)
    }

    func testPushingTheSheetControllerItselfIsRefused() {
        let controller = makeController()
        controller.push(content: .viewController(controller), header: nil, footer: nil, animated: false, completion: nil)
        XCTAssertEqual(controller.pageCount, 1)
    }

    func testPushAfterReleaseIsRefused() {
        let controller = makeController()
        controller.releaseContent()
        controller.push(content: .view(makeView(height: 100)), header: nil, footer: nil, animated: false, completion: nil)
        XCTAssertEqual(controller.pageCount, 1)
    }

    func testReleaseGivesBackEveryPage() {
        let controller = makeController()
        let views = (0..<3).map { _ in makeView(height: 100) }
        views.forEach { controller.push(content: .view($0), header: nil, footer: nil, animated: false, completion: nil) }
        controller.releaseContent()
        XCTAssertTrue(views.allSatisfy { $0.superview == nil })
    }
}

@MainActor
final class PageHandleTests: XCTestCase {
    func testHandlePageCallsOnAGoneSheetDoNothing() {
        let host = UIViewController()
        let sheet = BottomSheet.present(content: host, from: host, animated: false) // refused: an inert handle
        XCTAssertEqual(sheet.pageCount, 0)
        var count = 0
        sheet.push(content: UIView()) { count += 1 }
        sheet.pop { count += 1 }
        sheet.popToRoot { count += 1 }
        let done = expectation(description: "completions")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { done.fulfill() }
        wait(for: [done], timeout: 2)
        XCTAssertEqual(count, 3)
    }

    func testHeaderThatIsAboveThePresenterViewIsRefused() {
        let host = UIViewController()
        let header = UIView()
        header.addSubview(host.view)
        let sheet = BottomSheet.present(content: UIView(), header: header, from: host, animated: false)
        XCTAssertEqual(sheet.pageCount, 0)
    }
}
