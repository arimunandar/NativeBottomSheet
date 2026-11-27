import UIKit

/// Why a sheet closed.
public enum BottomSheetDismissReason {
    /// The user dragged the sheet down, or tapped the dimmed area.
    case interactive
    /// Your code dismissed it, or UIKit did, for example when the presenter went away.
    case programmatic
}

/// A native bottom sheet built on `UISheetPresentationController`.
///
/// Present content with one call. The sheet follows the content height by default:
///
/// ```swift
/// let sheet = BottomSheet.present(content: myView, from: self)
/// ```
///
/// A sheet shows pages. A page is an optional header pinned to the top, the content, and an optional footer
/// pinned to the bottom. Only the content scrolls. You can push more pages onto the sheet with `push`.
///
/// The returned handle controls the sheet while it is shown. It holds the sheet weakly,
/// so keeping the handle never keeps the sheet alive. After the sheet is dismissed, all calls do nothing.
@MainActor
public final class BottomSheet {
    private weak var controller: BottomSheetController?

    #if DEBUG
    /// Number of live sheets. Use it in debug builds to check for leaks. Not available in release builds.
    public static var liveSheetCount: Int { BottomSheetController.liveCount }
    #endif

    private init(controller: BottomSheetController?) {
        self.controller = controller
    }

    // MARK: Presenting

    /// Presents a view in a sheet.
    ///
    /// The view must get its height from Auto Layout, from top to bottom.
    /// The sheet scrolls it when it is taller than the maximum. A `UIScrollView`, `UITableView`
    /// or `UICollectionView` is used as it is, and its `contentSize` sets the height.
    ///
    /// - Parameters:
    ///   - content: The view to show.
    ///   - header: A view pinned to the top of the page. It must get its height from Auto Layout.
    ///   - footer: A view pinned to the bottom of the page, above the keyboard. It must get its height from Auto Layout.
    ///   - sizing: How the sheet gets its height. Default: follow the content.
    ///   - configuration: Appearance and behavior.
    ///   - presenter: The view controller that presents the sheet. If it already presents something,
    ///     the sheet is presented on top of that.
    ///   - animated: Whether to animate the presentation.
    ///   - completion: Called when the presentation ends.
    /// - Returns: A handle to resize or dismiss the sheet.
    @discardableResult
    public static func present(
        content: UIView,
        header: UIView? = nil,
        footer: UIView? = nil,
        sizing: BottomSheetSizing = .dynamic(),
        configuration: BottomSheetConfiguration = BottomSheetConfiguration(),
        from presenter: UIViewController,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) -> BottomSheet {
        present(.view(content), header, footer, sizing, configuration, presenter, animated, completion)
    }

    /// Presents a view controller in a sheet. The controller does not need a base class.
    ///
    /// The controller's view is sized in the same way as a view.
    /// If its `preferredContentSize` has a height above 0, that height is used instead of Auto Layout.
    /// A `UITableViewController` or `UICollectionViewController` scrolls by itself.
    @discardableResult
    public static func present(
        content: UIViewController,
        header: UIView? = nil,
        footer: UIView? = nil,
        sizing: BottomSheetSizing = .dynamic(),
        configuration: BottomSheetConfiguration = BottomSheetConfiguration(),
        from presenter: UIViewController,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) -> BottomSheet {
        present(.viewController(content), header, footer, sizing, configuration, presenter, animated, completion)
    }

    private static func present(
        _ content: BottomSheetContent,
        _ header: UIView?,
        _ footer: UIView?,
        _ sizing: BottomSheetSizing,
        _ configuration: BottomSheetConfiguration,
        _ presenter: UIViewController,
        _ animated: Bool,
        _ completion: (() -> Void)?
    ) -> BottomSheet {
        // The page cannot live in this sheet. Return a handle that does nothing.
        guard BottomSheetPage.canBePresented(content: content, header: header, footer: footer, from: presenter, existing: []) else {
            DispatchQueue.main.async { completion?() }
            return BottomSheet(controller: nil)
        }
        // A view controller can present only one controller at a time. Present on top of the stack.
        let host = presenter.topmostPresented
        let controller = BottomSheetController(content: content, header: header, footer: footer, sizing: sizing, configuration: configuration)
        controller.prepare(for: host)
        host.present(controller, animated: animated, completion: completion)
        return BottomSheet(controller: controller)
    }

    // MARK: Pages

    /// Slides a new page in. The sheet follows the height of the new page when its sizing follows the content.
    ///
    /// The page below stays loaded and keeps its state, but it gets no appearance callbacks.
    /// A view or controller can be used by one page only. A page that cannot be pushed is refused, and the completion still runs.
    /// Calls that arrive while a page slides run one after the other. The ones that wait skip their animation.
    public func push(
        content: UIView,
        header: UIView? = nil,
        footer: UIView? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        push(.view(content), header, footer, animated, completion)
    }

