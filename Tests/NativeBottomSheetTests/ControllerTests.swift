import XCTest
@testable import NativeBottomSheet

/// These tests do not present anything. A test bundle without a host app cannot present reliably.
@MainActor
final class ControllerTests: XCTestCase {
    private func makeView(height: CGFloat) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    private func makeController(_ content: BottomSheetContent, sizing: BottomSheetSizing = .dynamic()) -> BottomSheetController {
        BottomSheetController(content: content, sizing: sizing, configuration: BottomSheetConfiguration())
    }

    func testPrepareMeasuresTheContent() {
        let controller = makeController(.view(makeView(height: 120)))
        controller.prepare(for: UIViewController())
        XCTAssertEqual(controller.diagnostics.measuredContentHeight, 120, accuracy: 0.5)
    }

    func testPrepareWorksWithAPresenterThatHasNoWindow() {
        let presenter = UIViewController() // its view is not loaded
        let controller = makeController(.view(makeView(height: 80)))
        controller.prepare(for: presenter)
        XCTAssertFalse(presenter.isViewLoaded)
        XCTAssertEqual(controller.diagnostics.measuredContentHeight, 80, accuracy: 0.5)
    }

    func testUpdateHeightChangesTheSizing() {
        let controller = makeController(.view(makeView(height: 120)))
        controller.updateHeight(400, animated: false)
        XCTAssertEqual(controller.sizing, .fixed(400))
        XCTAssertEqual(controller.diagnostics.requestedHeight, 400)
    }

    func testSameHeightTwiceInvalidatesOnce() {
        let controller = makeController(.view(makeView(height: 120)))
        controller.updateHeight(400, animated: false)
        let invalidations = controller.diagnostics.invalidations
        controller.updateHeight(400, animated: false)
        XCTAssertEqual(controller.diagnostics.invalidations, invalidations)
    }

    func testNaNHeightIsHandledAndNotRepeated() {
        let controller = makeController(.view(makeView(height: 120)))
        controller.updateHeight(.nan, animated: false)
        XCTAssertEqual(controller.sizing, .fixed(0))
        let invalidations = controller.diagnostics.invalidations
        controller.updateHeight(.nan, animated: false)
        XCTAssertEqual(controller.diagnostics.invalidations, invalidations)
    }

    func testSelectedDetentIsKeptInRangeWhenDetentsShrink() {
        let controller = makeController(.view(makeView(height: 120)), sizing: .detents([.fixed(100), .medium, .large]))
        controller.selectDetent(at: 2, animated: false)
        controller.setSizing(.detents([.fixed(100), .medium]), animated: false)
        XCTAssertEqual(controller.diagnostics.selectedDetentIndex, 1)
    }

    func testSelectingAnInvalidDetentIsIgnored() {
        let controller = makeController(.view(makeView(height: 120)), sizing: .detents([.fixed(100), .large]))
        controller.selectDetent(at: -1, animated: false)
        controller.selectDetent(at: 5, animated: false)
        XCTAssertEqual(controller.diagnostics.selectedDetentIndex, 0)
    }

    func testViewIsRestoredWhenTheSheetReleasesIt() {
        let view = makeView(height: 120)
        view.translatesAutoresizingMaskIntoConstraints = true
        let controller = makeController(.view(view))
        controller.loadViewIfNeeded()
        XCTAssertNotNil(view.superview)
        controller.releaseContent()
        XCTAssertNil(view.superview)
        XCTAssertTrue(view.translatesAutoresizingMaskIntoConstraints)
    }

    func testControllerContentCanBeReusedAfterRelease() {
        let child = UIViewController()
        let first = makeController(.viewController(child))
        first.loadViewIfNeeded()
        XCTAssertTrue(child.parent === first)
        first.releaseContent()
        XCTAssertNil(child.parent)

        let second = makeController(.viewController(child))
        second.loadViewIfNeeded()
        XCTAssertTrue(child.parent === second)
    }

    func testContentThatHasAParentIsMoved() {
        let oldParent = UIViewController()
        let child = UIViewController()
        oldParent.addChild(child)
        oldParent.view.addSubview(child.view)
        child.didMove(toParent: oldParent)

        let controller = makeController(.viewController(child))
        controller.loadViewIfNeeded()
        XCTAssertTrue(child.parent === controller)
        XCTAssertFalse(child.view.superview === oldParent.view)
    }

    func testReleaseTwiceIsSafe() {
        let controller = makeController(.view(makeView(height: 120)))
        controller.loadViewIfNeeded()
        controller.releaseContent()
        controller.releaseContent()
    }

    func testReleaseBeforeTheViewIsLoadedIsSafe() {
        makeController(.view(makeView(height: 120))).releaseContent()
    }

    #if DEBUG
    func testControllersAreNotLeaked() {
        let before = BottomSheetController.liveCount
        autoreleasepool {
            for _ in 0..<50 {
                let controller = makeController(.view(makeView(height: 120)))
                controller.loadViewIfNeeded()
                controller.updateHeight(300, animated: false)
                controller.push(content: .view(makeView(height: 80)), header: makeView(height: 40), footer: makeView(height: 40), animated: false, completion: nil)
                controller.onDiagnosticsChange = { _ in }
            }
        }
        XCTAssertEqual(BottomSheetController.liveCount, before)
    }
    #endif
}

@MainActor
final class HandleTests: XCTestCase {
    func testContentThatIsThePresenterIsRefused() {
        let host = UIViewController()
        let done = expectation(description: "completion")
        let sheet = BottomSheet.present(content: host, from: host, animated: false) { done.fulfill() }
        wait(for: [done], timeout: 2)
        XCTAssertNil(sheet.diagnostics)
    }

    func testContentThatIsAParentOfThePresenterIsRefused() {
        let parent = UIViewController()
        let host = UIViewController()
        parent.addChild(host)
        parent.view.addSubview(host.view)
        host.didMove(toParent: parent)
        let sheet = BottomSheet.present(content: parent, from: host, animated: false)
        XCTAssertNil(sheet.diagnostics)
    }

    func testViewAbovethePresenterViewIsRefused() {
        let host = UIViewController()
        let container = UIView()
        container.addSubview(host.view)
        let sheet = BottomSheet.present(content: container, from: host, animated: false)
        XCTAssertNil(sheet.diagnostics)
    }

    func testDismissOnAGoneSheetStillCallsTheCompletion() {
        let host = UIViewController()
        let sheet = BottomSheet.present(content: host, from: host, animated: false)
        let done = expectation(description: "completion")
        sheet.dismiss(animated: false) { done.fulfill() }
        wait(for: [done], timeout: 2)
    }

    func testControlsOnAGoneSheetDoNothing() {
        let host = UIViewController()
        let sheet = BottomSheet.present(content: host, from: host, animated: false)
        sheet.updateHeight(300, animated: true)
        sheet.setSizing(.large)
        sheet.selectDetent(at: 3)
        sheet.invalidateContentHeight()
        sheet.configuration = BottomSheetConfiguration(showsGrabber: true)
        XCTAssertNil(sheet.configuration)
        XCTAssertNil(sheet.diagnostics)
    }
}
