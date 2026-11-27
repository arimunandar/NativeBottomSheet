import UIKit

/// The layout view of a page. It reports every layout pass, so a header or footer that changes its height is seen.
final class BottomSheetPageView: UIView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

/// One page of a sheet: an optional header, the content, and an optional footer.
/// The header is pinned to the top and the footer to the bottom. The content scrolls between them.
@MainActor
final class BottomSheetPage {
    let content: BottomSheetContent
    let header: UIView?
    let footer: UIView?
    /// The view placed in the sheet.
    let view = BottomSheetPageView()

    /// Called, at most once per run loop turn, when the height of the page may have changed.
    var onChange: (() -> Void)? {
        get { observer.onChange }
        set { observer.onChange = newValue }
    }

    private let observer = BottomSheetContentSizeObserver()
    private let resolver = BottomSheetHeightResolver()
    private var preferredHeightConstraint: NSLayoutConstraint?
    private var originalTranslates: [(view: UIView, value: Bool)] = []
    private var isInstalled = false
    private var isReleased = false

    init(content: BottomSheetContent, header: UIView?, footer: UIView?) {
        self.content = content
        self.header = header
        self.footer = footer
    }

    var childController: UIViewController? {
        if case .viewController(let controller) = content { return controller }
        return nil
    }

    /// The objects a page uses. One object can be used by one page only.
    static func objects(content: BottomSheetContent, header: UIView?, footer: UIView?) -> [AnyObject] {
        var result: [AnyObject] = []
        switch content {
        case .view(let view): result.append(view)
        case .viewController(let controller): result.append(controller)
        }
        if let header { result.append(header) }
        if let footer { result.append(footer) }
        return result
    }

    /// False when the page cannot live in a sheet shown from `presenter`, or when another page already uses part of it.
    static func canBePresented(
        content: BottomSheetContent, header: UIView?, footer: UIView?,
        from presenter: UIViewController, existing: [BottomSheetPage]
    ) -> Bool {
        guard content.canBePresented(from: presenter) else { return false }
        for view in [header, footer].compactMap({ $0 }) where presenter.viewIfLoaded?.isDescendant(of: view) ?? false {
            return false
        }
        let new = objects(content: content, header: header, footer: footer).map(ObjectIdentifier.init)
        guard Set(new).count == new.count else { return false }
        let taken = Set(existing.flatMap { objects(content: $0.content, header: $0.header, footer: $0.footer) }.map(ObjectIdentifier.init))
        return taken.isDisjoint(with: new)
    }

    // MARK: Installing

    /// Builds the page. Content that still sits in another parent is moved here.
    func install(in parent: UIViewController) {
        guard !isInstalled else { return }
        isInstalled = true
        switch content {
        case .viewController(let child):
            if child.parent != nil {
                child.willMove(toParent: nil)
                child.viewIfLoaded?.removeFromSuperview()
                child.removeFromParent()
            }
            parent.addChild(child)
        case .view(let contentView):
            contentView.removeFromSuperview()
        }
        header?.removeFromSuperview()
        footer?.removeFromSuperview()

        let contentView = content.view
        for item in [contentView, header, footer].compactMap({ $0 }) {
            originalTranslates.append((item, item.translatesAutoresizingMaskIntoConstraints))
            item.translatesAutoresizingMaskIntoConstraints = false
        }
        view.translatesAutoresizingMaskIntoConstraints = false

        // `observed` reports content size changes. `body` is the view between the header and the footer.
        let observed: UIScrollView
        let body: UIView
        if let own = content.scrollView {
            // The content scrolls by itself.
            observed = own
            body = contentView
            view.addSubview(contentView)
        } else {
            // Plain content grows with Auto Layout. The page scrolls it when it exceeds the maximum.
            let wrapper = UIScrollView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            wrapper.contentInsetAdjustmentBehavior = .never
            wrapper.alwaysBounceVertical = false
            wrapper.keyboardDismissMode = .interactive
            view.addSubview(wrapper)
            wrapper.addSubview(contentView)
            NSLayoutConstraint.activate([
                contentView.topAnchor.constraint(equalTo: wrapper.contentLayoutGuide.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: wrapper.contentLayoutGuide.bottomAnchor),
                contentView.leadingAnchor.constraint(equalTo: wrapper.contentLayoutGuide.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: wrapper.contentLayoutGuide.trailingAnchor),
                contentView.widthAnchor.constraint(equalTo: wrapper.frameLayoutGuide.widthAnchor),
            ])
            observed = wrapper
            body = wrapper
        }

        var constraints = [
            body.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ]
        if let header {
            view.addSubview(header)
            constraints += [
                header.topAnchor.constraint(equalTo: view.topAnchor),
                header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                body.topAnchor.constraint(equalTo: header.bottomAnchor),
            ]
        } else {
            constraints.append(body.topAnchor.constraint(equalTo: view.topAnchor))
        }
        if let footer {
            view.addSubview(footer)
            constraints += [
                footer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                body.bottomAnchor.constraint(equalTo: footer.topAnchor),
            ]
        } else {
            constraints.append(body.bottomAnchor.constraint(equalTo: view.bottomAnchor))
        }
        NSLayoutConstraint.activate(constraints)

        if case .viewController(let child) = content { child.didMove(toParent: parent) }
        observer.observe(observed)
        view.onLayout = { [weak self] in self?.observer.contentDidChange() }
        updatePreferredHeightConstraint()
    }

    /// Gives the content, the header and the footer back, so the app can use them again.
    func release() {
        guard isInstalled, !isReleased else { return }
        isReleased = true
        preferredHeightConstraint?.isActive = false
        preferredHeightConstraint = nil
        view.onLayout = nil
        observer.onChange = nil
        if case .viewController(let child) = content {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        } else {
            content.view.removeFromSuperview()
        }
        header?.removeFromSuperview()
        footer?.removeFromSuperview()
        view.removeFromSuperview()
        for item in originalTranslates { item.view.translatesAutoresizingMaskIntoConstraints = item.value }
    }

    // MARK: Measuring

    /// The height of the page at `width`: header, content and footer. Includes `topInset`.
    func height(width: CGFloat, topInset: CGFloat) -> CGFloat {
        let size = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        func fitting(_ view: UIView?) -> CGFloat {
            view?.systemLayoutSizeFitting(size, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height ?? 0
        }
        let body = resolver.contentHeight(of: content, width: width, topInset: topInset)
        return max(body + fitting(header) + fitting(footer), 0)
    }

    /// Call when the height may have changed in a way that is not observed automatically.
    func contentDidChange() {
        observer.contentDidChange()
    }

    /// Call when the `preferredContentSize` of the content controller changed.
    func preferredContentSizeDidChange() {
        updatePreferredHeightConstraint()
        observer.contentDidChange()
    }

    private func updatePreferredHeightConstraint() {
        preferredHeightConstraint?.isActive = false
        preferredHeightConstraint = nil
        guard let child = childController, content.scrollView == nil, child.preferredContentSize.height > 0 else { return }
        let constraint = child.view.heightAnchor.constraint(equalToConstant: child.preferredContentSize.height)
        constraint.priority = .defaultHigh
        constraint.isActive = true
        preferredHeightConstraint = constraint
    }
}
