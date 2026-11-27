import UIKit
import NativeBottomSheet

final class HeaderFooterPushDemo: DemoViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        addHeader("The header and the footer stay in place. Only the content scrolls.")
        addButton("Header + long content + footer, dynamic(max 400)", prominent: true) { [weak self] in
            guard let self else { return }
            present(StackContentView((1...25).map { makeLabel("Row \($0)") }),
                    header: makeHeader(title: "Header", back: nil),
                    footer: makeFooter(title: "Footer button") { [weak self] in self?.sheet?.dismiss(animated: true) },
                    sizing: .dynamic(maxHeight: 400))
        }
        addHeader("Pages. The sheet follows the height of the page on top.")
        addButton("Settings with pages, dynamic(max 520)", prominent: true) { [weak self] in
            guard let self else { return }
            present(makeRootContent(),
                    header: makeHeader(title: "Settings", back: nil),
                    footer: makeFooter(title: "Close") { [weak self] in self?.sheet?.dismiss(animated: true) },
                    sizing: .dynamic(maxHeight: 520))
        }
        addButton("Push 5 pages in a row (no waiting)") { [weak self] in
            for number in 1...5 {
                self?.sheet?.push(content: StackContentView([makeLabel("Page \(number)", style: .headline)]),
                                  header: self?.makeHeader(title: "Page \(number)", back: { self?.sheet?.pop() }))
            }
        }
        addButton("Pop to root") { [weak self] in self?.sheet?.popToRoot() }
    }

    // MARK: Pages

    private func makeRootContent() -> UIView {
        StackContentView([
            makeButton("Account (short page)") { [weak self] in self?.pushDetail(title: "Account", paragraphs: 1) },
            makeButton("About (medium page)") { [weak self] in self?.pushDetail(title: "About", paragraphs: 4) },
            makeButton("Notifications (long page, scrolls)") { [weak self] in self?.pushDetail(title: "Notifications", paragraphs: 14) },
            makeButton("Profile form (keyboard)") { [weak self] in self?.pushForm() },
        ])
    }

    private func pushDetail(title: String, paragraphs: Int) {
        sheet?.push(
            content: StackContentView((1...paragraphs).map { makeLabel("\($0). " + loremIpsum, style: .callout) }),
            header: makeHeader(title: title, back: { [weak self] in self?.sheet?.pop() }),
            footer: makeFooter(title: "Back to start") { [weak self] in self?.sheet?.popToRoot() }
        )
    }

    private func pushForm() {
        let fields = (1...3).map { index -> UITextField in
            let field = UITextField()
            field.borderStyle = .roundedRect
            field.placeholder = "Field \(index)"
            return field
        }
        sheet?.push(
            content: StackContentView([makeLabel("Tap a field. The footer rises above the keyboard.", style: .callout)] + fields),
            header: makeHeader(title: "Profile", back: { [weak self] in self?.sheet?.pop() }),
            footer: makeFooter(title: "Save") { [weak self] in self?.sheet?.popToRoot() }
        )
    }

    // MARK: Header and footer

    /// A bar. Its height comes from its Auto Layout constraints, from top to bottom.
    private func makeBar(_ arranged: [UIView], isHeader: Bool) -> UIView {
        let bar = UIView()
        bar.backgroundColor = .secondarySystemBackground
        let stack = UIStackView(arrangedSubviews: arranged)
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: bar.topAnchor, constant: isHeader ? 18 : 12),
            stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
        ])
        return bar
    }

    private func makeHeader(title: String, back: (() -> Void)?) -> UIView {
        var items: [UIView] = []
        if let back {
            let button = makeButton("‹ Back", action: back)
            button.setContentHuggingPriority(.required, for: .horizontal)
            items.append(button)
        }
        items.append(makeLabel(title, style: .headline))
        return makeBar(items, isHeader: true)
    }

    private func makeFooter(title: String, action: @escaping () -> Void) -> UIView {
        let button = UIButton(configuration: .filled(), primaryAction: UIAction { _ in action() })
        button.configuration?.title = title
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let bar = makeBar([button], isHeader: false)
        (bar.subviews[0] as? UIStackView)?.alignment = .fill
        return bar
    }
}
