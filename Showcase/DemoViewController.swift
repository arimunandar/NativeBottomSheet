import UIKit
import NativeBottomSheet

/// Base screen for a demo. It shows the debug panel and a column of controls.
class DemoViewController: UIViewController {
    let controls = UIStackView()
    private let debugLabel = UILabel()
    private(set) var sheet: BottomSheet?

    /// Undimmed by default, so the controls on this screen stay usable.
    var configuration = BottomSheetConfiguration(showsGrabber: true, dimsBackground: false)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Dismiss", primaryAction: UIAction { [weak self] _ in
            self?.sheet?.dismiss(animated: true)
        })

        debugLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        debugLabel.numberOfLines = 0
        debugLabel.text = "No sheet presented" + String(repeating: "\n", count: 4)
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 10
        card.translatesAutoresizingMaskIntoConstraints = false
        debugLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(debugLabel)

        controls.axis = .vertical
        controls.spacing = 10
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        controls.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(controls)

        view.addSubview(card)
        view.addSubview(scrollView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            debugLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            debugLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            debugLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            debugLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            scrollView.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            controls.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            controls.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            controls.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            controls.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            controls.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }

    // MARK: Presenting

    func present(_ content: UIView, sizing: BottomSheetSizing) {
        dismissCurrentSheet { [self] in
            track(BottomSheet.present(content: content, sizing: sizing, configuration: configuration, from: self))
        }
    }

    func present(_ content: UIViewController, sizing: BottomSheetSizing) {
        dismissCurrentSheet { [self] in
            track(BottomSheet.present(content: content, sizing: sizing, configuration: configuration, from: self))
        }
    }

    private func dismissCurrentSheet(then next: @escaping () -> Void) {
        if presentedViewController != nil {
            dismiss(animated: false, completion: next)
        } else {
            next()
        }
    }

    private func track(_ newSheet: BottomSheet) {
        sheet = newSheet
        newSheet.onDiagnosticsChange = { [weak self] in self?.render($0) }
        if let diagnostics = newSheet.diagnostics { render(diagnostics) }
    }

    private func render(_ d: BottomSheetDiagnostics) {
        func pt(_ value: CGFloat?) -> String { value.map { String(format: "%.1f", $0) } ?? "–" }
        debugLabel.text = """
        sizing    \(d.sizingMode)  (detent \(d.selectedDetentIndex))
        requested \(pt(d.requestedHeight))   measured \(pt(d.measuredContentHeight))
        resolved  \(pt(d.resolvedDetentHeight))   actual   \(pt(d.actualSheetHeight))
        max       \(pt(d.maximumDetentValue))
        layouts   \(d.layoutPasses)   invalidations \(d.invalidations)
        """
    }

    // MARK: Controls

    @discardableResult
    func addButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = title
        let button = UIButton(configuration: buttonConfiguration, primaryAction: UIAction { _ in action() })
        controls.addArrangedSubview(button)
        return button
    }

    func addHeader(_ text: String) {
        let label = UILabel()
        label.text = text.uppercased()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        controls.addArrangedSubview(label)
    }

    func addRow(_ title: String, _ control: UIView) {
        let label = UILabel()
        label.text = title
        let row = UIStackView(arrangedSubviews: [label, control])
        row.spacing = 12
        row.alignment = .center
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        controls.addArrangedSubview(row)
    }
}
