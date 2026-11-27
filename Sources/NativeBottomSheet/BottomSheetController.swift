import UIKit

/// Sizing numbers of a sheet, for debug screens and tests. All heights are in points.
public struct BottomSheetDiagnostics {
    public var sizingMode = ""
    /// Set only when the sizing is `.fixed`.
    public var requestedHeight: CGFloat?
    public var measuredContentHeight: CGFloat = 0
    /// Last height the detent resolver returned for the selected detent.
    /// nil for the system detents (`.medium`, `.large`). UIKit does not ask us for their height.
    public var resolvedDetentHeight: CGFloat?
    public var actualSheetHeight: CGFloat = 0
    public var maximumDetentValue: CGFloat = 0
    public var layoutPasses = 0
    public var invalidations = 0
    public var selectedDetentIndex = 0

    public init() {}
}

/// The presented view controller. It hosts the content and drives the sheet.
@MainActor
final class BottomSheetController: UIViewController, UISheetPresentationControllerDelegate {
    #if DEBUG
    /// Live instances. Used to check for leaks.
    private(set) static var liveCount = 0
    #endif

    private(set) var sizing: BottomSheetSizing
    var configuration: BottomSheetConfiguration {
        didSet { applyConfiguration() }
    }
    private(set) var diagnostics = BottomSheetDiagnostics()
    var onDiagnosticsChange: ((BottomSheetDiagnostics) -> Void)?

    private let content: BottomSheetContent
    private let resolver = BottomSheetHeightResolver()
    private let observer = BottomSheetContentSizeObserver()

    /// Cached content height. It is the detent height, so it excludes the bottom safe area.
    private var measuredHeight: CGFloat = 0
    private var measuredWidth: CGFloat = 0
    private var measuredTopInset: CGFloat = 0
    private var resolvedHeights: [Int: CGFloat] = [:]
    private var preferredHeightConstraint: NSLayoutConstraint?
    private var isDiagnosticsScheduled = false
    private let grabberView = UIView()
    private var originalTranslatesAutoresizing = true
    private var isContentReleased = false

    init(content: BottomSheetContent, sizing: BottomSheetSizing, configuration: BottomSheetConfiguration) {
        self.content = content
        self.sizing = sizing.sanitized
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
        #if DEBUG
        Self.liveCount += 1
        #endif
        modalPresentationStyle = .pageSheet
        observer.onChange = { [weak self] in self?.contentDidChange() }
        if let sheet = sheetPresentationController {
            sheet.delegate = self
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.detents = makeDetents()
            sheet.selectedDetentIdentifier = identifier(at: 0)
        }
        applyConfiguration()
        refreshDiagnostics()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    #if DEBUG
    deinit { MainActor.assumeIsolated { Self.liveCount -= 1 } }
    #endif

    // MARK: Runtime controls

    func setSizing(_ requested: BottomSheetSizing, animated: Bool) {
        let newSizing = requested.sanitized
        guard newSizing != sizing else { return }
        sizing = newSizing
        resolvedHeights = [:]
        diagnostics.selectedDetentIndex = min(diagnostics.selectedDetentIndex, sizing.detentList.count - 1)
        guard let sheet = sheetPresentationController else { return }
        applyToSheet(animated: animated) {
            sheet.detents = self.makeDetents()
            sheet.selectedDetentIdentifier = self.identifier(at: self.diagnostics.selectedDetentIndex)
            self.applyConfiguration()
            sheet.invalidateDetents()
        }
    }

    func updateHeight(_ height: CGFloat, animated: Bool) {
        setSizing(.fixed(height), animated: animated)
    }

    /// Call when the content changed in a way that is not observed automatically.
    func invalidateContentHeight() {
        observer.contentDidChange()
    }

    func selectDetent(at index: Int, animated: Bool) {
        guard sizing.detentList.indices.contains(index), let sheet = sheetPresentationController else { return }
        diagnostics.selectedDetentIndex = index
        diagnostics.resolvedDetentHeight = resolvedHeights[index]
        applyToSheet(animated: animated) { sheet.selectedDetentIdentifier = self.identifier(at: index) }
    }

    // MARK: Presentation

    /// Measures the content before the first presentation, so the sheet opens at the right height.
    func prepare(for presenter: UIViewController) {
        // Do not load the presenter's view just to measure. Without a window the width is a guess,
        // and the first layout in the sheet corrects it.
        let window = presenter.viewIfLoaded?.window
        let measured = window?.bounds.width ?? presenter.viewIfLoaded?.bounds.width ?? 0
        let width = measured > 0 ? measured : 375
        loadViewIfNeeded()
        view.frame = CGRect(x: 0, y: 0, width: width, height: window?.bounds.height ?? 800)
        view.layoutIfNeeded()
        measure(width: width, topInset: 0)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = configuration.backgroundColor ?? .systemBackground
        installContent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        diagnostics.layoutPasses += 1
        diagnostics.actualSheetHeight = view.frame.height
        if view.bounds.width != measuredWidth || view.safeAreaInsets.top != measuredTopInset {
            observer.contentDidChange()
        }
        scheduleDiagnostics()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { releaseContent() }
    }

    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        updatePreferredHeightConstraint()
        observer.contentDidChange()
    }

