import UIKit
import NativeBottomSheet

/// Base screen for a demo. It shows the live numbers of the sheet and a column of controls.
class DemoViewController: UIViewController {
    let controls = UIStackView()
    private let metrics = MetricsView()
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

        metrics.translatesAutoresizingMaskIntoConstraints = false
        controls.axis = .vertical
        controls.spacing = 10
        controls.translatesAutoresizingMaskIntoConstraints = false
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.addSubview(controls)

        view.addSubview(metrics)
        view.addSubview(scrollView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            metrics.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            metrics.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            metrics.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: metrics.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            controls.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            controls.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            controls.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            controls.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            controls.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }

    // MARK: Presenting

    func present(_ content: UIView, header: UIView? = nil, footer: UIView? = nil, sizing: BottomSheetSizing) {
        dismissCurrentSheet { [self] in
            track(BottomSheet.present(content: content, header: header, footer: footer, sizing: sizing, configuration: configuration, from: self))
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
        newSheet.onDiagnosticsChange = { [weak self] in self?.metrics.update($0) }
        newSheet.onDismiss = { [weak self] reason in
            self?.metrics.showEvent(reason == .interactive ? "dismissed by the user" : "dismissed by code")
            self?.metrics.update(nil)
        }
        newSheet.onAttemptToDismiss = { [weak self] in self?.metrics.showEvent("the user tried to dismiss, but it is blocked") }
        newSheet.onDetentChange = { [weak self] index in self?.metrics.showEvent("detent changed to \(index)") }
        newSheet.onPageChange = { [weak self] count in self?.metrics.showEvent("now \(count) page\(count == 1 ? "" : "s")") }
        metrics.update(newSheet.diagnostics)
    }

    // MARK: Controls

    /// A button. A prominent button opens a sheet. The others change a sheet or the screen.
    @discardableResult
    func addButton(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> UIButton {
        var buttonConfiguration: UIButton.Configuration = prominent ? .filled() : .tinted()
        buttonConfiguration.title = title
        buttonConfiguration.cornerStyle = .large
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        if prominent {
            buttonConfiguration.image = UIImage(systemName: "rectangle.bottomthird.inset.filled")
            buttonConfiguration.imagePadding = 8
        }
        let button = UIButton(configuration: buttonConfiguration, primaryAction: UIAction { _ in action() })
        controls.addArrangedSubview(button)
        return button
    }

    /// A short note above a group of controls.
    func addHeader(_ text: String) {
        if let last = controls.arrangedSubviews.last { controls.setCustomSpacing(22, after: last) }
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        controls.addArrangedSubview(label)
        controls.setCustomSpacing(8, after: label)
    }

    /// A row with a title and a control, on a card.
    func addRow(_ title: String, _ control: UIView) {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [label, control])
        row.spacing = 12
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12
        card.layer.cornerCurve = .continuous
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
        ])
        controls.addArrangedSubview(card)
    }
}
