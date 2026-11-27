import UIKit
import NativeBottomSheet

/// A card with the live numbers of a sheet. A value that changes flashes in the tint color.
final class MetricsView: UIView {
    private let modeLabel = UILabel()
    private let detentLabel = UILabel()
    private let eventLabel = UILabel()
    private var valueLabels: [String: UILabel] = [:]
    private let titles = ["Requested", "Content", "Resolved", "Actual", "Max", "Layouts", "Invalidations", "Pages"]

    init() {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous

        detentLabel.font = .preferredFont(forTextStyle: .footnote)
        detentLabel.textColor = .tintColor
        detentLabel.setContentHuggingPriority(.required, for: .horizontal)
        detentLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let top = UIStackView(arrangedSubviews: [modeLabel, detentLabel])
        top.alignment = .firstBaseline
        top.spacing = 8

        modeLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        modeLabel.numberOfLines = 0
        modeLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let tiles = titles.map(makeTile)
        let rows = stride(from: 0, to: tiles.count, by: 4).map { start -> UIStackView in
            let row = UIStackView(arrangedSubviews: Array(tiles[start..<min(start + 4, tiles.count)]))
            row.distribution = .fillEqually
            row.spacing = 8
            return row
        }
        eventLabel.font = .preferredFont(forTextStyle: .footnote)
        eventLabel.textColor = .secondaryLabel
        eventLabel.numberOfLines = 0
        eventLabel.text = "Last event: none yet"
        let stack = UIStackView(arrangedSubviews: [top] + rows + [eventLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(12, after: top)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])
        update(nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func makeTile(_ title: String) -> UIView {
        let value = UILabel()
        value.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .monospacedDigitSystemFont(ofSize: 16, weight: .semibold))
        value.adjustsFontSizeToFitWidth = true
        value.minimumScaleFactor = 0.7
        let caption = UILabel()
        caption.text = title
        caption.font = .preferredFont(forTextStyle: .caption2)
        caption.textColor = .secondaryLabel
        caption.adjustsFontSizeToFitWidth = true
        caption.minimumScaleFactor = 0.7
        valueLabels[title] = value
        let tile = UIStackView(arrangedSubviews: [value, caption])
        tile.axis = .vertical
        tile.spacing = 1
        return tile
    }

    /// Shows the numbers of a sheet. `nil` means no sheet is presented.
    func update(_ d: BottomSheetDiagnostics?) {
        func points(_ value: CGFloat?) -> String {
            guard let value, !value.isNaN else { return "–" }
            if value.isInfinite { return value > 0 ? "max" : "–" }   // Int(value) would trap on infinity
            return value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
        }
        modeLabel.text = d?.sizingMode ?? "No sheet presented"
        modeLabel.textColor = d == nil ? .tertiaryLabel : .label
        detentLabel.text = d.map { "Detent \($0.selectedDetentIndex)" }
        set("Requested", points(d?.requestedHeight))
        set("Content", d.map { points($0.measuredContentHeight) } ?? "–")
        set("Resolved", points(d?.resolvedDetentHeight))
        set("Actual", d.map { points($0.actualSheetHeight) } ?? "–")
        set("Max", d.map { points($0.maximumDetentValue) } ?? "–")
        set("Layouts", d.map { "\($0.layoutPasses)" } ?? "–")
        set("Invalidations", d.map { "\($0.invalidations)" } ?? "–")
        set("Pages", d.map { "\($0.pageCount)" } ?? "–")
    }

    /// Shows the last event the sheet reported to the app, for example a dismissal. It flashes.
    func showEvent(_ text: String) {
        eventLabel.text = "Last event: \(text)"
        eventLabel.textColor = .tintColor
        UIView.transition(with: eventLabel, duration: 1.2, options: [.allowUserInteraction, .transitionCrossDissolve]) {
            self.eventLabel.textColor = .secondaryLabel
        }
    }

    private func set(_ title: String, _ text: String) {
        guard let label = valueLabels[title] else { return }
        let changed = label.text != nil && label.text != text && text != "–"
        label.text = text
        label.textColor = text == "–" ? .tertiaryLabel : .label
        guard changed else { return }
        label.textColor = .tintColor
        UIView.transition(with: label, duration: 0.8, options: [.allowUserInteraction, .transitionCrossDissolve]) {
            label.textColor = .label
        }
    }
}
