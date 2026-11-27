import XCTest
@testable import NativeBottomSheet

/// These tests do not present anything. They call the UIKit delegate methods and lifecycle methods directly.
@MainActor
final class CallbackTests: XCTestCase {
    private func makeView(height: CGFloat = 100) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    private func makeController(sizing: BottomSheetSizing = .dynamic()) -> BottomSheetController {
        let controller = BottomSheetController(content: .view(makeView()), sizing: sizing, configuration: BottomSheetConfiguration())
        controller.prepare(for: UIViewController())
        return controller
    }

    // MARK: Pages

    func testPageChangeReportsTheNewCount() {
        let controller = makeController()
        var counts: [Int] = []
        controller.onPageChange = { counts.append($0) }
        controller.push(content: .view(makeView()), header: nil, footer: nil, animated: false, completion: nil)
        controller.push(content: .view(makeView()), header: nil, footer: nil, animated: false, completion: nil)
        controller.pop(animated: false, completion: nil)
        controller.popToRoot(animated: false, completion: nil)
        XCTAssertEqual(counts, [2, 3, 2, 1])
    }

    func testPageChangeIsNotReportedForARefusedPushOrAPopOnTheFirstPage() {
        let controller = makeController()
        var counts: [Int] = []
        controller.onPageChange = { counts.append($0) }
        controller.pop(animated: false, completion: nil)
        controller.push(content: .viewController(controller), header: nil, footer: nil, animated: false, completion: nil)
        XCTAssertEqual(counts, [])
    }

    // MARK: Detents

    func testDetentChangeIsReportedOnceForEachChange() {
        let controller = makeController(sizing: .detents([.fixed(100), .medium, .large]))
        var indexes: [Int] = []
        controller.onDetentChange = { indexes.append($0) }
        controller.selectDetent(at: 1, animated: false)
        controller.selectDetent(at: 1, animated: false) // the same detent: no report
        controller.selectDetent(at: 2, animated: false)
        XCTAssertEqual(indexes, [1, 2])
    }

    func testAMoveByTheUserAfterSelectDetentIsNotReportedTwice() {
        let controller = makeController(sizing: .detents([.fixed(100), .medium, .large]))
        var indexes: [Int] = []
        controller.onDetentChange = { indexes.append($0) }
        controller.selectDetent(at: 1, animated: false)
        // UIKit may call the delegate for the same move.
        controller.sheetPresentationControllerDidChangeSelectedDetentIdentifier(controller.sheetPresentationController!)
        XCTAssertEqual(indexes, [1])
    }

    func testDetentChangeIsReportedWhenFewerDetentsMoveTheSelection() {
        let controller = makeController(sizing: .detents([.fixed(100), .medium, .large]))
        controller.selectDetent(at: 2, animated: false)
        var indexes: [Int] = []
        controller.onDetentChange = { indexes.append($0) }
        controller.setSizing(.detents([.fixed(100), .medium]), animated: false)
        XCTAssertEqual(indexes, [1])
    }

    // MARK: Dismissal

    private func expectDismiss(_ controller: BottomSheetController, after action: () -> Void) -> [BottomSheetDismissReason] {
        var reasons: [BottomSheetDismissReason] = []
        controller.onDismiss = { reasons.append($0) }
        action()
        let done = expectation(description: "turn")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { done.fulfill() }
        wait(for: [done], timeout: 2)
        return reasons
    }

    func testDismissByCodeIsProgrammatic() {
        let controller = makeController()
        controller.loadViewIfNeeded()
        let reasons = expectDismiss(controller) { controller.viewDidDisappear(false) }
        XCTAssertEqual(reasons.count, 1)
        XCTAssertEqual(reasons.first, .programmatic)
    }

    func testDismissByTheUserIsInteractive() {
        let controller = makeController()
        controller.loadViewIfNeeded()
        let reasons = expectDismiss(controller) {
            controller.presentationControllerDidDismiss(controller.presentationController!)
            controller.viewDidDisappear(false)
        }
        XCTAssertEqual(reasons, [.interactive])
    }

    func testInteractiveDismissIsRecognisedWhenUIKitCallsInTheOtherOrder() {
        let controller = makeController()
        controller.loadViewIfNeeded()
        let reasons = expectDismiss(controller) {
            controller.viewDidDisappear(false)
            controller.presentationControllerDidDismiss(controller.presentationController!)
        }
        XCTAssertEqual(reasons, [.interactive])
    }

    func testDismissIsReportedOnlyOnce() {
        let controller = makeController()
        controller.loadViewIfNeeded()
        let reasons = expectDismiss(controller) {
            controller.viewDidDisappear(false)
            controller.viewDidDisappear(false)
        }
        XCTAssertEqual(reasons.count, 1)
    }