    /// Slides a new page in with a view controller as its content.
    public func push(
        content: UIViewController,
        header: UIView? = nil,
        footer: UIView? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        push(.viewController(content), header, footer, animated, completion)
    }

    private func push(_ content: BottomSheetContent, _ header: UIView?, _ footer: UIView?, _ animated: Bool, _ completion: (() -> Void)?) {
        guard let controller else {
            DispatchQueue.main.async { completion?() }
            return
        }
        controller.push(content: content, header: header, footer: footer, animated: animated, completion: completion)
    }

    /// Removes the top page. Does nothing when only the first page is left. The completion always runs.
    /// The view or controller of the removed page is given back, so you can use it again.
    public func pop(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let controller else {
            DispatchQueue.main.async { completion?() }
            return
        }
        controller.pop(animated: animated, completion: completion)
    }

    /// Removes all pages except the first one. The completion always runs.
    public func popToRoot(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let controller else {
            DispatchQueue.main.async { completion?() }
            return
        }
        controller.popToRoot(animated: animated, completion: completion)
    }

    /// The number of pages. 1 after `present`. 0 when the sheet is gone.
    public var pageCount: Int { controller?.pageCount ?? 0 }

    // MARK: Runtime controls

    /// Changes the sheet to a fixed height. The sheet is not presented again, and the content keeps its state.
    /// Calls with the same height are ignored.
    public func updateHeight(_ height: CGFloat, animated: Bool) {
        controller?.updateHeight(height, animated: animated)
    }

    /// Changes how the sheet gets its height.
    public func setSizing(_ sizing: BottomSheetSizing, animated: Bool = true) {
        controller?.setSizing(sizing, animated: animated)
    }

    /// Measures the top page again. Call it after a change that is not observed automatically.
    ///
    /// The sheet observes Auto Layout changes, `contentSize` changes and width changes by itself.
    /// It cannot see changes that need no layout pass, such as frame-based layout.
    public func invalidateContentHeight() {
        controller?.invalidateContentHeight()
    }

    /// Moves the sheet to one of the detents of `.detents([...])`. `index` counts from 0.
    public func selectDetent(at index: Int, animated: Bool = true) {
        controller?.selectDetent(at: index, animated: animated)
    }

    /// Dismisses the sheet. The completion always runs, also when the sheet is already gone.
    public func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        guard let controller, controller.presentingViewController != nil else {
            DispatchQueue.main.async { completion?() }
            return
        }
        controller.dismiss(animated: animated, completion: completion)
    }

    /// The appearance of the sheet. Changes apply at once. `nil` when the sheet is gone.
    public var configuration: BottomSheetConfiguration? {
        get { controller?.configuration }
        set { if let newValue { controller?.configuration = newValue } }
    }

    // MARK: Diagnostics

    /// The current sizing numbers. `nil` when the sheet is gone.
    public var diagnostics: BottomSheetDiagnostics? { controller?.diagnostics }

    // MARK: Events

    /// Called once when the sheet has closed, for any reason. Not called when the sheet never appeared.
    /// The sheet and its content are already given back at that point.
    public var onDismiss: ((BottomSheetDismissReason) -> Void)? {
        get { controller?.onDismiss }
        set { controller?.onDismiss = newValue }
    }

    /// Called when the user tries to dismiss the sheet, but `allowsInteractiveDismissal` is false.
    /// Use it to ask "Discard changes?".
    public var onAttemptToDismiss: (() -> Void)? {
        get { controller?.onAttemptToDismiss }
        set { controller?.onAttemptToDismiss = newValue }
    }

    /// Called when the selected detent changes, by the user or by `selectDetent`. It gets the index of the new detent.
    public var onDetentChange: ((Int) -> Void)? {
        get { controller?.onDetentChange }
        set { controller?.onDetentChange = newValue }
    }

    /// Called when a page is added or removed by `push`, `pop` or `popToRoot`. It gets the new number of pages.
    public var onPageChange: ((Int) -> Void)? {
        get { controller?.onPageChange }
        set { controller?.onPageChange = newValue }
    }

    /// Called on the main queue after the numbers change. At most once per run loop turn.
    public var onDiagnosticsChange: ((BottomSheetDiagnostics) -> Void)? {
        get { controller?.onDiagnosticsChange }
        set { controller?.onDiagnosticsChange = newValue }
    }
}

private extension UIViewController {
    /// The controller on top of the presented stack, skipping one that is being dismissed.
    var topmostPresented: UIViewController {
        var top = self
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        return top
    }
}