    // MARK: Content

    private func installContent() {
        adoptContent()
        let contentView = content.view
        originalTranslatesAutoresizing = contentView.translatesAutoresizingMaskIntoConstraints
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // `observed` reports content size changes. `pinned` is the view placed in the sheet.
        let observed: UIScrollView
        let pinned: UIView
        if let own = content.scrollView {
            // The content scrolls by itself.
            observed = own
            pinned = contentView
            view.addSubview(contentView)
        } else {
            // Plain content grows with Auto Layout. The sheet scrolls it when it exceeds the maximum.
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
            pinned = wrapper
        }
        // The pinned view fills the safe area, and stops above the keyboard.
        NSLayoutConstraint.activate([
            pinned.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pinned.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            pinned.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            pinned.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
        if case .viewController(let child) = content { child.didMove(toParent: self) }

        // Own grabber, used only when `grabberColor` is set. It sits on top and never takes touches.
        grabberView.translatesAutoresizingMaskIntoConstraints = false
        grabberView.isUserInteractionEnabled = false
        grabberView.layer.cornerRadius = 2.5
        view.addSubview(grabberView)
        NSLayoutConstraint.activate([
            grabberView.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            grabberView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: 36),
            grabberView.heightAnchor.constraint(equalToConstant: 5),
        ])
        applyConfiguration()
        observer.observe(observed)
        updatePreferredHeightConstraint()
    }

    /// Takes the content. Content that still sits in another hierarchy is moved here.
    private func adoptContent() {
        switch content {
        case .viewController(let child):
            if child.parent != nil {
                child.willMove(toParent: nil)
                child.viewIfLoaded?.removeFromSuperview()
                child.removeFromParent()
            }
            addChild(child)
        case .view(let view):
            view.removeFromSuperview()
        }
    }

    /// Gives the content back, so the app can use it again, for example in the next sheet.
    /// Runs when the sheet is dismissed.
    func releaseContent() {
        guard isViewLoaded, !isContentReleased else { return }
        isContentReleased = true
        preferredHeightConstraint?.isActive = false
        preferredHeightConstraint = nil
        let contentView = content.view
        if case .viewController(let child) = content {
            child.willMove(toParent: nil)
            contentView.removeFromSuperview()
            child.removeFromParent()
        } else {
            contentView.removeFromSuperview()
        }
        contentView.translatesAutoresizingMaskIntoConstraints = originalTranslatesAutoresizing
        onDiagnosticsChange = nil
    }

    private func updatePreferredHeightConstraint() {
        preferredHeightConstraint?.isActive = false
        preferredHeightConstraint = nil
        guard case .viewController(let child) = content, content.scrollView == nil,
              child.preferredContentSize.height > 0 else { return }
        let constraint = child.view.heightAnchor.constraint(equalToConstant: child.preferredContentSize.height)
        constraint.priority = .defaultHigh
        constraint.isActive = true
        preferredHeightConstraint = constraint
    }

    // MARK: Measuring and applying

    @discardableResult
    private func measure(width: CGFloat, topInset: CGFloat) -> Bool {
        let height = resolver.contentHeight(of: content, width: width, topInset: topInset)
        measuredWidth = width
        measuredTopInset = topInset
        guard abs(height - measuredHeight) >= 0.5 else { return false }
        measuredHeight = height
        diagnostics.measuredContentHeight = height
        return true
    }

    /// Runs on the observer's coalesced callback. Never runs inside a layout pass.
    private func contentDidChange() {
        guard view.window != nil, view.bounds.width > 0 else { return }
        // Skip when the height did not change. This stops invalidation loops.
        guard measure(width: view.bounds.width, topInset: view.safeAreaInsets.top) else { return }
        if sizing.followsContent, let sheet = sheetPresentationController {
            applyToSheet(animated: true) { sheet.invalidateDetents() }
        }
        scheduleDiagnostics()
    }

    private func applyToSheet(animated: Bool, _ change: @escaping () -> Void) {
        guard let sheet = sheetPresentationController else { return }
        diagnostics.invalidations += 1
        if animated, view.window != nil {
            sheet.animateChanges(change)
        } else {
            change()
        }
        scheduleDiagnostics()
    }

    // MARK: Detents and appearance

    private func identifier(at index: Int) -> UISheetPresentationController.Detent.Identifier {
        if case .medium = sizing.detentList[index] { return .medium }
        // `.large` is a custom detent, see `BottomSheetHeightResolver.detentHeight`.
        return UISheetPresentationController.Detent.Identifier("bottomsheet.\(index)")
    }

    private func makeDetents() -> [UISheetPresentationController.Detent] {
        sizing.detentList.enumerated().map { index, item in
            if case .medium = item { return .medium() }
            return .custom(identifier: identifier(at: index)) { [weak self] context in
                self?.resolveHeight(of: item, at: index, maximum: context.maximumDetentValue)
            }
        }
    }

    /// Called by UIKit while it lays out the sheet. Reads cached values only.
    private func resolveHeight(of item: BottomSheetSizing, at index: Int, maximum: CGFloat) -> CGFloat {
        let height = resolver.detentHeight(for: item, contentHeight: measuredHeight, maximum: maximum)
        resolvedHeights[index] = height
        diagnostics.maximumDetentValue = maximum
        diagnostics.resolvedDetentHeight = resolvedHeights[diagnostics.selectedDetentIndex]
        return height
    }

    private func applyConfiguration() {
        if isViewLoaded { view.backgroundColor = configuration.backgroundColor ?? .systemBackground }
        grabberView.backgroundColor = configuration.grabberColor
        grabberView.isHidden = !(configuration.showsGrabber && configuration.grabberColor != nil)
        isModalInPresentation = !configuration.allowsInteractiveDismissal
        guard let sheet = sheetPresentationController else { return }
        sheet.preferredCornerRadius = configuration.cornerRadius.flatMap { $0.isFinite ? max($0, 0) : nil }
        sheet.prefersGrabberVisible = configuration.showsGrabber && configuration.grabberColor == nil
        sheet.prefersScrollingExpandsWhenScrolledToEdge = configuration.prefersScrollingExpandsWhenScrolledToEdge
        #if compiler(>=6.2.1) // The SDK of Xcode 26.1 has `UIColorEffect(color:)`.
        if #available(iOS 26.1, *) {
            let effect = configuration.backgroundColor.map { UIColorEffect(color: $0) }
            sheet.detents.forEach { $0.backgroundEffect = effect }
        }
        #endif
        sheet.largestUndimmedDetentIdentifier = configuration.dimsBackground ? nil : identifier(at: sizing.detentList.count - 1)
    }

    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheet: UISheetPresentationController) {
        guard let selected = sheet.selectedDetentIdentifier,
              let index = sizing.detentList.indices.first(where: { identifier(at: $0) == selected }) else { return }
        diagnostics.selectedDetentIndex = index
        diagnostics.resolvedDetentHeight = resolvedHeights[index]
        scheduleDiagnostics()
    }

    // MARK: Diagnostics

    private func refreshDiagnostics() {
        diagnostics.sizingMode = sizing.description
        if case .fixed(let height) = sizing { diagnostics.requestedHeight = height } else { diagnostics.requestedHeight = nil }
    }

    private func scheduleDiagnostics() {
        refreshDiagnostics()
        guard onDiagnosticsChange != nil, !isDiagnosticsScheduled else { return }
        isDiagnosticsScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isDiagnosticsScheduled = false
            onDiagnosticsChange?(diagnostics)
        }
    }
}