    func testTheReasonSurvivesTheControllerBeingReleased() {
        // The presenter releases the controller right after a dismissal. This is what happens on a device.
        var reasons: [BottomSheetDismissReason] = []
        autoreleasepool {
            var controller: BottomSheetController? = makeController()
            controller?.loadViewIfNeeded()
            controller?.onDismiss = { reasons.append($0) }
            controller?.presentationControllerDidDismiss(controller!.presentationController!)
            controller?.viewDidDisappear(false)
            controller = nil
        }
        let done = expectation(description: "turn")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { done.fulfill() }
        wait(for: [done], timeout: 2)
        XCTAssertEqual(reasons, [.interactive])
    }

    func testAttemptToDismissIsReported() {
        let controller = makeController()
        var attempts = 0
        controller.onAttemptToDismiss = { attempts += 1 }
        controller.presentationControllerDidAttemptToDismiss(controller.presentationController!)
        XCTAssertEqual(attempts, 1)
    }

    // MARK: Memory

    func testCallbacksAreDroppedWhenTheSheetCloses() {
        let controller = makeController()
        controller.loadViewIfNeeded()
        weak var probe: NSObject?
        autoreleasepool {
            let object = NSObject()
            probe = object
            controller.onPageChange = { _ in _ = object }
            controller.onDetentChange = { _ in _ = object }
            controller.onAttemptToDismiss = { _ = object }
            controller.onDiagnosticsChange = { _ in _ = object }
        }
        XCTAssertNotNil(probe)
        controller.releaseContent()
        XCTAssertNil(probe)
    }

    func testTheDismissCallbackIsDroppedAfterItRan() {
        let controller = makeController()
        controller.loadViewIfNeeded()
        weak var probe: NSObject?
        autoreleasepool {
            let object = NSObject()
            probe = object
            controller.onDismiss = { _ in _ = object }
        }
        controller.viewDidDisappear(false)
        let done = expectation(description: "turn")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { done.fulfill() }
        wait(for: [done], timeout: 2)
        XCTAssertNil(probe)
    }
}

@MainActor
final class HandleEventTests: XCTestCase {
    func testEventPropertiesOnAGoneSheetDoNothing() {
        let host = UIViewController()
        let sheet = BottomSheet.present(content: host, from: host, animated: false) // refused: an inert handle
        sheet.onDismiss = { _ in }
        sheet.onAttemptToDismiss = {}
        sheet.onDetentChange = { _ in }
        sheet.onPageChange = { _ in }
        XCTAssertNil(sheet.onDismiss)
        XCTAssertNil(sheet.onAttemptToDismiss)
        XCTAssertNil(sheet.onDetentChange)
        XCTAssertNil(sheet.onPageChange)
    }
}

@MainActor
final class DimmingTests: XCTestCase {
    func testDimmingColorIsOffByDefault() {
        XCTAssertNil(BottomSheetConfiguration().dimmingColor)
        XCTAssertEqual(BottomSheetConfiguration(dimmingColor: .red).dimmingColor, .red)
    }

    func testTheDimmingGoesOnTheTopMostAncestor() {
        let root = UINavigationController(rootViewController: UIViewController())
        let screen = root.viewControllers[0]
        XCTAssertTrue(BottomSheetController.topAncestor(of: screen) === root)
        XCTAssertTrue(BottomSheetController.topAncestor(of: root) === root)
        XCTAssertNil(BottomSheetController.topAncestor(of: nil))
    }

    func testASheetOnASheetUsesTheLowerSheetAsTheAncestor() {
        let lower = BottomSheetController(content: .view(UIView()), sizing: .dynamic(), configuration: BottomSheetConfiguration())
        XCTAssertTrue(BottomSheetController.topAncestor(of: lower) === lower)
    }

    func testNoDimmingLayerWithoutAPresenter() {
        // `viewWillAppear` without a presenting controller must not crash, and must not add a layer.
        let controller = BottomSheetController(
            content: .view(UIView()), sizing: .dynamic(),
            configuration: BottomSheetConfiguration(dimmingColor: UIColor.black.withAlphaComponent(0.5))
        )
        controller.loadViewIfNeeded()
        controller.viewWillAppear(false)
        controller.viewWillDisappear(false)
        controller.releaseContent()
    }

    func testChangingTheConfigurationBeforeTheSheetIsShownIsSafe() {
        let controller = BottomSheetController(content: .view(UIView()), sizing: .dynamic(), configuration: BottomSheetConfiguration())
        controller.configuration = BottomSheetConfiguration(dimsBackground: true, dimmingColor: .blue)
        controller.configuration = BottomSheetConfiguration(dimsBackground: false, dimmingColor: .blue)
        controller.configuration = BottomSheetConfiguration()
    }
}
