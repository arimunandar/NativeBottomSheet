import UIKit
import NativeBottomSheet

final class DynamicControllerDemo: DemoViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        addHeader("A plain UIViewController. No base class is needed.")
        addButton("Present controller, dynamic()") { [weak self] in
            self?.present(ProfileViewController(), sizing: .dynamic())
        }
    }
}

/// An ordinary controller. It does not know it lives in a sheet.
private final class ProfileViewController: UIViewController {
    private let stack = UIStackView()
    private let lifecycle = makeLabel("", style: .caption1, color: .secondaryLabel)
    private var counts = (willAppear: 0, didAppear: 0, willDisappear: 0)
    private var paragraphs = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        let buttons = UIStackView(arrangedSubviews: [
            makeButton("Add text") { [weak self] in self?.addParagraph() },
            makeButton("preferred 420") { [weak self] in self?.preferredContentSize = CGSize(width: 0, height: 420) },
            makeButton("Auto Layout") { [weak self] in self?.preferredContentSize = .zero },
        ])
        buttons.distribution = .fillEqually
        buttons.spacing = 8
        [makeLabel("Embedded controller", style: .headline), lifecycle, makeLabel(loremIpsum, style: .callout), buttons]
            .forEach(stack.addArrangedSubview)
        updateLifecycle()
    }

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); counts.willAppear += 1; updateLifecycle() }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); counts.didAppear += 1; updateLifecycle() }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); counts.willDisappear += 1 }

    private func updateLifecycle() {
        lifecycle.text = "viewWillAppear ×\(counts.willAppear), viewDidAppear ×\(counts.didAppear)"
    }

    private func addParagraph() {
        paragraphs += 1
        stack.insertArrangedSubview(makeLabel("Paragraph \(paragraphs). " + loremIpsum, style: .callout), at: 3)
    }
}
