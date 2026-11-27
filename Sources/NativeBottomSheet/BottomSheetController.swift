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
    /// Number of pages in the sheet. 1 means no page was pushed.
    public var pageCount = 1

    public init() {}
}

/// The presented view controller. It hosts a stack of pages and drives the sheet.
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

    /// The pages. The last one is on top. There is always at least one until the sheet releases its content.
    private(set) var pages: [BottomSheetPage]
    private let resolver = BottomSheetHeightResolver()

    /// Cached height of the top page. It is the detent height, so it excludes the bottom safe area.
    private var measuredHeight: CGFloat = 0
    private var measuredWidth: CGFloat = 0
    private var measuredTopInset: CGFloat = 0
    private var resolvedHeights: [Int: CGFloat] = [:]
    private var isDiagnosticsScheduled = false
    private let grabberView = UIView()
    private var isContentReleased = false

    /// Push and pop requests run one after the other.
    private var queue: [(animated: Bool, completion: (() -> Void)?, run: (_ animated: Bool, _ done: @escaping () -> Void) -> Void)] = []
    private var isTransitioning = false

    init(content: BottomSheetContent, header: UIView? = nil, footer: UIView? = nil, sizing: BottomSheetSizing, configuration: BottomSheetConfiguration) {
        self.pages = [BottomSheetPage(content: content, header: header, footer: footer)]
        self.sizing = sizing.sanitized
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
        #if DEBUG
        Self.liveCount += 1
        #endif
        modalPresentationStyle = .pageSheet
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
        pages.last?.contentDidChange()
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
        view.clipsToBounds = true
        installGrabber()
        mount(pages[0])
        applyConfiguration()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        diagnostics.layoutPasses += 1
        diagnostics.actualSheetHeight = view.frame.height
        if view.bounds.width != measuredWidth || view.safeAreaInsets.top != measuredTopInset {
            pages.last?.contentDidChange()
        }
        scheduleDiagnostics()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { releaseContent() }
    }

    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        pages.first { $0.childController === container }?.preferredContentSizeDidChange()
    }

    /// Gives all content back, so the app can use it again, for example in the next sheet.
    /// Runs when the sheet is dismissed.
    func releaseContent() {
        guard isViewLoaded, !isContentReleased else { return }
        isContentReleased = true
        queue.removeAll()
        pages.forEach { $0.release() }
        onDiagnosticsChange = nil
    }

    // MARK: Pages

    var pageCount: Int { pages.count }

    /// Whether a page with this content could be pushed now.
    func canPush(content: BottomSheetContent, header: UIView?, footer: UIView?) -> Bool {
        isViewLoaded && !isContentReleased
            && BottomSheetPage.canBePresented(content: content, header: header, footer: footer, from: self, existing: pages)
    }

    func push(content: BottomSheetContent, header: UIView?, footer: UIView?, animated: Bool, completion: (() -> Void)?) {
        guard canPush(content: content, header: header, footer: footer) else {
            DispatchQueue.main.async { completion?() }
            return
        }
        let page = BottomSheetPage(content: content, header: header, footer: footer)
        enqueue(animated: animated, completion: completion) { [weak self] animated, done in
            guard let self, !isContentReleased else { return done() }
            let outgoing = pages[pages.count - 1]
            pages.append(page)
            mount(page)
            view.layoutIfNeeded()
            measureAndApply()
            let shift = slideDistance
            guard animated else {
                outgoing.view.isHidden = true
                return done()
            }
            page.view.transform = CGAffineTransform(translationX: shift, y: 0)
            UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseInOut) {
                page.view.transform = .identity
                outgoing.view.transform = CGAffineTransform(translationX: -shift * 0.3, y: 0)
                outgoing.view.alpha = 0
            } completion: { _ in
                outgoing.view.isHidden = true
                outgoing.view.transform = .identity
                outgoing.view.alpha = 1
                done()
            }
        }
    }

    /// Removes the top page. Does nothing when only one page is left.
    func pop(animated: Bool, completion: (() -> Void)?) {
        enqueue(animated: animated, completion: completion) { [weak self] animated, done in
            guard let self else { return done() }
            popPages(keeping: pages.count - 1, animated: animated, done: done)
        }
    }

    /// Removes all pages except the first one.
    func popToRoot(animated: Bool, completion: (() -> Void)?) {
        enqueue(animated: animated, completion: completion) { [weak self] animated, done in
            guard let self else { return done() }
            popPages(keeping: 1, animated: animated, done: done)
        }
    }

    private func popPages(keeping count: Int, animated: Bool, done: @escaping () -> Void) {
        guard !isContentReleased, count >= 1, pages.count > count else { return done() }
        let leaving = Array(pages[count...])
        pages.removeSubrange(count...)
        let revealed = pages[count - 1]
        let top = leaving[leaving.count - 1]
        revealed.view.isHidden = false
        measureAndApply()
        let finish = {
            leaving.forEach { $0.release() }
            done()
        }
        guard animated else { return finish() }
        let shift = slideDistance
        revealed.view.transform = CGAffineTransform(translationX: -shift * 0.3, y: 0)
        revealed.view.alpha = 0
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseInOut) {
            revealed.view.transform = .identity
            revealed.view.alpha = 1
            top.view.transform = CGAffineTransform(translationX: shift, y: 0)
        } completion: { _ in finish() }
    }

    /// Runs one request at a time. Requests that wait behind another one skip their animation,
    /// so a quick series of calls finishes fast.
    private func enqueue(animated: Bool, completion: (() -> Void)?, _ run: @escaping (_ animated: Bool, _ done: @escaping () -> Void) -> Void) {
        queue.append((animated, completion, run))
        runNext()
    }

    private func runNext() {
        guard !isTransitioning, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        isTransitioning = true
        let animated = next.animated && queue.isEmpty && view.window != nil
        next.run(animated) { [weak self] in
            next.completion?()
            self?.isTransitioning = false
            self?.runNext()
        }
    }

    /// How far a page slides. The sign follows the layout direction.
    private var slideDistance: CGFloat {
        (view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? -1 : 1) * view.bounds.width
    }

    private func installGrabber() {
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
    }

    /// Puts a page in the sheet. It fills the safe area, and stops above the keyboard.
    private func mount(_ page: BottomSheetPage) {
        page.install(in: self)
        view.insertSubview(page.view, belowSubview: grabberView)
        NSLayoutConstraint.activate([
            page.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            page.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            page.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            page.view.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
        page.onChange = { [weak self, weak page] in
            guard let self, let page, page === pages.last else { return }
            contentDidChange()
        }
    }

    // MARK: Measuring and applying

    @discardableResult
    private func measure(width: CGFloat, topInset: CGFloat) -> Bool {
        guard let page = pages.last else { return false }
        let height = page.height(width: width, topInset: topInset)
        measuredWidth = width
        measuredTopInset = topInset
        guard abs(height - measuredHeight) >= 0.5 else { return false }
        measuredHeight = height
        diagnostics.measuredContentHeight = height
        return true
    }

    /// Runs on the observer's coalesced callback. Never runs inside a layout pass.
    private func contentDidChange() {
        guard view.window != nil else { return }
        measureAndApply()
    }

    /// Measures the top page, and invalidates the detents when the height changed.
    /// Skips when the height did not change. This stops invalidation loops.
    private func measureAndApply() {
        guard view.bounds.width > 0,
              measure(width: view.bounds.width, topInset: view.safeAreaInsets.top) else { return }
        if sizing.followsContent, let sheet = sheetPresentationController {
            applyToSheet(animated: view.window != nil) { sheet.invalidateDetents() }
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
        diagnostics.pageCount = pages.count
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
